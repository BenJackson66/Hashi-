extends SceneTree
const Board = preload("res://scripts/hashi_board.gd")
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
var checks:=0
var failures:=0
var board: Board
var mutations:=0
var last_kind:=""
func _initialize():call_deferred("run")
func check(value: bool,label: String):
	checks+=1
	if not value:
		failures+=1
		printerr("IGOR TOUCH FAIL: ",label)
func fixture(bridges: Dictionary) -> void:
	var islands: Array=[]
	for row in 5:
		for col in 5:
			islands.append({"id":"i%d%d" % [col,row],"x":col,"y":row,"target":2,"variant":"classic","color":"neutral"})
	board.set_puzzle(Puzzle.new({"id":"touch-grid","title":"touch-grid","islands":islands}))
	board.puzzle.bridges=bridges.duplicate(true)
	board._layout_islands()
	mutations=0;last_kind=""
func touch(point: Vector2,pressed: bool,index: int=0,canceled: bool=false):
	var event:=InputEventScreenTouch.new();event.position=point;event.index=index;event.pressed=pressed;event.canceled=canceled;board._gui_input(event)
func drag(point: Vector2,index: int=0):
	var event:=InputEventScreenDrag.new();event.position=point;event.index=index;board._gui_input(event)
func stroke(points: Array):
	touch(points[0],true)
	for i in range(1,points.size()-1):drag(points[i])
	touch(points[-1],false)
func mouse(point: Vector2,pressed: bool,device: int=0):
	var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.device=device;board._gui_input(event)
func run():
	root.size=Vector2i(240,240)
	board=Board.new();root.add_child(board);board.size=Vector2(240,240);board.set_motion_enabled(false)
	board.puzzle_changed.connect(func():mutations+=1;last_kind=board.last_action.kind)
	await process_frame
	var edge:="i11:i21"
	fixture({edge:1})
	var a: Vector2=board.centers.i11
	var b: Vector2=board.centers.i21
	var mid: Vector2=(a+b)/2
	var upper:=mid+Vector2(-3,-20)
	var lower:=mid+Vector2(3,20)
	check(board._core_hit(upper).is_empty() and board._core_hit(lower).is_empty(),"dense sweep starts outside visual cores")
	stroke([upper,lower])
	check(board.puzzle.bridges.is_empty() and mutations==1 and last_kind=="cut","dense perpendicular sweep cuts instead of accidental connection")
	fixture({edge:2});stroke([upper,mid,lower])
	check(board.puzzle.bridges.is_empty() and mutations==1,"double bridge costs one mutation and landing exactly on line still crosses")
	fixture({edge:1});stroke([mid+Vector2(-15,-15),mid,mid+Vector2(15,-15)])
	check(board.puzzle.bridges.get(edge,0)>=1 and last_kind!="cut","tangent touching line never causes a cut or withdrawal")
	fixture({edge:1});stroke([mid+Vector2(-15,0),mid+Vector2(15,0)])
	check(board.puzzle.bridges.get(edge,0)>=1 and last_kind!="cut","collinear drag never causes a cut or withdrawal")
	fixture({edge:1});touch(mid,true);touch(mid,false)
	check(board.puzzle.bridges.has(edge) and mutations==0,"tap bridge is free")
	fixture({edge:1});touch(upper,true);drag(lower);touch(lower,false,0,true)
	check(board.puzzle.bridges.has(edge) and mutations==0,"cancel discards accumulated crossing")
	fixture({edge:1});touch(upper,true);drag(lower);board.cancel_gesture();touch(lower,false)
	check(board.puzzle.bridges.has(edge) and mutations==0,"navigation cancellation discards accumulated crossing")
	fixture({edge:1});touch(upper,true,0);touch(lower,true,1);drag(lower,1);touch(lower,false,1)
	check(board.puzzle.bridges.has(edge) and mutations==0,"secondary finger cannot cut or release primary")
	drag(lower,0);touch(lower,false,0)
	check(board.puzzle.bridges.is_empty() and mutations==1,"primary finger still commits exactly once")
	fixture({edge:1});mouse(upper,true);var motion:=InputEventMouseMotion.new();motion.position=lower;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;board._gui_input(motion);mouse(lower,false)
	check(board.puzzle.bridges.is_empty() and mutations==1,"mouse stroke uses same cut policy")
	fixture({edge:1});mouse(upper,true,-1);mouse(lower,false,-1)
	check(board.puzzle.bridges.has(edge) and mutations==0,"synthetic mouse duplicate cannot cut")
	fixture({edge:1});stroke([a,b])
	check(board.puzzle.bridges.get(edge)==2 and mutations==1 and last_kind=="move","center-to-center connection has priority")
	fixture({edge:1});stroke([board.centers.i01,board.centers.i31])
	check(board.puzzle.bridges=={edge:1} and mutations==0,"rejected island connection never falls back to cut")
	fixture({edge:1});stroke([a+Vector2(10,-20),a+Vector2(10,20)])
	check(board.puzzle.bridges.has(edge) and mutations==0,"near-endpoint visual core protects bridge")
	# A single actual stroke crosses two interior bridges on a dense grid.
	var second:="i12:i22"
	fixture({edge:1,second:2})
	var second_mid: Vector2=(board.centers.i12+board.centers.i22)/2
	stroke([upper,second_mid+Vector2(3,20)])
	check(board.puzzle.bridges.is_empty() and mutations==1 and last_kind=="cut","dense multi-edge sweep removes all crossed bridges once")
	# Repeated tremor crosses the line but never leaves a small local neighborhood.
	fixture({edge:1})
	var jitter_start:=mid+Vector2(0,-2)
	touch(jitter_start,true)
	for i in 20:
		drag(mid+Vector2(0,2 if i%2==0 else -2))
	touch(jitter_start,false)
	check(board.puzzle.bridges=={edge:1} and mutations==0,"repeated two-pixel jitter cannot accumulate into a paid cut")
	# A deliberate loop exceeds the excursion threshold even if it ends at its origin.
	fixture({edge:1})
	stroke([upper,lower,upper])
	check(board.puzzle.bridges.is_empty() and mutations==1 and last_kind=="cut","wide crossing loop cuts once despite returning to its origin")
	# A tiny movement across the nearest-island boundary must stay anchored to its origin.
	fixture({edge:2})
	stroke([mid+Vector2(-1,0),mid+Vector2(1,0)])
	check(board.puzzle.bridges=={edge:2} and mutations==0,"outside-core midpoint jitter cannot cycle a double bridge")
	fixture({edge:2})
	stroke([a+Vector2(board.radius-1,0),mid+Vector2(1,0)])
	check(board.puzzle.bridges=={edge:2} and mutations==0,"small slip from core edge across midpoint cannot withdraw a double bridge")
	print("IGOR COZY TOUCH REVIEW: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
