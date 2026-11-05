class_name HashiLandscapeSteps
extends HBoxContainer
const Progress=preload("res://scripts/hashi_landscape_progress.gd")
const Art=preload("res://scripts/hashi_art.gd")
var marks: Array[PanelContainer] = []
func _ready() -> void:
	alignment=BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation",14)
	for i in 4:
		var mark:=PanelContainer.new();mark.custom_minimum_size=Vector2(44,44);mark.tooltip_text=Progress.PARTS[i]
		var image:=TextureRect.new();image.texture=Art.ICONS[Progress.ICONS[i]];image.custom_minimum_size=Vector2(23,23);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.modulate=Art.INK;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;mark.add_child(image)
		add_child(mark);marks.append(mark)
func set_progress(value: int) -> void:
	for i in marks.size():
		var done:=value>=(i+1)*3
		var current:=value>=i*3
		marks[i].add_theme_stylebox_override("panel",Art.surface(Color("d8e2c8") if done else Art.PAPER,Art.GOLD if current and not done else Art.BORDER,22))
		marks[i].tooltip_text=Progress.PARTS[i]+(" · restaurado" if done else " · %d/3"%clampi(value-i*3,0,3))
