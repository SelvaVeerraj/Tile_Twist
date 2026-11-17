extends Control
## Animated game logo: four colourful jigsaw pieces that gently bob and sway.

var _t := 0.0
var _poly: PackedVector2Array
var _colors: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poly = UIKit.piece_polygon(1.0)
	_colors = [UIKit.c("primary"), UIKit.c("blue"), UIKit.c("green"), UIKit.c("pink")]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 1.0:
		return
	var center := size * 0.5
	var piece := s * 0.36
	var offsets := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in 4:
		var off: Vector2 = offsets[i]
		var bob := sin(_t * 2.0 + i * 1.3) * s * 0.025
		var pos := center + off * piece * 0.6 + Vector2(0, bob)
		var rot := i * PI * 0.5 + sin(_t * 1.4 + i) * 0.06
		var col: Color = _colors[i]
		# Shadow, body, then a soft highlight.
		draw_set_transform(pos + Vector2(0, s * 0.03), rot, Vector2(piece, piece))
		draw_colored_polygon(_poly, Color(0, 0, 0, 0.25))
		draw_set_transform(pos, rot, Vector2(piece, piece))
		draw_colored_polygon(_poly, col)
		draw_set_transform(pos + Vector2(-piece * 0.06, -piece * 0.06), rot, Vector2(piece, piece) * 0.62)
		draw_colored_polygon(_poly, Color(1, 1, 1, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
