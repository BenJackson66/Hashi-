class_name HashiStoryView
extends MarginContainer
## Presentation of unlocked levels; Session independently enforces access.
signal selected(ordinal: int)
signal back_requested
const Catalog = preload("res://scripts/hashi_story_catalog.gd")
const Story = preload("res://scripts/hashi_story_state.gd")
var scroll: ScrollContainer
var content: VBoxContainer
var level_buttons: Array[Button] = []
var message: Label
var follow_button: Button
var back_button: Button
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 20)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
func refresh(state: Dictionary, completed_ids: Array) -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	level_buttons.clear()
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)
	_label("Historia · Ruta clásica", 26)
	_label("Etapas de cuatro niveles. Resuelve uno para desbloquear el siguiente.")
	_label("Se conservan los 12 iniciales y los 4 niveles más recientes de la ruta continua.")
	var current := int(state.frontier)
	follow_button = _button("Seguir · " + Catalog.title(current), func(): selected.emit(current))
	follow_button.name = "FollowStory"
	for ordinal in Catalog.COUNT:
		if ordinal % Catalog.STAGE_SIZE == 0:
			_label("Etapa %d" % (ordinal / Catalog.STAGE_SIZE + 1), 22)
		_level(ordinal, state, completed_ids)
	if current >= Catalog.COUNT:
		_label("Ruta continua", 22)
		var keys: Array = state.recipes.keys()
		keys.sort_custom(func(a, b): return int(a) < int(b))
		for key in keys:
			_level(int(key), state, completed_ids)
	back_button = _button("Volver a Inicio", func(): back_requested.emit())
func _level(ordinal: int, state: Dictionary, completed_ids: Array) -> void:
	var locked := ordinal > int(state.frontier)
	var text := Catalog.title(ordinal)
	if ordinal < int(state.frontier):
		text += " ✓"
	elif locked:
		text += " · Bloqueado"
	var button := _button(text, func(): selected.emit(ordinal))
	button.disabled = locked
	if locked:
		button.set_meta("locked", true)
	level_buttons.append(button)
func _label(text: String, font_size: int = 16) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	content.add_child(label)
func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	content.add_child(button)
	return button

func update_state(busy: bool, text: String) -> void:
	for button in level_buttons:
		button.disabled = busy or button.has_meta("locked")
	if follow_button != null:
		follow_button.disabled = busy
	if message != null:
		message.text = text
		message.visible = not text.is_empty()
