extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Session=preload("res://scripts/hashi_session.gd")
const Solver=preload("res://scripts/hashi_solver.gd")
const VariantSolver=preload("res://scripts/hashi_variant_solver.gd")
const Rules=preload("res://scripts/hashi_rule_set.gd")
const Progress=preload("res://scripts/hashi_landscape_progress.gd")
const Landscape=preload("res://scripts/hashi_landscape.gd")
const Sound=preload("res://scripts/hashi_sound.gd")
const Preferences=preload("res://scripts/hashi_art_preferences.gd")
var checks:=0
var failures:=0
var reveals:=0
var tutorials: Array
func _initialize():call_deferred("run")
func check(value: bool,label: String):
	checks+=1
	if not value:
		failures+=1
		printerr("IGOR LIGHTHOUSE FAIL: ",label)
func settle():
	for i in 4:await process_frame
func dispose(node):
	node.queue_free();await settle();await create_timer(.08).timeout
func solution(puzzle) -> Dictionary:
	var result: Dictionary=Solver.new().solve(puzzle) if puzzle.ruleset=="classic-1" else VariantSolver.new().solve(puzzle)
	check(result.status=="unique","actual level has one visible solution")
	return result.solutions[0].duplicate(true)
func clear_files(path: String):
	for suffix in ["",".appearance",".preferences"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
func prepare_preferences(path: String,motion: bool=false,sound: bool=true):
	var prefs:=Preferences.new(path+".appearance")
	check(prefs.save_motion(motion) and prefs.save_sound(sound),"fixture preferences durable")
func open_ui(path: String):
	var ui=Main.instantiate();ui.save_path=path;root.add_child(ui);ui.quality_worker.set_process(false);await settle();return ui
func complete(ui):
	ui.board.puzzle.bridges=solution(ui.board.puzzle)
	ui._save_game()
func run():
	tutorials=JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	for pair in [[-1,0],[0,0],[1,1],[3,3],[6,6],[9,9],[12,12],[99,12]]:
		var state: Dictionary={"frontier":pair[0]}
		var before:=state.duplicate(true)
		check(Progress.progress(state)==pair[1] and state==before,"landscape derives clamped progress without writing state")
	check(Progress.PARTS.size()==4 and Progress.MOMENTS.size()==12 and Landscape.LAYERS.size()==12,"four places and twelve improvements")
	for pair in [[0,0],[3,1],[6,2],[9,3],[12,3]]:
		check(Progress.part(pair[0])==pair[1],"restoration place boundary")
	await preferences_review()
	await sound_review()
	await landscape_review()
	await durable_review()
	await generation_race()
	print("IGOR LIGHTHOUSE REVIEW: ",checks," checks, ",failures," failures")
	await create_timer(.12).timeout
	quit(1 if failures else 0)
func preferences_review():
	var path:="user://igor-lighthouse-preferences.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var prefs:=Preferences.new(path)
	check(prefs.motion and prefs.sound,"new cosmetic preferences default independently enabled")
	check(prefs.save_motion(false) and prefs.save_sound(false),"both preferences saved independently")
	prefs=Preferences.new(path)
	check(not prefs.motion and not prefs.sound,"both disabled preferences restore")
	check(prefs.save_motion(true),"motion can change without sound")
	var restored:=Preferences.new(path)
	check(restored.motion and not restored.sound,"motion change preserves persistent mute")
	var bytes:=FileAccess.get_file_as_string(path)
	var temp:=ProjectSettings.globalize_path(path+".tmp")
	check(DirAccess.make_dir_absolute(temp)==OK,"block cosmetic preference write")
	check(not prefs.save_sound(true) and not prefs.sound and prefs.motion,"failed sound preference does not change memory")
	check(FileAccess.get_file_as_string(path)==bytes,"failed sound preference preserves file")
	DirAccess.remove_absolute(temp)
	check(prefs.save_sound(true),"sound preference retries")
	restored=Preferences.new(path)
	check(restored.motion and restored.sound,"sound retry preserves motion")
func sound_review():
	var sound:=Sound.new();root.add_child(sound);await process_frame
	check(sound.voices.size()==6,"sound voice pool bounded")
	sound.set_context(0,true)
	check(sound.ambience.playing,"story sea ambience starts")
	sound.play("bridge")
	check(sound.events.count("bridge")==1,"known enabled cue recorded")
	sound._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(sound.suspended and not sound.ambience.playing,"pause stops ambience")
	var count:=sound.events.size();sound.play("win")
	check(sound.events.size()==count,"pause suppresses one-shot celebration")
	sound._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not sound.suspended and sound.ambience.playing,"resume restores ambience only")
	check(sound.events.size()==count,"resume does not replay queued cue")
	sound.set_enabled(false)
	check(not sound.ambience.playing,"mute stops ambience")
	sound.play("remove");check(sound.events.size()==count,"mute suppresses new cues")
	sound._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);sound._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not sound.ambience.playing,"focus resume does not override mute")
	sound.set_enabled(true);sound.set_context(3,true)
	check(sound.ambience.playing and sound._context==1,"restored harbor ambience can start after unmute")
	sound.set_context(3,false);check(not sound.ambience.playing,"leaving story stops ambience")
	await dispose(sound)
