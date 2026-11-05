class_name HashiRestorationView
extends MarginContainer
signal continue_requested
signal map_requested
signal revealed
signal sound_requested
const Art=preload("res://scripts/hashi_art.gd")
const Landscape=preload("res://scripts/hashi_landscape.gd")
const Progress=preload("res://scripts/hashi_landscape_progress.gd")
const Steps=preload("res://scripts/hashi_landscape_steps.gd")
var landscape: Landscape
var steps: Steps
var caption: Label
var level: Label
var next_button: Button
var back_button: Button
var sound_button: Button
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:add_theme_constant_override("margin_"+side,16)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);add_child(column)
	var header:=HBoxContainer.new();column.add_child(header)
	back_button=Button.new();header.add_child(back_button);Art.symbol(back_button,"back","Ver el paisaje");back_button.pressed.connect(func():map_requested.emit())
	level=Label.new();level.text="El faro";Art.heading(level,28);level.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;level.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(level)
	sound_button=Button.new();header.add_child(sound_button);Art.symbol(sound_button,"sound","Silenciar");sound_button.pressed.connect(func():sound_requested.emit())
	landscape=Landscape.new();landscape.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(landscape);landscape.revealed.connect(func():revealed.emit())
	caption=Label.new();caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.add_theme_font_size_override("font_size",21);column.add_child(caption)
	steps=Steps.new();column.add_child(steps)
	var footer:=CenterContainer.new();column.add_child(footer)
	next_button=Button.new();Art.symbol(next_button,"play","Seguir jugando");next_button.custom_minimum_size=Vector2(64,64);Art.primary(next_button);next_button.pressed.connect(func():continue_requested.emit());footer.add_child(next_button)
func present(before: int, after: int, motion: bool) -> void:
	show();caption.text=Progress.moment(after);steps.set_progress(after)
	landscape.set_motion_enabled(motion);landscape.set_progress(after,before,true)
func dismiss() -> void:
	landscape.stop_reveal();hide()

func set_sound_enabled(value: bool) -> void:
	Art.symbol(sound_button,"sound" if value else "mute","Silenciar" if value else "Activar sonidos")
