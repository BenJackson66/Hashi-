class_name HashiStoryView
extends MarginContainer
signal selected(ordinal:int)
signal back_requested
signal help_requested
const Catalog=preload("res://scripts/hashi_story_catalog.gd")
const Story=preload("res://scripts/hashi_story_state.gd")
const Landscape=preload("res://scripts/hashi_landscape.gd")
const Progress=preload("res://scripts/hashi_landscape_progress.gd")
const Steps=preload("res://scripts/hashi_landscape_steps.gd")
var landscape:Landscape
var steps:Steps
var motion_enabled:=true
const Art=preload("res://scripts/hashi_art.gd")
var scroll:ScrollContainer
var content:VBoxContainer
var level_buttons:Array[Button]=[]
var message:Label
var follow_button:Button
var back_button:Button
var grid:GridContainer
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:add_theme_constant_override("margin_"+side,20)
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",20);scroll.add_child(content)
func refresh(state:Dictionary,_completed_ids:Array) -> void:
	for child in content.get_children():content.remove_child(child);child.queue_free()
	level_buttons.clear()
	var header:=HBoxContainer.new();content.add_child(header)
	back_button=_button("",func():back_requested.emit(),header);Art.symbol(back_button,"back","Inicio")
	var title:=Label.new();title.text="El faro";Art.heading(title,28);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;header.add_child(title)
	var help:=_button("",func():help_requested.emit(),header);Art.symbol(help,"menu","Ayuda de Historia")
	landscape=Landscape.new();landscape.custom_minimum_size=Vector2(200,290);content.add_child(landscape);landscape.set_motion_enabled(motion_enabled);landscape.set_progress(Progress.progress(state))
	steps=Steps.new();content.add_child(steps);steps.set_progress(Progress.progress(state))
	message=Label.new();message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(message)
	var current:=int(state.frontier)
	var follow_callback := func(): selected.emit(current)
	follow_button=_button(Progress.title(Progress.progress(state)),follow_callback);follow_button.tooltip_text="Jugar "+level_code(current);follow_button.name="FollowStory";follow_button.icon=Art.ICONS.play;follow_button.add_theme_constant_override("icon_max_width",24);Art.primary(follow_button)
	for ordinal in Catalog.COUNT:
		if ordinal % Catalog.STAGE_SIZE==0:
			var stage:=Label.new();stage.text=str(ordinal/Catalog.STAGE_SIZE+1);Art.heading(stage,26);content.add_child(stage)
			grid=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);content.add_child(grid)
		_level(ordinal,state)
	if current>=Catalog.COUNT:
		grid=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",8);content.add_child(grid)
		var keys:Array=state.recipes.keys();keys.sort_custom(func(a,b):return int(a)<int(b))
		for key in keys:_level(int(key),state)
func _level(ordinal:int,state:Dictionary) -> void:
	var locked:=ordinal>int(state.frontier)
	var callback := func(): selected.emit(ordinal)
	var button:=_button(level_code(ordinal),callback,grid)
	button.disabled=locked;button.custom_minimum_size=Vector2(60,56);button.add_theme_font_size_override("font_size",16)
	if ordinal<int(state.frontier):button.icon=Art.ICONS.check
	elif locked:button.icon=Art.ICONS.lock;button.set_meta("locked",true)
	button.add_theme_constant_override("icon_max_width",12)
	level_buttons.append(button)
static func level_code(ordinal:int) -> String:
	return "%d-%d" % [ordinal/Catalog.STAGE_SIZE+1,ordinal%Catalog.STAGE_SIZE+1]
func _button(text:String,callback:Callable,parent:Control=null) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size.y=56;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.pressed.connect(callback);(content if parent==null else parent).add_child(button);return button
func update_state(busy:bool,text:String) -> void:
	for button in level_buttons:button.disabled=busy or button.has_meta("locked")
	if follow_button!=null:follow_button.disabled=busy
	if message!=null:message.text=text;message.visible=not text.is_empty()
