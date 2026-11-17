extends RefCounted
## Pure puzzle rules – no nodes and no drawing, so it is easy to unit test
## (see tests/test_puzzle_logic.gd).
##
## The board has grid_size × grid_size slots, numbered row by row.
## Every tile has a unique id equal to the slot it belongs in – its
## "correct-position identifier". `slots[s]` holds the id of the tile that is
## currently sitting in slot s, so a tile is correct when slots[s] == s and
## the puzzle is solved only when that holds for EVERY slot.
##
## Tiles are swapped freely (no empty-space sliding), so every permutation can
## be solved: any shuffle produced here is always solvable.

var grid_size: int = 3
var tile_count: int = 9
var slots: Array[int] = []
var rng := RandomNumberGenerator.new()


func _init(p_grid_size: int = 3, seed_value: int = -1) -> void:
	grid_size = maxi(2, p_grid_size)
	tile_count = grid_size * grid_size
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	reset_solved()


## Puts every tile back into its own slot.
func reset_solved() -> void:
	slots.clear()
	for i in tile_count:
		slots.append(i)


## Shuffles into a random *derangement*: no tile starts in its correct slot.
## That guarantees the puzzle is never already solved, and no tile is locked
## before the player has done anything.
func shuffle() -> void:
	# Fisher–Yates + rejection sampling (~37% of permutations are
	# derangements, so this almost always succeeds within a few tries).
	for _attempt in 100:
		reset_solved()
		for i in range(tile_count - 1, 0, -1):
			var j := rng.randi_range(0, i)
			_swap_raw(i, j)
		if count_correct() == 0:
			return
	# Guaranteed fallback: Sattolo's algorithm always yields a single cycle,
	# which is a derangement.
	reset_solved()
	for i in range(tile_count - 1, 0, -1):
		var j := rng.randi_range(0, i - 1)
		_swap_raw(i, j)


## Swaps the tiles in two slots. Returns how many tiles became correct.
func swap(a: int, b: int) -> int:
	if a == b or not is_valid_slot(a) or not is_valid_slot(b):
		return 0
	var before := int(is_correct(a)) + int(is_correct(b))
	_swap_raw(a, b)
	var after := int(is_correct(a)) + int(is_correct(b))
	return maxi(0, after - before)


func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < tile_count


## True when the tile in `slot` has the id that belongs there.
func is_correct(slot: int) -> bool:
	return slots[slot] == slot


func tile_at(slot: int) -> int:
	return slots[slot]


func slot_of_tile(tile_id: int) -> int:
	return slots.find(tile_id)


func count_correct() -> int:
	var n := 0
	for i in tile_count:
		if slots[i] == i:
			n += 1
	return n


## Success is declared only when every single tile id matches its slot.
func is_solved() -> bool:
	for i in tile_count:
		if slots[i] != i:
			return false
	return true


func misplaced_slots() -> Array[int]:
	var out: Array[int] = []
	for i in tile_count:
		if slots[i] != i:
			out.append(i)
	return out


## Minimum number of swaps needed to solve the current arrangement:
## tile_count minus the number of permutation cycles.
func min_swaps_to_solve() -> int:
	var visited: Array[bool] = []
	visited.resize(tile_count)
	visited.fill(false)
	var cycles := 0
	for i in tile_count:
		if visited[i]:
			continue
		cycles += 1
		var j := i
		while not visited[j]:
			visited[j] = true
			j = slots[j]
	return tile_count - cycles


## Picks one misplaced tile for the hint system.
## Returns {"from": slot the tile is in now, "to": slot it belongs in},
## or an empty dictionary when the puzzle is solved.
func find_hint() -> Dictionary:
	var wrong := misplaced_slots()
	if wrong.is_empty():
		return {}
	var from_slot: int = wrong[rng.randi_range(0, wrong.size() - 1)]
	return {"from": from_slot, "to": slots[from_slot]}


func _swap_raw(a: int, b: int) -> void:
	var tmp := slots[a]
	slots[a] = slots[b]
	slots[b] = tmp
