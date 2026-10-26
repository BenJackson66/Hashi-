extends Control
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const Board = preload("res://scripts/hashi_board.gd")
const Session = preload("res://scripts/hashi_session.gd")
const Home = preload("res://scripts/hashi_home.gd")
const GenerationTask = preload("res://scripts/hashi_generation_task.gd")
var home: Home
var game_view: MarginContainer
var home_button: Button
var screen := "home"
var _has_game := false
var _confirmation_pending := false
var _confirmation_origin := "home"
var puzzles: Array = []
var board: Board
var session: Session
var status: Label
var selector: OptionButton
var undo_button: Button
var redo_button: Button
var next_button: Button
var restart_button: Button
var new_board_button: Button
var generation_options := {"width": 5, "height": 5, "island_count": 10,
	"max_attempts": 100, "max_time_ms": 1500, "solver_max_nodes": 100000}
var generation_task: GenerationTask
var _generation_epoch := 0
var _request_epoch := -1
var _generation_message := ""
var _seed_rng := RandomNumberGenerator.new()
var _last_requested_seed := -1
# Dependency injection for integration tests; production always uses user://.
var save_path := "user://hashi-save-v1.json"
var save_failed := false

func _ready() -> void:
	set_process(false)
	_seed_rng.randomize()
	puzzles = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	session = Session.new(puzzles, save_path)
	_has_game = session.restore()
	if not session.procedural.is_empty():
		_last_requested_seed = str(session.procedural.values()[0].seed).to_int()
	var recovery_message := session.store.last_error
	var margin := MarginContainer.new()
	game_view = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	home_button = _button("Inicio", header, _show_home)
	home_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
	new_board_button = _button("Nuevo tablero", history_row, _ask_new_puzzle)
	var navigation := HBoxContainer.new()
	column.add_child(navigation)
	restart_button = _button("Reiniciar", navigation, board.reset)
	next_button = _button("Siguiente", navigation, _next_puzzle)
	board.puzzle_changed.connect(_on_puzzle_changed)
	board.state_changed.connect(_update_status)
	selector.item_selected.connect(_select_puzzle)
	home = Home.new()
	add_child(home)
	home.build(puzzles)
	home.continue_requested.connect(_continue_game)
	home.new_requested.connect(_ask_new_puzzle)
	home.lesson_requested.connect(_select_puzzle)
	home.confirm_requested.connect(_confirm_new_puzzle)
	home.cancel_requested.connect(_cancel_new_puzzle)
	home.page_changed.connect(_on_home_page_changed)
	_display_current()
	_show_home()
	if not recovery_message.is_empty():
		_generation_message = recovery_message
		_update_status("")

