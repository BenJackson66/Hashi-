extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Session=preload("res://scripts/hashi_session.gd")
const Solver=preload("res://scripts/hashi_solver.gd")
const Generator=preload("res://scripts/hashi_generator.gd")
const Rules=preload("res://scripts/hashi_rule_set.gd")
var checks:=0
var failures:=0
var tutorials: Array
func _initialize():call_deferred("run")
func check(value: bool,label: String):
	checks+=1
	if not value:
		failures+=1
		printerr("BACKLOG REVIEW FAIL: ",label)
func touch(board,point: Vector2,pressed: bool):
	var e:=InputEventScreenTouch.new();e.position=point;e.index=0;e.pressed=pressed;board._gui_input(e)
func connect_touch(board,edge: String):
	board._layout_islands()
	var ends:=edge.split(":")
	for id in ends:
		touch(board,board.centers[id],true);touch(board,board.centers[id],false)
func cold_story(path: String,count: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var session:=Session.new(tutorials,path)
	check(session.select_and_save(session.story_index(0)),"story fixture selected")
	var puzzle:=session.current_puzzle()
	var answer:=Solver.new().solve(puzzle)
	var prefix: Dictionary={}
	var pending: Array=[]
	for edge in answer.solutions[0]:
		for n in int(answer.solutions[0][edge]):
			prefix[edge]=int(prefix.get(edge,0))+1
			pending.append({"serial":pending.size()+1,"id":puzzle.puzzle_id,"bridges":prefix.duplicate(true),"iron":false})
			if pending.size()==count:break
		if pending.size()==count:break
	check(pending.size()==count,"enough real monotone prefixes in fixture")
	session.boards[puzzle.puzzle_id]=prefix.duplicate(true)
	session.quality.serial=count;session.quality.pending=pending
	check(session.save_game(),"valid pending snapshot persisted before UI opens")
func open_ui(path: String):
	var ui=Main.instantiate();ui.save_path=path;root.add_child(ui)
	ui.quality_worker.set_process(false)
	for i in 5:await process_frame
	ui._continue_game()
	for i in 3:await process_frame
	return ui
func dispose(ui):
	ui.queue_free();await process_frame
func run():
	tutorials=JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	root.size=Vector2i(360,640);root.content_scale_size=Vector2i(360,640)
	cold_story("user://backlog-edit.json",1)
	var ui=await open_ui("user://backlog-edit.json")
	check(ui.session.quality.pending.size()==1 and ui.board.input_enabled,"cold pending below cap allows editing")
	check(not ui.notice.visible,"allowed partial editing does not introduce a moving wait notice")
	check(ui.restart_button.disabled and ui.next_button.disabled and ui.selector.disabled and ui.new_board_button.disabled,"navigation and restart remain blocked while any prefix pending")
	var answer: Dictionary=Solver.new().solve(ui.board.puzzle)
	var next_edge:=""
	for edge in answer.solutions[0]:
		if ui.board.puzzle.bridge_count(str(edge).split(":")[0],str(edge).split(":")[1])<int(answer.solutions[0][edge]):
			next_edge=str(edge);break
	var before: Dictionary=ui.board.puzzle.bridges.duplicate(true)
	connect_touch(ui.board,next_edge)
	var after: Dictionary=ui.board.puzzle.bridges.duplicate(true)
	check(after!=before and not ui.save_failed,"real touch commits a further correct bridge while pending")
	check(ui.session.quality.pending[0].serial==1 and ui.session.quality.pending[0].bridges==before,"older prefix stays at FIFO head")
	check(not ui.undo_button.disabled and ui.board.input_enabled,"Undo enabled for editable pending state")
	ui.undo_button.pressed.emit()
	check(ui.board.puzzle.bridges==before and ui.session.story_corrections_left()==2,"Undo works and charges a correction behind pending")
	check(not ui.redo_button.disabled and ui.board.input_enabled,"Redo remains enabled behind pending")
	ui.redo_button.pressed.emit()
	check(ui.board.puzzle.bridges==after and ui.session.story_corrections_left()==2,"Redo restores an addition without charging twice")
	# An actual correction write fails, then retries once with the original event retained.
	var snapshot: Dictionary=ui.session.snapshot_data()
	var bytes:=FileAccess.get_file_as_string(ui.save_path)
	var temp:=ProjectSettings.globalize_path(ui.save_path+".tmp")
	check(DirAccess.make_dir_absolute(temp)==OK,"real write failure installed")
	ui.undo_button.pressed.emit()
	check(ui.save_failed and not ui.board.input_enabled and ui.quality_retry.visible,"failed save overrides editable backlog and exposes retry")
	check(ui.session.snapshot_data()==snapshot and FileAccess.get_file_as_string(ui.save_path)==bytes,"failed correction does not publish budget or bridges")
	DirAccess.remove_absolute(temp)
	ui.quality_retry.pressed.emit()
	check(not ui.save_failed and ui.session.story_corrections_left()==1 and ui._quality_actions.is_empty(),"retry commits exactly one pending correction")
	ui._save_game();check(ui.session.story_corrections_left()==1,"passive save cannot replay corrected action")
	# Uncertain state cancels a gesture; retry may reopen editing without losing the prefix.
	ui.board._layout_islands()
	var ends:=next_edge.split(":")
	touch(ui.board,ui.board.centers[ends[0]],true)
	check(ui.board._gesture_active,"gesture started while allowed")
	ui.quality_worker.uncertain=true;ui._update_status("")
	check(not ui.board.input_enabled and not ui.board._gesture_active and ui.quality_retry.visible,"asynchronous uncertainty blocks and cancels active gesture")
	before=ui.board.puzzle.bridges.duplicate(true)
	touch(ui.board,ui.board.centers[ends[1]],false)
	check(ui.board.puzzle.bridges==before,"late release after uncertainty cannot mutate")
	ui.quality_retry.pressed.emit()
	check(ui.board.input_enabled and not ui.quality_worker.uncertain,"explicit retry permits bounded editing again")
	snapshot=ui.session.snapshot_data();ui._select_puzzle(0);ui._ask_mode("fixed","local")
	check(ui.session.snapshot_data()==snapshot and ui.generation_task==null,"selection and new mode still blocked")
	await dispose(ui)
	# At eight durable prefixes, input stops; one resolved FIFO head frees room.
	cold_story("user://backlog-cap.json",8)
	ui=await open_ui("user://backlog-cap.json")
	check(not ui.board.input_enabled and ui.undo_button.disabled and ui.redo_button.disabled,"cap eight blocks edits and history")
	before=ui.board.puzzle.bridges.duplicate(true)
	answer=Solver.new().solve(ui.board.puzzle)
	var one: String=answer.solutions[0].keys()[0]
	connect_touch(ui.board,one)
	check(ui.board.puzzle.bridges==before,"real touch ignored at cap")
	var serial: int=ui.session.quality.pending[0].serial
	ui._accept_quality_verdict({"serial":serial,"status":"viable"})
	check(ui.session.quality.pending.size()==7 and ui.board.input_enabled,"resolving one head reopens bounded editing")
	check(ui.selector.disabled and ui.restart_button.disabled,"navigation remains blocked after partial drain")
	ui.board._layout_islands();var begin: Vector2=ui.board.centers[str(one).split(":")[0]]
	touch(ui.board,begin,true);ui.board.size+=Vector2(1,0)
	check(not ui.board._gesture_active,"resize cancels gesture with old geometry")
	await dispose(ui)
	# A visibly complete board is held until every earlier prefix has a verdict.
	cold_story("user://backlog-victory.json",1)
	ui=await open_ui("user://backlog-victory.json")
	answer=Solver.new().solve(ui.board.puzzle)
	for edge in answer.solutions[0]:
		var pair:=str(edge).split(":")
		var remaining: int=int(answer.solutions[0][edge])-ui.board.puzzle.bridge_count(pair[0],pair[1])
		for n in remaining:
			# On a slower runner, model a worker draining one proven viable prefix at capacity.
			if ui.session.quality.pending.size()>=ui.INPUT_BACKLOG_LIMIT:
				ui._accept_quality_verdict({"serial":int(ui.session.quality.pending[0].serial),"status":"viable"})
			connect_touch(ui.board,str(edge))
	check(Rules.is_solved(ui.board.puzzle) and not ui.save_failed,"rapid correct touches can complete pending board")
	check(not ui.board.input_enabled and ui.next_button.disabled,"complete pending board waits instead of accepting further edits")
	check(ui.session.story.frontier==0 and ui.session.quality.streak==0,"pending victory gives no progression or perfect credit")
	while not ui.session.quality.pending.is_empty():
		serial=int(ui.session.quality.pending[0].serial)
		ui._accept_quality_verdict({"serial":serial,"status":"viable"})
	check(ui.session.story.frontier==1 and ui.session.quality.streak==1 and not ui.next_button.disabled,"final verdict credits once and enables Next")
	ui._save_game();check(ui.session.quality.streak==1,"extra save cannot duplicate pending victory credit")
	await dispose(ui)
	# A late real impossible prefix ends Iron and cancels a gesture already in progress.
	var path:="user://backlog-iron.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var session:=Session.new(tutorials,path)
	var generated:=Generator.new().generate(42,{})
	var recipe: Dictionary={"seed":str(generated.seed),"algorithm_version":generated.algorithm_version,"identity_schema":1,"parameters":generated.parameters,"puzzle":generated.puzzle}
	check(session.install_procedural_and_save(recipe,{"version":1,"mode":"iron","fixed_profile":"local","wins":0,"credited_id":"","board_profile":"local"}),"real Iron recipe installed")
	var puzzle:=session.current_puzzle();answer=Solver.new().solve(puzzle)
	var bad:=""
	for edge in answer.solutions[0]:
		if answer.solutions[0][edge]==1:bad=str(edge);break
	check(not bad.is_empty(),"Iron fixture has a provably wrong forced double")
	session.boards[puzzle.puzzle_id]={bad:2}
	session.quality.serial=1;session.quality.pending=[{"serial":1,"id":puzzle.puzzle_id,"bridges":{bad:2},"iron":true}]
	check(session.save_game(),"Iron unresolved prefix saved for cold open")
	ui=await open_ui(path)
	check(ui.board.input_enabled and not ui.session.quality.iron_ended,"Iron partial pending is initially editable")
	ui.board._layout_islands();ends=bad.split(":")
	touch(ui.board,ui.board.centers[ends[0]],true)
	check(ui.board._gesture_active,"Iron touch in progress before verdict")
	ui._accept_quality_verdict({"serial":1,"status":"impossible"})
	check(ui.session.quality.iron_ended and not ui.board.input_enabled and not ui.board._gesture_active,"impossible verdict ends Iron and cancels active gesture")
	snapshot=ui.session.snapshot_data()
	touch(ui.board,ui.board.centers[ends[1]],false)
	check(ui.session.snapshot_data()==snapshot and ui.board.puzzle.bridges==snapshot.boards[puzzle.puzzle_id],"late release after Iron verdict cannot mutate durable or live board")
	await dispose(ui)
	print("IGOR COZY BACKLOG REVIEW: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
