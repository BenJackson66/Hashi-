extends SceneTree
const Session = preload("res://scripts/hashi_session.gd")
const Solver = preload("res://scripts/hashi_solver.gd")
const Rules = preload("res://scripts/hashi_rule_set.gd")
const Attempts = preload("res://scripts/hashi_story_attempts.gd")
var checks := 0
var failures := 0
var tutorials: Array
func _initialize():
	call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if not value:
		failures += 1
		printerr("IGOR COZY REVIEW FAIL: ",label)
func event(before: Dictionary, after: Dictionary, kind: String = "cut") -> Dictionary:
	return {"kind":kind,"before":before.duplicate(true),"bridges":after.duplicate(true)}
func fixture(path: String) -> Session:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var session := Session.new(tutorials,path)
	check(session.select_and_save(session.story_index(0)),"initial story selected")
	return session
func solved_bridges(session: Session) -> Dictionary:
	var result := Solver.new().solve(session.current_puzzle())
	check(result.status=="unique","real introduction unique")
	return result.solutions[0].duplicate(true)
func extra_base(solution: Dictionary, missing: bool = false) -> Dictionary:
	var result := solution.duplicate(true)
	var singles: Array=[]
	for edge in solution:
		if solution[edge]==1:
			singles.append(edge)
	check(singles.size()>=4,"fixture has enough independent simple edges")
	for i in 3:
		result[singles[i]]=2
	if missing:
		result.erase(singles[3])
	return result
func seed_board(session: Session, bridges: Dictionary) -> void:
	var puzzle := session.current_puzzle()
	puzzle.bridges=bridges.duplicate(true)
	check(session.capture_and_save(puzzle,[event({},bridges,"move")]),"seed structurally legal editing board")
func reopen(session: Session) -> Session:
	var restored := Session.new(tutorials,session.store.path)
	check(restored.restore(),"reopen succeeds")
	check(restored.snapshot_data()==session.snapshot_data(),"exact snapshot restored")
	return restored