func landscape_review():
	var view:=Landscape.new();root.add_child(view);view.size=Vector2(320,300);view.revealed.connect(func():reveals+=1)
	view.set_motion_enabled(false);view.set_progress(3,2,true)
	check(view.target==3 and view.progress==3.0 and not view.is_processing(),"reduced motion reveals final art immediately without processing")
	check(reveals==1,"reduced motion still emits one restoration completion")
	view.set_progress(3,3,true)
	check(reveals==1,"no-change reveal emits no duplicate completion")
	view.set_progress(3)
	check(reveals==1,"map display emits no celebration")
	view.set_motion_enabled(true);view.set_progress(6,5,true);view.stop_reveal()
	await create_timer(1.6).timeout
	check(view.progress==6.0 and reveals==1,"cancelled reveal cannot emit stale completion")
	view.hide();check(not view.is_processing(),"hidden landscape stops decorative processing")
	await dispose(view)
func durable_review():
	var path:="user://igor-lighthouse-ui.json"
	clear_files(path);prepare_preferences(path,false,true)
	root.size=Vector2i(360,640);root.content_scale_size=Vector2i(360,640)
	var ui=await open_ui(path)
	ui._select_story(0);await settle()
	check(not ui.art_preferences.motion and ui.sound.enabled,"UI applies motion and sound independently")
	var before: Dictionary=ui.session.snapshot_data()
	var bytes:=FileAccess.get_file_as_string(path)
	var temp:=ProjectSettings.globalize_path(path+".tmp")
	ui.sound.events.clear();DirAccess.make_dir_absolute(temp)
	complete(ui);await settle()
	check(ui.save_failed and ui.session.snapshot_data()==before and FileAccess.get_file_as_string(path)==bytes,"winning write failure publishes no frontier or board")
	check(ui.sound.events.is_empty() and ui.screen=="game" and not ui.restoration_view.visible,"failed victory creates no cue or restoration")
	DirAccess.remove_absolute(temp);ui.quality_retry.pressed.emit();await settle()
	check(not ui.save_failed and ui.session.story.frontier==1 and ui.screen=="restoration","retry celebrates only durable first victory")
	check(ui.sound.events.count("win")==1 and not ui.board.input_enabled,"durable win sounds once and locks hidden board")
	check(ui.restoration_view.landscape.target==1 and ui.restoration_view.landscape.progress==1.0,"first visual improvement derives from durable frontier")
	# The interstitial speaker and help toggle share one durable preference.
	var sound_snapshot: Dictionary=ui.session.snapshot_data()
	ui.restoration_view.sound_button.pressed.emit()
	check(not ui.sound.enabled and not ui.sound_toggle.button_pressed and ui.restoration_view.sound_button.tooltip_text=="Activar sonidos","interstitial mute synchronizes manager and help toggle")
	check(not ui.sound.ambience.playing and not ui.art_preferences.motion and ui.session.snapshot_data()==sound_snapshot,"mute stops ambience without touching motion or domain")
	var appearance_temp:=ProjectSettings.globalize_path(path+".appearance.tmp")
	var appearance_bytes:=FileAccess.get_file_as_string(path+".appearance")
	check(DirAccess.make_dir_absolute(appearance_temp)==OK,"block interstitial preference write")
	ui.restoration_view.sound_button.pressed.emit()
	check(not ui.sound.enabled and not ui.sound_toggle.button_pressed and ui.restoration_view.sound_button.tooltip_text=="Activar sonidos" and FileAccess.get_file_as_string(path+".appearance")==appearance_bytes,"failed unmute keeps all controls and file synchronized")
	DirAccess.remove_absolute(appearance_temp)
	ui.restoration_view.sound_button.pressed.emit()
	check(ui.sound.enabled and ui.sound_toggle.button_pressed and ui.restoration_view.sound_button.tooltip_text=="Silenciar","speaker unmute retry synchronizes both views")
	check(ui.sound.events.count("win")==1 and ui.session.snapshot_data()==sound_snapshot,"preference retry cannot replay victory or alter progression")

	var snapshot: Dictionary=ui.session.snapshot_data()
	ui._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST);await settle()
	check(ui.screen=="story" and not ui.restoration_view.visible,"Android Back from interstitial opens map")
	check(ui.story_view.landscape.target==1 and ui.session.snapshot_data()==snapshot,"map shows committed improvement without domain mutation")
	ui._select_story(0);ui.sound.events.clear();ui._save_game();await settle()
	check(ui.sound.events.is_empty() and ui.screen=="game","reselecting solved board and passive save remain silent")
	# Restart/replay is allowed to sound a win, but never rebuilds an old improvement.
	ui._restart_current();await create_timer(.05).timeout
	var bridges:=solution(ui.board.puzzle)
	for edge in bridges:
		var ends:=str(edge).split(":")
		for n in int(bridges[edge]):ui.board._connect_islands(ends[0],ends[1])
	await settle()
	check(Rules.is_solved(ui.board.puzzle) and ui.session.story.frontier==1 and ui.screen=="game","replay cannot advance landscape or open restoration")
	await create_timer(.05).timeout;ui.sound.events.clear();ui.board.undo();await create_timer(.05).timeout;ui.board.redo();await settle()
	check(ui.sound.events.count("win")==1 and ui.session.story.frontier==1 and ui.screen=="game","Undo/Redo resolution may sound once without restoration or new progress")
	ui.sound.events.clear();ui._save_game();check(ui.sound.events.is_empty(),"passive save after replay remains silent")
	# A second new level tests Continue; the third tests pending-quality and milestone sound.
	ui._select_story(1);await create_timer(.05).timeout;complete(ui);await settle()
	check(ui.screen=="restoration" and ui.restoration_view.landscape.target==2,"second first-time victory shows second improvement")
	ui.restoration_view.next_button.pressed.emit();await settle()
	check(ui.screen=="game" and ui.session.story_ordinal()==2 and ui.session.story.frontier==2,"interstitial Continue selects next unlocked level")
	var serial: int=int(ui.session.quality.serial)+1
	var id: String=ui.board.puzzle.puzzle_id
	ui.session.quality.serial=serial;ui.session.quality.pending=[{"serial":serial,"id":id,"bridges":{},"iron":false}]
	check(ui.session.save_game(),"valid unresolved prefix fixture persisted")
	ui._update_status("");ui.sound.events.clear();complete(ui);await settle()
	check(ui.session.story.frontier==2 and ui.screen=="game" and ui.sound.events.count("win")==0 and not ui.restoration_view.visible,"complete board with unresolved quality does not celebrate")
	before=ui.session.snapshot_data();bytes=FileAccess.get_file_as_string(path);DirAccess.make_dir_absolute(temp)
	ui._accept_quality_verdict({"serial":serial,"status":"viable"});await settle()
	check(ui.save_failed and ui.session.snapshot_data()==before and FileAccess.get_file_as_string(path)==bytes,"failed quality verdict cannot publish victory")
	check(ui.sound.events.count("win")==0 and ui.sound.events.count("restore")==0 and ui.screen=="game","failed quality verdict remains silent")
	DirAccess.remove_absolute(temp);await create_timer(.05).timeout;ui.quality_retry.pressed.emit();await settle()
	check(ui.session.story.frontier==3 and ui.screen=="restoration","resolved durable quality triggers third restoration")
	check(ui.sound.events.count("win")==1 and ui.sound.events.count("restore")==1,"milestone cue works once even with reduced motion")
	ui.restoration_view.back_button.pressed.emit();await settle()
	check(ui.screen=="story" and ui.story_view.landscape.target==3,"interstitial map button opens correct durable landscape")
	ui._select_story(3);ui._show_help();ui.sound_toggle.set_pressed(false)
	check(not ui.sound.enabled and not ui.art_preferences.sound and not ui.art_preferences.motion,"UI mute does not re-enable motion")
	ui.home.motion_button.set_pressed(true)
	check(ui.art_preferences.motion and not ui.art_preferences.sound and not ui.sound.enabled,"UI motion change preserves mute")
	snapshot=ui.session.snapshot_data();await dispose(ui)
	ui=await open_ui(path)
	check(ui.session.snapshot_data()==snapshot and ui.sound.events.is_empty() and not ui.restoration_view.visible,"cold reopening restores domain without cue or interstitial")
	check(ui.art_preferences.motion and not ui.sound.enabled,"both cosmetic choices survive reopening")
	ui._show_story();check(ui.story_view.landscape.target==3,"reopened map derives same restoration")
	await dispose(ui)
