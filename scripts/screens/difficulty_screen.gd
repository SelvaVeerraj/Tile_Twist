extends "res://scripts/screens/screen_base.gd"
## Difficulty selection: continue the campaign, or quick-play any grid size.

const LevelConfig = preload("res://scripts/core/level_config.gd")


func build() -> void:
	root_box.add_child(make_header("Select Difficulty"))

	# Campaign card.
	var camp := PanelContainer.new()
	camp.add_theme_stylebox_override("panel", UIKit.glass_style(26))
	root_box.add_child(camp)
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 20)
	camp.add_child(cr)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	cr.add_child(info)
	var done := GameData.campaign_complete()
	# Once every level is finished, the button replays the campaign from level 1.
	var lvl := 1 if done else GameData.current_campaign_level()
	var d := LevelConfig.difficulty_for_level(lvl)
	var cfg := LevelConfig.get_config(d)
	info.add_child(UIKit.make_label("CAMPAIGN · %d/%d LEVELS DONE" % [GameData.levels_completed(), LevelConfig.MAX_LEVEL],
			22, Color(1, 1, 1, 0.75), true, HORIZONTAL_ALIGNMENT_LEFT))
	var title_txt := "Campaign Complete!" if done else "Level %d · %s %d×%d" % [lvl, cfg["name"], int(cfg["grid"]), int(cfg["grid"])]
	var t := UIKit.make_title_label(title_txt, 38)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(t)
	info.add_child(UIKit.make_label("Grids grow as you advance: 2×2 → 3×3 → 4×4 → 5×5", 20, Color(1, 1, 1, 0.85), false, HORIZONTAL_ALIGNMENT_LEFT))
	var cont := UIKit.make_big_button("REPLAY" if done else "CONTINUE", "Level %d" % lvl, "orange", UIKit.c("brown"), 300, 92)
	cont.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cont.pressed.connect(func(): go("game", {"mode": "campaign", "level": lvl}))
	cr.add_child(cont)

	root_box.add_child(UIKit.make_title_label("Quick Play", 32))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	root_box.add_child(row)
	var delay := 0.0
	for diff in LevelConfig.DIFFICULTIES:
		var card := _difficulty_card(str(diff))
		row.add_child(card)
		UIKit.pop_in(card, delay)
		delay += 0.06


func _difficulty_card(diff: String) -> Button:
	var cfg := LevelConfig.get_config(diff)
	var color := str(cfg["color"])
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 250)
	UIKit.style_button(b, UIKit.c(color), 28)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	b.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -8
	var dark := UIKit.c(color).darkened(0.45)
	var grid_txt := UIKit.make_title_label("%d×%d" % [int(cfg["grid"]), int(cfg["grid"])], 58, Color.WHITE, dark)
	box.add_child(grid_txt)
	box.add_child(UIKit.make_title_label(str(cfg["name"]), 34, Color.WHITE, dark))
	box.add_child(UIKit.make_label("%d tiles · %d sec" % [int(cfg["grid"]) * int(cfg["grid"]), int(cfg["time"])], 21, Color.WHITE, true))
	var best := GameData.best_score(diff)
	var bt := GameData.best_time(diff)
	var best_txt := "Best: %s · %s" % [UIKit.format_number(best), UIKit.format_time_precise(bt)] if best > 0 else "Not played yet"
	box.add_child(UIKit.make_label(best_txt, 19, Color(1, 1, 1, 0.85)))
	UIKit.ignore_mouse_recursive(box)
	UIKit.add_press_feedback(b)
	b.pressed.connect(func(): go("game", {"mode": "free", "difficulty": diff}))
	return b
