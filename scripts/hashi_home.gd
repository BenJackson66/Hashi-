extends MarginContainer
## Presentation only: navigation and save/generation policies belong to main.
signal story_requested
signal continue_requested
signal new_requested
signal lesson_requested(index: int)
signal confirm_requested
signal cancel_requested
signal profile_requested(profile: String)
signal mode_requested(mode: String, profile: String)
signal page_changed
signal motion_requested(enabled: bool)
const Art = preload("res://scripts/hashi_art.gd")
var motion_button: CheckButton
var story_button: Button
var iron_button: Button
var fixed_button: Button
var progression_button: Button
var challenge: OptionButton
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
var _primary_ready := false
var _primary_continue := false

func build(catalog: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		add_theme_constant_override("margin_" + side, 20)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 18)
	hero.custom_minimum_size.y = 100
	content.add_child(hero)
	var mark := TextureRect.new()
	mark.texture = Art.MARK
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(72, 72)
	hero.add_child(mark)
	var wordmark := VBoxContainer.new()
	wordmark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wordmark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(wordmark)
	var title := _label("HASHI", wordmark, 42)
	Art.heading(title, 42)
	var subtitle := _label("ISLAS Y PUENTES", wordmark, 11)
	subtitle.add_theme_color_override("font_color", Art.GOLD)
	_label("Una isla. Un puente. Todo conectado.", content, 15)
	for name in ["home", "learn", "rules", "confirm"]:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		content.add_child(column)
		pages[name] = column
	continue_button = _button("Continuar partida", pages.home, func(): continue_requested.emit())
	Art.primary(continue_button)
	story_button = _button("Historia", pages.home, func(): story_requested.emit())
	story_button.custom_minimum_size.y = 64
	_label("Partida libre", pages.home, 22)
	challenge = OptionButton.new()
	challenge.custom_minimum_size.y = 56
	challenge.add_theme_font_size_override("font_size", 18)
	challenge.add_item("Directo · deducción local")
	challenge.add_item("Reflexivo · por contradicción")
	challenge.item_selected.connect(func(index: int): profile_requested.emit("local" if index == 0 else "contradiction1"))
	pages.home.add_child(challenge)
	_label("Directo para deducir paso a paso. Reflexivo para explorar posibilidades.", pages.home, 14)
	new_button = _button("Nuevo tablero", pages.home, func(): new_requested.emit())
	fixed_button = _button("Dificultad fija", pages.home, func(): mode_requested.emit("fixed", "local" if challenge.selected == 0 else "contradiction1"))
	progression_button = _button("Progresión", pages.home, func(): mode_requested.emit("progression", "local"))
	_label("Fija mantiene tu perfil. Progresión aumenta el desafío. Cada nueva serie empieza desde cero.", pages.home, 14)
	iron_button = _button("Alma de Hierro", pages.home, func(): mode_requested.emit("iron", "local" if challenge.selected == 0 else "contradiction1"))
	iron_button.add_theme_stylebox_override("normal", Art.surface(Color("273a3e"), Art.GOLD))
	_label("Sin margen de error. La primera falta termina el desafío; tu récord permanece.", pages.home, 14)
	learn_button = _button("Aprender a jugar", pages.home, func(): show_page("learn"))
	rules_button = _button("Cómo jugar", pages.home, func(): show_page("rules"))
	motion_button = CheckButton.new()
	motion_button.text = "Animaciones suaves"
	motion_button.custom_minimum_size.y = 48
	motion_button.toggled.connect(func(enabled: bool): motion_requested.emit(enabled))
	pages.home.add_child(motion_button)
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
	_label("Historia · Azules (S): solo puentes simples, y el número cuenta todos los puentes. Misteriosas (?): no tienen número; deduce sus conexiones con las otras islas y une toda la red.", pages.rules)
	_label("Rachas: cada tablero perfecto cuenta una sola vez. Azul: 1, morado: 3, dorado: 7. Deshacer, retirar/reducir puentes o dejar un tablero sin extensión posible rompe la racha. En modos normales conservas tu progreso; en Alma de Hierro la primera falta termina el desafío y conserva el récord.", pages.rules)
	rules_back_button = _button("Volver a Inicio", pages.rules, func(): show_page("home"))
	_label("¿Sustituir tu tablero?", pages.confirm, 24)
	_label("Tu tablero actual tiene puentes y aún no está resuelto. El nuevo lo sustituirá cuando esté listo. Tus niveles de Historia y aprendizaje se conservan.", pages.confirm)
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

func update_state(can_continue: bool, busy: bool, message: String, selection_blocked: bool = false) -> void:
	if not _primary_ready or _primary_continue != can_continue:
		for button in [continue_button, story_button]:
			for style in ["normal", "hover", "pressed"]:
				button.remove_theme_stylebox_override(style)
			for color in ["font_color", "font_hover_color", "font_pressed_color"]:
				button.remove_theme_color_override(color)
		Art.primary(continue_button if can_continue else story_button)
		_primary_ready = true
		_primary_continue = can_continue
	continue_button.disabled = not can_continue
	new_button.disabled = busy
	challenge.disabled = busy
	fixed_button.disabled = busy
	progression_button.disabled = busy
	iron_button.disabled = busy
	for lesson in lesson_buttons:
		lesson.disabled = selection_blocked
	notice.text = message
	if message.is_empty() and not can_continue and page == "home":
		notice.text = "Aún no tienes una partida. Crea un tablero o elige uno para aprender."
	notice.visible = not notice.text.is_empty()

func _label(text: String, parent: Control, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	if font_size >= 22:
		Art.heading(label, font_size)
	else:
		label.add_theme_color_override("font_color", Art.MUTED)
	parent.add_child(label)
	return label

func _button(text: String, parent: Control, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 56
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

