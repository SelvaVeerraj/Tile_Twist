extends Node
## GameData (autoload) – persistent progress, statistics and settings.
## Everything is stored locally as JSON in user:// so the game works offline.

signal achievement_unlocked(achievement: Dictionary)
signal sound_toggled(enabled: bool)
signal data_changed

const Achievements = preload("res://scripts/core/achievements.gd")
const LevelConfig = preload("res://scripts/core/level_config.gd")

const SAVE_PATH := "user://tile_twist_save.json"
const DIFFS := ["easy", "medium", "hard", "expert"]
const MAX_LEADERBOARD := 10
const RECENT_IMAGE_MEMORY := 6

var data: Dictionary = {}


func _ready() -> void:
	load_game()


func _defaults() -> Dictionary:
	return {
		"version": 1,
		"settings": {
			"sound": true,
			"vibration": true,
			"show_preview": true,
			"preview_seconds": 3,
			"tile_numbers": false,
		},
		"highest_score": 0,
		"best_scores": {"easy": 0, "medium": 0, "hard": 0, "expert": 0},
		"best_times": {"easy": -1.0, "medium": -1.0, "hard": -1.0, "expert": -1.0},
		"games_played": 0,
		"puzzles_completed": 0,
		"games_failed": 0,
		"total_moves": 0,
		"three_star_count": 0,
		"max_combo": 0,
		"unlocked_level": 1,
		"level_stars": {},
		"achievements": {},
		"leaderboard": [],
		"daily": {"last_completed": "", "streak": 0, "best_streak": 0, "completions": 0, "best_score": 0},
		"recent_images": [],
	}


# ---------------------------------------------------------------- persistence

func load_game() -> void:
	data = _defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_merge(data, parsed)
	# Older saves came from an endless campaign; clamp to the 50-level cap.
	# MAX_LEVEL + 1 means "every level finished".
	data["unlocked_level"] = clampi(int(data["unlocked_level"]), 1, LevelConfig.MAX_LEVEL + 1)


## Copies saved values over the defaults so new keys added in later
## versions always exist.
func _merge(target: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		if target.has(k) and target[k] is Dictionary and src[k] is Dictionary:
			_merge(target[k], src[k])
		else:
			target[k] = src[k]


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file: %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))


## Wipes progress but keeps the player's settings.
func reset_progress() -> void:
	var settings: Dictionary = data["settings"].duplicate()
	data = _defaults()
	data["settings"] = settings
	save_game()
	data_changed.emit()


# ------------------------------------------------------------------ settings

func get_setting(key: String):
	return data["settings"].get(key)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	save_game()


func is_sound_on() -> bool:
	return bool(get_setting("sound"))


func toggle_sound() -> void:
	set_setting("sound", not is_sound_on())
	sound_toggled.emit(is_sound_on())


func vibrate(ms: int) -> void:
	if bool(get_setting("vibration")) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# --------------------------------------------------------------- stat access

func unlocked_level() -> int:
	return int(data["unlocked_level"])


func levels_completed() -> int:
	return unlocked_level() - 1


func campaign_complete() -> bool:
	return unlocked_level() > LevelConfig.MAX_LEVEL


## The level the PLAY button should start (the last level once all are done).
func current_campaign_level() -> int:
	return mini(unlocked_level(), LevelConfig.MAX_LEVEL)


func highest_score() -> int:
	return int(data["highest_score"])


func best_score(diff: String) -> int:
	return int(data["best_scores"].get(diff, 0))


## Best completion time in seconds, or -1 when never completed.
func best_time(diff: String) -> float:
	return float(data["best_times"].get(diff, -1.0))


func level_stars(level: int) -> int:
	return int(data["level_stars"].get(str(level), 0))


func get_leaderboard() -> Array:
	return data["leaderboard"]


func is_achievement_unlocked(id: String) -> bool:
	return data["achievements"].has(id)


func achievements_unlocked_count() -> int:
	return data["achievements"].size()


# --------------------------------------------------------------- daily stuff

func today_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


func yesterday_key() -> String:
	# Work in "local date as if UTC" to stay consistent with today_key().
	var today := Time.get_date_dict_from_system()
	var t := Time.get_unix_time_from_datetime_dict(today) - 86400
	var d := Time.get_date_dict_from_unix_time(t)
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


## Same number for everybody on the same date → same daily image.
func daily_seed() -> int:
	return today_key().replace("-", "").to_int()


