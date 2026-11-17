extends "res://scripts/overlays/overlay_base.gd"
## Success screen: banner, animated stars, score count-up, stats, buttons.

signal next_requested
signal again_requested
signal home_requested

const Icon = preload("res://scripts/components/icon.gd")

var result: Dictionary = {}
var info: Dictionary = {}
var breakdown: Dictionary = {}
var next_text := "Next Level"

var _stars: Array = []
var _score_label: Label


func _build() -> void:
	card_width = 940.0
	card.custom_minimum_size = Vector2(card_width, 0)
	content.add_theme_constant_override("separation", 12)
	var stars := int(result.get("stars", 1))

	var banner_text := "PERFECT!" if stars >= 3 else ("GREAT!" if stars == 2 else "WELL DONE!")
	var banner := UIKit.make_title_label(banner_text, 64, UIKit.c("yellow"), Color("c2410c"))
	content.add_child(banner)
	content.add_child(UIKit.make_label("Puzzle Completed!", 28, UIKit.c("green").darkened(0.2), true))

	# Three big stars, filled one by one.
	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 14)
	content.add_child(star_row)
	for i in 3:
		var s := Icon.new()
		s.kind = "star"
		s.color = Color(0, 0, 0, 0.12)
		var big := 104 if i == 1 else 86
		s.custom_minimum_size = Vector2(big, big)
		s.size_flags_vertical = Control.SIZE_SHRINK_END if i != 1 else Control.SIZE_SHRINK_BEGIN
		star_row.add_child(s)
		_stars.append(s)

	# Stats: time, moves, score.
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 14)
	content.add_child(stats)
	stats.add_child(_stat_box("TIME", UIKit.format_time_precise(float(result["time_used"])), "blue",
			"Best time!" if bool(info.get("new_best_time", false)) else ""))
	stats.add_child(_stat_box("MOVES", "%d" % int(result["moves"]), "purple", "Best possible: %d" % int(result["min_moves"])))
	var score_box := _stat_box("SCORE", "0", "orange",
			"NEW HIGH SCORE!" if bool(info.get("new_high_score", false)) else "Best: %s" % UIKit.format_number(GameData.highest_score()))
	_score_label = score_box.get_meta("value")
	stats.add_child(score_box)

	# Compact score breakdown.
	var parts: Array = []
	parts.append("Base %d" % int(breakdown.get("base", 0)))
	parts.append("Time +%d" % int(breakdown.get("time_bonus", 0)))
	parts.append("Moves +%d" % int(breakdown.get("move_bonus", 0)))
	if int(breakdown.get("combo_bonus", 0)) > 0:
		parts.append("Combo +%d" % int(breakdown["combo_bonus"]))
	if int(breakdown.get("daily_bonus", 0)) > 0:
		parts.append("Daily +%d" % int(breakdown["daily_bonus"]))
	if int(breakdown.get("hint_penalty", 0)) > 0:
		parts.append("Hints -%d" % int(breakdown["hint_penalty"]))
	content.add_child(UIKit.make_label("  ·  ".join(PackedStringArray(parts)), 21, UIKit.c("ink_soft")))
	if bool(info.get("campaign_complete", false)):
		content.add_child(UIKit.make_title_label("CAMPAIGN COMPLETE!", 40, UIKit.c("yellow"), Color("5b21b6")))
		content.add_child(UIKit.make_label("You finished all 50 levels!", 24, UIKit.c("green").darkened(0.15), true))
	elif int(info.get("unlocked_level", 0)) > 0:
		content.add_child(UIKit.make_label("Level %d unlocked!" % int(info["unlocked_level"]), 24, UIKit.c("green").darkened(0.15), true))

	# Buttons.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)
	var home := UIKit.make_button("Home", "purple", 30, 88)
	home.pressed.connect(func(): home_requested.emit())
	var again := UIKit.make_button("Play Again", "blue", 30, 88)
	again.pressed.connect(func(): again_requested.emit())
	var nxt := UIKit.make_button(next_text, "green", 32, 88)
	nxt.pressed.connect(func(): next_requested.emit())
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nxt.size_flags_stretch_ratio = 1.4
	row.add_child(home)
	row.add_child(again)
	row.add_child(nxt)

	_animate_results(stars, int(result["score"]))


func _stat_box(caption: String, value: String, color_name: String, note: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIKit.stylebox(UIKit.c("paper_soft"), 22)
	sb.set_content_margin_all(12)
	sb.set_border_width_all(3)
	sb.border_color = UIKit.c(color_name).lightened(0.3)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	p.add_child(box)
	box.add_child(UIKit.make_label(caption, 19, UIKit.c(color_name).darkened(0.1), true))
	var v := UIKit.make_label(value, 40, UIKit.c("ink"), true)
	v.add_theme_font_override("font", UIKit.font_black)
	box.add_child(v)
	var n := UIKit.make_label(note, 18, UIKit.c("ink_soft"))
	box.add_child(n)
	p.set_meta("value", v)
	return p


func _animate_results(stars: int, score: int) -> void:
	await get_tree().create_timer(0.35).timeout
	for i in stars:
		if not is_inside_tree():
			return
		var s = _stars[i]
		s.pivot_offset = s.size * 0.5
		s.color = UIKit.c("yellow")
		s.scale = Vector2(1.6, 1.6)
		var tw: Tween = s.create_tween()
		tw.tween_property(s, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		SoundManager.play("star", 1.0 + i * 0.15)
		await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	var count := create_tween()
	count.tween_method(_set_score_text, 0.0, float(score), 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _set_score_text(v: float) -> void:
	_score_label.text = UIKit.format_number(int(v))


func handle_back() -> void:
	home_requested.emit()
