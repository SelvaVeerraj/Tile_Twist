extends RefCounted
## Achievement definitions and the rules that unlock them.

const LIST := [
	{"id": "first_win", "title": "First Steps", "desc": "Complete your first puzzle"},
	{"id": "ten_wins", "title": "Puzzle Fan", "desc": "Complete 10 puzzles"},
	{"id": "fifty_wins", "title": "Puzzle Master", "desc": "Complete 50 puzzles"},
	{"id": "three_stars", "title": "Superstar", "desc": "Earn 3 stars on a puzzle"},
	{"id": "speedster", "title": "Speed Demon", "desc": "Finish using under 25% of the time"},
	{"id": "perfect_moves", "title": "Efficiency Expert", "desc": "Solve with the minimum possible moves"},
	{"id": "combo_5", "title": "Combo King", "desc": "Reach a x5 combo"},
	{"id": "sharp_eyes", "title": "Sharp Eyes", "desc": "Solve Hard or Expert with no hints or previews"},
	{"id": "expert_win", "title": "Expert Solver", "desc": "Complete an Expert puzzle"},
	{"id": "close_call", "title": "Close Call", "desc": "Finish with under 5 seconds left"},
	{"id": "score_5000", "title": "High Roller", "desc": "Score 5,000+ points in one puzzle"},
	{"id": "daily_first", "title": "Daily Player", "desc": "Complete a Daily Challenge"},
	{"id": "daily_streak_3", "title": "On Fire", "desc": "Reach a 3-day Daily Challenge streak"},
	{"id": "level_10", "title": "Climber", "desc": "Unlock campaign level 10"},
	{"id": "level_25", "title": "Summit", "desc": "Unlock campaign level 25"},
	{"id": "campaign_complete", "title": "Champion", "desc": "Finish all 50 campaign levels"},
]


static func get_def(id: String) -> Dictionary:
	for a in LIST:
		if a["id"] == id:
			return a
	return {"id": id, "title": id, "desc": ""}


## Returns ids of every achievement whose condition holds after a win.
## `d` is the save data (already updated with this result), `r` the result.
static func evaluate(d: Dictionary, r: Dictionary) -> Array:
	var out: Array = []
	if not bool(r.get("success", false)):
		return out
	var completed := int(d["puzzles_completed"])
	if completed >= 1:
		out.append("first_win")
	if completed >= 10:
		out.append("ten_wins")
	if completed >= 50:
		out.append("fifty_wins")
	if int(r["stars"]) >= 3:
		out.append("three_stars")
	if float(r["time_used"]) <= float(r["time_limit"]) * 0.25:
		out.append("speedster")
	if int(r["moves"]) <= int(r["min_moves"]):
		out.append("perfect_moves")
	if int(r["max_combo"]) >= 5:
		out.append("combo_5")
	var diff := str(r["difficulty"])
	if (diff == "hard" or diff == "expert") and int(r["hints"]) == 0 and int(r["previews"]) == 0:
		out.append("sharp_eyes")
	if diff == "expert":
		out.append("expert_win")
	if float(r["time_left"]) < 5.0:
		out.append("close_call")
	if int(r["score"]) >= 5000:
		out.append("score_5000")
	if str(r["mode"]) == "daily":
		out.append("daily_first")
		if int(d["daily"]["streak"]) >= 3:
			out.append("daily_streak_3")
	if int(d["unlocked_level"]) >= 10:
		out.append("level_10")
	if int(d["unlocked_level"]) >= 25:
		out.append("level_25")
	if int(d["unlocked_level"]) > 50:
		out.append("campaign_complete")
	return out
