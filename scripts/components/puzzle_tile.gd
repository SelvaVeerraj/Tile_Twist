extends Control
## One puzzle tile. It draws its slice of the shared puzzle texture as a
## textured rounded rectangle, plus every visual state: lifted while dragged,
## highlighted as a drop target, locked when correct, hint pulses, flashes.
##
## All tiles share ONE texture and only differ by `region`, which keeps memory
## use tiny regardless of grid size.

## Correct-position identifier: the slot this tile belongs in.
var tile_id: int = 0
## Slot the tile currently occupies.
var current_slot: int = 0
var texture: Texture2D
## Area of the texture this tile shows.
var region: Rect2 = Rect2()

var show_number: bool = false:
	set(value):
		show_number = value
		queue_redraw()
var locked: bool = false:
	set(value):
		locked = value
		queue_redraw()
var lift: float = 0.0:
	set(value):
		lift = value
		queue_redraw()
var drop_target: bool = false:
	set(value):
		drop_target = value
		queue_redraw()
var correct_flash: float = 0.0:
	set(value):
		correct_flash = value
		queue_redraw()
var hint: bool = false:
	set(value):
		hint = value
		_update_processing()
var hint_target: bool = false:
	set(value):
		hint_target = value
		_update_processing()
var corner: float = 12.0:
	set(value):
		corner = value
		_dirty = true
		queue_redraw()
## When the puzzle is solved, borders disappear so the full picture shows.
var solved_mode: bool = false:
	set(value):
		solved_mode = value
		queue_redraw()

var _pts := PackedVector2Array()
var _outline := PackedVector2Array()
var _uvs := PackedVector2Array()
var _cols := PackedColorArray()
var _dirty := true
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	set_process(false)


func _on_resized() -> void:
	_dirty = true
	pivot_offset = size * 0.5
	queue_redraw()


func _update_processing() -> void:
	set_process(hint or hint_target)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _rebuild() -> void:
	_pts = UIKit.rounded_rect_points(Rect2(Vector2.ZERO, size), corner)
	_outline = _pts.duplicate()
	_outline.append(_pts[0])
	_uvs.resize(_pts.size())
	_cols.resize(_pts.size())
	var tex_size := texture.get_size()
	for i in _pts.size():
		var f := _pts[i] / size
		_uvs[i] = (region.position + f * region.size) / tex_size
		_cols[i] = Color.WHITE
	_dirty = false


func _draw() -> void:
	if texture == null or size.x <= 2.0:
		return
	if _dirty:
		_rebuild()

	# Drop shadow while lifted.
	if lift > 0.01:
		draw_set_transform(Vector2(4, 12) * lift, 0.0, Vector2.ONE)
		draw_colored_polygon(_pts, Color(0, 0, 0, 0.38 * lift))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The picture slice itself.
	draw_polygon(_pts, _cols, _uvs, texture)

	if not solved_mode:
		draw_polyline(_outline, Color(1, 1, 1, 0.28), 2.0, true)

	if locked and not solved_mode:
		draw_polyline(_outline, Color(0.25, 0.92, 0.55, 0.95), 4.0, true)
		var r := size.x * 0.085
		var c := size - Vector2(r, r) * 1.5
		draw_circle(c, r, Color(0.18, 0.76, 0.45, 0.95))
		var check := PackedVector2Array([c + Vector2(-0.5, 0.0) * r, c + Vector2(-0.12, 0.4) * r, c + Vector2(0.5, -0.35) * r])
		draw_polyline(check, Color.WHITE, maxf(2.0, r * 0.28), true)

	if drop_target:
		draw_colored_polygon(_pts, Color(1, 1, 1, 0.28))
		draw_polyline(_outline, Color.WHITE, 6.0, true)

	if lift > 0.01:
		draw_polyline(_outline, Color(1.0, 0.84, 0.3, lift), 5.0, true)

	if hint:
		var k := 0.5 + 0.5 * sin(_time * 7.0)
		draw_colored_polygon(_pts, Color(1.0, 0.85, 0.2, 0.15 + 0.2 * k))
		draw_polyline(_outline, Color(1.0, 0.85, 0.2, 0.6 + 0.4 * k), 6.0, true)

	if hint_target:
		var k2 := 0.5 + 0.5 * sin(_time * 7.0 + PI)
		draw_colored_polygon(_pts, Color(0.3, 0.9, 1.0, 0.12 + 0.2 * k2))
		draw_polyline(_outline, Color(0.3, 0.9, 1.0, 0.6 + 0.4 * k2), 6.0, true)

	if correct_flash > 0.0:
		draw_colored_polygon(_pts, Color(1, 1, 1, 0.6 * correct_flash))

	if show_number and not solved_mode:
		var nr := maxf(12.0, size.x * 0.12)
		var nc := Vector2(nr + 4.0, nr + 4.0)
		draw_circle(nc, nr, Color(0, 0, 0, 0.55))
		var fs := int(nr * 1.1)
		draw_string(UIKit.font_bold, Vector2(nc.x - nr, nc.y + fs * 0.36), str(tile_id + 1),
				HORIZONTAL_ALIGNMENT_CENTER, nr * 2.0, fs, Color.WHITE)
