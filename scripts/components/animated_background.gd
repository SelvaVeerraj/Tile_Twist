extends Control
## Bright sky background: a blue gradient, slowly drifting clouds, a soft cloud
## bank along the bottom and a few faint jigsaw pieces floating upwards.

const CLOUD_COUNT := 6
const PIECE_COUNT := 9

var _clouds: Array = []
var _pieces: Array = []
var _poly: PackedVector2Array
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poly = UIKit.piece_polygon(1.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in CLOUD_COUNT:
		_clouds.append({
			"x": rng.randf_range(-0.1, 1.1),
			"y": rng.randf_range(0.06, 0.5),
			"scale": rng.randf_range(0.6, 1.3),
			"speed": rng.randf_range(0.004, 0.012),
		})
	for i in PIECE_COUNT:
		_pieces.append({
			"x": rng.randf(),
			"y": rng.randf(),
			"size": rng.randf_range(40.0, 100.0),
			"speed": rng.randf_range(0.008, 0.025),
			"rot": rng.randf() * TAU,
			"spin": rng.randf_range(-0.3, 0.3),
			"alpha": rng.randf_range(0.08, 0.16),
		})


func _process(delta: float) -> void:
	_t += delta
	for c in _clouds:
		c["x"] = float(c["x"]) + float(c["speed"]) * delta
		if float(c["x"]) > 1.25:
			c["x"] = -0.25
			c["y"] = randf_range(0.06, 0.5)
	for p in _pieces:
		p["y"] = float(p["y"]) - float(p["speed"]) * delta
		p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		if float(p["y"]) < -0.15:
			p["y"] = 1.15
			p["x"] = randf()
	queue_redraw()


func _draw() -> void:
	var top: Color = UIKit.c("bg_top")
	var bottom: Color = UIKit.c("bg_bottom")
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([top, top, bottom, bottom]))

	# Floating jigsaw pieces (behind the clouds).
	for p in _pieces:
		var pos := Vector2(float(p["x"]) * size.x, float(p["y"]) * size.y)
		var s := float(p["size"])
		draw_set_transform(pos, float(p["rot"]), Vector2(s, s))
		draw_colored_polygon(_poly, Color(1, 1, 1, float(p["alpha"])))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Drifting clouds.
	for c in _clouds:
		_draw_cloud(Vector2(float(c["x"]) * size.x, float(c["y"]) * size.y), 90.0 * float(c["scale"]), Color(1, 1, 1, 0.85))

	# Cloud bank along the bottom edge, gently breathing.
	var bank: Color = UIKit.c("cloud")
	var step := 150.0
	var n := int(size.x / step) + 2
	for i in n:
		var x := i * step - 40.0
		var r := 110.0 + 30.0 * sin(i * 1.7) + 6.0 * sin(_t * 0.8 + i)
		draw_circle(Vector2(x, size.y + 30.0), r, bank)
	draw_rect(Rect2(0, size.y - 20.0, size.x, 20.0), bank)


func _draw_cloud(center: Vector2, r: float, col: Color) -> void:
	# Opaque-looking puff made of overlapping circles drawn as one polygon
	# so translucent overlaps don't show darker seams.
	var puffs := [Vector2(-0.9, 0.15), Vector2(-0.35, -0.25), Vector2(0.3, -0.35), Vector2(0.9, 0.1), Vector2(0.0, 0.2)]
	var radii := [0.45, 0.6, 0.7, 0.5, 0.55]
	var pts := PackedVector2Array()
	# Sample the union outline by casting rays from the centre.
	for i in 48:
		var a := TAU * float(i) / 48.0
		var dir := Vector2(cos(a), sin(a))
		var best := 0.0
		for k in puffs.size():
			var pc: Vector2 = puffs[k]
			var pr: float = radii[k]
			# Furthest intersection of the ray with this circle.
			var b := dir.dot(pc)
			var disc := b * b - (pc.length_squared() - pr * pr)
			if disc >= 0.0:
				best = maxf(best, b + sqrt(disc))
		pts.append(center + dir * best * r)
	draw_colored_polygon(pts, col)
