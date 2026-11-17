extends "res://scripts/screens/screen_base.gd"
## Records: local leaderboard (personal bests) and achievements, in two tabs.

const Icon = preload("res://scripts/components/icon.gd")
const Achievements = preload("res://scripts/core/achievements.gd")
const LevelConfig = preload("res://scripts/core/level_config.gd")

var _tab := "leaderboard"
var _content: VBoxContainer
var _tab_buttons := {}


func build() -> void:
	_tab = str(params.get("tab", "leaderboard"))
	root_box.add_child(make_header("Records"))
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 16)
	root_box.add_child(tabs)
	for t in [["leaderboard", "Leaderboard"], ["achievements", "Achievements"]]:
		var key := str(t[0])
		var b := UIKit.make_button(str(t[1]), "blue", 26, 66)
		b.custom_minimum_size = Vector2(260, 66)
		b.pressed.connect(func(): _show_tab(key))
		tabs.add_child(b)
		_tab_buttons[key] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	_show_tab(_tab)


func _show_tab(tab: String) -> void:
	_tab = tab
	for key in _tab_buttons:
		UIKit.style_button(_tab_buttons[key], UIKit.c("orange") if key == tab else UIKit.c("tile_btn"), 20)
	for c in _content.get_children():
		c.queue_free()
	if tab == "achievements":
		_build_achievements()
	else:
		_build_leaderboard()


func _build_leaderboard() -> void:
	# Personal bests per difficulty.
	var bests := HBoxContainer.new()
	bests.add_theme_constant_override("separation", 14)
	_content.add_child(bests)
	for d in LevelConfig.DIFFICULTIES:
		var card: Dictionary = UIKit.make_stat_card(LevelConfig.display_name(str(d)).to_upper(),
				UIKit.format_number(GameData.best_score(str(d))), 34)
		var t := UIKit.make_label("Best time " + UIKit.format_time_precise(GameData.best_time(str(d))), 18, Color(1, 1, 1, 0.85))
		card["panel"].get_child(0).add_child(t)
		bests.add_child(card["panel"])

	_content.add_child(UIKit.make_title_label("Top Scores", 30))
	var board: Array = GameData.get_leaderboard()
	if board.is_empty():
		_content.add_child(UIKit.make_title_label("No scores yet – complete a puzzle to get on the board!", 24))
		return
	var rank := 1
	for e in board:
		_content.add_child(_score_row(rank, e))
		rank += 1


func _score_row(rank: int, e: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	var gold := rank == 1
	var sb := UIKit.stylebox(Color("fff7d6") if gold else UIKit.c("paper"), 20, 4)
	sb.set_content_margin_all(10)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	p.add_child(row)
	var r := UIKit.make_label("#%d" % rank, 30, UIKit.c("orange") if rank <= 3 else UIKit.c("ink_soft"), true)
	r.custom_minimum_size = Vector2(70, 0)
	row.add_child(r)
	var score := UIKit.make_label(UIKit.format_number(int(e.get("score", 0))), 32, UIKit.c("ink"), true, HORIZONTAL_ALIGNMENT_LEFT)
	score.custom_minimum_size = Vector2(160, 0)
	row.add_child(score)
	var mode_txt: String = {"campaign": "Campaign", "daily": "Daily", "free": "Quick Play"}.get(str(e.get("mode", "")), "")
	var desc := "%s · %s · %s · %d moves" % [LevelConfig.display_name(str(e.get("difficulty", "easy"))), mode_txt,
			UIKit.format_time_precise(float(e.get("time", 0.0))), int(e.get("moves", 0))]
	var dl := UIKit.make_label(desc, 22, UIKit.c("ink_soft"), false, HORIZONTAL_ALIGNMENT_LEFT)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)
	row.add_child(UIKit.make_star_row(int(e.get("stars", 0)), 28))
	row.add_child(UIKit.make_label(str(e.get("date", "")), 18, UIKit.c("ink_soft")))
	return p


func _build_achievements() -> void:
	_content.add_child(UIKit.make_title_label("%d / %d unlocked" % [GameData.achievements_unlocked_count(), Achievements.LIST.size()], 28))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_content.add_child(grid)
	for a in Achievements.LIST:
		var unlocked := GameData.is_achievement_unlocked(str(a["id"]))
		var p := PanelContainer.new()
		var sb := UIKit.stylebox(UIKit.c("paper") if unlocked else Color(1, 1, 1, 0.55), 22, 4 if unlocked else 0)
		sb.set_content_margin_all(12)
		p.add_theme_stylebox_override("panel", sb)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		p.add_child(row)
		var icon := Icon.new()
		icon.kind = "trophy" if unlocked else "lock"
		icon.color = UIKit.c("orange") if unlocked else UIKit.c("gray")
		icon.custom_minimum_size = Vector2(54, 54)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		col.add_child(UIKit.make_label(str(a["title"]), 24, UIKit.c("ink") if unlocked else UIKit.c("ink_soft"), true, HORIZONTAL_ALIGNMENT_LEFT))
		col.add_child(UIKit.make_wrapped_label(str(a["desc"]), 18, UIKit.c("ink_soft"), HORIZONTAL_ALIGNMENT_LEFT))
		grid.add_child(p)
