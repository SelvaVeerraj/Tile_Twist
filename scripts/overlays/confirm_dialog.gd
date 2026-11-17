extends "res://scripts/overlays/overlay_base.gd"
## Yes / No confirmation, used before restarting or leaving an active game.

signal confirmed

var title_text := "Are you sure?"
var message := ""
var confirm_text := "Yes"
var cancel_text := "Cancel"
var confirm_color := "red"


func _build() -> void:
	card_width = 560.0
	card.custom_minimum_size = Vector2(card_width, 0)
	add_title(title_text, 42)
	if message != "":
		var m := UIKit.make_wrapped_label(message, 26, UIKit.c("ink_soft"))
		m.custom_minimum_size = Vector2(480, 0)
		content.add_child(m)
	content.add_child(UIKit.spacer(6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	content.add_child(row)
	var cancel := UIKit.make_button(cancel_text, "blue", 30, 84)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(close)
	row.add_child(cancel)
	var ok := UIKit.make_button(confirm_text, confirm_color, 30, 84)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_on_confirm)
	row.add_child(ok)


func _on_confirm() -> void:
	confirmed.emit()
	close()
