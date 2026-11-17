extends "res://scripts/screens/screen_base.gd"
## Home screen (landscape): title and big PLAY / Daily buttons in the centre,
## stat cards on both sides, and a row of square menu buttons at the bottom.

const Logo = preload("res://scripts/components/logo.gd")
const LevelConfig = preload("res://scripts/core/level_config.gd")

var _sound_btn: Button


func build() -> void:
	root_box.add_theme_constant_override("separation", 6)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 20)
	root_box.add_child(middle)

	# ---- left column: sound toggle + stats
	var left := _side_column()
	middle.add_child(left)
	var sound_box := UIKit.make_tile_button(UIKit.sound_icon(), "Sound", "card_strong", 78)
	sound_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_sound_btn = sound_box.get_meta("button")
	_sound_btn.pressed.connect(_toggle_sound)
	left.add_child(sound_box)
	left.add_child(UIKit.spacer(0, true))
	left.add_child(_stat("BEST SCORE", UIKit.format_number(GameData.highest_score())))
	left.add_child(_stat("LEVELS COMPLETED", "%d/%d" % [GameData.levels_completed(), LevelConfig.MAX_LEVEL]))

	# ---- centre column: title, logo, play buttons
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 10)
	middle.add_child(center)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", -36)
	center.add_child(title_box)
	title_box.add_child(UIKit.make_title_label("TILE", 92, UIKit.c("yellow"), Color("5b21b6")))
	title_box.add_child(UIKit.make_title_label("TWIST", 80, Color("ff6f91"), Color("5b21b6")))
	var logo_holder := CenterContainer.new()
	var logo := Logo.new()
	logo.custom_minimum_size = Vector2(96, 96)
	logo_holder.add_child(logo)
	center.add_child(logo_holder)

	var play: Button
	if GameData.campaign_complete():
		play = UIKit.make_big_button("PLAY", "All %d levels complete!" % LevelConfig.MAX_LEVEL, "orange", UIKit.c("brown"), 420, 108)
		play.pressed.connect(func(): go("difficulty"))
	else:
		var level := GameData.current_campaign_level()
		var sub := "Level %d/%d · %s" % [level, LevelConfig.MAX_LEVEL, _difficulty_label(level)]
		play = UIKit.make_big_button("PLAY", sub, "orange", UIKit.c("brown"), 420, 108)
		play.pressed.connect(func(): go("game", {"mode": "campaign", "level": GameData.current_campaign_level()}))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(play)

	var daily_sub := "Done today · streak %d" % GameData.daily_streak() if GameData.daily_done_today() else "A new puzzle every day"
	var daily := UIKit.make_big_button("Daily Puzzle", daily_sub, "green", Color("14532d"), 380, 84)
	daily.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	daily.pressed.connect(func(): go("game", {"mode": "daily"}))
	if not GameData.daily_done_today():
		_add_badge(daily)
	center.add_child(daily)

	# ---- right column: records + more stats
	var right := _side_column()
	middle.add_child(right)
	var trophy_box := UIKit.make_tile_button("trophy", "Records", "card_strong", 78)
	trophy_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	trophy_box.get_meta("button").pressed.connect(func(): go("records", {"tab": "leaderboard"}))
	right.add_child(trophy_box)
	right.add_child(UIKit.spacer(0, true))
	right.add_child(_stat("PUZZLES SOLVED", str(int(GameData.data["puzzles_completed"]))))
	right.add_child(_stat("DAILY STREAK", str(GameData.daily_streak())))

	# ---- bottom menu row
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 34)
	root_box.add_child(bottom)
	var items := [
		["gear", "Settings", "settings", {}],
		["grid", "Difficulty", "difficulty", {}],
		["help", "How to Play", "instructions", {}],
		["chart", "Leaderboard", "records", {"tab": "leaderboard"}],
		["star", "Achievements", "records", {"tab": "achievements"}],
	]
	var delay := 0.35
	for it in items:
		var box := UIKit.make_tile_button(str(it[0]), str(it[1]), "tile_btn", 76)
		var target := str(it[2])
		var p: Dictionary = it[3]
		box.get_meta("button").pressed.connect(func(): go(target, p))
		bottom.add_child(box)
		UIKit.pop_in(box, delay)
		delay += 0.05

	UIKit.pop_in(title_box, 0.0)
	UIKit.pop_in(logo_holder, 0.1)
	UIKit.pop_in(play, 0.18)
	UIKit.pop_in(daily, 0.26)
	_start_play_pulse(play)


func _side_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(250, 0)
	col.add_theme_constant_override("separation", 12)
	return col


func _stat(caption: String, value: String) -> PanelContainer:
	var card: Dictionary = UIKit.make_stat_card(caption, value, 38)
	return card["panel"]


func _difficulty_label(level: int) -> String:
	var d: String = LevelConfig.difficulty_for_level(level)
	var cfg: Dictionary = LevelConfig.get_config(d)
	return "%s %d×%d" % [cfg["name"], int(cfg["grid"]), int(cfg["grid"])]


## Little red notification dot on a button's top-right corner.
func _add_badge(b: Button) -> void:
	var dot := Panel.new()
	dot.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.c("red"), 15))
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(dot)
	dot.anchor_left = 1.0
	dot.anchor_right = 1.0
	dot.offset_left = -34
	dot.offset_right = -4
	dot.offset_top = -6
	dot.offset_bottom = 24


## Gentle breathing scale on the PLAY button to draw the eye.
func _start_play_pulse(b: Button) -> void:
	var tw := b.create_tween().set_loops()
	tw.tween_interval(0.8)
	tw.tween_property(b, "scale", Vector2(1.04, 1.04), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


func _toggle_sound() -> void:
	GameData.toggle_sound()
	UIKit.set_button_icon(_sound_btn, UIKit.sound_icon())


func handle_back() -> bool:
	return false  # quits the app
