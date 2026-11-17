extends RefCounted
## Difficulty tables, campaign progression, scoring and star rating.
## Everything is static so any script can `preload` this file and call it.

const HINTS_PER_LEVEL := 3
const MAX_LEVEL := 50
const DAILY_BONUS := 500
const DIFFICULTIES := ["easy", "medium", "hard", "expert"]

## grid  – tiles per side
## time  – countdown in seconds
## mult  – score multiplier
## base  – points for finishing at all
const CONFIG := {
	"easy": {"name": "Easy", "grid": 2, "time": 60, "mult": 1.0, "base": 500, "color": "green"},
	"medium": {"name": "Medium", "grid": 3, "time": 90, "mult": 1.5, "base": 1000, "color": "blue"},
	"hard": {"name": "Hard", "grid": 4, "time": 120, "mult": 2.0, "base": 2000, "color": "primary"},
	"expert": {"name": "Expert", "grid": 5, "time": 180, "mult": 3.0, "base": 3500, "color": "pink"},
}

## Daily challenge difficulty rotates by weekday (0 = Sunday).
const DAILY_ROTATION := ["hard", "medium", "hard", "expert", "medium", "hard", "expert"]


static func get_config(difficulty: String) -> Dictionary:
	if CONFIG.has(difficulty):
		return CONFIG[difficulty]
	return CONFIG["easy"]


static func display_name(difficulty: String) -> String:
	return str(get_config(difficulty)["name"])


## Progressive difficulty for the 50-level campaign: the grid grows as you advance.
##   1–5 Easy 2×2 · 6–15 Medium 3×3 · 16–30 Hard 4×4 · 31–50 Expert 5×5
static func difficulty_for_level(level: int) -> String:
	if level <= 5:
		return "easy"
	if level <= 15:
		return "medium"
	if level <= 30:
		return "hard"
	return "expert"


static func daily_difficulty() -> String:
	var d := Time.get_date_dict_from_system()
	return str(DAILY_ROTATION[int(d["weekday"]) % 7])


static func combo_points(combo: int, difficulty: String) -> int:
	return int(25.0 * combo * float(get_config(difficulty)["mult"]))


static func hint_penalty(difficulty: String) -> int:
	return int(100.0 * float(get_config(difficulty)["mult"]))


## Score for a completed puzzle. Returns a breakdown for the success screen.
static func compute_score(difficulty: String, time_left: float, moves: int, min_moves: int,
		combo_bonus: int, hints_used: int, is_daily: bool) -> Dictionary:
	var cfg := get_config(difficulty)
	var mult := float(cfg["mult"])
	var base := int(cfg["base"])
	# Faster completion → more points.
	var time_bonus := int(time_left * 10.0 * mult)
	# Fewer moves → more points. Every move above the optimum costs a little.
	var extra_moves := maxi(0, moves - min_moves)
	var move_bonus := maxi(0, int(base * 0.6 - extra_moves * 15.0 * mult))
	var penalty := hints_used * hint_penalty(difficulty)
	var daily := DAILY_BONUS if is_daily else 0
	var total := maxi(0, base + time_bonus + move_bonus + combo_bonus + daily - penalty)
	return {
		"base": base,
		"time_bonus": time_bonus,
		"move_bonus": move_bonus,
		"combo_bonus": combo_bonus,
		"hint_penalty": penalty,
		"daily_bonus": daily,
		"total": total,
	}


## Points shown when time runs out: credit for the tiles already placed.
static func partial_score(correct: int, difficulty: String, combo_bonus: int, hints_used: int) -> int:
	var mult := float(get_config(difficulty)["mult"])
	return maxi(0, int(correct * 20.0 * mult) + combo_bonus - hints_used * hint_penalty(difficulty))


## 1–3 stars from completion time and move efficiency.
static func compute_stars(time_used: float, time_limit: float, moves: int, min_moves: int) -> int:
	var time_ratio := time_used / maxf(1.0, time_limit)
	var move_ratio := float(moves) / float(maxi(1, min_moves))
	if time_ratio <= 0.5 and move_ratio <= 1.5:
		return 3
	if time_ratio <= 0.8 and move_ratio <= 2.5:
		return 2
	return 1