func _button(text: String, parent: Control, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _display_current() -> void:
	_invalidate_generation()
	board.set_puzzle(session.current_puzzle())
	_sync_selector()
	selector.select(session.current_index)
	_update_status("")

func _select_puzzle(index: int) -> void:
	if index < 0 or index >= session.catalog.size():
		return
	if index != session.current_index or not _has_game:
		if not session.select_and_save(index):
			_generation_message = "No se pudo guardar la selección. Se conserva tu partida. Inténtalo de nuevo."
			_update_status("")
			return
		_has_game = true
		save_failed = false
		_display_current()
	_open_game()

func _next_puzzle() -> void:
	if not Rules.is_solved(board.puzzle):
		return
	var index := 0 if session.is_procedural() else session.sequence.ids.find(session.sequence.next_id(board.puzzle.puzzle_id))
	_select_puzzle(index)

func _show_home() -> void:
	_confirmation_pending = false
	_invalidate_generation()
	screen = "home"
	game_view.hide()
	home.show()
	home.show_page("home")
	_clear_gesture()
	_update_status("")

func _on_home_page_changed() -> void:
	_invalidate_generation()
	_update_status("")

func _clear_gesture() -> void:
	board.selected = ""
	board.pressed = ""
	board.active_touch = -1
	board.queue_redraw()

func _open_game() -> void:
	_confirmation_pending = false
	_invalidate_generation()
	screen = "game"
	home.hide()
	game_view.show()
	_clear_gesture()
	_update_status("")

func _continue_game() -> void:
	if _has_game:
		_open_game()

func _ask_new_puzzle() -> void:
	if generation_task != null or _confirmation_pending or is_queued_for_deletion():
		return
	for id in session.procedural:
		var previous := Puzzle.new(session.procedural[id].puzzle)
		previous.bridges = session.boards.get(id, {}).duplicate(true)
		if not previous.bridges.is_empty() and not Rules.is_solved(previous):
			_confirmation_origin = screen
			_confirmation_pending = true
			screen = "confirm"
			_clear_gesture()
			game_view.hide()
			home.show()
			home.show_page("confirm")
			return
	_request_new_puzzle()

func _cancel_new_puzzle() -> void:
	if not _confirmation_pending:
		return
	_confirmation_pending = false
	if _confirmation_origin == "game":
		_open_game()
	else:
		_show_home()

func _confirm_new_puzzle() -> void:
	if not _confirmation_pending:
		return
	_cancel_new_puzzle()
	_request_new_puzzle()

func _on_puzzle_changed() -> void:
	_invalidate_generation()
	if session.capture(board.puzzle):
		_save_game()

func _save_game() -> void:
	save_failed = not session.save_game()
	_has_game = true
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
	next_button.text = "Volver al primero" if session.is_procedural() else ("Volver al primero" if session.sequence.wraps_after(board.puzzle.puzzle_id) else "Siguiente")
	new_board_button.disabled = generation_task != null
	_sync_selector()
	if solved:
		if session.is_procedural():
			status.text = "¡Tablero resuelto! Puedes crear otro."
		else:
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
	if generation_task != null:
		status.text = "Generando tablero… Puedes seguir jugando." if _generation_epoch == _request_epoch else "Finalizando solicitud anterior…"
	elif not _generation_message.is_empty():
		status.text = _generation_message
	if save_failed:
		status.text += " No se pudo guardar la partida."
	if home != null:
		home.update_state(_has_game, generation_task != null, status.text if generation_task != null or not _generation_message.is_empty() or save_failed else "")

func _sync_selector() -> void:
	if selector.item_count != session.catalog.size():
		selector.clear()
		for definition in session.catalog:
			selector.add_item(str(definition.title))
	for i in session.catalog.size():
		var definition: Dictionary = session.catalog[i]
		var title := "%d · %s" % [i + 1, definition.title] if i < session.base_catalog.size() else "Procedural"
		selector.set_item_text(i, title + (" ✓" if str(definition.id) in session.completed_ids else ""))
	selector.select(session.current_index)

func _invalidate_generation() -> void:
	_generation_epoch += 1
	_generation_message = ""

func _request_new_puzzle() -> bool:
	if generation_task != null or is_queued_for_deletion():
		return false
	var seed_value := _seed_rng.randi_range(0, 2147483645)
	var previous_seeds := [_last_requested_seed]
	if not session.procedural.is_empty():
		previous_seeds.append(str(session.procedural.values()[0].seed).to_int())
	while seed_value in previous_seeds:
		seed_value = (seed_value + 1) % 2147483646
	_last_requested_seed = seed_value
	_generation_epoch += 1
	_request_epoch = _generation_epoch
	_generation_message = ""
	generation_task = GenerationTask.new()
	if not generation_task.start(seed_value, generation_options):
		generation_task = null
		_generation_message = "No se pudo iniciar la generación. Inténtalo de nuevo."
		_update_status("")
		return false
	set_process(true)
	_update_status("")
	return true

func _process(_delta: float) -> void:
	if is_queued_for_deletion():
		_invalidate_generation()
		return
	if generation_task == null:
		set_process(false)
		return
	var result := generation_task.poll()
	if result.is_empty():
		return
	generation_task = null
	set_process(false)
	if _generation_epoch != _request_epoch:
		_update_status("")
		return
	if result.status != "success":
		_generation_message = "No se pudo generar un tablero. Inténtalo de nuevo."
		_update_status("")
	elif session.install_procedural_and_save(result.recipe):
		save_failed = false
		_has_game = true
		_display_current()
		_open_game()
	else:
		# No new playable state was published; do not retry the rejected board on pause.
		_generation_message = "No se pudo guardar el nuevo tablero. Se conserva tu partida. Inténtalo de nuevo."
		_update_status("")

func _exit_tree() -> void:
	_invalidate_generation()
	if generation_task != null:
		generation_task.finish_on_shutdown()
		generation_task = null
