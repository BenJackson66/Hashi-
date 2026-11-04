extends Control
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rule_set.gd")
const Board = preload("res://scripts/hashi_board.gd")
const Session = preload("res://scripts/hashi_session.gd")
const Mode = preload("res://scripts/hashi_play_mode.gd")
const Story = preload("res://scripts/hashi_story_state.gd")
const StoryCatalog = preload("res://scripts/hashi_story_catalog.gd")
const StoryPolicy = preload("res://scripts/hashi_story_policy.gd")
const StoryView = preload("res://scripts/hashi_story_view.gd")
const Quality = preload("res://scripts/hashi_quality.gd")
const QualityWorker = preload("res://scripts/hashi_quality_worker.gd")
const Settings = preload("res://scripts/hashi_free_settings.gd")
const Home = preload("res://scripts/hashi_home.gd")
const GenerationTask = preload("res://scripts/hashi_generation_task.gd")
var story_view: StoryView
var _request_story := -1
var quality_worker: QualityWorker
var quality_status: Label
var quality_retry: Button
var _quality_actions: Array = []
var _quality_verdict: Dictionary = {}
var settings: Settings
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
var mode_status: Label
var gesture_hint: Label
var _pending_run: Dictionary = {}
var _request_run: Dictionary = {}
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
	get_tree().quit_on_go_back = false
	_seed_rng.randomize()
	puzzles = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	session = Session.new(puzzles, save_path)
	_has_game = session.restore()
	settings = Settings.new(save_path + ".preferences")
	settings.restore()
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
	selector.fit_to_longest_item = false
	selector.clip_text = true
	selector.custom_minimum_size.y = 48
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in puzzles.size():
		selector.add_item("%d · %s" % [i + 1, puzzles[i].title])
	header.add_child(selector)
	var hint := Label.new()
	gesture_hint = hint
	hint.text = "Toca dos islas o desliza entre ellas.\nPuentes: 0 → 1 → 2 → 0. Une toda la red."
	hint.add_theme_font_size_override("font_size", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	mode_status = Label.new()
	mode_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_status.add_theme_font_size_override("font_size", 14)
	column.add_child(mode_status)
	quality_status = Label.new()
	quality_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quality_status.add_theme_font_size_override("font_size", 14)
	column.add_child(quality_status)
	quality_retry = _button("Reintentar comprobación", column, _retry_quality)
	quality_retry.custom_minimum_size.y = 36
	quality_retry.hide()
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
	home.challenge.select(0 if settings.profile == "local" else 1)
	story_view = StoryView.new()
	add_child(story_view)
	story_view.hide()
	story_view.selected.connect(_select_story)
	story_view.back_requested.connect(_show_home)
	home.story_requested.connect(_show_story)
	home.profile_requested.connect(_choose_profile)
	home.continue_requested.connect(_continue_game)
	home.new_requested.connect(func(): _ask_mode("free", settings.profile))
	home.mode_requested.connect(_ask_mode)
	home.lesson_requested.connect(_select_puzzle)
	home.confirm_requested.connect(_confirm_new_puzzle)
	home.cancel_requested.connect(_cancel_new_puzzle)
	home.page_changed.connect(_on_home_page_changed)
	quality_worker = QualityWorker.new()
	quality_worker.host = self
	add_child(quality_worker)
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
	if not session.quality.pending.is_empty():
		return
	if save_failed:
		_save_game()
		if save_failed:
			return
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
	if not session.quality.pending.is_empty() or _iron_ended():
		return
	if not Rules.is_solved(board.puzzle):
		return
	if session.is_story():
		_select_story(_next_story_ordinal())
	elif session.is_procedural():
		_ask_new_puzzle()
	else:
		_select_puzzle(session.sequence.ids.find(session.sequence.next_id(board.puzzle.puzzle_id)))

func _choose_profile(profile: String) -> void:
	if generation_task != null:
		return
	if not settings.choose(profile):
		_generation_message = "La preferencia se aplica en esta sesión, pero no se pudo guardar."
	_update_status("")

func _show_home() -> void:
	_confirmation_pending = false
	_invalidate_generation()
	screen = "home"
	if story_view != null:
		story_view.hide()
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
	story_view.hide()
	home.hide()
	game_view.show()
	_clear_gesture()
	_update_status("")

func _continue_game() -> void:
	if _has_game:
		_open_game()

func _ask_mode(mode: String, profile: String) -> void:
	if mode not in Mode.MODES or profile not in Mode.PROFILES:
		return
	_ask_new_puzzle(Mode.fresh(mode, profile))

func _ask_new_puzzle(requested_run: Dictionary = {}) -> void:
	if not session.quality.pending.is_empty() or (_iron_ended() and requested_run.is_empty()):
		return
	if generation_task != null or _confirmation_pending or is_queued_for_deletion():
		return
	if save_failed:
		_save_game()
		if save_failed:
			return
	_pending_run = requested_run.duplicate(true) if not requested_run.is_empty() else session.run.duplicate(true)
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
	_pending_run = {}
	if _confirmation_origin == "game":
		_open_game()
	else:
		_show_home()

func _confirm_new_puzzle() -> void:
	if not _confirmation_pending:
		return
	var intended_run := _pending_run.duplicate(true)
	_cancel_new_puzzle()
	_pending_run = intended_run
	_request_new_puzzle()

func _on_puzzle_changed() -> void:
	_quality_actions.append(board.last_action.duplicate(true))
	_invalidate_generation()
	_save_game()

func _save_game() -> void:
	save_failed = not session.capture_and_save(board.puzzle, _quality_actions, _quality_verdict)
	if not save_failed:
		_quality_actions.clear()
		_quality_verdict.clear()
	_has_game = true
	_update_status("")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and home != null:
		if _confirmation_pending:
			_cancel_new_puzzle()
		elif screen in ["game", "story"]:
			_show_home()
		elif home.page != "home":
			home.show_page("home")
		else:
			if save_failed:
				_save_game()
			get_tree().quit()
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		# Successful changes are already flushed. Retry only a pending failure;
		# opening/focusing a bad save must not silently replace it with an empty one.
		if session != null and board != null and save_failed:
			_save_game()

func _update_status(message: String) -> void:
	var solved := Rules.is_solved(board.puzzle)
	if gesture_hint != null:
		var has_blue := false
		for item in board.puzzle.islands:
			has_blue = has_blue or item.get("variant") == "blue"
		gesture_hint.text = "Toca dos islas o desliza entre ellas.\nS: 0 → 1 → 0 · Otras: 0 → 1 → 2 → 0" if has_blue else "Toca dos islas o desliza entre ellas.\nPuentes: 0 → 1 → 2 → 0. Une toda la red."
	undo_button.disabled = board.history.past.is_empty()
	redo_button.disabled = board.history.future.is_empty()
	next_button.disabled = not solved or generation_task != null or save_failed
	next_button.text = "Siguiente tablero" if session.is_procedural() else ("Volver al primero" if session.sequence.wraps_after(board.puzzle.puzzle_id) else "Siguiente")
	new_board_button.disabled = generation_task != null or save_failed
	new_board_button.visible = not session.is_story()
	mode_status.visible = session.is_procedural() or session.is_story()
	mode_status.text = ("Historia · " + StoryCatalog.title(session.story_ordinal()) + " · " + ("Directo" if StoryPolicy.profile(session.story_ordinal()) == "local" else "Reflexivo")) if session.is_story() else Mode.description(session.run)
	if session.is_story():
		var kind := Story.kind(session.story, session.story_ordinal())
		if kind != "classic":
			mode_status.text = "Historia · " + StoryCatalog.title(session.story_ordinal()) + " · " + {"blue": "Azules: S = puentes simples", "mystery": "?: sin número; conecta toda la red", "combined": "S: simples · ?: sin número"}[kind]
		next_button.text = "Continuar ruta" if _next_story_ordinal() > session.story_ordinal() + 1 else "Siguiente nivel"
	_sync_selector()
	if solved:
		if session.is_story():
			status.text = "¡Nivel resuelto! Puedes seguir o repetirlo."
		elif session.is_procedural():
			status.text = "¡Tablero resuelto! Puedes crear otro."
		else:
			status.text = "Tablero resuelto. Fin de la secuencia provisional." if session.sequence.wraps_after(board.puzzle.puzzle_id) else "¡Tablero resuelto! Puedes pasar al siguiente."
	elif not message.is_empty():
		status.text = message
	elif board.warnings_enabled:
		status.text = "Sin excesos. Comprueba los números y la conexión."
		for item in board.puzzle.islands:
			if item.get("variant", "classic") != "mystery" and board.puzzle.degree(str(item.id)) > int(item.target):
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
	var pending_quality: bool = not session.quality.pending.is_empty()
	var ended := _iron_ended()
	board.bridge_color = Color("f1c55b") if session.quality.streak >= 7 else (Color("a982e7") if session.quality.streak >= 3 else (Color("5db9ff") if session.quality.streak >= 1 else Color("aac4d1")))
	board.queue_redraw()
	board.input_enabled = not pending_quality and not ended and not save_failed
	undo_button.disabled = undo_button.disabled or pending_quality or ended or save_failed
	redo_button.disabled = redo_button.disabled or pending_quality or ended or save_failed
	restart_button.disabled = pending_quality or ended or save_failed
	next_button.disabled = next_button.disabled or pending_quality or ended or save_failed
	new_board_button.disabled = new_board_button.disabled or pending_quality or ended or save_failed
	selector.disabled = pending_quality
	quality_status.text = "%s · Racha %d · Récord Alma %d" % [Quality.color_name(session.quality), int(session.quality.streak), int(session.quality.iron_record)]
	quality_status.add_theme_color_override("font_color", Color("e5c45c") if session.quality.streak >= 7 else (Color("be9be9") if session.quality.streak >= 3 else Color("8acbff")))
	quality_retry.visible = save_failed or (pending_quality and quality_worker != null and quality_worker.uncertain)
	quality_retry.text = "Reintentar guardado" if save_failed else "Reintentar comprobación"
	if pending_quality:
		status.text = "Comprobando la racha… Puedes volver a Inicio."
		if quality_worker != null and quality_worker.uncertain:
			status.text = "Racha pendiente. Reintenta; tu progreso se conserva."
	if ended:
		status.text = "Alma terminó. Récord conservado. Nuevo desafío desde Inicio."
	if story_view != null and screen == "story":
		story_view.update_state(generation_task != null or pending_quality, status.text if generation_task != null or pending_quality or not _generation_message.is_empty() or save_failed else "")
	if home != null:
		home.update_state(_has_game, generation_task != null or pending_quality, status.text if generation_task != null or pending_quality or not _generation_message.is_empty() or save_failed else "", pending_quality)

func _sync_selector() -> void:
	if selector.item_count != session.catalog.size():
		selector.clear()
		for definition in session.catalog:
			selector.add_item(str(definition.title))
	for i in session.catalog.size():
		var definition: Dictionary = session.catalog[i]
		var title := "%d · %s" % [i + 1, definition.title] if i < session.base_catalog.size() else str(definition.title)
		if session.procedural.has(str(definition.id)) and session.run.mode != "free":
			title = ({"fixed": "Fija", "iron": "Alma", "progression": "Progresión"}[session.run.mode]) + " · " + ("Directo" if session.run.board_profile == "local" else "Reflexivo")
		var ordinal := Story.ordinal(session.story, str(definition.id))
		if ordinal >= 0:
			title = "Historia · " + StoryCatalog.title(ordinal)
		selector.set_item_disabled(i, ordinal > int(session.story.frontier))
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
	var excluded_id := str(session.procedural.keys()[0]) if not session.procedural.is_empty() else ""
	_request_story = -1
	_request_run = _pending_run.duplicate(true) if not _pending_run.is_empty() else session.run.duplicate(true)
	_pending_run = {}
	_request_run.board_profile = Mode.next_profile(_request_run, settings.profile)
	if not generation_task.start_free(seed_value, _request_run.board_profile, generation_options, excluded_id):
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
	elif _request_story >= 0:
		if session.install_story_and_save(_request_story, result.recipe):
			save_failed = false
			_has_game = true
			_display_current()
			_open_game()
		else:
			_generation_message = "No se pudo guardar el nivel. Se conserva tu partida."
			_update_status("")
	elif session.install_procedural_and_save(result.recipe, _request_run):
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


func _show_story() -> void:
	_invalidate_generation()
	screen = "story"
	home.hide()
	game_view.hide()
	story_view.refresh(session.story, session.completed_ids)
	story_view.show()
	_update_status("")

func _select_story(ordinal: int) -> void:
	if not session.quality.pending.is_empty():
		return
	if generation_task != null or ordinal < 0 or ordinal > int(session.story.frontier):
		return
	if save_failed:
		_save_game()
		if save_failed:
			return
	var index := session.story_index(ordinal)
	if index >= 0:
		_select_puzzle(index)
		return
	if ordinal != int(session.story.frontier) or ordinal < StoryCatalog.COUNT:
		return
	_generation_epoch += 1
	_request_epoch = _generation_epoch
	_request_story = ordinal
	generation_task = GenerationTask.new()
	if not generation_task.start_story(ordinal, generation_options, Story.definitions(session.story), int(session.story.variant_from)):
		generation_task = null
		_generation_message = "No se pudo iniciar el nivel. Inténtalo de nuevo."
	else:
		set_process(true)
	_update_status("")

func _next_story_ordinal() -> int:
	var following := session.story_ordinal() + 1
	return following if session.story_index(following) >= 0 else int(session.story.frontier)

func _iron_ended() -> bool:
	return session != null and session.is_procedural() and session.run.mode == "iron" and session.quality.iron_ended
func _accept_quality_verdict(verdict: Dictionary) -> void:
	if verdict.status in ["viable", "impossible"]:
		_quality_verdict = verdict.duplicate(true)
		_save_game()
	else:
		_update_status("")
func _retry_quality() -> void:
	if save_failed:
		_save_game()
	if quality_worker != null and not save_failed:
		quality_worker.retry()
	_update_status("")
