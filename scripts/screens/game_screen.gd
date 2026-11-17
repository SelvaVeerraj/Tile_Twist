extends "res://scripts/screens/screen_base.gd"
## Active gameplay (landscape).
##   left  : home button, level info, moves, placed tiles, status text
##   centre: countdown pill + square puzzle board
##   right : pause, sound, preview, hint, restart
##
## State machine:
##   INTRO   – memorize preview + shuffle animation, input disabled
##   READY   – board interactive, timer waits for the first touch
##   PLAYING – timer counting down
##   PAUSED  – timer frozen, pause menu open
##   WON / FAILED – final; timer can never run again in these states
##
## Params: {"mode": "campaign" | "free" | "daily", "difficulty": String, "level": int}

const PuzzleLogic = preload("res://scripts/core/puzzle_logic.gd")
const LevelConfig = preload("res://scripts/core/level_config.gd")
const PuzzleBoard = preload("res://scripts/components/puzzle_board.gd")
const Confetti = preload("res://scripts/components/confetti.gd")
const Icon = preload("res://scripts/components/icon.gd")
const PreviewOverlay = preload("res://scripts/overlays/preview_overlay.gd")
const PauseOverlay = preload("res://scripts/overlays/pause_overlay.gd")
const SuccessOverlay = preload("res://scripts/overlays/success_overlay.gd")
const FailedOverlay = preload("res://scripts/overlays/failed_overlay.gd")
const ConfirmDialog = preload("res://scripts/overlays/confirm_dialog.gd")

enum State { INTRO, READY, PLAYING, PAUSED, WON, FAILED }

const WARNING_SECONDS := 15

var state: State = State.INTRO
var _paused_from: State = State.READY

var mode := "campaign"
var difficulty := "easy"
var level := 1
var cfg: Dictionary = {}

var logic = null
var image_info: Dictionary = {}
var texture: Texture2D

var time_limit := 60.0
var time_left := 60.0
var moves := 0
var min_moves := 0
var combo := 0
var max_combo := 0
var combo_bonus := 0
var hints_left := 3
var hints_used := 0
var previews_used := 0
var started := false

var _attempt := 0
var _token := 0               # invalidates async callbacks from old puzzles
var _last_tick := -1
var _warning := false
var _warn_tween: Tween
var _overlays: Array = []

# UI
var board
var level_label: Label
var sub_label: Label
var moves_label: Label
var placed_label: Label
var status_label: Label
var time_label: Label
var time_pill: PanelContainer
var time_style: StyleBoxFlat
var hint_box: VBoxContainer
var sound_btn: Button


# ------------------------------------------------------------------- build

func build() -> void:
	mode = str(params.get("mode", "campaign"))
	match mode:
		"campaign":
			level = clampi(int(params.get("level", GameData.current_campaign_level())), 1, LevelConfig.MAX_LEVEL)
			difficulty = LevelConfig.difficulty_for_level(level)
		"daily":
			difficulty = LevelConfig.daily_difficulty()
		_:
			mode = "free"
			difficulty = str(params.get("difficulty", "easy"))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	root_box.add_child(row)
	row.add_child(_build_left_panel())
	row.add_child(_build_center())
	row.add_child(_build_right_panel())
	start_new_puzzle.call_deferred()


func _build_left_panel() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(250, 0)
	col.add_theme_constant_override("separation", 12)
	var home := UIKit.make_icon_button("back", "tile_btn", 76)
	home.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	home.pressed.connect(_request_home)
	col.add_child(home)

	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", UIKit.glass_style(24))
	var ib := VBoxContainer.new()
	ib.add_theme_constant_override("separation", 0)
	info.add_child(ib)
	level_label = UIKit.make_title_label("", 36)
	sub_label = UIKit.make_label("", 20, Color(1, 1, 1, 0.85), true)
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ib.add_child(level_label)
	ib.add_child(sub_label)
	col.add_child(info)

	var m: Dictionary = UIKit.make_stat_card("MOVES", "0", 40)
	moves_label = m["value"]
	col.add_child(m["panel"])
	var p: Dictionary = UIKit.make_stat_card("PLACED", "0/0", 40)
	placed_label = p["value"]
	col.add_child(p["panel"])

	status_label = UIKit.make_wrapped_label("", 22, Color.WHITE)
	UIKit.add_outline(status_label, UIKit.c("navy"), 6)
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(status_label)
	return col


