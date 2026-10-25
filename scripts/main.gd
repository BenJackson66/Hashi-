extends Control
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const Board = preload("res://scripts/hashi_board.gd")
var puzzles: Array = []
var board: Board
var status: Label
var selector: OptionButton

func _ready() -> void:
	puzzles = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "HASHI"
	heading.add_theme_font_size_override("font_size", 32)
	column.add_child(heading)
	selector = OptionButton.new()
	selector.custom_minimum_size.y = 48
	for i in puzzles.size():
		selector.add_item("%d · %s" % [i + 1, puzzles[i].title])
	column.add_child(selector)
	var hint := Label.new()
	hint.text = "Toca dos islas o desliza entre ellas.\nPuentes: 0 → 1 → 2 → 0. Une toda la red."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	board = Board.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(200, 200)
	column.add_child(board)
	status = Label.new()
	status.custom_minimum_size.y = 48
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var warnings := CheckButton.new()
	warnings.text = "Advertencias de errores"
	warnings.custom_minimum_size.y = 48
	warnings.button_pressed = false
	warnings.toggled.connect(func(enabled: bool):
		board.warnings_enabled = enabled
		board.queue_redraw()
		_update_status("")
	)
	column.add_child(warnings)
	var restart := Button.new()
	restart.text = "Reiniciar tablero"
	restart.custom_minimum_size.y = 48
	restart.pressed.connect(board.reset)
	column.add_child(restart)
	board.state_changed.connect(_update_status)
	selector.item_selected.connect(_select_puzzle)
	_select_puzzle(0)

func _select_puzzle(index: int) -> void:
	board.set_puzzle(Puzzle.new(puzzles[index]))
	_update_status("")

func _update_status(message: String) -> void:
	if Rules.is_solved(board.puzzle):
		status.text = "¡Tablero resuelto! Toda la red está conectada."
	elif not message.is_empty():
		status.text = message
	elif board.warnings_enabled:
		for item in board.puzzle.islands:
			if board.puzzle.degree(str(item.id)) > int(item.target):
				status.text = "Hay islas con más puentes de los indicados."
				return
		status.text = "Sin excesos. Comprueba los números y la conexión."
	else:
		status.text = "Completa cada número y conecta todas las islas."
