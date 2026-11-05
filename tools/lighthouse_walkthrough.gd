extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Solver=preload("res://scripts/hashi_solver.gd")
const OUTPUT="res://docs/review/lighthouse"
var failures:=0
func _initialize():call_deferred("run")
func check(value: bool,label: String):
 if not value:failures+=1;printerr("LIGHTHOUSE VISUAL FAIL: ",label)
func settle():
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
func work(ui):
 var deadline:=Time.get_ticks_msec()+20000
 while (ui.generation_task!=null or not ui.session.quality.pending.is_empty()) and Time.get_ticks_msec()<deadline:await process_frame
 check(ui.generation_task==null and ui.session.quality.pending.is_empty(),"bounded work")
 await settle()
func capture(ui,name: String,dim: Vector2i):
 await settle()
 if ui.screen=="restoration":
  for button in [ui.restoration_view.back_button,ui.restoration_view.next_button]:
   var rect:Rect2=button.get_global_rect()
   check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=dim.x and rect.end.y<=dim.y,name+" controls inside")
  check(ui.restoration_view.landscape.size.y>=240,name+" scene space")
 check(root.get_texture().get_image().save_png(OUTPUT+"/"+name+"-%d.png"%dim.x)==OK,"save capture")
func run():
 if DisplayServer.get_name()=="headless":quit(2);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 for dim in [Vector2i(360,640),Vector2i(480,800)]:
  root.size=dim;root.content_scale_size=dim
  var ui=Main.instantiate();ui.save_path="user://lighthouse-render-%d-%d.json"%[dim.x,Time.get_ticks_usec()];root.add_child(ui);await settle()
  ui.sound.set_enabled(false)
  ui._show_story();await capture(ui,"coast-before",dim)
  ui._select_story(0);await work(ui);ui._show_help();await settle();var help_scroll:ScrollContainer=ui.help_text.get_parent().get_parent();help_scroll.scroll_vertical=int(help_scroll.get_v_scroll_bar().max_value);await capture(ui,"sound-option",dim);ui._close_help()
  for ordinal in 12:
   ui._select_story(ordinal);await work(ui)
   var answer=Solver.new().solve(ui.board.puzzle)
   check(answer.status=="unique","real unique Story puzzle")
   for edge in answer.solutions[0]:
    var ids=str(edge).split(":")
    for n in int(answer.solutions[0][edge]):
     ui.board._connect_islands(ids[0],ids[1]);await work(ui)
   await work(ui)
   check(ui.screen=="restoration" and ui.session.story.frontier==ordinal+1,"durable win opens scene")
   ui.restoration_view.landscape.stop_reveal()
   await capture(ui,"restore-%02d"%(ordinal+1),dim)
   if ordinal<11:ui.restoration_view.next_button.pressed.emit();await work(ui)
  ui.restoration_view.back_button.pressed.emit();await capture(ui,"coast-after",dim)
  ui.queue_free();await process_frame
 print("LIGHTHOUSE RENDER: ",failures," failures; renderer=",RenderingServer.get_video_adapter_name())
 quit(1 if failures else 0)
