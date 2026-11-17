extends "res://scripts/overlays/overlay_base.gd"
## "Time's Up!" screen. Shows the original picture and how far the player got.
## The previous best score is untouched – it is only displayed here.

signal retry_requested
signal difficulty_requested
signal home_requested

var texture: Texture2D
var correct := 0
var total := 0
var score := 0


func _build() -> void:
	card_width = 900.0
	card.custom_minimum_size = Vector2(card_width, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	content.add_child(row)

	var frame := PanelContainer.new()
	var fs := UIKit.stylebox(UIKit.c("navy"), 18)
	fs.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", fs)
	row.add_child(frame)
	var img := TextureRect.new()
	img.texture = texture
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(400, 400)
	frame.add_child(img)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	row.add_child(col)
	col.add_child(UIKit.make_title_label("Time's Up!", 60, UIKit.c("red"), Color("7f1d1d")))
	col.add_child(UIKit.make_label("Tiles placed: %d / %d" % [correct, total], 28, UIKit.c("ink"), true))
	var bar := UIKit.make_progress_bar(UIKit.c("green"), 18)
	bar.value = 100.0 * correct / maxf(1.0, total)
	col.add_child(bar)
	col.add_child(UIKit.make_label("Score: %s" % UIKit.format_number(score), 30, UIKit.c("orange").darkened(0.2), true))
	col.add_child(UIKit.make_label("Best score kept: %s" % UIKit.format_number(GameData.highest_score()), 22, UIKit.c("ink_soft")))
	col.add_child(UIKit.spacer(4))
	var retry := UIKit.make_button("Try Again", "orange", 30, 80)
	retry.pressed.connect(func(): retry_requested.emit())
	col.add_child(retry)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 14)
	col.add_child(sub)
	var diff := UIKit.make_button("Difficulty", "blue", 26, 76)
	diff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff.pressed.connect(func(): difficulty_requested.emit())
	var home := UIKit.make_button("Home", "purple", 26, 76)
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.pressed.connect(func(): home_requested.emit())
	sub.add_child(diff)
	sub.add_child(home)


func handle_back() -> void:
	home_requested.emit()
