class_name HashiLandscape
extends Control
## Original SVG layers keep art crisp and each restoration independently visible.
const COAST=preload("res://assets/landscape/coast.svg")
const LAYERS=[preload("res://assets/landscape/pilings.svg"),preload("res://assets/landscape/deck.svg"),preload("res://assets/landscape/boat.svg"),preload("res://assets/landscape/trail.svg"),preload("res://assets/landscape/footbridge.svg"),preload("res://assets/landscape/flowers.svg"),preload("res://assets/landscape/roof.svg"),preload("res://assets/landscape/windows.svg"),preload("res://assets/landscape/garden.svg"),preload("res://assets/landscape/tower.svg"),preload("res://assets/landscape/lantern.svg"),preload("res://assets/landscape/light.svg")]
signal revealed
var progress := 0.0
var target := 0
var motion_enabled := true
var _tween: Tween
var _clock := 0.0
var _redraw := 0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=custom_minimum_size.max(Vector2(200,240))
	resized.connect(queue_redraw)
	visibility_changed.connect(_refresh_processing)
	_refresh_processing()
func set_progress(value: int, from: int = -1, animate: bool = false) -> void:
	if _tween!=null:_tween.kill();_tween=null
	target=clampi(value,0,12)
	progress=float(clampi(from,0,target)) if animate and motion_enabled and from>=0 else float(target)
	queue_redraw()
	if animate and motion_enabled and progress<float(target):
		_tween=create_tween()
		_tween.tween_method(_set_progress,progress,float(target),minf(3.0,1.25+0.1*(target-progress))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_callback(func():revealed.emit())
	elif animate and from>=0 and target>from:
		revealed.emit()
	_refresh_processing()
func _set_progress(value: float) -> void:
	progress=value;queue_redraw()
func set_motion_enabled(value: bool) -> void:
	motion_enabled=value
	if not value:
		if _tween!=null:_tween.kill();_tween=null
		progress=float(target);queue_redraw()
	_refresh_processing()
func stop_reveal() -> void:
	if _tween!=null:_tween.kill();_tween=null
	progress=float(target);queue_redraw()
func _refresh_processing() -> void:
	set_process(motion_enabled and is_visible_in_tree())
func _process(delta: float) -> void:
	_clock+=delta;_redraw+=delta
	if _redraw>=.05:_redraw=0.0;queue_redraw()
func artwork_rect() -> Rect2:
	var scale_value:=minf(size.x/800.0,size.y/760.0)
	var extent:=Vector2(800,760)*scale_value
	return Rect2((size-extent)/2.0,extent)
func _draw() -> void:
	var rect:=artwork_rect()
	draw_texture_rect(COAST,rect,false)
	for i in LAYERS.size():
		var amount:=clampf(progress-float(i),0.0,1.0)
		if amount<=0:continue
		var placed:=rect
		if i==2 and motion_enabled:placed.position.y+=sin(_clock*1.1)*rect.size.y/380.0
		draw_texture_rect(LAYERS[i],placed,false,Color(1,1,1,amount))
	if progress>=12 and motion_enabled:
		var center:=rect.position+Vector2(594.0/800.0,242.0/760.0)*rect.size
		draw_circle(center,rect.size.x*.018,Color(1,.91,.65,.08+.06*sin(_clock*.8)))
