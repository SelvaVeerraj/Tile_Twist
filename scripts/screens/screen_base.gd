extends Control
## Base class for full-screen pages. Provides a safe-area-aware margin,
## a vertical `root_box` to fill, navigation helpers and back handling.
## `main` and `params` are set by Main before the screen enters the tree.

var main = null                  # Main (screen manager)
var params: Dictionary = {}
var margin: MarginContainer
var root_box: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe: Dictionary = UIKit.safe_margins(get_viewport())
	margin.add_theme_constant_override("margin_left", int(28 + float(safe["left"])))
	margin.add_theme_constant_override("margin_right", int(28 + float(safe["right"])))
	margin.add_theme_constant_override("margin_top", int(20 + float(safe["top"])))
	margin.add_theme_constant_override("margin_bottom", int(20 + float(safe["bottom"])))
	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 16)
	margin.add_child(root_box)
	build()


## Override: build the screen's widgets.
func build() -> void:
	pass


## Override: return true if the back button was handled.
func handle_back() -> bool:
	go("home")
	return true


func go(screen_name: String, p: Dictionary = {}) -> void:
	if main:
		main.change_screen(screen_name, p)


## Standard header: back button, big centred title, balancing spacer.
func make_header(title: String, back_to: String = "home") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var back := UIKit.make_icon_button("back", "tile_btn", 76)
	back.pressed.connect(func(): go(back_to))
	row.add_child(back)
	var l := UIKit.make_title_label(title, 50)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UIKit.spacer(0))
	var bal := Control.new()
	bal.custom_minimum_size = Vector2(76, 76)
	bal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bal)
	return row


## Adds a confirmation dialog on top of this screen.
func confirm(title: String, message: String, confirm_text: String, on_confirm: Callable, color: String = "red") -> void:
	var d = load("res://scripts/overlays/confirm_dialog.gd").new()
	d.title_text = title
	d.message = message
	d.confirm_text = confirm_text
	d.confirm_color = color
	add_child(d)
	d.confirmed.connect(on_confirm)
