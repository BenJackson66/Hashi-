extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Board = preload("res://scripts/hashi_board.gd")
const Art = preload("res://scripts/hashi_art.gd")
var checks := 0
var failures := 0
var events := 0
func _initialize():
	call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if not value:
		failures += 1
		printerr("ART FAIL: ",label)
func run():
	var ui = Main.instantiate()
	ui.save_path = "user://art-presentation-%d.json" % Time.get_ticks_usec()
	root.add_child(ui)
	await process_frame
	check(ui.theme.default_font == Art.BODY,"bundled body font active")
	check(ui.board.motion_enabled,"motion enabled by default")
	ui._select_puzzle(0)
	ui.board.puzzle_changed.connect(func(): events += 1)
	ui.board._connect_islands("0","1")
	var state: Dictionary = ui.session.snapshot_data()
	var bridges: Dictionary = ui.board.puzzle.bridges.duplicate(true)
	check(events == 1 and bridges == {"0:1":1},"gesture updates domain immediately")
	check(not ui.board._motions.is_empty(),"gesture starts a visual transition")
	for delta in [0.04,0.04,0.2,0.8]:
		ui.board._process(delta)
		check(ui.session.snapshot_data() == state and ui.board.puzzle.bridges == bridges,"animation never changes game/save/credit")
	check(events == 1 and ui.board._motions.is_empty() and not ui.board.is_processing(),"animation finishes without extra gestures")
	ui.board._connect_islands("0","3")
	check(events == 1 and ui.board._motions.is_empty(),"rejected diagonal never animates or credits")
	ui.home.motion_button.button_pressed = false
	check(not ui.board.motion_enabled and not ui.board.is_processing(),"reduced motion disables redraw loop")
	check(ui.session.snapshot_data() == state,"cosmetic preference leaves progress snapshot untouched")
	ui.board._connect_islands("0","1")
	check(ui.board.puzzle.bridge_count("0","1") == 2 and ui.board._motions.is_empty(),"motion disabled still accepts real moves")
	ui.board.undo()
	check(ui.board.puzzle.bridge_count("0","1") == 1,"undo behavior retained without animation")
	var path: String = ui.save_path
	state = ui.session.snapshot_data()
	ui.queue_free(); await process_frame
	ui = Main.instantiate();ui.save_path=path;root.add_child(ui);await process_frame
	check(not ui.board.motion_enabled and not ui.home.motion_button.button_pressed,"appearance preference survives restart")
	check(ui.session.snapshot_data() == state and ui.board._motions.is_empty(),"restore neither animates nor changes saved board")
	ui.home.motion_button.button_pressed = true
	check(ui.board.motion_enabled and ui.session.snapshot_data() == state,"enabling motion does not replay a gesture")
	ui.queue_free();await process_frame
	# Public variant marks remain semantically separate from bridge reward colors.
	var board := Board.new()
	board.size = Vector2(320,240)
	board.set_puzzle(Puzzle.new({"id":"visible-art","ruleset":"visible-variants-1","islands":[{"id":"a","x":0,"y":0,"target":1,"variant":"blue"},{"id":"b","x":1,"y":0,"target":0,"variant":"mystery"}]}))
	board._connect_islands("a","b")
	check(board.puzzle.bridge_count("a","b") == 1,"blue first bridge works")
	board._process(1)
	check(board._motions.is_empty() and board._win_glow == 0,"win feedback ends within bounded time")
	board._connect_islands("a","b")
	check(board.puzzle.bridges.is_empty(),"blue still cycles 0 to1 to0")
	board._layout_islands()
	check(board._hit(board.centers.a) == "a" and board._hit(board.centers.b) == "b","new drawing preserves hit centers")
	board.set_puzzle(Puzzle.new({"id":"restored","islands":[{"id":"a","x":0,"y":0,"target":1},{"id":"b","x":1,"y":0,"target":1}]}))
	check(board._motions.is_empty() and not board.is_processing(),"changing board cancels old animation")
	board.free()
	print("ART PRESENTATION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