func _build_center() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)

	# Countdown pill (dark, white border; turns red when time is short).
	var pill_holder := CenterContainer.new()
	col.add_child(pill_holder)
	time_pill = PanelContainer.new()
	time_style = UIKit.stylebox(Color("111827"), 20, 8)
	time_style.set_border_width_all(4)
	time_style.border_color = Color.WHITE
	time_style.content_margin_left = 26
	time_style.content_margin_right = 30
	time_style.content_margin_top = 4
	time_style.content_margin_bottom = 4
	time_pill.add_theme_stylebox_override("panel", time_style)
	time_pill.resized.connect(func(): time_pill.pivot_offset = time_pill.size * 0.5)
	pill_holder.add_child(time_pill)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 12)
	time_pill.add_child(pr)
	var clock := Icon.new()
	clock.kind = "clock"
	clock.custom_minimum_size = Vector2(40, 40)
	clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(clock)
	time_label = UIKit.make_label("60 SEC", 46, Color.WHITE, true)
	time_label.add_theme_font_override("font", UIKit.font_black)
	time_label.custom_minimum_size = Vector2(190, 0)
	pr.add_child(time_label)

	# Square board that fills the remaining space.
	var arc := AspectRatioContainer.new()
	arc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arc.ratio = 1.0
	arc.stretch_mode = AspectRatioContainer.STRETCH_FIT
	col.add_child(arc)
	board = PuzzleBoard.new()
	arc.add_child(board)
	board.first_interaction.connect(_on_first_interaction)
	board.tile_swapped.connect(_on_tile_swapped)
	board.puzzle_solved.connect(_on_puzzle_solved)
	board.invalid_drop.connect(_on_invalid_drop)
	return col


func _build_right_panel() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(250, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 14)
	col.add_child(grid)

	var pause_box := UIKit.make_tile_button("pause", "Pause", "tile_btn", 80)
	pause_box.get_meta("button").pressed.connect(_pause)
	var sound_box := UIKit.make_tile_button(UIKit.sound_icon(), "Sound", "tile_btn", 80)
	sound_btn = sound_box.get_meta("button")
	sound_btn.pressed.connect(_toggle_sound)
	var preview_box := UIKit.make_tile_button("eye", "Preview", "blue", 80)
	preview_box.get_meta("button").pressed.connect(_peek_preview)
	hint_box = UIKit.make_tile_button("bulb", "Hint (3)", "orange", 80)
	hint_box.get_meta("button").pressed.connect(_use_hint)
	var restart_box := UIKit.make_tile_button("restart", "Restart", "pink", 80)
	restart_box.get_meta("button").pressed.connect(_request_restart)
	for b in [pause_box, sound_box, preview_box, hint_box, restart_box]:
		grid.add_child(b)
	return col


# ---------------------------------------------------------- puzzle lifecycle

## Creates a brand-new randomized puzzle (also used by Restart / Play Again).
func start_new_puzzle() -> void:
	_close_all_overlays()
	_token += 1
	_attempt += 1
	var token := _token
	state = State.INTRO
	cfg = LevelConfig.get_config(difficulty)
	time_limit = float(cfg["time"])
	time_left = time_limit
	moves = 0
	combo = 0
	max_combo = 0
	combo_bonus = 0
	hints_left = LevelConfig.HINTS_PER_LEVEL
	hints_used = 0
	previews_used = 0
	started = false
	_last_tick = -1
	_set_warning(false)

	# Pick a picture: daily = same image for everyone today, otherwise random
	# and different from the recently used ones.
	var seed_value := -1
	if mode == "daily":
		var ds := GameData.daily_seed()
		image_info = ImageLibrary.pick_seeded(ds)
		seed_value = ds * 31 + _attempt
	elif mode == "campaign":
		image_info = ImageLibrary.pick_for_level(level)
	else:
		image_info = ImageLibrary.pick_random(GameData.get_recent_images())
	GameData.push_recent_image(str(image_info["path"]))
	texture = ImageLibrary.load_texture(image_info)

	logic = PuzzleLogic.new(int(cfg["grid"]), seed_value)
	logic.shuffle()
	min_moves = logic.min_swaps_to_solve()
	board.input_enabled = false
	board.setup(logic, texture, bool(GameData.get_setting("tile_numbers")))
	_update_titles()
	_refresh_hud()

	if bool(GameData.get_setting("show_preview")):
		_set_status("Memorize the picture!")
		var p = PreviewOverlay.new()
		p.texture = texture
		p.memorize = true
		p.duration = float(GameData.get_setting("preview_seconds"))
		p.subtitle = "%s · %s" % [image_info.get("name", ""), ImageLibrary.category_title(str(image_info.get("category", "")))]
		p.closed.connect(_on_memorize_closed.bind(token))
		_push_overlay(p)
	else:
		_begin_shuffle()


