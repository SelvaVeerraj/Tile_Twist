extends SceneTree
## Headless self-test for the puzzle rules.
## Run:  godot --headless --path . --script res://tests/test_puzzle_logic.gd

const PuzzleLogic = preload("res://scripts/core/puzzle_logic.gd")
const LevelConfig = preload("res://scripts/core/level_config.gd")

var failures := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", msg)


func _init() -> void:
	for size in [2, 3, 4, 5]:
		for i in 2000:
			var p = PuzzleLogic.new(size)
			p.shuffle()
			# Unique ids: the board is a permutation of 0..n-1.
			var sorted: Array = p.slots.duplicate()
			sorted.sort()
			var ok := true
			for k in p.tile_count:
				if sorted[k] != k:
					ok = false
			check(ok, "slots must be a permutation (size %d)" % size)
			check(not p.is_solved(), "shuffle must never be solved (size %d)" % size)
			check(p.count_correct() == 0, "shuffle should start with no tile in place (size %d)" % size)
			# Solvable: greedily swap each tile home and count the swaps.
			var expected: int = p.min_swaps_to_solve()
			var swaps := 0
			for s in p.tile_count:
				while p.tile_at(s) != s:
					p.swap(s, p.tile_at(s))
					swaps += 1
			check(p.is_solved(), "greedy solve must finish (size %d)" % size)
			check(swaps == expected, "min_swaps mismatch: %d vs %d" % [swaps, expected])

	# Swap return value counts newly correct tiles.
	var q = PuzzleLogic.new(2, 1)
	q.slots.assign([1, 0, 3, 2])
	check(q.swap(0, 1) == 2, "swapping a 2-cycle places two tiles")
	check(not q.is_solved(), "half solved is not solved")
	check(q.swap(2, 3) == 2, "second 2-cycle")
	check(q.is_solved(), "fully solved")

	# Seeded shuffles are reproducible (daily challenge).
	var a = PuzzleLogic.new(4, 12345)
	var b = PuzzleLogic.new(4, 12345)
	a.shuffle()
	b.shuffle()
	check(a.slots == b.slots, "same seed → same shuffle")

	# Hints always point a misplaced tile to its own slot.
	var h = PuzzleLogic.new(3)
	h.shuffle()
	var hint: Dictionary = h.find_hint()
	check(h.tile_at(int(hint["from"])) == int(hint["to"]), "hint targets the tile's correct slot")

	# Stars and scoring sanity.
	check(LevelConfig.compute_stars(10, 60, 3, 3) == 3, "fast + optimal = 3 stars")
	check(LevelConfig.compute_stars(59, 60, 30, 3) == 1, "slow + wasteful = 1 star")
	var sc: Dictionary = LevelConfig.compute_score("hard", 60.0, 15, 15, 0, 0, false)
	check(int(sc["total"]) > 0, "score positive")

	if failures == 0:
		print("All puzzle logic tests passed.")
	else:
		printerr("%d test(s) failed." % failures)
	quit(1 if failures > 0 else 0)
