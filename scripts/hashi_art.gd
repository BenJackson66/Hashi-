class_name HashiArt
extends RefCounted
## Shared presentation palette and resources; no puzzle or progression policy.
const BODY = preload("res://assets/fonts/Body.ttf")
const DISPLAY = preload("res://assets/fonts/Display.ttf")
const NUMBERS = preload("res://assets/fonts/Numbers.ttf")
const MARK = preload("res://assets/art/mark.svg")
const INK := Color("0e2027")
const PAPER := Color("efe9db")
const MUTED := Color("b7c7c4")
const GOLD := Color("d8b779")
static func surface(fill: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box
static func theme() -> Theme:
	var value := Theme.new()
	value.default_font = BODY
	value.default_font_size = 16
	value.set_color("font_color", "Label", PAPER)
	value.set_color("font_color", "Button", PAPER)
	value.set_color("font_hover_color", "Button", Color.WHITE)
	value.set_color("font_pressed_color", "Button", PAPER)
	value.set_color("font_disabled_color", "Button", Color("8b9e9c"))
	for type in ["Button", "OptionButton"]:
		value.set_stylebox("normal", type, surface(Color("1c363e"), Color("37545c")))
		value.set_stylebox("hover", type, surface(Color("274750"), Color("719490")))
		value.set_stylebox("pressed", type, surface(Color("102d33"), GOLD))
		value.set_stylebox("disabled", type, surface(Color("142a32"), Color("29424a")))
		var focus := surface(Color(0,0,0,0), GOLD)
		focus.set_border_width_all(2)
		value.set_stylebox("focus", type, focus)
	value.set_color("font_color", "OptionButton", PAPER)
	value.set_color("font_disabled_color", "OptionButton", Color("8b9e9c"))
	value.set_stylebox("panel", "PopupMenu", surface(Color("162f37"), Color("53716f")))
	value.set_stylebox("hover", "PopupMenu", surface(Color("2b4f52"), Color("2b4f52"), 6))
	value.set_color("font_color", "PopupMenu", PAPER)
	value.set_color("font_disabled_color", "PopupMenu", Color("8b9e9c"))
	value.set_color("font_color", "CheckButton", MUTED)
	value.set_constant("separation", "VBoxContainer", 10)
	value.set_constant("separation", "HBoxContainer", 8)
	for name in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		var bar := surface(Color("11272e") if name == "scroll" else Color("557773"), Color("11272e"), 3)
		bar.content_margin_left = 3
		bar.content_margin_right = 3
		bar.content_margin_top = 0
		bar.content_margin_bottom = 0
		value.set_stylebox(name, "VScrollBar", bar)
	return value
static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", surface(GOLD, GOLD))
	button.add_theme_stylebox_override("hover", surface(Color("ead0a1"), Color("ead0a1")))
	button.add_theme_stylebox_override("pressed", surface(Color("bfa06a"), GOLD))
	for name in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(name, INK)
static func heading(label: Label, font_size: int = 28) -> void:
	label.add_theme_font_override("font", DISPLAY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", PAPER)