func generation_race():
	var path:="user://igor-lighthouse-race.json"
	clear_files(path);prepare_preferences(path,false,true)
	var session:=Session.new(tutorials,path)
	for ordinal in 11:
		check(session.select_and_save(session.story_index(ordinal)),"unlock race introduction level")
		var puzzle:=session.current_puzzle();puzzle.bridges=solution(puzzle)
		check(session.capture_and_save(puzzle),"complete race fixture introduction")
	check(session.select_and_save(session.story_index(11)),"select final introduction before race")
	var ui=await open_ui(path);ui._continue_game();complete(ui)
	check(ui.session.story.frontier==12,"twelfth victory durable before deferred presentation")
	ui._select_story(12)
	var deadline:=Time.get_ticks_msec()+15000
	while ui.generation_task!=null and Time.get_ticks_msec()<deadline:await process_frame
	await settle()
	check(ui.generation_task==null and ui.session.story_ordinal()==12 and ui.screen=="game","next generated level survives stale deferred restoration")
	check(not ui.restoration_view.visible and Progress.progress(ui.session.story)==12,"cancelled presentation does not overwrite navigation")
	await create_timer(.05).timeout;ui.sound.events.clear();complete(ui);await settle()
	check(ui.session.story.frontier==13 and Progress.progress(ui.session.story)==12 and ui.screen=="game","continuation remains playable after lighthouse chapter is complete")
	check(not ui.restoration_view.visible and ui.sound.events.count("restore")==0,"beyond twelve there is no false extra restoration")
	await dispose(ui)
