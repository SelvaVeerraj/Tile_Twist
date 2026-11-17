extends Control
## Celebration confetti. Add it to a full-screen parent and call burst().
## Frees itself once every particle has fallen off screen.

var _parts: Array = []
var _colors: Array = []
var _running := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_colors = [UIKit.c("yellow"), UIKit.c("pink"), UIKit.c("blue"), UIKit.c("green"), UIKit.c("primary"), UIKit.c("purple"), Color.WHITE]


func burst(count: int = 150) -> void:
	var view := get_viewport_rect().size
	for i in count:
		var from_left := i % 2 == 0
		var dir := 1.0 if from_left else -1.0
		_parts.append({
			"pos": Vector2(-20.0 if from_left else view.x + 20.0, randf_range(view.y * 0.35, view.y * 0.65)),
			"vel": Vector2(randf_range(350.0, 1050.0) * dir, randf_range(-1400.0, -500.0)),
			"rot": randf() * TAU,
			"spin": randf_range(-9.0, 9.0),
			"w": randf_range(10.0, 20.0),
			"h": randf_range(6.0, 12.0),
			"color": _colors[randi() % _colors.size()],
			"life": randf_range(2.2, 3.4),
		})
	_running = true


func _process(delta: float) -> void:
	if not _running:
		return
	var alive: Array = []
	for p in _parts:
		var v: Vector2 = p["vel"]
		v.y += 1500.0 * delta
		v.x *= 0.985
		p["vel"] = v
		p["pos"] = (p["pos"] as Vector2) + v * delta
		p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) > 0.0:
			alive.append(p)
	_parts = alive
	queue_redraw()
	if _parts.is_empty():
		queue_free()


func _draw() -> void:
	for p in _parts:
		var w := float(p["w"])
		var h := float(p["h"])
		var col: Color = p["color"]
		col.a = clampf(float(p["life"]) * 2.0, 0.0, 1.0)
		draw_set_transform(p["pos"], float(p["rot"]), Vector2.ONE)
		draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
