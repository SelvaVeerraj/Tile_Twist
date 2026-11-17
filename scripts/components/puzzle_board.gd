extends Control
## Puzzle board: lays tiles out in a square grid and handles touch
## drag-and-drop. The rules live in PuzzleLogic – this node only presents
## them and reports what happened through signals.
##
## Touch input arrives as emulated mouse events (project setting
## "emulate_mouse_from_touch"), so the same code works with a finger or mouse.
## Godot keeps sending motion events to this control while the press that
## started inside it is held, so dragging past the edge is safe.

signal first_interaction
signal tile_swapped(newly_correct: int)
signal invalid_drop
signal puzzle_solved

const PuzzleTile = preload("res://scripts/components/puzzle_tile.gd")

var logic = null                 # PuzzleLogic instance
var texture: Texture2D
var tiles: Array = []            # index = tile_id
var slot_tiles: Array = []       # index = slot -> tile node in that slot
var grid := 3
var gap := 6.0
var input_enabled := false
var interacted := false
var fail_flash: float = 0.0:
	set(value):
		fail_flash = value
		if _overlay:
			_overlay.queue_redraw()

var _base_gap := 6.0
var _base_corner := 12.0
var _origin := Vector2.ZERO
var _side := 0.0
var _tile_size := 0.0
var _drag_tile = null
var _drag_offset := Vector2.ZERO
var _hover_tile = null
var _intro_pending := false
var _tweens := {}
var _overlay: Control           # top layer: hint arrow + fail tint
var _hint := {}
var _hint_serial := 0
var _bg_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg_style = UIKit.stylebox(Color(0.06, 0.14, 0.38, 0.55), 22)
	_bg_style.set_border_width_all(4)
	_bg_style.border_color = Color(1, 1, 1, 0.9)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	resized.connect(_layout)


# ------------------------------------------------------------------- set-up

## Builds tiles for a freshly shuffled puzzle. Tiles start at their SOLVED
## positions (showing the full picture) until play_shuffle_intro() runs.
func setup(p_logic, p_texture: Texture2D, show_numbers: bool) -> void:
	_drag_tile = null
	_hover_tile = null
	clear_hint()
	for t in tiles:
		t.queue_free()
	tiles.clear()
	_tweens.clear()
	logic = p_logic
	texture = p_texture
	grid = logic.grid_size
	_base_gap = 6.0 if grid <= 3 else 4.0
	_base_corner = 14.0 if grid <= 3 else 9.0
	gap = _base_gap
	interacted = false
	fail_flash = 0.0
	var cell: Vector2 = texture.get_size() / float(grid)
	for id in logic.tile_count:
		var tile = PuzzleTile.new()
		tile.tile_id = id
		tile.texture = texture
		tile.region = Rect2(Vector2(id % grid, id / grid) * cell, cell)
		tile.corner = _base_corner
		tile.show_number = show_numbers
		add_child(tile)
		tiles.append(tile)
	slot_tiles.clear()
	slot_tiles.resize(logic.tile_count)
	for slot in logic.tile_count:
		var t = tiles[logic.tile_at(slot)]
		t.current_slot = slot
		slot_tiles[slot] = t
	move_child(_overlay, get_child_count() - 1)
	_intro_pending = true
	_layout()


func set_show_numbers(on: bool) -> void:
	for t in tiles:
		t.show_number = on


