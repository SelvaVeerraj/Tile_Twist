extends "res://scripts/screens/screen_base.gd"
## How to Play: illustrated step cards in a scrollable grid.

const Icon = preload("res://scripts/components/icon.gd")

const STEPS := [
	["eye", "blue", "1. Memorize", "A random picture is shown for a few seconds before it gets shuffled."],
	["grid", "purple", "2. Drag & swap", "Drag any tile and drop it on another tile – the two swap places."],
	["check", "green", "3. Lock in", "A tile in its correct spot glows green and locks so it can't be moved by mistake."],
	["clock", "red", "4. Beat the clock", "The timer starts on your first touch. It turns red with 15 seconds left."],
	["bulb", "orange", "5. Hints & preview", "Preview shows the full picture; Hint points a tile to its home. Hints cost points."],
	["star", "pink", "6. Combos & stars", "Place tiles on consecutive moves for combo bonuses. Fast + few moves = 3 stars."],
]


func build() -> void:
	root_box.add_child(make_header("How to Play"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	body.add_child(grid)
	var delay := 0.0
	for s in STEPS:
		var card := _step_card(str(s[0]), str(s[1]), str(s[2]), str(s[3]))
		grid.add_child(card)
		UIKit.pop_in(card, delay)
		delay += 0.05

	# Difficulty summary.
	var table := PanelContainer.new()
	table.add_theme_stylebox_override("panel", UIKit.glass_style(22))
	body.add_child(table)
	var tr := HBoxContainer.new()
	tr.alignment = BoxContainer.ALIGNMENT_CENTER
	tr.add_theme_constant_override("separation", 40)
	table.add_child(tr)
	for d in [["Easy", "2×2", "60s"], ["Medium", "3×3", "90s"], ["Hard", "4×4", "120s"], ["Expert", "5×5", "180s"]]:
		var v := VBoxContainer.new()
		v.add_child(UIKit.make_title_label(str(d[0]), 28))
		v.add_child(UIKit.make_label("%s · %s" % [d[1], d[2]], 22, Color.WHITE, true))
		tr.add_child(v)

	var ok := UIKit.make_big_button("GOT IT!", "", "green", Color("14532d"), 320, 80)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func(): go("home"))
	body.add_child(ok)


func _step_card(icon_kind: String, color: String, title: String, text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIKit.stylebox(UIKit.c("paper"), 24, 6)
	sb.set_content_margin_all(16)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 160)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	p.add_child(row)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.c(color), 20))
	badge.custom_minimum_size = Vector2(72, 72)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var icon := Icon.new()
	icon.kind = icon_kind
	icon.custom_minimum_size = Vector2(72, 72)
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 16)
	m.add_child(icon)
	badge.add_child(m)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	col.add_child(UIKit.make_label(title, 26, UIKit.c("ink"), true, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(UIKit.make_wrapped_label(text, 19, UIKit.c("ink_soft"), HORIZONTAL_ALIGNMENT_LEFT))
	return p
