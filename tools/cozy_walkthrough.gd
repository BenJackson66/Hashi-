extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Solver=preload("res://scripts/hashi_solver.gd")
const OUTPUT="res://docs/review/cozy"
var failures:=0
func _initialize():call_deferred("run")
func check(value:bool,label:String):
 if not value:failures+=1;printerr("COZY VISUAL FAIL: ",label)
func settle():
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
func work(ui):
 var limit:=Time.get_ticks_msec()+15000
 while (ui.generation_task!=null or not ui.session.quality.pending.is_empty()) and Time.get_ticks_msec()<limit:await process_frame
 check(ui.generation_task==null and ui.session.quality.pending.is_empty(),"bounded work")
func capture(ui,name:String,dim:Vector2i):
 await create_timer(0.75).timeout
 await settle()
 if ui.screen=="game" and not ui.help_view.visible:
  check(ui.board.size.y>=300,name+" large board")
  check(absf(ui.level_label.get_global_rect().get_center().x-dim.x/2.0)<1,name+" centered level")
  for button in [ui.home_button,ui.help_button,ui.undo_button,ui.redo_button,ui.restart_button,ui.next_button]:
   var rect:Rect2=button.get_global_rect()
   check(rect.size.x>=48 and rect.size.y>=48,name+" touch target")
   check(rect.end.x<=dim.x and rect.end.y<=dim.y,name+" inside viewport")
  check(not ui.gesture_hint.visible and not ui.mode_status.visible and not ui.quality_status.visible,"no prose in play")
 check(root.get_texture().get_image().save_png(OUTPUT+"/"+name+"-%d.png"%dim.x)==OK,"capture")
func touch(board,point:Vector2,pressed:bool):
 var event:=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=pressed;board._gui_input(event)
func run():
 if DisplayServer.get_name()=="headless":quit(2);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 for dim in [Vector2i(360,640),Vector2i(480,800)]:
  root.size=dim;root.content_scale_size=dim
  var ui=Main.instantiate();ui.save_path="user://cozy-render-%d-%d.json"%[dim.x,Time.get_ticks_usec()];root.add_child(ui);await settle()
  await capture(ui,"home",dim)
  ui.home.modes_button.pressed.emit();await capture(ui,"modes",dim)
  ui._show_story();await capture(ui,"map",dim)
  ui._select_story(0);await work(ui);await capture(ui,"story",dim)
  check(ui.level_label.text=="1-1" and ui.attempt_count.text=="3","initial story counter")
  ui._show_help();await capture(ui,"story-help",dim);ui._close_help()
  ui.board._layout_islands()
  var result:=Solver.new().solve(ui.board.puzzle)
  check(result.status=="unique","real story puzzle")
  var chosen:="";var start:=Vector2.ZERO;var end:=Vector2.ZERO
  for edge in result.solutions[0]:
   var ids:PackedStringArray=str(edge).split(":");var a:Vector2=ui.board.centers[ids[0]];var b:Vector2=ui.board.centers[ids[1]]
   if a.distance_to(b)<90:continue
   var mid:Vector2=(a+b)/2;var normal:Vector2=(b-a).normalized().orthogonal()
   for offset in [24,32,40,52]:
    var one:Vector2=mid+normal*offset;var two:Vector2=mid-normal*offset
    if ui.board._core_hit(one).is_empty() and ui.board._core_hit(two).is_empty():chosen=str(edge);start=one;end=two;break
   if not chosen.is_empty():break
  check(not chosen.is_empty(),"cut fixture visible gap")
  if chosen.is_empty():quit(1);return
  var endpoints:PackedStringArray=chosen.split(":")
  ui.board._connect_islands(endpoints[0],endpoints[1]);await work(ui)
  touch(ui.board,start,true);touch(ui.board,end,false);await work(ui)
  check(not ui.board.puzzle.bridges.has(chosen) and ui.session.story_corrections_left()==2,"real cut costs one")
  await capture(ui,"story-cut",dim)
  for i in 2:
   ui.board._connect_islands(endpoints[0],endpoints[1]);await work(ui);ui.board.undo();await work(ui)
  check(ui.session.story_lost() and not ui.board.input_enabled,"three corrections lose attempt")
  await capture(ui,"story-lost",dim)
  ui.restart_button.pressed.emit();check(ui.session.story_corrections_left()==3 and ui.board.puzzle.bridges.is_empty(),"retry restores attempts")
  await capture(ui,"story-retry",dim)
  ui.board.puzzle.bridges=result.solutions[0].duplicate(true);ui._save_game();await work(ui);await capture(ui,"story-win",dim)
  ui._next_puzzle();await work(ui);check(ui.level_label.text=="1-2","next centered code");await capture(ui,"story-next",dim)
  ui._show_home();await capture(ui,"home-continue",dim)
  ui.home.show_page("modes");ui.home.new_button.pressed.emit();await work(ui);await capture(ui,"free-game",dim)
  ui._show_help();await capture(ui,"free-help",dim);ui._close_help()
  ui._show_home();ui.home.show_page("modes");ui.home.iron_button.pressed.emit();await work(ui);await capture(ui,"iron-game",dim)
  ui.queue_free();await process_frame
 print("COZY RENDER: ",failures," failures; renderer=",RenderingServer.get_video_adapter_name())
 quit(1 if failures else 0)