## Animates tiles from the solved picture into their shuffled slots.
func play_shuffle_intro() -> void:
	_intro_pending = false
	if tiles.is_empty():
		return
	var tw := create_tween().set_parallel(true)
	var i := 0
	for t in tiles:
		tw.tween_property(t, "position", slot_rect(t.current_slot).position, 0.5) \
			.set_delay(0.025 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		i += 1
	SoundManager.play("shuffle")
	await tw.finished


# ------------------------------------------------------------------- layout

func _layout() -> void:
	_side = minf(size.x, size.y)
	_origin = (size - Vector2(_side, _side)) * 0.5
	_overlay.position = Vector2.ZERO
	_overlay.size = size
	if logic == null:
		queue_redraw()
		return
	_tile_size = (_side - gap * (grid + 1)) / grid
	for t in tiles:
		if t == _drag_tile:
			continue
		_kill_tween(t)
		var slot: int = t.tile_id if _intro_pending else t.current_slot
		t.size = Vector2(_tile_size, _tile_size)
		t.position = slot_rect(slot).position
		t.pivot_offset = t.size * 0.5
	queue_redraw()


func slot_rect(slot: int) -> Rect2:
	var col := slot % grid
	var row := slot / grid
	var pos := _origin + Vector2(gap + col * (_tile_size + gap), gap + row * (_tile_size + gap))
	return Rect2(pos, Vector2(_tile_size, _tile_size))


func slot_at(p: Vector2) -> int:
	var step := _tile_size + gap
	if step <= 0.0:
		return -1
	var local := p - _origin - Vector2(gap, gap) * 0.5
	var col := int(floor(local.x / step))
	var row := int(floor(local.y / step))
	if col < 0 or row < 0 or col >= grid or row >= grid:
		return -1
	return row * grid + col


func _draw() -> void:
	if _side <= 0.0:
		return
	draw_style_box(_bg_style, Rect2(_origin, Vector2(_side, _side)).grow(4.0))
	if logic == null:
		return
	# Empty-slot placeholders (visible under a lifted tile).
	for s in logic.tile_count:
		draw_rect(slot_rect(s), Color(1, 1, 1, 0.07))


# -------------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if input_enabled and _drag_tile == null:
				_begin_drag(event.position)
		elif _drag_tile != null:
			_end_drag(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _drag_tile != null:
		_update_drag(event.position)
		accept_event()


func _begin_drag(p: Vector2) -> void:
	var slot := slot_at(p)
	if slot < 0:
		return
	if not interacted:
		interacted = true
		first_interaction.emit()
		if not input_enabled:
			return
	var tile = slot_tiles[slot]
	if tile.locked:
		# Correct tiles are locked in place.
		_shake(tile)
		SoundManager.play("locked")
		return
	_kill_tween(tile)
	_drag_tile = tile
	_drag_offset = p - tile.position
	move_child(tile, get_child_count() - 1)
	move_child(_overlay, get_child_count() - 1)
	var tw := _new_tween(tile).set_parallel(true)
	tw.tween_property(tile, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tile, "lift", 1.0, 0.12)
	SoundManager.play("pick")
	GameData.vibrate(12)


func _update_drag(p: Vector2) -> void:
	_drag_tile.position = p - _drag_offset
	var target := _target_slot()
	var new_hover = null
	if target >= 0 and target != _drag_tile.current_slot and not slot_tiles[target].locked:
		new_hover = slot_tiles[target]
	if new_hover != _hover_tile:
		if _hover_tile:
			_hover_tile.drop_target = false
		_hover_tile = new_hover
		if _hover_tile:
			_hover_tile.drop_target = true


func _end_drag(p: Vector2) -> void:
	_update_drag(p)
	var tile = _drag_tile
	var target := _target_slot()
	_drag_tile = null
	if _hover_tile:
		_hover_tile.drop_target = false
		_hover_tile = null
	if target >= 0 and target != tile.current_slot and not slot_tiles[target].locked:
		_swap(tile.current_slot, target)
	else:
		_animate_to_slot(tile, tile.current_slot)
		if target >= 0 and target != tile.current_slot:
			SoundManager.play("locked")
			invalid_drop.emit()
		else:
			SoundManager.play("drop")


## Slot under the centre of the dragged tile.
func _target_slot() -> int:
	if _drag_tile == null:
		return -1
	return slot_at(_drag_tile.position + _drag_tile.size * 0.5)


## Returns a dragged tile to its slot (used on pause, time-up, overlays).
func cancel_drag() -> void:
	if _hover_tile:
		_hover_tile.drop_target = false
		_hover_tile = null
	if _drag_tile:
		var t = _drag_tile
		_drag_tile = null
		_animate_to_slot(t, t.current_slot)


# --------------------------------------------------------------------- swap

func _swap(a: int, b: int) -> void:
	var ta = slot_tiles[a]
	var tb = slot_tiles[b]
	logic.swap(a, b)
	slot_tiles[a] = tb
	slot_tiles[b] = ta
	ta.current_slot = b
	tb.current_slot = a
	_animate_to_slot(ta, b, 0.18)
	_animate_to_slot(tb, a, 0.24)
	if not _hint.is_empty() and (_hint["tile"] == ta or _hint["tile"] == tb or _hint["target"] == ta or _hint["target"] == tb):
		clear_hint()
	# Validation uses tile ids via PuzzleLogic, never the picture itself.
	var newly := 0
	for t in [ta, tb]:
		if logic.is_correct(t.current_slot):
			t.locked = true
			newly += 1
			_celebrate_tile(t)
	SoundManager.play("correct" if newly > 0 else "swap")
	GameData.vibrate(25 if newly > 0 else 10)
	tile_swapped.emit(newly)
	if logic.is_solved():
		input_enabled = false
		puzzle_solved.emit()


func _celebrate_tile(t) -> void:
	var tw := create_tween()
	tw.tween_interval(0.16)
	tw.tween_property(t, "correct_flash", 1.0, 0.08)
	tw.tween_property(t, "correct_flash", 0.0, 0.45)


func _animate_to_slot(tile, slot: int, duration: float = 0.2) -> void:
	var tw := _new_tween(tile).set_parallel(true)
	tw.tween_property(tile, "position", slot_rect(slot).position, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tile, "scale", Vector2.ONE, duration)
	tw.tween_property(tile, "lift", 0.0, duration)


func _shake(tile) -> void:
	var base := slot_rect(tile.current_slot).position
	var tw := _new_tween(tile)
	for dx in [10.0, -10.0, 6.0, -4.0, 0.0]:
		tw.tween_property(tile, "position", base + Vector2(dx, 0), 0.04)


func _new_tween(tile) -> Tween:
	_kill_tween(tile)
	var tw := create_tween()
	_tweens[tile] = tw
	return tw


func _kill_tween(tile) -> void:
	if _tweens.has(tile):
		var tw: Tween = _tweens[tile]
		if tw and tw.is_valid():
			tw.kill()
		_tweens.erase(tile)


# --------------------------------------------------------------------- hint

## Highlights a misplaced tile and the slot where it belongs, with an arrow.
func show_hint(from_slot: int, to_slot: int) -> void:
	clear_hint()
	var tile = slot_tiles[from_slot]
	var target = slot_tiles[to_slot]
	tile.hint = true
	target.hint_target = true
	_hint = {"tile": tile, "target": target}
	_hint_serial += 1
	get_tree().create_timer(4.0).timeout.connect(_on_hint_timeout.bind(_hint_serial))


func _on_hint_timeout(serial: int) -> void:
	if serial == _hint_serial and is_inside_tree():
		clear_hint()


func clear_hint() -> void:
	if not _hint.is_empty():
		if is_instance_valid(_hint["tile"]):
			_hint["tile"].hint = false
		if is_instance_valid(_hint["target"]):
			_hint["target"].hint_target = false
	_hint = {}
	if _overlay:
		_overlay.queue_redraw()


func _process(_delta: float) -> void:
	if not _hint.is_empty():
		_overlay.queue_redraw()


func _draw_overlay() -> void:
	if not _hint.is_empty() and is_instance_valid(_hint["tile"]) and is_instance_valid(_hint["target"]):
		var a: Vector2 = _hint["tile"].position + _hint["tile"].size * 0.5
		var b: Vector2 = _hint["target"].position + _hint["target"].size * 0.5
		var dir := (b - a).normalized()
		var col := Color(1.0, 0.88, 0.25, 0.95)
		var tip := b - dir * _tile_size * 0.18
		draw_line(a, tip, Color(0, 0, 0, 0.35), 12.0, true)
		draw_line(a, tip, col, 7.0, true)
		var nrm := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([tip + dir * 26.0, tip + nrm * 18.0, tip - nrm * 18.0]), col)
		draw_circle(a, 10.0, col)
	if fail_flash > 0.0:
		draw_rect(Rect2(_origin, Vector2(_side, _side)), Color(1.0, 0.2, 0.25, 0.4 * fail_flash))


# ---------------------------------------------------------------- feedback

## Closes the gaps so the finished picture appears seamless.
func play_win_animation() -> void:
	clear_hint()
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	for t in tiles:
		t.solved_mode = true
	var tw := create_tween()
	tw.tween_method(_set_gap_progress, 1.0, 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_inside_tree():
		return
	# Diagonal shine sweeping across the finished picture.
	var shine := create_tween().set_parallel(true)
	for t in tiles:
		var d := 0.04 * float(t.tile_id % grid + t.tile_id / grid)
		shine.tween_property(t, "correct_flash", 0.7, 0.12).set_delay(d)
		shine.tween_property(t, "correct_flash", 0.0, 0.35).set_delay(d + 0.12)
	await shine.finished


func _set_gap_progress(k: float) -> void:
	gap = _base_gap * k
	for t in tiles:
		t.corner = _base_corner * k
	_layout()


func play_fail_animation() -> void:
	var tw := create_tween()
	tw.tween_property(self, "fail_flash", 1.0, 0.12)
	tw.tween_property(self, "fail_flash", 0.0, 0.5)


## Floating "+points" / "Combo x3!" text over the board.
func float_text(text: String, color: Color, big: bool = false) -> void:
	var l: Label = UIKit.make_title_label(text, 56 if big else 42, color, Color(0.1, 0.12, 0.35))
	add_child(l)
	l.size = Vector2(size.x, 90)
	l.position = Vector2(0, size.y * 0.5 - 45.0)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.1)
	tw.tween_property(l, "position:y", l.position.y - 100.0, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.25)
	tw.tween_callback(l.queue_free)
