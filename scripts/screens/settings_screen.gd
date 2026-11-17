extends "res://scripts/screens/screen_base.gd"
## Settings: sound, vibration, preview options, tile numbers, reset progress.

const PREVIEW_CHOICES := [2, 3, 5]


func build() -> void:
	root_box.add_child(make_header("Settings"))
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 20)
	root_box.add_child(cols)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 14)
	cols.add_child(left)
	left.add_child(_toggle_row("Sound effects", "Clicks, chimes and fanfares", "sound"))
	left.add_child(_toggle_row("Vibration", "Haptic feedback on phones", "vibration"))
	left.add_child(_toggle_row("Show picture first", "Memorize the image before the shuffle", "show_preview"))
	left.add_child(_toggle_row("Tile numbers", "Assist mode: shows each tile's number", "tile_numbers"))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	cols.add_child(right)
	right.add_child(_preview_row())

	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", UIKit.glass_style(22))
	right.add_child(stats)
	var sv := VBoxContainer.new()
	stats.add_child(sv)
	var d := GameData.data
	sv.add_child(UIKit.make_title_label("Your stats", 28))
	sv.add_child(UIKit.make_label("Games played: %d   ·   Completed: %d" % [int(d["games_played"]), int(d["puzzles_completed"])], 22, Color.WHITE, true))
	sv.add_child(UIKit.make_label("Achievements: %d / 15   ·   Best combo: x%d" % [GameData.achievements_unlocked_count(), int(d["max_combo"])], 22, Color.WHITE, true))

	var reset := UIKit.make_button("Reset Progress", "red", 28, 80)
	reset.pressed.connect(_ask_reset)
	right.add_child(reset)
	right.add_child(UIKit.spacer(0, true))
	var ver := UIKit.make_label("Tile Twist v%s · Works offline" % str(ProjectSettings.get_setting("application/config/version", "1.0")), 18, Color(1, 1, 1, 0.8))
	right.add_child(ver)


func _row_panel() -> Array:
	var p := PanelContainer.new()
	var sb := UIKit.stylebox(UIKit.c("paper"), 24, 6)
	sb.set_content_margin_all(14)
	sb.content_margin_left = 22
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	p.add_child(row)
	return [p, row]


func _texts(row: HBoxContainer, title: String, desc: String) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	col.add_child(UIKit.make_label(title, 27, UIKit.c("ink"), true, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(UIKit.make_label(desc, 19, UIKit.c("ink_soft"), false, HORIZONTAL_ALIGNMENT_LEFT))


func _toggle_row(title: String, desc: String, key: String) -> PanelContainer:
	var parts := _row_panel()
	var row: HBoxContainer = parts[1]
	_texts(row, title, desc)
	var toggle := UIKit.make_button("", "green", 26, 64)
	toggle.custom_minimum_size = Vector2(130, 64)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_toggle(toggle, bool(GameData.get_setting(key)))
	toggle.pressed.connect(_on_toggle.bind(toggle, key))
	row.add_child(toggle)
	return parts[0]


func _on_toggle(toggle: Button, key: String) -> void:
	var on := not bool(GameData.get_setting(key))
	if key == "sound":
		GameData.toggle_sound()
	else:
		GameData.set_setting(key, on)
	_style_toggle(toggle, on)


func _style_toggle(b: Button, on: bool) -> void:
	b.text = "ON" if on else "OFF"
	var col: Color = UIKit.c("green") if on else UIKit.c("gray")
	UIKit.style_button(b, col, 32)
	b.add_theme_color_override("font_outline_color", col.darkened(0.35))


func _preview_row() -> PanelContainer:
	var parts := _row_panel()
	var row: HBoxContainer = parts[1]
	_texts(row, "Preview time", "How long the picture is shown first")
	var b := UIKit.make_button("%ds" % int(GameData.get_setting("preview_seconds")), "blue", 26, 64)
	b.custom_minimum_size = Vector2(130, 64)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_cycle_preview.bind(b))
	row.add_child(b)
	return parts[0]


func _cycle_preview(b: Button) -> void:
	var cur := int(GameData.get_setting("preview_seconds"))
	var idx := PREVIEW_CHOICES.find(cur)
	var nxt: int = PREVIEW_CHOICES[(idx + 1) % PREVIEW_CHOICES.size()]
	GameData.set_setting("preview_seconds", nxt)
	b.text = "%ds" % nxt


func _ask_reset() -> void:
	confirm("Reset progress?", "Scores, levels, achievements and the leaderboard will be erased. Settings are kept.",
			"Reset", _do_reset)


func _do_reset() -> void:
	GameData.reset_progress()
	go("settings")