func _on_memorize_closed(token: int) -> void:
	if token == _token and state == State.INTRO:
		_begin_shuffle()


func _begin_shuffle() -> void:
	var token := _token
	_set_status("Shuffling...")
	await get_tree().create_timer(0.15).timeout
	if token != _token or not is_inside_tree():
		return
	await board.play_shuffle_intro()
	if token != _token or not is_inside_tree() or state != State.INTRO:
		return
	state = State.READY
	board.input_enabled = true
	_set_status("Drag a tile onto another to swap them.\nThe clock starts on your first touch!")


func _on_first_interaction() -> void:
	if state != State.READY:
		return
	state = State.PLAYING
	started = true
	GameData.record_game_started()
	_set_status("Go go go!")


# -------------------------------------------------------------------- timer

func _process(delta: float) -> void:
	# The timer ONLY runs while PLAYING – never during intro, pause,
	# success or failure.
	if state != State.PLAYING:
		return
	time_left = maxf(0.0, time_left - delta)
	_update_timer_label()
	if time_left <= 0.0:
		_on_time_up()


func _update_timer_label() -> void:
	var secs := int(ceil(time_left))
	time_label.text = "%d SEC" % secs
	if secs <= WARNING_SECONDS and state == State.PLAYING:
		_set_warning(true)
		if secs != _last_tick and secs > 0:
			_last_tick = secs
			SoundManager.play("tick", 1.25 if secs <= 5 else 1.0)
			var tw := time_pill.create_tween()
			tw.tween_property(time_pill, "scale", Vector2(1.12, 1.12), 0.08)
			tw.tween_property(time_pill, "scale", Vector2.ONE, 0.2)


func _set_warning(on: bool) -> void:
	if on == _warning:
		return
	_warning = on
	time_style.bg_color = UIKit.c("red") if on else Color("111827")
	time_style.border_color = UIKit.c("yellow") if on else Color.WHITE
	time_pill.queue_redraw()
	if on:
		_set_status("Hurry! Time is running out!")


# ---------------------------------------------------------------- gameplay

func _on_tile_swapped(newly_correct: int) -> void:
	moves += 1
	if newly_correct > 0:
		combo += 1
		max_combo = maxi(max_combo, combo)
		if combo >= 2:
			# Combo bonus: consecutive moves that each place a tile correctly.
			var pts := LevelConfig.combo_points(combo, difficulty)
			combo_bonus += pts
			board.float_text("Combo x%d  +%d" % [combo, pts], UIKit.c("yellow"), combo >= 4)
			SoundManager.play("combo", 1.0 + minf(0.5, combo * 0.06))
		elif newly_correct >= 2:
			board.float_text("Double!", UIKit.c("green"))
	else:
		combo = 0
	_refresh_hud()


func _on_invalid_drop() -> void:
	_set_status("That tile is already in the right place!")


func _on_puzzle_solved() -> void:
	if state == State.PLAYING or state == State.READY:
		_on_win()


