extends Control
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const Board = preload("res://scripts/hashi_board.gd")
const Session = preload("res://scripts/hashi_session.gd")
var puzzles: Array = []
var board: Board
var session: Session
var status: Label
var selector: OptionButton
var undo_button: Button
var redo_button: Button
var next_button: Button
var restart_button: Button
# Dependency injection for integration tests; production always uses user://.
var save_path := "user://hashi-save-v1.json"
var save_failed := false

func _ready() -> void:
	puzzles = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	session = Session.new(puzzles, save_path)
	session.restore()
	var recovery_message := session.store.last_error
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := Label.new()
	heading.text = "HASHI"
	heading.add_theme_font_size_override("font_size", 24)
	header.add_child(heading)
	selector = OptionButton.new()
	selector.custom_minimum_size.y = 48
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in puzzles.size():
		selector.add_item("%d · %s" % [i + 1, puzzles[i].title])
	header.add_child(selector)
	var hint := Label.new()
	hint.text = "Toca dos islas o desliza entre ellas.\nPuentes: 0 → 1 → 2 → 0. Une toda la red."
	hint.add_theme_font_size_override("font_size", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	board = Board.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(200, 200)
	column.add_child(board)
	status = Label.new()
	status.custom_minimum_size.y = 36
	status.add_theme_font_size_override("font_size", 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var warnings := CheckButton.new()
	warnings.text = "Advertencias de errores"
	warnings.custom_minimum_size.y = 44
	warnings.button_pressed = false
	warnings.toggled.connect(func(enabled: bool):
		board.warnings_enabled = enabled
		board.queue_redraw()
		_update_status("")
	)
	column.add_child(warnings)
	var history_row := HBoxContainer.new()
	column.add_child(history_row)
	undo_button = _button("Deshacer", history_row, board.undo)
	redo_button = _button("Rehacer", history_row, board.redo)
	var navigation := HBoxContainer.new()
	column.add_child(navigation)
	restart_button = _button("Reiniciar", navigation, board.reset)
	next_button = _button("Siguiente", navigation, _next_puzzle)
	board.puzzle_changed.connect(_on_puzzle_changed)
	board.state_changed.connect(_update_status)
	selector.item_selected.connect(_select_puzzle)
	_display_current()
	if not recovery_message.is_empty():
		status.text = recovery_message

func _button(text: String, parent: Control, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _display_current() -> void:
	board.set_puzzle(session.current_puzzle())
	selector.select(session.current_index)
	_update_status("")

func _select_puzzle(index: int) -> void:
	if index != session.current_index and session.select(index):
		_display_current()
		_save_game()

func _next_puzzle() -> void:
	if session.advance():
		_display_current()
		_save_game()

func _on_puzzle_changed() -> void:
	if session.capture(board.puzzle):
		_save_game()

func _save_game() -> void:
	save_failed = not session.save_game()
	_update_status("")

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		# Successful changes are already flushed. Retry only a pending failure;
		# opening/focusing a bad save must not silently replace it with an empty one.
		if session != null and board != null and save_failed:
			_save_game()

func _update_status(message: String) -> void:
	var solved := Rules.is_solved(board.puzzle)
	undo_button.disabled = board.history.past.is_empty()
	redo_button.disabled = board.history.future.is_empty()
	next_button.disabled = not solved
	next_button.text = "Volver al primero" if session.sequence.wraps_after(board.puzzle.puzzle_id) else "Siguiente"
	for i in puzzles.size():
		var completed := str(puzzles[i].id) in session.completed_ids
		selector.set_item_text(i, "%d · %s%s" % [i + 1, puzzles[i].title, " ✓" if completed else ""])
	if solved:
		status.text = "Tablero resuelto. Fin de la secuencia provisional." if session.sequence.wraps_after(board.puzzle.puzzle_id) else "¡Tablero resuelto! Puedes pasar al siguiente."
	elif not message.is_empty():
		status.text = message
	elif board.warnings_enabled:
		status.text = "Sin excesos. Comprueba los números y la conexión."
		for item in board.puzzle.islands:
			if board.puzzle.degree(str(item.id)) > int(item.target):
				status.text = "Hay islas con más puentes de los indicados."
				break
	else:
		status.text = "Completa cada número y conecta todas las islas."
	if save_failed:
		status.text += " No se pudo guardar la partida."