func run():
	tutorials=JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	var session:=fixture("user://igor-cozy-winner.json")
	var solution:=solved_bridges(session)
	var base:=extra_base(solution)
	seed_board(session,base)
	check(session.story_corrections_left()==3 and not session.story_lost(),"new attempt starts with three")
	var puzzle:=session.current_puzzle()
	var corrections: Array=[]
	for edge in solution:
		if base.get(edge)==2 and solution[edge]==1:
			corrections.append(edge)
	for i in 3:
		var before:=puzzle.bridges.duplicate(true)
		puzzle.bridges[corrections[i]]=1
		check(session.capture_and_save(puzzle,[event(before,puzzle.bridges)]),"correction saved")
		check(session.story_corrections_left()==2-i,"one charge per correction")
	check(Rules.is_solved(puzzle) and not session.story_lost() and session.story.frontier==1,"third correction may win")
	session=reopen(session)
	var completed:=session.completed_ids.duplicate()
	var frontier: int=session.story.frontier
	var quality: Dictionary=session.quality.duplicate(true)
	var bytes:=FileAccess.get_file_as_string(session.store.path)
	var before_snapshot:=session.snapshot_data()
	var temp:=ProjectSettings.globalize_path(session.store.path+".tmp")
	check(DirAccess.make_dir_absolute(temp)==OK,"block restart write")
	check(not session.restart_story_and_save(),"restart write really fails")
	check(session.snapshot_data()==before_snapshot and FileAccess.get_file_as_string(session.store.path)==bytes,"failed restart publishes nothing")
	DirAccess.remove_absolute(temp)
	check(session.restart_story_and_save(),"explicit restart succeeds")
	check(session.story_corrections_left()==3 and not session.story_lost() and session.current_puzzle().bridges.is_empty(),"restart restores attempt only")
	check(session.story.frontier==frontier and session.completed_ids==completed and session.quality.iron_record==quality.iron_record,"restart preserves advancement and records")
	session=fixture("user://igor-cozy-prefix.json")
	solution=solved_bridges(session)
	base=extra_base(solution,true)
	seed_board(session,base)
	puzzle=session.current_puzzle()
	var actions: Array=[]
	for edge in corrections:
		var prior:=puzzle.bridges.duplicate(true)
		puzzle.bridges[edge]=1
		actions.append(event(prior,puzzle.bridges))
	var lost_prefix:=puzzle.bridges.duplicate(true)
	check(not Rules.is_solved(puzzle),"third correction prefix remains unresolved")
	puzzle.bridges=solution.duplicate(true)
	actions.append(event(lost_prefix,puzzle.bridges,"move"))
	before_snapshot=session.snapshot_data()
	bytes=FileAccess.get_file_as_string(session.store.path)
	temp=ProjectSettings.globalize_path(session.store.path+".tmp")
	DirAccess.make_dir_absolute(temp)
	check(not session.capture_and_save(puzzle,actions),"loss write fails")
	check(session.snapshot_data()==before_snapshot and FileAccess.get_file_as_string(session.store.path)==bytes,"loss failure retains committed budget")
	DirAccess.remove_absolute(temp)
	check(session.capture_and_save(puzzle,actions),"loss prefix retries atomically")
	check(session.story_lost() and session.story_corrections_left()==0 and session.story.frontier==0,"later solved suffix cannot erase third-correction loss")
	session=reopen(session)
	puzzle=session.current_puzzle()
	before_snapshot=session.snapshot_data()
	puzzle.bridges={}
	check(not session.capture_and_save(puzzle,[event(before_snapshot.boards[puzzle.puzzle_id],{},"cut")]) and session.snapshot_data()==before_snapshot,"lost attempt rejects later mutation")
	check(session.restart_story_and_save() and session.story_corrections_left()==3 and not session.story_lost(),"lost attempt can restart explicitly")
	# One action removes multiple edges; a repeated unchanged action is free.
	session=fixture("user://igor-cozy-multi.json")
	solution=solved_bridges(session)
	base=extra_base(solution)
	seed_board(session,base)
	puzzle=session.current_puzzle()
	var multi_before:=puzzle.bridges.duplicate(true)
	puzzle.bridges[corrections[0]]=1
	puzzle.bridges[corrections[1]]=1
	check(session.capture_and_save(puzzle,[event(multi_before,puzzle.bridges)]),"multi-edge gesture saved")
	check(session.story_corrections_left()==2,"multiple removed bridges charge only one gesture")
	var ghost_snapshot:=session.snapshot_data()
	var ghost_bytes:=FileAccess.get_file_as_string(session.store.path)
	check(not session.capture_and_save(puzzle,[event(multi_before,puzzle.bridges)]),"already committed old action cannot replay as a fresh correction")
	check(session.snapshot_data()==ghost_snapshot and FileAccess.get_file_as_string(session.store.path)==ghost_bytes,"rejected duplicate preserves budget and file")
	check(session.capture_and_save(puzzle,[event(puzzle.bridges,puzzle.bridges)]),"unchanged gesture accepted as no-op")
	check(session.story_corrections_left()==2,"no-op gesture costs nothing")
	var undo_before:=puzzle.bridges.duplicate(true)
	puzzle.bridges[corrections[0]]=2
	check(session.capture_and_save(puzzle,[event(undo_before,puzzle.bridges,"undo")]),"undo increasing bridge accepted")
	check(session.story_corrections_left()==1,"actual undo costs one even when it increases a bridge")
	session=reopen(session)
	var tutorial_session:=Session.new(tutorials,"user://igor-cozy-learning.json")
	var tutorial_puzzle:=tutorial_session.current_puzzle()
	var tutorial_result:=Solver.new().solve(tutorial_puzzle)
	tutorial_puzzle.bridges=tutorial_result.solutions[0].duplicate(true)
	check(tutorial_session.capture_and_save(tutorial_puzzle),"learning fixture saved")
	var old_tutorial:=tutorial_puzzle.bridges.duplicate(true)
	tutorial_puzzle.bridges={}
	check(tutorial_session.capture_and_save(tutorial_puzzle,[event(old_tutorial,{})]),"learning reduction saved")
	check(tutorial_session.story_attempts.levels.is_empty(),"learning does not consume story corrections")
	# Restart preserves already-consumed perfect credit and historical records.
	session=fixture("user://igor-cozy-credit.json")
	puzzle=session.current_puzzle()
	puzzle.bridges=solved_bridges(session)
	check(session.capture_and_save(puzzle),"fresh perfect solved")
	var credited_id:=puzzle.puzzle_id
	check(session.quality.marks[credited_id].credited and session.quality.streak==1,"fresh perfect accredited once")
	check(session.restart_story_and_save(),"credited level restarted")
	check(session.quality.marks[credited_id].credited and session.quality.marks[credited_id].spoiled and session.quality.streak==0,"restart preserves credit while spoiling the new attempt")
	puzzle=session.current_puzzle()
	puzzle.bridges=solved_bridges(session)
	check(session.capture_and_save(puzzle) and session.quality.streak==0,"re-solving restarted level cannot farm streak")
	var legacy:=session.snapshot_data()
	legacy.version=6
	legacy.erase("story_attempts")
	var file:=FileAccess.open(session.store.path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy));file.close()
	var legacy_bytes:=FileAccess.get_file_as_string(session.store.path)
	var migrated:=Session.new(tutorials,session.store.path)
	check(migrated.restore(),"actual v6 snapshot readable")
	check(migrated.story_attempts.levels.is_empty() and migrated.story_corrections_left()==3,"legacy gains only fresh correction budget")
	check(migrated.boards==session.boards and migrated.story==session.story and migrated.quality==session.quality,"migration preserves progress and quality")
	check(FileAccess.get_file_as_string(session.store.path)==legacy_bytes,"legacy opening never rewrites bytes")
	# Empty fresh restart must preserve a legitimately earned streak.
	session=fixture("user://igor-cozy-empty-restart.json")
	puzzle=session.current_puzzle();puzzle.bridges=solved_bridges(session)
	check(session.capture_and_save(puzzle),"perfect before entering next empty level")
	check(session.select_and_save(session.story_index(1)),"next empty level selected")
	before_snapshot=session.snapshot_data()
	bytes=FileAccess.get_file_as_string(session.store.path)
	check(session.restart_story_and_save(),"empty fresh restart is harmless success")
	check(session.snapshot_data()==before_snapshot and FileAccess.get_file_as_string(session.store.path)==bytes,"empty fresh restart is true no-op and preserves streak")
	# Version, count and lost invariants are checked before accepting a saved file.
	for change in [{"left":-1,"lost":false},{"left":4,"lost":false},{"left":1.5,"lost":false},{"left":2,"lost":true},{"left":true,"lost":false}]:
		var invalid:=Attempts.fresh()
		invalid.levels[puzzle.puzzle_id]=change
		check(not Attempts.valid(invalid,[puzzle.puzzle_id],{puzzle.puzzle_id:{}}),"invalid attempt budget rejected "+str(change))
	print("IGOR COZY DOMAIN REVIEW: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