func _on_win() -> void:
	state = State.WON
	var token := _token
	board.input_enabled = false
	_set_warning(false)
	time_pill.scale = Vector2.ONE
	var time_used := time_limit - time_left
	var breakdown := LevelConfig.compute_score(difficulty, time_left, moves, min_moves, combo_bonus, hints_used, mode == "daily")
	var stars := LevelConfig.compute_stars(time_used, time_limit, moves, min_moves)
	var result := {
		"success": true,
		"mode": mode,
		"difficulty": difficulty,
		"level": level,
		"time_used": time_used,
		"time_limit": time_limit,
		"time_left": time_left,
		"moves": moves,
		"min_moves": min_moves,
		"hints": hints_used,
		"previews": previews_used,
		"max_combo": max_combo,
		"combo_bonus": combo_bonus,
		"score": int(breakdown["total"]),
		"stars": stars,
		"correct": logic.tile_count,
		"total": logic.tile_count,
		"image": str(image_info.get("name", "")),
	}
	var info: Dictionary = GameData.record_win(result)
	_set_status("Brilliant!")
	SoundManager.play("win")
	GameData.vibrate(60)
	await board.play_win_animation()
	if token != _token or not is_inside_tree():
		return
	var confetti = Confetti.new()
	add_child(confetti)
	confetti.burst()
	await get_tree().create_timer(0.5).timeout
	if token != _token or not is_inside_tree():
		return
	var s = SuccessOverlay.new()
	s.result = result
	s.info = info
	s.breakdown = breakdown
	s.next_text = "Next Level" if mode == "campaign" else ("Next Puzzle" if mode == "free" else "Campaign")
	if mode == "campaign" and level >= LevelConfig.MAX_LEVEL:
		s.next_text = "Quick Play"
	elif mode == "daily" and GameData.campaign_complete():
		s.next_text = "Quick Play"
	s.next_requested.connect(_on_next)
	s.again_requested.connect(start_new_puzzle)
	s.home_requested.connect(func(): go("home"))
	_push_overlay(s)


func _on_time_up() -> void:
	state = State.FAILED
	var token := _token
	board.cancel_drag()
	board.input_enabled = false
	board.clear_hint()
	_close_all_overlays()
	var correct: int = logic.count_correct()
	var score := LevelConfig.partial_score(correct, difficulty, combo_bonus, hints_used)
	GameData.record_fail({"mode": mode, "difficulty": difficulty, "score": score, "correct": correct})
	time_label.text = "0 SEC"
	_set_status("Time's up!")
	SoundManager.play("fail")
	GameData.vibrate(250)
	board.play_fail_animation()
	await get_tree().create_timer(0.9).timeout
	if token != _token or not is_inside_tree():
		return
	var f = FailedOverlay.new()
	f.texture = texture
	f.correct = correct
	f.total = logic.tile_count
	f.score = score
	f.retry_requested.connect(start_new_puzzle)
	f.difficulty_requested.connect(func(): go("difficulty"))
	f.home_requested.connect(func(): go("home"))
	_push_overlay(f)


func _on_next() -> void:
	match mode:
		"campaign":
			if level >= LevelConfig.MAX_LEVEL:
				go("difficulty")
				return
			level += 1
			difficulty = LevelConfig.difficulty_for_level(level)
		"daily":
			if GameData.campaign_complete():
				go("difficulty")
				return
			mode = "campaign"
			level = GameData.current_campaign_level()
			difficulty = LevelConfig.difficulty_for_level(level)
	start_new_puzzle()


# ----------------------------------------------------------------- controls

func _can_act() -> bool:
	return state == State.READY or state == State.PLAYING


func _is_active_game() -> bool:
	return started and (state == State.PLAYING or state == State.PAUSED)


func _pause() -> void:
	if not _can_act() or not _overlays.is_empty():
		return
	_paused_from = state
	state = State.PAUSED
	board.cancel_drag()
	board.input_enabled = false
	SoundManager.play("pause")
	var p = PauseOverlay.new()
	p.resume_requested.connect(_resume)
	p.restart_requested.connect(_request_restart)
	p.home_requested.connect(_request_home)
	_push_overlay(p)


func _resume() -> void:
	if state != State.PAUSED:
		return
	_close_all_overlays()
	state = _paused_from
	board.input_enabled = true


func _request_restart() -> void:
	if state == State.INTRO:
		return
	if _is_active_game():
		var d = _make_confirm("Restart level?", "You'll get a brand-new shuffle and the timer resets.", "Restart", "orange")
		d.confirmed.connect(start_new_puzzle)
	else:
		start_new_puzzle()


