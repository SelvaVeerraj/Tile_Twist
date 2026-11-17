extends Control
## Main – root node and screen manager.
## Owns the animated background, swaps screens with a fade transition,
## shows achievement toasts and routes the Android back button.

const AnimatedBackground = preload("res://scripts/components/animated_background.gd")
const Icon = preload("res://scripts/components/icon.gd")

const SCREENS := {
	"splash": "res://scripts/screens/splash_screen.gd",
	"home": "res://scripts/screens/home_screen.gd",
	"difficulty": "res://scripts/screens/difficulty_screen.gd",
	"instructions": "res://scripts/screens/instructions_screen.gd",
	"settings": "res://scripts/screens/settings_screen.gd",
	"records": "res://scripts/screens/records_screen.gd",
	"game": "res://scripts/screens/game_screen.gd",
}

var background: Control
var screen_layer: Control
var toast_layer: Control
var blocker: Control
var current_screen: Control = null
var current_name := ""
var _toast_queue: Array = []
var _toast_busy := false


func _ready() -> void:
	theme = UIKit.build_theme()
	background = AnimatedBackground.new()
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_layer = _make_layer()
	toast_layer = _make_layer()
	blocker = _make_layer()
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	GameData.achievement_unlocked.connect(_on_achievement_unlocked)
	change_screen("splash")


func _make_layer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Replaces the current screen with a fade transition.
func change_screen(screen_name: String, params: Dictionary = {}) -> void:
	if not SCREENS.has(screen_name):
		push_error("Unknown screen: %s" % screen_name)
		return
	# Drop any screen still fading out from an earlier transition.
	for child in screen_layer.get_children():
		if child != current_screen:
			child.queue_free()
	var old := current_screen
	var scr: Control = load(SCREENS[screen_name]).new()
	scr.set("main", self)
	scr.set("params", params)
	screen_layer.add_child(scr)
	scr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current_screen = scr
	current_name = screen_name

	scr.modulate.a = 0.0
	blocker.visible = true
	var tw := create_tween()
	if old:
		tw.tween_property(old, "modulate:a", 0.0, 0.16)
		tw.tween_callback(old.queue_free)
	tw.tween_property(scr, "modulate:a", 1.0, 0.22)
	tw.tween_callback(func(): blocker.visible = false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back()


func _unhandled_input(event: InputEvent) -> void:
	# Escape on desktop behaves like the Android back button.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_handle_back()


func _handle_back() -> void:
	if current_screen == null or blocker.visible:
		return
	var handled: bool = current_screen.handle_back()
	if not handled:
		get_tree().quit()


# -------------------------------------------------------------------- toasts

func _on_achievement_unlocked(a: Dictionary) -> void:
	show_toast("Achievement unlocked!", "%s – %s" % [a.get("title", ""), a.get("desc", "")])


func show_toast(title: String, subtitle: String = "") -> void:
	_toast_queue.append([title, subtitle])
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	var item: Array = _toast_queue.pop_front()
	var panel := PanelContainer.new()
	var sb := UIKit.stylebox(UIKit.c("paper"), 26, 12)
	sb.set_content_margin_all(16)
	sb.set_border_width_all(4)
	sb.border_color = UIKit.c("yellow")
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var icon := Icon.new()
	icon.kind = "trophy"
	icon.color = UIKit.c("orange")
	icon.custom_minimum_size = Vector2(56, 56)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	col.add_child(UIKit.make_label(str(item[0]), 26, UIKit.c("ink"), true, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(UIKit.make_label(str(item[1]), 20, UIKit.c("ink_soft"), false, HORIZONTAL_ALIGNMENT_LEFT))
	toast_layer.add_child(panel)
	panel.reset_size()
	var w := maxf(panel.get_combined_minimum_size().x, 520.0)
	panel.size = Vector2(w, panel.get_combined_minimum_size().y)
	panel.position = Vector2((size.x - w) * 0.5, -panel.size.y - 20.0)
	SoundManager.play("unlock")
	var tw := create_tween()
	tw.tween_property(panel, "position:y", 18.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.3)
	tw.tween_property(panel, "position:y", -panel.size.y - 20.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(panel.queue_free)
	tw.tween_callback(_next_toast)
