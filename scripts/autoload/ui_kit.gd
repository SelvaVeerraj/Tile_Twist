extends Node
## UIKit (autoload) – shared look & feel.
## Holds the colour palette, fonts and small factory functions that every
## screen uses to build its widgets from code. Keeping all styling here makes
## the game easy to re-skin and keeps screen scripts focused on behaviour.

const Icon = preload("res://scripts/components/icon.gd")

var colors: Dictionary = {
	"bg_top": Color("3f8ff0"),
	"bg_bottom": Color("8fd3ff"),
	"cloud": Color("eef7ff"),
	"navy": Color("1d3b7a"),
	"brown": Color("6b2e05"),
	"panel": Color(0.08, 0.2, 0.48, 0.42),
	"tile_btn": Color("7a5ce6"),
	"orange": Color("ffa424"),
	"ink": Color("2b2350"),
	"ink_soft": Color("6f6894"),
	"paper": Color("ffffff"),
	"paper_soft": Color("f2eefb"),
	"card": Color(0.08, 0.2, 0.48, 0.3),
	"card_strong": Color("5b8fe6"),
	"primary": Color("ff8a3d"),
	"green": Color("4cc95a"),
	"blue": Color("3d9bff"),
	"purple": Color("9b5cff"),
	"pink": Color("ff5c8a"),
	"yellow": Color("ffc93d"),
	"red": Color("ff4d5e"),
	"teal": Color("17c3b2"),
	"gray": Color("a19cb8"),
}

var font_regular: SystemFont
var font_bold: SystemFont
var font_black: SystemFont


func _init() -> void:
	font_regular = _make_font(500)
	font_bold = _make_font(700)
	font_black = _make_font(900)


