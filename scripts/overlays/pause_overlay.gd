extends "res://scripts/overlays/overlay_base.gd"
## Pause menu. The game screen stops the timer before opening this.

signal resume_requested
signal restart_requested
signal home_requested

var _sound_btn: Button


func _build() -> void:
	card_width = 640.0
	card.custom_minimum_size = Vector2(card_width, 0)
	add_title("Paused", 56)
	content.add_child(UIKit.make_label("The clock is stopped. Take a breather!", 24, UIKit.c("ink_soft")))
	content.add_child(UIKit.spacer(4))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	content.add_child(grid)
	var resume := UIKit.make_button("Resume", "green", 32, 92)
	resume.pressed.connect(func(): resume_requested.emit())
	var restart := UIKit.make_button("Restart", "orange", 32, 92)
	restart.pressed.connect(func(): restart_requested.emit())
	_sound_btn = UIKit.make_button(_sound_text(), "blue", 32, 92)
	_sound_btn.pressed.connect(_toggle_sound)
	var home := UIKit.make_button("Home", "purple", 32, 92)
	home.pressed.connect(func(): home_requested.emit())
	for b in [resume, restart, _sound_btn, home]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)


func _sound_text() -> String:
	return "Sound: ON" if GameData.is_sound_on() else "Sound: OFF"


func _toggle_sound() -> void:
	GameData.toggle_sound()
	_sound_btn.text = _sound_text()


func handle_back() -> void:
	resume_requested.emit()