func daily_done_today() -> bool:
	return str(data["daily"]["last_completed"]) == today_key()


func daily_streak() -> int:
	var last := str(data["daily"]["last_completed"])
	if last == today_key() or last == yesterday_key():
		return int(data["daily"]["streak"])
	return 0


# ------------------------------------------------------------- recent images

func get_recent_images() -> Array:
	return data["recent_images"]


func push_recent_image(path: String) -> void:
	var recent: Array = data["recent_images"]
	recent.erase(path)
	recent.push_front(path)
	while recent.size() > RECENT_IMAGE_MEMORY:
		recent.pop_back()


# ----------------------------------------------------------- result handling

## Call when the player actually starts a puzzle (first interaction).
func record_game_started() -> void:
	data["games_played"] = int(data["games_played"]) + 1
	save_game()


## Stores a successful result. Returns what changed so the success screen can
## celebrate it: new_high_score, new_best_time, new_best_for_difficulty,
## unlocked_level (0 = none) and achievements (newly unlocked ids).
func record_win(r: Dictionary) -> Dictionary:
	var info := {
		"new_high_score": false,
		"new_best_time": false,
		"new_best_for_difficulty": false,
		"unlocked_level": 0,
		"achievements": [],
	}
	var diff := str(r["difficulty"])
	var score := int(r["score"])
	var time_used := float(r["time_used"])

	data["puzzles_completed"] = int(data["puzzles_completed"]) + 1
	data["total_moves"] = int(data["total_moves"]) + int(r["moves"])
	data["max_combo"] = maxi(int(data["max_combo"]), int(r["max_combo"]))
	if int(r["stars"]) >= 3:
		data["three_star_count"] = int(data["three_star_count"]) + 1

	if score > highest_score():
		data["highest_score"] = score
		info["new_high_score"] = true
	if score > best_score(diff):
		data["best_scores"][diff] = score
		info["new_best_for_difficulty"] = true
	var bt := best_time(diff)
	if bt < 0.0 or time_used < bt:
		data["best_times"][diff] = snappedf(time_used, 0.01)
		info["new_best_time"] = true

	match str(r["mode"]):
		"campaign":
			var lvl := int(r["level"])
			var key := str(lvl)
			data["level_stars"][key] = maxi(level_stars(lvl), int(r["stars"]))
			if lvl >= unlocked_level():
				data["unlocked_level"] = mini(lvl + 1, LevelConfig.MAX_LEVEL + 1)
				if lvl >= LevelConfig.MAX_LEVEL:
					info["campaign_complete"] = true
				else:
					info["unlocked_level"] = lvl + 1
		"daily":
			var daily: Dictionary = data["daily"]
			var today := today_key()
			if str(daily["last_completed"]) != today:
				if str(daily["last_completed"]) == yesterday_key():
					daily["streak"] = int(daily["streak"]) + 1
				else:
					daily["streak"] = 1
				daily["best_streak"] = maxi(int(daily["best_streak"]), int(daily["streak"]))
				daily["last_completed"] = today
				daily["completions"] = int(daily["completions"]) + 1
			daily["best_score"] = maxi(int(daily["best_score"]), score)

	_add_leaderboard_entry(r)
	info["achievements"] = _unlock_achievements(r)
	save_game()
	data_changed.emit()
	return info


## Stores a failed attempt. Best scores and times are never touched here.
func record_fail(_r: Dictionary) -> void:
	data["games_failed"] = int(data["games_failed"]) + 1
	save_game()
	data_changed.emit()


func _add_leaderboard_entry(r: Dictionary) -> void:
	var board: Array = data["leaderboard"]
	board.append({
		"score": int(r["score"]),
		"difficulty": str(r["difficulty"]),
		"mode": str(r["mode"]),
		"time": snappedf(float(r["time_used"]), 0.1),
		"moves": int(r["moves"]),
		"stars": int(r["stars"]),
		"image": str(r.get("image", "")),
		"date": today_key(),
	})
	board.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	while board.size() > MAX_LEADERBOARD:
		board.pop_back()


func _unlock_achievements(r: Dictionary) -> Array:
	var fresh: Array = []
	for id in Achievements.evaluate(data, r):
		if not data["achievements"].has(id):
			data["achievements"][id] = int(Time.get_unix_time_from_system())
			fresh.append(id)
			achievement_unlocked.emit(Achievements.get_def(id))
	return fresh
