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
const Art = preload("res://scripts/hashi_art.gd")
const Backdrop = preload("res://scripts/hashi_backdrop.gd")
const ArtPreferences = preload("res://scripts/hashi_art_preferences.gd")
var art_preferences: ArtPreferences
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

var level_label: Label
var help_button: Button
var help_view: MarginContainer
var help_title: Label
var help_text: Label
var warnings_toggle: CheckButton
var notice: Label
var streak_count: Label
var record_count: Label
var attempt_count: Label
var attempt_chip: HBoxContainer
var record_chip: HBoxContainer
var _confirmation_page := "home"
const INPUT_BACKLOG_LIMIT := 8

func _ready() -> void:
	set_process(false)
	theme = Art.theme()
	add_child(Backdrop.new())
	art_preferences = ArtPreferences.new(save_path + ".appearance")
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
	game_view = MarginContainer.new()
	game_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		game_view.add_theme_constant_override("margin_" + side, 16)
	add_child(game_view)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	game_view.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	home_button = _button("", header, _show_home)
	Art.symbol(home_button, "back", "Inicio")
	level_label = Label.new()
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Art.heading(level_label, 30)
	header.add_child(level_label)
	help_button = _button("", header, _show_help)
	Art.symbol(help_button, "menu", "Ayuda y opciones")
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 24)
	column.add_child(stats)
	streak_count = _stat(stats, "flame", "Racha de tableros perfectos")
	attempt_count = _stat(stats, "heart", "Correcciones de Historia restantes")
	attempt_chip = attempt_count.get_parent()
	record_count = _stat(stats, "crown", "Récord de Alma de Hierro")
	record_chip = record_count.get_parent()
	board = Board.new()
	board.set_motion_enabled(art_preferences.motion)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(200, 200)
	column.add_child(board)
	notice = Label.new()
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notice)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(controls)
	undo_button = _button("", controls, board.undo)
	Art.symbol(undo_button, "undo", "Deshacer")
	redo_button = _button("", controls, board.redo)
	Art.symbol(redo_button, "redo", "Rehacer")
	restart_button = _button("", controls, _restart_current)
	Art.symbol(restart_button, "restart", "Repetir nivel")
	new_board_button = _button("", controls, _ask_new_puzzle)
	Art.symbol(new_board_button, "new", "Nuevo tablero")
	next_button = _button("", controls, _next_puzzle)
	Art.symbol(next_button, "play", "Siguiente")
	Art.primary(next_button)
	quality_retry = _button("", column, _retry_quality)
	Art.symbol(quality_retry, "restart", "Reintentar")
	quality_retry.hide()
	# Semantic state retained for accessibility, help and regression tests; hidden from play.
	selector = OptionButton.new()
	selector.fit_to_longest_item = false
	selector.clip_text = true
	add_child(selector)
	selector.hide()
	for i in puzzles.size():
		selector.add_item(str(i+1))
	gesture_hint = Label.new()
	mode_status = Label.new()
	quality_status = Label.new()
	status = Label.new()
	for label in [gesture_hint, mode_status, quality_status, status]:
		add_child(label)
		label.hide()
	board.puzzle_changed.connect(_on_puzzle_changed)
	board.state_changed.connect(_update_status)
	selector.item_selected.connect(_select_puzzle)
	home = Home.new()
	add_child(home)
	home.build(puzzles)
	home.challenge.select(0 if settings.profile == "local" else 1)
	home.motion_button.set_pressed_no_signal(art_preferences.motion)
	home.motion_requested.connect(func(enabled: bool):
		if art_preferences.save_motion(enabled):
			board.set_motion_enabled(enabled)
		else:
			home.motion_button.set_pressed_no_signal(art_preferences.motion)
	)
	story_view = StoryView.new()
	add_child(story_view)
	story_view.hide()
	story_view.selected.connect(_select_story)
	story_view.back_requested.connect(_show_home)
	story_view.help_requested.connect(func(): _show_help(true))
	home.story_requested.connect(_show_story)
	home.profile_requested.connect(_choose_profile)
	home.continue_requested.connect(_continue_game)
	home.new_requested.connect(func(): _ask_mode("free", settings.profile))
	home.mode_requested.connect(_ask_mode)
	home.lesson_requested.connect(_select_puzzle)
	home.confirm_requested.connect(_confirm_new_puzzle)
	home.cancel_requested.connect(_cancel_new_puzzle)
	home.page_changed.connect(_on_home_page_changed)
	_build_help()
	quality_worker = QualityWorker.new()
	quality_worker.host = self
	add_child(quality_worker)
	_display_current()
	_show_home()
	if not recovery_message.is_empty():
		_generation_message = recovery_message
		_update_status("")