func _make_font(weight: int) -> SystemFont:
	var f := SystemFont.new()
	# First installed font wins; Godot falls back to its built-in font.
	f.font_names = PackedStringArray(["Nunito", "Poppins", "Segoe UI", "Roboto", "Helvetica Neue", "Arial", "sans-serif"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_regular
	t.default_font_size = 28
	return t


## Palette lookup by name.
func c(name: String) -> Color:
	return colors.get(name, Color.WHITE)


# ---------------------------------------------------------------- styleboxes

func stylebox(color: Color, radius: int = 24, shadow: int = 0, bottom_lip: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 10
	sb.anti_aliasing = true
	if bottom_lip > 0:
		# Darker bottom border gives buttons a chunky, tappable 3D feel.
		sb.border_width_bottom = bottom_lip
		sb.border_color = color.darkened(0.28)
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_color = Color(0, 0, 0, 0.22)
		sb.shadow_offset = Vector2(0, shadow * 0.5)
	return sb


## White rounded card used for dialogs and pop-ups.
func card_style() -> StyleBoxFlat:
	var sb := stylebox(c("paper"), 40, 18)
	sb.set_content_margin_all(36)
	return sb


## Translucent navy panel that keeps white text readable on the sky.
func glass_style(radius: int = 26, alpha: float = 0.42) -> StyleBoxFlat:
	var sb := stylebox(Color(0.08, 0.2, 0.48, alpha), radius)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_content_margin_all(16)
	return sb


## Readable white text on the bright background: dark outline + drop shadow.
func make_title_label(text: String, font_size: int, color: Color = Color.WHITE, outline: Color = Color("1d3b7a")) -> Label:
	var l := make_label(text, font_size, color, true)
	l.add_theme_font_override("font", font_black)
	add_outline(l, outline, maxi(6, int(font_size * 0.16)))
	add_shadow(l, Vector2(0, maxi(3, int(font_size * 0.07))), Color(0.05, 0.12, 0.35, 0.45))
	return l


# ------------------------------------------------------------------- widgets

func make_label(text: String, font_size: int = 28, color: Color = Color.WHITE, bold: bool = false,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold)
	return l


func make_wrapped_label(text: String, font_size: int = 26, color: Color = Color.WHITE,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := make_label(text, font_size, color, false, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func add_outline(label: Label, color: Color, size: int = 8) -> void:
	label.add_theme_color_override("font_outline_color", color)
	label.add_theme_constant_override("outline_size", size)


func add_shadow(label: Label, offset: Vector2 = Vector2(0, 5), color: Color = Color(0, 0, 0, 0.3)) -> void:
	label.add_theme_color_override("font_shadow_color", color)
	label.add_theme_constant_override("shadow_offset_x", int(offset.x))
	label.add_theme_constant_override("shadow_offset_y", int(offset.y))


## Big rounded game button with press animation and click sound.
func make_button(text: String, color_name: String = "primary", font_size: int = 34, min_height: int = 96) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	b.focus_mode = Control.FOCUS_NONE
	style_button(b, c(color_name), int(min_height * 0.3))
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", font_size)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	b.add_theme_color_override("font_outline_color", c(color_name).darkened(0.35))
	b.add_theme_constant_override("outline_size", 6)
	add_press_feedback(b)
	return b


## Large two-line pill button (title + small subtitle), like a main PLAY button.
func make_big_button(title: String, subtitle: String, color_name: String = "orange",
		text_color: Color = Color("6b2e05"), width: int = 420, height: int = 104) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(width, height)
	b.focus_mode = Control.FOCUS_NONE
	style_button(b, c(color_name), int(height * 0.5))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -4)
	b.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -8
	var t := make_label(title, int(height * 0.4), text_color, true)
	t.add_theme_font_override("font", font_black)
	box.add_child(t)
	if subtitle != "":
		var s := make_label(subtitle, int(height * 0.19), text_color.lerp(c(color_name), 0.35), true)
		box.add_child(s)
		b.set_meta("subtitle", s)
	ignore_mouse_recursive(box)
	add_press_feedback(b)
	return b


## Rounded-square icon button with a caption underneath (bottom menu row).
## Returns the container; the button is stored in meta "button".
func make_tile_button(kind: String, caption: String, color_name: String = "tile_btn", side: int = 84) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var b := Button.new()
	b.custom_minimum_size = Vector2(side, side)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	style_button(b, c(color_name), int(side * 0.24))
	var icon := Icon.new()
	icon.kind = kind
	b.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := side * 0.26
	icon.offset_left = m
	icon.offset_right = -m
	icon.offset_top = m - 3
	icon.offset_bottom = -m - 3
	b.set_meta("icon", icon)
	add_press_feedback(b)
	box.add_child(b)
	var l := make_label(caption, 20, Color.WHITE, true)
	add_outline(l, c("navy"), 6)
	box.add_child(l)
	box.set_meta("button", b)
	box.set_meta("label", l)
	return box


## (Re)applies the coloured styleboxes of a button – also used for toggles.
func style_button(b: Button, base: Color, radius: int = 28) -> void:
	b.add_theme_stylebox_override("normal", stylebox(base, radius, 6, 8))
	b.add_theme_stylebox_override("hover", stylebox(base.lightened(0.08), radius, 6, 8))
	b.add_theme_stylebox_override("pressed", stylebox(base.darkened(0.08), radius, 2, 3))
	b.add_theme_stylebox_override("hover_pressed", stylebox(base.darkened(0.08), radius, 2, 3))
	b.add_theme_stylebox_override("disabled", stylebox(c("gray"), radius, 0, 6))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Round button that shows a vector Icon.
func make_icon_button(kind: String, color_name: String = "card_strong", diameter: int = 84,
		icon_color: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.focus_mode = Control.FOCUS_NONE
	style_button(b, c(color_name), int(diameter * 0.5))
	var icon := Icon.new()
	icon.kind = kind
	icon.color = icon_color
	b.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := diameter * 0.27
	icon.offset_left = m
	icon.offset_right = -m
	icon.offset_top = m - 3
	icon.offset_bottom = -m - 3
	b.set_meta("icon", icon)
	add_press_feedback(b)
	return b


func set_button_icon(b: Button, kind: String) -> void:
	if b and b.has_meta("icon"):
		b.get_meta("icon").kind = kind


func sound_icon() -> String:
	return "sound_on" if GameData.is_sound_on() else "sound_off"


## Squash on press, bounce on release, click + tiny vibration.
func add_press_feedback(b: BaseButton) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func(): _tween_scale(b, Vector2(0.93, 0.93), 0.08))
	b.button_up.connect(func(): _tween_scale(b, Vector2.ONE, 0.22))
	b.pressed.connect(_on_feedback_pressed)


func _on_feedback_pressed() -> void:
	SoundManager.play("click")
	GameData.vibrate(8)


func _tween_scale(ctrl: Control, target: Vector2, duration: float) -> void:
	if not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
		return
	var tw := ctrl.create_tween()
	tw.tween_property(ctrl, "scale", target, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Small glass card with a caption and a big value. Returns
## {"panel": PanelContainer, "value": Label, "caption": Label, "style": StyleBoxFlat}.
func make_stat_card(caption: String, value: String, value_size: int = 40) -> Dictionary:
	var panel := PanelContainer.new()
	var style := glass_style(24)
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	var cap := make_label(caption, 19, Color(1, 1, 1, 0.7), true)
	var val := make_label(value, value_size, Color.WHITE, true)
	box.add_child(cap)
	box.add_child(val)
	panel.resized.connect(func(): panel.pivot_offset = panel.size * 0.5)
	return {"panel": panel, "value": val, "caption": cap, "style": style}


func make_progress_bar(fill_color: Color, height: int = 18, back_color: Color = Color(0, 0, 0, 0.12)) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0
	bar.max_value = 100
	bar.custom_minimum_size = Vector2(0, height)
	bar.add_theme_stylebox_override("background", stylebox(back_color, int(height * 0.5)))
	bar.add_theme_stylebox_override("fill", stylebox(fill_color, int(height * 0.5)))
	return bar


func spacer(height: float = 0.0, expand: bool = false) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func make_star_row(count: int, star_size: int = 30, gap: int = 4) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var s := Icon.new()
		s.kind = "star"
		s.color = c("yellow") if i < count else Color(0, 0, 0, 0.18)
		s.custom_minimum_size = Vector2(star_size, star_size)
		row.add_child(s)
	return row


## Makes a whole subtree transparent to touches (used for button contents).
func ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse_recursive(child)


## Fade + bounce entrance animation.
func pop_in(ctrl: Control, delay: float = 0.0) -> void:
	ctrl.modulate.a = 0.0
	var tw := ctrl.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(_prepare_pop.bind(ctrl))
	tw.tween_property(ctrl, "modulate:a", 1.0, 0.22)
	tw.parallel().tween_property(ctrl, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _prepare_pop(ctrl: Control) -> void:
	ctrl.pivot_offset = ctrl.size * 0.5
	ctrl.scale = Vector2(0.85, 0.85)


# ------------------------------------------------------------------ geometry

## Clockwise rounded-rectangle outline (used for textured tiles).
func rounded_rect_points(rect: Rect2, radius: float, segments: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if r <= 0.5:
		pts.append(rect.position)
		pts.append(Vector2(rect.end.x, rect.position.y))
		pts.append(rect.end)
		pts.append(Vector2(rect.position.x, rect.end.y))
		return pts
	var centers := [
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.position.y + r),
	]
	var starts := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for corner in 4:
		var center: Vector2 = centers[corner]
		var start: float = starts[corner]
		for i in segments + 1:
			var a := start + (PI * 0.5) * float(i) / float(segments)
			pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


## Jigsaw-piece outline centred on (0,0) with a side length of `side`:
## knob on top, knob on the right, notch on the bottom, flat left side.
func piece_polygon(side: float = 1.0) -> PackedVector2Array:
	var h := side * 0.5
	var r := side * 0.17
	var seg := 10
	var pts := PackedVector2Array()
	pts.append(Vector2(-h, -h))
	pts.append(Vector2(-r, -h))
	for i in range(1, seg):
		var a := PI + PI * float(i) / seg
		pts.append(Vector2(cos(a) * r, -h + sin(a) * r))
	pts.append(Vector2(r, -h))
	pts.append(Vector2(h, -h))
	pts.append(Vector2(h, -r))
	for i in range(1, seg):
		var a := -PI * 0.5 + PI * float(i) / seg
		pts.append(Vector2(h + cos(a) * r, sin(a) * r))
	pts.append(Vector2(h, r))
	pts.append(Vector2(h, h))
	pts.append(Vector2(r, h))
	for i in range(1, seg):
		var a := -PI * float(i) / seg
		pts.append(Vector2(cos(a) * r, h + sin(a) * r))
	pts.append(Vector2(-r, h))
	pts.append(Vector2(-h, h))
	return pts


# ------------------------------------------------------------------- helpers

func format_time(seconds: float) -> String:
	var s := int(ceil(maxf(seconds, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]


func format_time_precise(seconds: float) -> String:
	if seconds < 0.0:
		return "--"
	var whole := int(seconds)
	var tenths := int((seconds - whole) * 10.0)
	return "%d:%02d.%d" % [whole / 60, whole % 60, tenths]


func format_number(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Safe-area insets (camera notches, gesture bars) in viewport pixels.
## Returns {"left", "top", "right", "bottom"}; all zero on desktop.
func safe_margins(viewport: Viewport) -> Dictionary:
	var out := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if viewport == null or not OS.has_feature("mobile"):
		return out
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return out
	var k := viewport.get_visible_rect().size.x / float(screen.x)
	out["left"] = maxf(0.0, safe.position.x * k)
	out["top"] = maxf(0.0, safe.position.y * k)
	out["right"] = maxf(0.0, (screen.x - safe.end.x) * k)
	out["bottom"] = maxf(0.0, (screen.y - safe.end.y) * k)
	return out
