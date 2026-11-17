extends Control
## Vector icon drawn with 2D primitives. Needs no font glyphs or image files,
## so icons stay crisp at any resolution and look the same on every device.
## Coordinates below are in a 0..1 unit square scaled to the control size.

var kind: String = "pause":
	set(value):
		kind = value
		queue_redraw()

var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()

var _o := Vector2.ZERO
var _s := 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _s


func _poly(coords: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(0, coords.size(), 2):
		pts.append(_p(coords[i], coords[i + 1]))
	return pts


func _star_points(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + PI * float(i) / 5.0
		var r := outer if i % 2 == 0 else inner
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw() -> void:
	_s = minf(size.x, size.y)
	if _s <= 1.0:
		return
	_o = (size - Vector2(_s, _s)) * 0.5
	var w := maxf(2.0, _s * 0.11)
	match kind:
		"pause":
			draw_rect(Rect2(_p(0.16, 0.1), Vector2(0.24, 0.8) * _s), color)
			draw_rect(Rect2(_p(0.6, 0.1), Vector2(0.24, 0.8) * _s), color)
		"play":
			draw_colored_polygon(_poly([0.24, 0.08, 0.92, 0.5, 0.24, 0.92]), color)
		"restart":
			var c := _p(0.5, 0.53)
			var r := 0.34 * _s
			var a0 := -PI * 0.5 + 0.55
			var a1 := -PI * 0.5 + TAU - 0.35
			draw_arc(c, r, a0, a1, 32, color, w, true)
			var e := c + Vector2(cos(a1), sin(a1)) * r
			var tdir := Vector2(-sin(a1), cos(a1))
			var nrm := Vector2(cos(a1), sin(a1))
			draw_colored_polygon(PackedVector2Array([e + tdir * _s * 0.2, e + nrm * _s * 0.16, e - nrm * _s * 0.16]), color)
		"eye":
			var pts := PackedVector2Array()
			for i in 17:
				var t := float(i) / 16.0
				pts.append(_p(0.04 + 0.92 * t, 0.5 - 0.3 * sin(PI * t)))
			for i in range(15, 0, -1):
				var t := float(i) / 16.0
				pts.append(_p(0.04 + 0.92 * t, 0.5 + 0.3 * sin(PI * t)))
			pts.append(pts[0])
			draw_polyline(pts, color, w * 0.8, true)
			draw_circle(_p(0.5, 0.5), 0.15 * _s, color)
		"sound_on", "sound_off":
			draw_colored_polygon(_poly([0.06, 0.36, 0.26, 0.36, 0.5, 0.14, 0.5, 0.86, 0.26, 0.64, 0.06, 0.64]), color)
			if kind == "sound_on":
				draw_arc(_p(0.5, 0.5), 0.2 * _s, -0.85, 0.85, 12, color, w * 0.75, true)
				draw_arc(_p(0.5, 0.5), 0.36 * _s, -0.85, 0.85, 16, color, w * 0.75, true)
			else:
				draw_line(_p(0.64, 0.34), _p(0.94, 0.66), color, w * 0.8, true)
				draw_line(_p(0.94, 0.34), _p(0.64, 0.66), color, w * 0.8, true)
		"home":
			draw_colored_polygon(_poly([0.5, 0.06, 0.96, 0.5, 0.04, 0.5]), color)
			draw_colored_polygon(_poly([0.18, 0.44, 0.82, 0.44, 0.82, 0.94, 0.6, 0.94, 0.6, 0.68, 0.4, 0.68, 0.4, 0.94, 0.18, 0.94]), color)
		"bulb":
			draw_circle(_p(0.5, 0.4), 0.3 * _s, color)
			draw_rect(Rect2(_p(0.36, 0.62), Vector2(0.28, 0.16) * _s), color)
			draw_rect(Rect2(_p(0.4, 0.82), Vector2(0.2, 0.1) * _s), color)
		"gear":
			var gc := _p(0.5, 0.5)
			draw_arc(gc, 0.27 * _s, 0.0, TAU, 32, color, 0.15 * _s, true)
			for i in 8:
				draw_set_transform(gc, TAU * i / 8.0, Vector2.ONE)
				draw_rect(Rect2(Vector2(-0.075, -0.48) * _s, Vector2(0.15, 0.17) * _s), color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"trophy":
			draw_colored_polygon(_poly([0.24, 0.08, 0.76, 0.08, 0.73, 0.38, 0.6, 0.56, 0.4, 0.56, 0.27, 0.38]), color)
			draw_arc(_p(0.25, 0.26), 0.13 * _s, PI * 0.5, PI * 1.5, 12, color, w * 0.7, true)
			draw_arc(_p(0.75, 0.26), 0.13 * _s, -PI * 0.5, PI * 0.5, 12, color, w * 0.7, true)
			draw_rect(Rect2(_p(0.44, 0.54), Vector2(0.12, 0.2) * _s), color)
			draw_rect(Rect2(_p(0.26, 0.76), Vector2(0.48, 0.14) * _s), color)
		"star":
			draw_colored_polygon(_star_points(_p(0.5, 0.53), 0.5 * _s, 0.22 * _s), color)
		"back":
			draw_polyline(_poly([0.66, 0.12, 0.3, 0.5, 0.66, 0.88]), color, w * 1.25, true)
		"next":
			draw_polyline(_poly([0.34, 0.12, 0.7, 0.5, 0.34, 0.88]), color, w * 1.25, true)
		"close":
			draw_line(_p(0.18, 0.18), _p(0.82, 0.82), color, w * 1.2, true)
			draw_line(_p(0.82, 0.18), _p(0.18, 0.82), color, w * 1.2, true)
		"check":
			draw_polyline(_poly([0.12, 0.52, 0.4, 0.8, 0.88, 0.22]), color, w * 1.2, true)
		"help":
			var font := get_theme_default_font()
			var fs := int(_s * 0.95)
			draw_string(font, _p(0.0, 0.84), "?", HORIZONTAL_ALIGNMENT_CENTER, _s, fs, color)
		"calendar":
			draw_rect(Rect2(_p(0.1, 0.2), Vector2(0.8, 0.72) * _s), color, false, w * 0.8)
			draw_rect(Rect2(_p(0.1, 0.2), Vector2(0.8, 0.2) * _s), color)
			draw_rect(Rect2(_p(0.26, 0.06), Vector2(0.1, 0.2) * _s), color)
			draw_rect(Rect2(_p(0.64, 0.06), Vector2(0.1, 0.2) * _s), color)
			draw_rect(Rect2(_p(0.28, 0.54), Vector2(0.16, 0.14) * _s), color)
			draw_rect(Rect2(_p(0.56, 0.54), Vector2(0.16, 0.14) * _s), color)
		"grid":
			for gy in 2:
				for gx in 2:
					draw_rect(Rect2(_p(0.08 + gx * 0.46, 0.08 + gy * 0.46), Vector2(0.38, 0.38) * _s), color)
		"lock":
			draw_arc(_p(0.5, 0.42), 0.2 * _s, PI, TAU, 16, color, w * 0.9, true)
			draw_rect(Rect2(_p(0.2, 0.42), Vector2(0.6, 0.5) * _s), color)
		"clock":
			var cc := _p(0.5, 0.56)
			draw_circle(_p(0.2, 0.16), 0.13 * _s, color)
			draw_circle(_p(0.8, 0.16), 0.13 * _s, color)
			draw_circle(cc, 0.4 * _s, color)
			draw_circle(cc, 0.31 * _s, Color(0, 0, 0, 0.35))
			draw_line(cc, cc + Vector2(0, -0.22) * _s, color, w * 0.8, true)
			draw_line(cc, cc + Vector2(0.16, 0.06) * _s, color, w * 0.8, true)
		"chart":
			draw_rect(Rect2(_p(0.08, 0.5), Vector2(0.22, 0.42) * _s), color)
			draw_rect(Rect2(_p(0.39, 0.12), Vector2(0.22, 0.8) * _s), color)
			draw_rect(Rect2(_p(0.7, 0.32), Vector2(0.22, 0.6) * _s), color)
		_:
			draw_circle(_p(0.5, 0.5), 0.4 * _s, color)
