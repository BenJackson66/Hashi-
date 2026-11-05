class_name HashiArt
extends RefCounted
## Shared presentation palette and resources; no puzzle or progression policy.
const BODY = preload("res://assets/fonts/Body.ttf")
const DISPLAY = preload("res://assets/fonts/Display.ttf")
const NUMBERS = preload("res://assets/fonts/Numbers.ttf")
const MARK = preload("res://assets/art/mark.svg")
const INK := Color("304e43")
const PAPER := Color("f7f2e7")
const MUTED := Color("61766a")
const GOLD := Color("9a6d36")
const BACKGROUND := Color("f1eddf")
const BORDER := Color("cfd8c7")
const PRIMARY := Color("4e705c")
const ICONS := {
	"boat": preload("res://assets/icons/boat.svg"),
	"bridge": preload("res://assets/icons/bridge.svg"),
	"house": preload("res://assets/icons/house.svg"),
	"lighthouse": preload("res://assets/icons/lighthouse.svg"),
	"sound": preload("res://assets/icons/sound.svg"),
	"mute": preload("res://assets/icons/mute.svg"),

	"back": preload("res://assets/icons/back.svg"),
	"play": preload("res://assets/icons/play.svg"),
	"menu": preload("res://assets/icons/menu.svg"),
	"undo": preload("res://assets/icons/undo.svg"),
	"redo": preload("res://assets/icons/redo.svg"),
	"restart": preload("res://assets/icons/restart.svg"),
	"new": preload("res://assets/icons/new.svg"),
	"book": preload("res://assets/icons/book.svg"),
	"modes": preload("res://assets/icons/modes.svg"),
	"flame": preload("res://assets/icons/flame.svg"),
	"crown": preload("res://assets/icons/crown.svg"),
	"heart": preload("res://assets/icons/heart.svg"),
	"check": preload("res://assets/icons/check.svg"),
	"lock": preload("res://assets/icons/lock.svg"),
	"clock": preload("res://assets/icons/clock.svg"),
	"close": preload("res://assets/icons/close.svg"),
}
static func surface(fill: Color, border: Color, radius: int = 22) -> StyleBoxFlat:
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
	value.set_color("font_color", "Label", INK)
	value.set_color("font_color", "Button", INK)
	value.set_color("icon_normal_color", "Button", INK)
	value.set_color("icon_hover_color", "Button", INK)
	value.set_color("icon_pressed_color", "Button", INK)
	value.set_color("icon_disabled_color", "Button", Color("aab5a3"))
	value.set_color("font_hover_color", "Button", INK)
	value.set_color("font_pressed_color", "Button", INK)
	value.set_color("font_disabled_color", "Button", Color("89998c"))
	for type in ["Button", "OptionButton"]:
		value.set_stylebox("normal", type, surface(Color("e1e8d8"), BORDER))
		value.set_stylebox("hover", type, surface(Color("d7e2cb"), Color("a6b99f")))
		value.set_stylebox("pressed", type, surface(Color("cbdac1"), GOLD))
		value.set_stylebox("disabled", type, surface(Color("ececde"), Color("d8dece")))
		var focus := surface(Color(0,0,0,0), GOLD)
		focus.set_border_width_all(2)
		value.set_stylebox("focus", type, focus)
	value.set_color("font_color", "OptionButton", INK)
	value.set_color("font_disabled_color", "OptionButton", Color("89998c"))
	value.set_stylebox("panel", "PopupMenu", surface(PAPER, BORDER))
	value.set_stylebox("hover", "PopupMenu", surface(Color("d7e2cb"), Color("d7e2cb"), 6))
	value.set_color("font_color", "PopupMenu", INK)
	value.set_color("font_disabled_color", "PopupMenu", Color("89998c"))
	value.set_color("font_color", "CheckButton", MUTED)
	value.set_constant("separation", "VBoxContainer", 10)
	value.set_constant("separation", "HBoxContainer", 8)
	for name in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		var bar := surface(Color("e3e8d9") if name == "scroll" else Color("91aa91"), Color("e3e8d9"), 3)
		bar.content_margin_left = 3
		bar.content_margin_right = 3
		bar.content_margin_top = 0
		bar.content_margin_bottom = 0
		value.set_stylebox(name, "VScrollBar", bar)
	return value
static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", surface(PRIMARY, PRIMARY))
	button.add_theme_stylebox_override("hover", surface(Color("42614d"), Color("42614d")))
	button.add_theme_stylebox_override("pressed", surface(Color("3a5848"), PRIMARY))
	for name in ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		button.add_theme_color_override(name, PAPER)
static func heading(label: Label, font_size: int = 28) -> void:
	label.add_theme_font_override("font", DISPLAY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)

static func symbol(button: Button, name: String, label: String) -> void:
	button.text = ""
	button.icon = ICONS[name]
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 24)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(52,52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = label
	for property in button.get_property_list():
		if property.name == "accessibility_name":
			button.set("accessibility_name", label)
	for name_style in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(name_style).duplicate()
		box.set_corner_radius_all(26)
		box.content_margin_left = 10
		box.content_margin_right = 10
		button.add_theme_stylebox_override(name_style, box)
