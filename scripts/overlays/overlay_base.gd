extends Control
## Base class for modal pop-ups (pause, preview, results, confirmations).
## Dims the screen, shows a centred white card, and animates in and out.
## Subclasses set their properties BEFORE add_child() and fill `content`
## inside _build().

signal closed

var dim: ColorRect
var card: PanelContainer
var content: VBoxContainer
var card_width := 620.0
var _closing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	dim = ColorRect.new()
	dim.color = Color(0.03, 0.08, 0.22, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = PanelContainer.new()
	card.custom_minimum_size = Vector2(card_width, 0)
	card.add_theme_stylebox_override("panel", _card_style())
	center.add_child(card)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	card.add_child(content)
	_build()
	_animate_in()


func _card_style() -> StyleBox:
	var sb := UIKit.card_style()
	sb.set_content_margin_all(30)
	sb.set_border_width_all(6)
	sb.border_color = Color("dceaff")
	return sb


## Override in subclasses to add widgets to `content`.
func _build() -> void:
	pass


func _animate_in() -> void:
	modulate.a = 0.0
	await get_tree().process_frame
	if not is_inside_tree():
		return
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.86, 0.86)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_property(card, "scale", Vector2(0.92, 0.92), 0.15)
	tw.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	closed.emit()
	queue_free()


## Android back button / Escape.
func handle_back() -> void:
	close()


func add_title(text: String, font_size: int = 48, color: Color = Color("2b2350")) -> Label:
	var l := UIKit.make_label(text, font_size, color, true)
	l.add_theme_font_override("font", UIKit.font_black)
	content.add_child(l)
	return l