func _request_home() -> void:
	if _is_active_game():
		var d = _make_confirm("Leave puzzle?", "Your progress on this puzzle will be lost.", "Leave", "red")
		d.confirmed.connect(func(): go("home"))
	else:
		go("home")


func _make_confirm(title: String, msg: String, ok_text: String, color: String):
	# Pause the clock while the dialog is open.
	if state == State.PLAYING:
		_paused_from = state
		state = State.PAUSED
		board.cancel_drag()
		board.input_enabled = false
	var d = ConfirmDialog.new()
	d.title_text = title
	d.message = msg
	d.confirm_text = ok_text
	d.confirm_color = color
	d.closed.connect(_on_confirm_closed)
	_push_overlay(d)
	return d


func _on_confirm_closed() -> void:
	# Cancelled with no pause menu underneath → resume play.
	# (The closing dialog is still in the list for this frame, so ignore it.)
	var open := _overlays.filter(func(o): return is_instance_valid(o) and not o._closing)
	if state == State.PAUSED and open.is_empty():
		state = _paused_from
		board.input_enabled = true


func _peek_preview() -> void:
	if not _can_act() or not _overlays.is_empty():
		return
	if state == State.READY:
		_on_first_interaction()  # peeking starts the clock
	previews_used += 1
	board.cancel_drag()
	SoundManager.play("preview")
	var p = PreviewOverlay.new()
	p.texture = texture
	p.memorize = false
	p.duration = 2.5
	p.subtitle = "The clock is still running!"
	_push_overlay(p)


func _use_hint() -> void:
	if not _can_act() or not _overlays.is_empty():
		return
	if hints_left <= 0:
		SoundManager.play("wrong")
		_set_status("No hints left for this puzzle.")
		return
	var h: Dictionary = logic.find_hint()
	if h.is_empty():
		return
	if state == State.READY:
		_on_first_interaction()
	hints_left -= 1
	hints_used += 1
	board.show_hint(int(h["from"]), int(h["to"]))
	SoundManager.play("hint")
	_set_status("Move the glowing tile to the blue spot! (-%d pts)" % LevelConfig.hint_penalty(difficulty))
	_refresh_hud()


func _toggle_sound() -> void:
	GameData.toggle_sound()
	UIKit.set_button_icon(sound_btn, UIKit.sound_icon())


# ------------------------------------------------------------------ overlays

func _push_overlay(o: Control) -> void:
	add_child(o)
	_overlays.append(o)
	o.tree_exiting.connect(func(): _overlays.erase(o))


func _close_all_overlays() -> void:
	for o in _overlays.duplicate():
		if is_instance_valid(o):
			o.queue_free()
	_overlays.clear()


func handle_back() -> bool:
	if not _overlays.is_empty():
		var top = _overlays.back()
		if is_instance_valid(top):
			top.handle_back()
		return true
	if _can_act():
		_pause()
		return true
	if state == State.INTRO:
		return true
	go("home")
	return true


func _notification(what: int) -> void:
	# Auto-pause when the app goes to the background (call, home button...).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if state == State.PLAYING and _overlays.is_empty():
			_pause()


# ----------------------------------------------------------------------- HUD

func _update_titles() -> void:
	match mode:
		"campaign":
			level_label.text = "Level %d/%d" % [level, LevelConfig.MAX_LEVEL]
		"daily":
			level_label.text = "Daily Puzzle"
		_:
			level_label.text = "Quick Play"
	sub_label.text = "%s · %d×%d\n%s" % [cfg["name"], int(cfg["grid"]), int(cfg["grid"]),
			ImageLibrary.category_title(str(image_info.get("category", "")))]


func _refresh_hud() -> void:
	moves_label.text = str(moves)
	placed_label.text = "%d/%d" % [logic.count_correct(), logic.tile_count]
	time_label.text = "%d SEC" % int(ceil(time_left))
	var hb: Button = hint_box.get_meta("button")
	var hl: Label = hint_box.get_meta("label")
	hl.text = "Hint (%d)" % hints_left
	hb.disabled = hints_left <= 0


func _set_status(text: String) -> void:
	status_label.text = text
