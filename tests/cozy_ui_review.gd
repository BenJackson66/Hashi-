extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Solver = preload("res://scripts/hashi_solver.gd")
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(value: bool,label: String):
	checks+=1
	if not value:
		failures+=1
		printerr("IGOR COZY UI FAIL: ",label)
func settle():
	for i in 5:await process_frame
func touch(board,point: Vector2,pressed: bool):
	var event:=InputEventScreenTouch.new();event.position=point;event.index=0;event.pressed=pressed;board._gui_input(event)
func drag(board,point: Vector2):
	var event:=InputEventScreenDrag.new();event.position=point;event.index=0;board._gui_input(event)
func safe_cut(board) -> Array:
	board._layout_islands()
	var edges: Array=board.puzzle.bridges.keys()
	edges.sort_custom(func(a,b):
		var pa: PackedStringArray=str(a).split(":");var pb: PackedStringArray=str(b).split(":")
		return board.centers[pa[0]].distance_squared_to(board.centers[pa[1]])>board.centers[pb[0]].distance_squared_to(board.centers[pb[1]])
	)
	for edge in edges:
		var ids: PackedStringArray=str(edge).split(":")
		var a: Vector2=board.centers[ids[0]];var b: Vector2=board.centers[ids[1]]
		var mid: Vector2=(a+b)/2;var normal: Vector2=(b-a).normalized().orthogonal()
		for distance in [26.0,30.0,36.0]:
			var start: Vector2=mid-normal*distance;var end: Vector2=mid+normal*distance
			if Rect2(Vector2.ZERO,board.size).has_point(start) and Rect2(Vector2.ZERO,board.size).has_point(end) and board._core_hit(start).is_empty() and board._core_hit(end).is_empty():
				return [start,end]
	return []
func run():
	for dimensions in [Vector2i(360,640),Vector2i(480,800)]:
		root.size=dimensions;root.content_scale_size=dimensions
		var ui=Main.instantiate();ui.save_path="user://igor-cozy-ui-%d.json"%dimensions.x
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ui.save_path))
		root.add_child(ui);await settle()
		check(ui.home.pages.home.get_child_count()==3,"home has only two choices and conditional continue icon")
		check(not ui.home.continue_button.visible,"fresh home hides continue")
		ui._select_story(0);await settle()
		check(ui.level_label.text=="1-1","story header uses short centered code")
		check(absf(ui.level_label.get_global_rect().get_center().x-dimensions.x/2.0)<2,"header number centered")
		check(ui.board.size.y>=200 and ui.next_button.get_global_rect().end.y<=dimensions.y,"play controls fit viewport")
		check(not ui.mode_status.visible and not ui.status.visible and not ui.gesture_hint.visible,"legacy paragraphs hidden from play")
		ui.help_button.pressed.emit();await settle()
		check(ui.help_view.visible and not ui.board.input_enabled,"help modal blocks board")
		check("\n\n" in ui.help_text.text and "\\n" not in ui.help_text.text,"help uses actual newlines")
		check("tres correcciones" in ui.help_text.text and "S:" in ui.help_text.text and "?:" in ui.help_text.text,"contextual story and variant rules available")
		ui._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		check(not ui.help_view.visible and ui.board.input_enabled,"Android back closes help first")
		var answer: Dictionary=Solver.new().solve(ui.board.puzzle)
		check(answer.status=="unique","actual first story fixture solved")
		var base: Dictionary=answer.solutions[0].duplicate(true)
		var extras:=0
		for edge in base:
			if base[edge]==1 and extras<3:
				base[edge]=2;extras+=1
		ui.board.puzzle.bridges=base.duplicate(true);ui._save_game();await settle()
		check(not ui.save_failed and ui.session.story_corrections_left()==3,"editing fixture saved without spending corrections")
		var stroke:=safe_cut(ui.board)
		check(stroke.size()==2,"real board offers safe transverse cut")
		if stroke.is_empty():ui.queue_free();await process_frame;continue
		var before: Dictionary=ui.session.snapshot_data()
		var temp:=ProjectSettings.globalize_path(ui.save_path+".tmp")
		DirAccess.make_dir_absolute(temp)
		touch(ui.board,stroke[0],true);drag(ui.board,stroke[1]);touch(ui.board,stroke[1],false)
		check(ui.board.last_action.kind=="cut" and ui.save_failed,"real touch cut attempts save")
		check(ui.session.snapshot_data()==before and ui.session.story_corrections_left()==3,"failed cut retains durable budget and board")
		check(ui.quality_retry.visible and "guardado" in ui.quality_retry.tooltip_text and not ui.board.input_enabled,"failed save exposes retry and freezes editing")
		DirAccess.remove_absolute(temp)
		ui.quality_retry.pressed.emit();await settle()
		check(not ui.save_failed and ui.session.story_corrections_left()==2 and ui._quality_actions.is_empty(),"retry commits cut and charges once")
		ui._save_game();check(ui.session.story_corrections_left()==2,"passive save cannot charge same cut twice")
		var pending_stroke:=safe_cut(ui.board)
		if not pending_stroke.is_empty():
			var stable: Dictionary=ui.board.puzzle.bridges.duplicate(true)
			touch(ui.board,pending_stroke[0],true);drag(ui.board,pending_stroke[1]);ui._show_help();ui._close_help();touch(ui.board,pending_stroke[1],false)
			check(ui.board.puzzle.bridges==stable and ui.session.story_corrections_left()==2,"opening help cancels buffered cut")
			touch(ui.board,pending_stroke[0],true);drag(ui.board,pending_stroke[1]);ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);touch(ui.board,pending_stroke[1],false)
			check(ui.board.puzzle.bridges==stable and ui.session.story_corrections_left()==2,"focus loss cancels buffered cut")
		ui.undo_button.pressed.emit();check(ui.session.story_corrections_left()==1,"UI undo restoring cut costs one")
		ui.redo_button.pressed.emit();check(ui.session.story_lost() and ui.session.story_corrections_left()==0,"UI redo spends third correction and ends unresolved attempt")
		check(not ui.board.input_enabled and ui.undo_button.disabled and ui.redo_button.disabled and ui.next_button.disabled and not ui.restart_button.disabled,"lost state freezes play but permits explicit repeat")
		check(ui.notice.visible and "oportunidad" in ui.notice.text,"lost state visible")
		var frontier: int=ui.session.story.frontier
		ui.restart_button.pressed.emit();await settle()
		check(not ui.session.story_lost() and ui.session.story_corrections_left()==3 and ui.board.puzzle.bridges.is_empty() and ui.board.history.past.is_empty(),"UI restart restores empty attempt and clears history")
		check(ui.session.story.frontier==frontier and ui.board.input_enabled,"restart preserves campaign and resumes input")
		ui.queue_free();await process_frame
	print("IGOR COZY UI REVIEW: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
