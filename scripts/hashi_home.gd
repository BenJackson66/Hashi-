extends MarginContainer
signal story_requested
signal continue_requested
signal new_requested
signal lesson_requested(index: int)
signal confirm_requested
signal cancel_requested
signal profile_requested(profile: String)
signal mode_requested(mode: String, profile: String)
signal page_changed
signal motion_requested(enabled: bool)
const Art = preload("res://scripts/hashi_art.gd")
var story_button: Button
var modes_button: Button
var iron_button: Button
var fixed_button: Button
var progression_button: Button
var challenge: OptionButton
var scroll: ScrollContainer
var page := "home"
var pages: Dictionary = {}
var continue_button: Button
var new_button: Button
var learn_button: Button
var rules_button: Button
var rules_back_button: Button
var learn_back_button: Button
var lesson_buttons: Array[Button] = []
var confirm_button: Button
var cancel_button: Button
var notice: Label
var motion_button: CheckButton
var hero: VBoxContainer
var content: VBoxContainer
func build(catalog: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top","right","bottom"]:
		add_theme_constant_override("margin_"+side,24)
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",18);scroll.add_child(content)
	hero=VBoxContainer.new();hero.add_theme_constant_override("separation",14);content.add_child(hero)
	var mark:=TextureRect.new();mark.texture=Art.MARK;mark.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;mark.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;mark.custom_minimum_size=Vector2(96,96);hero.add_child(mark)
	var title:=_label("HASHI",hero,42);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;Art.heading(title,42)
	for name in ["home","modes","learn","rules","confirm"]:
		var column:=VBoxContainer.new();column.add_theme_constant_override("separation",16);content.add_child(column);pages[name]=column
	story_button=_button("Historia",pages.home,func():story_requested.emit());story_button.icon=Art.ICONS.book;story_button.add_theme_constant_override("icon_max_width",28);Art.primary(story_button)
	modes_button=_button("Modos",pages.home,func():show_page("modes"));modes_button.icon=Art.ICONS.modes;modes_button.add_theme_constant_override("icon_max_width",28)
	continue_button=_button("",pages.home,func():continue_requested.emit());Art.symbol(continue_button,"play","Continuar partida")
	var header:=HBoxContainer.new();pages.modes.add_child(header)
	var back:=_button("",header,func():show_page("home"));Art.symbol(back,"back","Inicio")
	var title_modes:=_label("Modos",header,26);title_modes.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title_modes.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	rules_button=_button("",header,func():show_page("rules"));Art.symbol(rules_button,"menu","Cómo jugar")
	challenge=OptionButton.new();challenge.custom_minimum_size.y=52;challenge.add_item("Directo");challenge.add_item("Reflexivo");challenge.item_selected.connect(func(index:int):profile_requested.emit("local" if index==0 else "contradiction1"));pages.modes.add_child(challenge)
	new_button=_button("Libre",pages.modes,func():new_requested.emit())
	fixed_button=_button("Dificultad fija",pages.modes,func():mode_requested.emit("fixed","local" if challenge.selected==0 else "contradiction1"))
	progression_button=_button("Progresión",pages.modes,func():mode_requested.emit("progression","local"))
	iron_button=_button("Alma de Hierro",pages.modes,func():mode_requested.emit("iron","local" if challenge.selected==0 else "contradiction1"))
	_label("Cómo jugar",pages.rules,28)
	_label("Conecta todas las islas en una sola red. Cada número indica cuántos puentes necesita esa isla. Entre dos islas caben hasta dos puentes. No pueden cruzarse ni pasar sobre otras islas.\n\nToca dos islas o desliza entre ellas: 0 → 1 → 2 → 0. Las S alternan 0 → 1 → 0. Cruza un puente con el dedo para borrarlo.\n\nS: solo puentes simples. ?: isla sin número.\n\nLa ayuda y las reglas de cada modo están en su botón de tres líneas.",pages.rules,17)
	learn_button=_button("Aprender",pages.rules,func():show_page("learn"))
	motion_button=CheckButton.new();motion_button.text="Animaciones suaves";motion_button.custom_minimum_size.y=52;motion_button.toggled.connect(func(enabled:bool):motion_requested.emit(enabled));pages.rules.add_child(motion_button)
	rules_back_button=_button("",pages.rules,func():show_page("modes"));Art.symbol(rules_back_button,"back","Volver")
	_label("Aprender",pages.learn,28)
	for i in catalog.size():
		var index:=i;lesson_buttons.append(_button(str(i+1),pages.learn,func():lesson_requested.emit(index)))
	learn_back_button=_button("",pages.learn,func():show_page("home"));Art.symbol(learn_back_button,"back","Inicio")
	_label("¿Empezar otra partida?",pages.confirm,26)
	_label("Este tablero aún no está terminado.",pages.confirm,17)
	var choices:=HBoxContainer.new();choices.alignment=BoxContainer.ALIGNMENT_CENTER;pages.confirm.add_child(choices)
	cancel_button=_button("",choices,func():cancel_requested.emit());Art.symbol(cancel_button,"back","Conservar partida")
	confirm_button=_button("",choices,func():confirm_requested.emit());Art.symbol(confirm_button,"play","Empezar otra partida");Art.primary(confirm_button)
	notice=_label("",content,15);notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	resized.connect(_fit);_fit();show_page("home")
func _fit() -> void:
	if content!=null:content.custom_minimum_size.y=maxf(0,size.y-48)
func show_page(value:String) -> void:
	if not pages.has(value):return
	page=value;hero.visible=value=="home";content.alignment=BoxContainer.ALIGNMENT_CENTER if value=="home" else BoxContainer.ALIGNMENT_BEGIN
	scroll.set_deferred("scroll_vertical",0)
	for name in pages:pages[name].visible=name==value
	page_changed.emit()
func update_state(can_continue:bool,busy:bool,message:String,selection_blocked:bool=false) -> void:
	continue_button.visible=can_continue;continue_button.disabled=not can_continue
	for button in [new_button,fixed_button,progression_button,iron_button]:button.disabled=busy
	challenge.disabled=busy
	for lesson in lesson_buttons:lesson.disabled=selection_blocked
	notice.text=message;notice.visible=not message.is_empty()
func _label(text:String,parent:Control,font_size:int=18) -> Label:
	var label:=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.add_theme_font_size_override("font_size",font_size);parent.add_child(label)
	if font_size>=24:Art.heading(label,font_size)
	return label
func _button(text:String,parent:Control,callback:Callable) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size.y=64;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.add_theme_font_size_override("font_size",20);button.pressed.connect(callback);parent.add_child(button);return button
