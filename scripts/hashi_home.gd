extends MarginContainer
## Presentation only: navigation and save/generation policies belong to main.
signal continue_requested
signal new_requested
signal lesson_requested(index: int)
signal confirm_requested
signal cancel_requested
signal page_changed
var scroll: ScrollContainer
var page := "home"
var pages: Dictionary = {}
var continue_button: Button
var new_button: Button
var learn_button: Button
var rules_button: Button
var rules_back_button: Button
var learn_back_button: Button
var lesson_buttons: Array[Button] = []
var confirm_button: Button
var cancel_button: Button
var notice: Label

func build(catalog: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		add_theme_constant_override("margin_" + side, 20)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)
	var title := _label("HASHI", content, 32)
	title.add_theme_color_override("font_color", Color("86cddd"))
	_label("Une las islas. Conecta toda la red.", content, 18)
	for name in ["home", "learn", "rules", "confirm"]:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		content.add_child(column)
		pages[name] = column
	continue_button = _button("Continuar partida", pages.home, func(): continue_requested.emit())
	new_button = _button("Nuevo tablero", pages.home, func(): new_requested.emit())
	learn_button = _button("Aprender a jugar", pages.home, func(): show_page("learn"))
	rules_button = _button("Cómo jugar", pages.home, func(): show_page("rules"))
	_label("Aprender a jugar", pages.learn, 24)
	_label("Elige un tablero. Cada uno conserva sus puentes.", pages.learn)
	for i in catalog.size():
		var index := i
		lesson_buttons.append(_button("%d · %s" % [i + 1, catalog[i].title], pages.learn,
			func(): lesson_requested.emit(index)))
	learn_back_button = _button("Volver a Inicio", pages.learn, func(): show_page("home"))
	_label("Cómo jugar", pages.rules, 24)
	_label("1. Une islas con puentes horizontales o verticales. Solo puedes unir las vecinas de una misma fila o columna.", pages.rules)
	_label("2. Cada número, del 1 al 8, indica cuántos puentes llegan a esa isla. Un puente doble cuenta como dos. Por ejemplo, una isla 3 puede recibir uno por un lado y dos por otro.", pages.rules)
	_label("3. Entre dos islas puede haber cero, uno o dos puentes. Nunca pueden cruzarse ni atravesar otra isla.", pages.rules)
	_label("4. Todas las islas deben quedar conectadas en una sola red. Completar los números en grupos separados no resuelve el tablero.", pages.rules)
	_label("Toca dos islas o desliza de una a otra para alternar 0 → 1 → 2 → 0. Puedes Deshacer y Rehacer. Las advertencias son opcionales.", pages.rules)
	rules_back_button = _button("Volver a Inicio", pages.rules, func(): show_page("home"))
	_label("¿Sustituir el tablero procedural?", pages.confirm, 24)
	_label("El procedural anterior tiene puentes y aún no está resuelto. Si el nuevo se genera y se guarda correctamente, sustituirá ese progreso. Los tres tableros de aprendizaje se conservan.", pages.confirm)
	cancel_button = _button("Conservar partida", pages.confirm, func(): cancel_requested.emit())
	confirm_button = _button("Sustituir y generar", pages.confirm, func(): confirm_requested.emit())
	notice = _label("", content)
	show_page("home")

func show_page(value: String) -> void:
	if not pages.has(value):
		return
	page = value
	scroll.set_deferred("scroll_vertical", 0)
	for name in pages:
		pages[name].visible = name == page
	page_changed.emit()

func update_state(can_continue: bool, busy: bool, message: String) -> void:
	continue_button.disabled = not can_continue
	new_button.disabled = busy
	notice.text = message
	if message.is_empty() and not can_continue:
		notice.text = "Aún no tienes una partida. Crea un tablero o elige uno para aprender."

func _label(text: String, parent: Control, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(text: String, parent: Control, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 56
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