func _stat(parent: Control, icon_name: String, label: String) -> Label:
	var chip := HBoxContainer.new()
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.tooltip_text = label
	parent.add_child(chip)
	var icon := TextureRect.new()
	icon.texture = Art.ICONS[icon_name]
	icon.modulate = Art.GOLD if icon_name == "flame" else Art.INK
	icon.custom_minimum_size = Vector2(22,22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chip.add_child(icon)
	var count := Label.new()
	count.add_theme_font_size_override("font_size", 18)
	chip.add_child(count)
	return count

func _build_help() -> void:
	help_view = MarginContainer.new()
	help_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		help_view.add_theme_constant_override("margin_" + side, 14)
	add_child(help_view)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Art.surface(Art.PAPER, Art.BORDER, 24))
	help_view.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var back := _button("", header, _close_help)
	Art.symbol(back, "back", "Volver a la partida")
	help_title = Label.new()
	Art.heading(help_title, 24)
	help_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(help_title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	scroll.add_child(body)
	help_text = Label.new()
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(help_text)
	warnings_toggle = CheckButton.new()
	warnings_toggle.text = "Señalar excesos"
	warnings_toggle.custom_minimum_size.y = 52
	warnings_toggle.toggled.connect(func(enabled: bool):
		board.warnings_enabled = enabled
		board.queue_redraw()
		_update_status("")
	)
	body.add_child(warnings_toggle)
	home.motion_button.reparent(body)
	_button("Aprender", body, func():
		_close_help()
		_show_home()
		home.show_page("learn")
	)
	help_view.hide()

func _show_help(force_story: bool = false) -> void:
	_clear_gesture()
	var in_story := force_story or session.is_story() or screen == "story"
	var name_mode: String = "Historia" if in_story else {"free":"Libre", "fixed":"Dificultad fija", "progression":"Progresión", "iron":"Alma de Hierro"}[session.run.mode]
	if not in_story and not session.is_procedural():
		name_mode = "Aprender"
	help_title.text = name_mode
	var description: String = "Resuelve un nivel para abrir el siguiente. El corazón cuenta tus tres correcciones por intento. Deshacer o borrar puentes consume una; cortar varios con un solo gesto cuenta una vez. Cuando se agotan, termina el intento si aún no has resuelto la red. Repite para volver a intentarlo: conservas los niveles superados." if in_story else {"free":"Un tablero a tu ritmo. Elige Directo o Reflexivo en Modos.", "fixed":"Una serie con el mismo perfil de desafío.", "progression":"Una serie que va de Directo a Reflexivo.", "iron":"La primera falta termina el desafío. Conservas tu récord al empezar otro."}[session.run.mode]
	if name_mode == "Aprender":
		description = "Unos tableros para familiarizarte con los puentes."
	help_text.text = description + "\n\nCÓMO JUGAR\nConecta todas las islas en una red. Cada número cuenta los puentes que necesita. Entre dos islas caben hasta dos puentes. No pueden cruzarse ni pasar sobre otra isla.\n\nToca dos islas o desliza entre ellas: 0 → 1 → 2 → 0. Las S alternan 0 → 1 → 0. Para borrar, cruza el puente con un trazo. Puedes cortar varios a la vez.\n\nS: solo puentes simples. ?: sin número.\n\nRACHA\nEl símbolo de la llama cuenta tableros perfectos. Deshacer, retirar puentes o dejar la red sin solución corta la racha. Azul:1; morado:3; dorado:7.\n\nLas flechas curvas deshacen y rehacen; la circular repite y el triángulo continúa."
	if save_failed or not session.quality.pending.is_empty():
		help_text.text += "\n\n" + status.text
	help_view.show()
	board.input_enabled = false

func _close_help() -> void:
	help_view.hide()
	_update_status("")

func _restart_current() -> void:
	if save_failed:
		_save_game()
		if save_failed:
			return
	if session.is_story():
		if session.restart_story_and_save():
			_display_current()
		else:
			_generation_message = "No se pudo repetir. Se conserva tu partida."
			_update_status("")
	else:
		board.reset()

func _button(text: String, parent: Control, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	for style in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = theme.get_stylebox(style, "Button").duplicate()
		box.content_margin_left = 8
		box.content_margin_right = 8
		button.add_theme_stylebox_override(style, box)
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
	if not session.quality.pending.is_empty() or _iron_ended() or session.story_lost():
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
	if help_view != null:
		help_view.hide()
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
	_clear_gesture()
	_invalidate_generation()
	_update_status("")

func _clear_gesture() -> void:
	board.cancel_gesture()

func _open_game() -> void:
	if help_view != null:
		help_view.hide()
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
			_confirmation_page = home.page
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
		if _confirmation_page == "modes":
			home.show_page("modes")

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
		if help_view != null and help_view.visible:
			_close_help()
		elif _confirmation_pending:
			_cancel_new_puzzle()
		elif screen in ["game", "story"]:
			_show_home()
		elif home.page != "home":
			home.show_page("modes" if home.page == "rules" else "home")
		else:
			if save_failed:
				_save_game()
			get_tree().quit()
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		if board != null:
			_clear_gesture()
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
	var was_input_enabled := board.input_enabled
	var input_wait: bool = pending_quality and (solved or session.quality.pending.size() >= INPUT_BACKLOG_LIMIT or (quality_worker != null and quality_worker.uncertain))
	board.bridge_color = Color("a16b29") if session.quality.streak >= 7 else (Color("77558a") if session.quality.streak >= 3 else (Color("2b7a9b") if session.quality.streak >= 1 else Color("466451")))
	board.queue_redraw()
	board.input_enabled = not input_wait and not ended and not save_failed
	undo_button.disabled = undo_button.disabled or input_wait or ended or save_failed
	redo_button.disabled = redo_button.disabled or input_wait or ended or save_failed
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

	var story_over := session.is_story() and session.story_corrections_left() == 0
	board.input_enabled = board.input_enabled and not story_over and not help_view.visible
	if was_input_enabled and not board.input_enabled:
		board.cancel_gesture()
	undo_button.disabled = undo_button.disabled or story_over
	redo_button.disabled = redo_button.disabled or story_over
	next_button.disabled = next_button.disabled or session.story_lost()
	if session.is_story():
		level_label.text = StoryView.level_code(session.story_ordinal())
	elif session.is_procedural():
		level_label.text = str(maxi(1, int(session.run.wins) + (0 if session.run.credited_id == board.puzzle.puzzle_id else 1)))
	else:
		level_label.text = str(session.current_index + 1)
	level_label.tooltip_text = mode_status.text
	streak_count.text = str(int(session.quality.streak))
	attempt_count.text = str(session.story_corrections_left())
	record_count.text = str(int(session.quality.iron_record))
	attempt_chip.visible = session.is_story()
	record_chip.visible = session.is_procedural() and session.run.mode == "iron"
	for semantic in [gesture_hint, mode_status, quality_status, status, selector]:
		semantic.hide()
	for button in [next_button, quality_retry]:
		button.tooltip_text = button.text
		button.text = ""
	if session.story_lost():
		status.text = "Intento terminado. Repite para volver a intentarlo."
	if save_failed:
		notice.text = "No se pudo guardar"
	elif session.story_lost():
		notice.text = "Otra oportunidad"
	elif ended:
		notice.text = "Ronda terminada"
	elif pending_quality and quality_worker != null and quality_worker.uncertain:
		notice.text = "Reintenta"
	elif generation_task != null or (pending_quality and (input_wait or solved)):
		notice.text = "Un momento…"
	elif solved:
		notice.text = "¡Bien hecho!"
	else:
		notice.text = "Inténtalo de nuevo" if not _generation_message.is_empty() else ""
	notice.visible = not notice.text.is_empty()

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
	_clear_gesture()
	if help_view != null:
		help_view.hide()
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
