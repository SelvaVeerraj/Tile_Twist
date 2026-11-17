extends "res://scripts/overlays/overlay_base.gd"
## Image Preview screen. Two modes:
##  • memorize = true  – shown before a level starts, with a countdown.
##  • memorize = false – quick peek during play (the timer keeps running).
## Tapping anywhere closes it early.

var texture: Texture2D
var duration := 3.0
var memorize := true
var subtitle := ""

var _left := 0.0
var _count_label: Label
var _bar: ProgressBar


func _build() -> void:
	card_width = 900.0
	card.custom_minimum_size = Vector2(card_width, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	content.add_child(row)

	# Picture on the left.
	var frame := PanelContainer.new()
	var fs := UIKit.stylebox(UIKit.c("navy"), 18)
	fs.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", fs)
	row.add_child(frame)
	var img := TextureRect.new()
	img.texture = texture
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(480, 480)
	frame.add_child(img)

	# Info column on the right.
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	row.add_child(col)
	var title := UIKit.make_wrapped_label("Memorize the picture!" if memorize else "Original Image", 38, UIKit.c("ink"))
	title.add_theme_font_override("font", UIKit.font_black)
	col.add_child(title)
	if subtitle != "":
		col.add_child(UIKit.make_wrapped_label(subtitle, 24, UIKit.c("ink_soft")))
	_count_label = UIKit.make_title_label(str(int(ceil(duration))), 110, UIKit.c("orange"), UIKit.c("brown"))
	col.add_child(_count_label)
	_bar = UIKit.make_progress_bar(UIKit.c("orange"), 18)
	_bar.value = 100
	col.add_child(_bar)
	col.add_child(UIKit.make_wrapped_label("Tap anywhere to start" if memorize else "Tap to close", 22, UIKit.c("ink_soft")))
	UIKit.ignore_mouse_recursive(row)
	_left = duration


func _process(delta: float) -> void:
	if _closing:
		return
	_left -= delta
	_count_label.text = str(int(ceil(maxf(_left, 0.0))))
	_bar.value = clampf(_left / duration, 0.0, 1.0) * 100.0
	if _left <= 0.0:
		close()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		close()
