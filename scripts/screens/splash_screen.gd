extends "res://scripts/screens/screen_base.gd"
## Splash screen: animated logo and a short loading bar, then Home.

const Logo = preload("res://scripts/components/logo.gd")

var _bar: ProgressBar


func build() -> void:
	root_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_box.add_child(UIKit.spacer(0, true))
	var logo_holder := CenterContainer.new()
	var logo := Logo.new()
	logo.custom_minimum_size = Vector2(190, 190)
	logo_holder.add_child(logo)
	root_box.add_child(logo_holder)
	var title := UIKit.make_title_label("TILE TWIST", 96, UIKit.c("yellow"), Color("5b21b6"))
	root_box.add_child(title)
	var tag := UIKit.make_title_label("Swap the tiles · Rebuild the picture", 30)
	root_box.add_child(tag)
	root_box.add_child(UIKit.spacer(10))
	var bar_holder := CenterContainer.new()
	_bar = UIKit.make_progress_bar(UIKit.c("orange"), 22, Color(0.08, 0.2, 0.48, 0.45))
	_bar.custom_minimum_size = Vector2(460, 22)
	bar_holder.add_child(_bar)
	root_box.add_child(bar_holder)
	root_box.add_child(UIKit.spacer(0, true))

	UIKit.pop_in(logo_holder, 0.05)
	UIKit.pop_in(title, 0.2)
	UIKit.pop_in(tag, 0.35)
	var tw := create_tween()
	tw.tween_property(_bar, "value", 100.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.15)
	tw.tween_callback(func(): go("home"))


func handle_back() -> bool:
	return true
