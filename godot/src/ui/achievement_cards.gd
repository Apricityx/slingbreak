extends Control
## Grouped achievements slide over earnings; their age freezes behind dialogs.
var visuals: RefCounted
var pending: Array=[]
var current: Dictionary={}
var age:=0.0
var hold:=.76
var blocked:=false
var card: PanelContainer
var reduced:=false

func _ready() -> void:
	position=Vector2(10,818);size=Vector2(392,89);z_index=3;mouse_filter=Control.MOUSE_FILTER_IGNORE

func accept(event: Dictionary) -> void:
	if not current.is_empty() and current.arrow==event.arrow:
		current.items.append(event);current.bonus+=event.bonus;hold=maxf(hold,age+.52);_paint();return
	for group in pending:
		if group.arrow==event.arrow:group.items.append(event);group.bonus+=event.bonus;return
	pending.append({"arrow":event.arrow,"items":[event],"bonus":event.bonus})
	if pending.size()>32:pending.pop_front()

func _process(delta: float) -> void:
	if blocked:return
	if not current.is_empty():
		age+=delta*minf(2,1+pending.size()*.35)
		if age>=hold:
			current={}
			if card!=null:card.queue_free();card=null
	if current.is_empty() and not pending.is_empty():
		current=pending.pop_front();age=0;hold=.76;_paint()
	if card!=null and not reduced:
		var enter:=clampf(age/.18,0,1);var leave:=clampf((age-hold+.16)/.16,0,1)
		card.position.x=(1-pow(1-enter,3))*22-22+leave*30
		card.modulate.a=enter*(1-leave)

func clear() -> void:
	pending.clear();current={}
	if card!=null:card.queue_free();card=null

func _paint() -> void:
	if card!=null:remove_child(card);card.queue_free()
	var item:Dictionary=current.items.back();var accent:=Color(visuals.manifest.achievements[item.id].color)
	var light:Color=visuals.mix(accent,Color("#eaffb9"),.3)
	if current.bonus>=1 or current.items.size()>=3:light=Color("#ffe39a")
	card=PanelContainer.new();card.size=size;card.add_theme_stylebox_override("panel",visuals.box(visuals.mix(accent,Color("#1d281a"),.18),visuals.mix(light,Color("#34452b"),.6),9,12));add_child(card)
	var row:HBoxContainer=visuals.row(card,12)
	var mark:=PanelContainer.new();mark.custom_minimum_size=Vector2(56,56);mark.size_flags_vertical=Control.SIZE_SHRINK_CENTER;mark.add_theme_stylebox_override("panel",visuals.box(visuals.mix(accent,Color("#283822"),.25),light,13));row.add_child(mark)
	var center:=CenterContainer.new();mark.add_child(center);visuals.image(center,"achievement-"+item.id,light,Vector2(37,37))
	var words:VBoxContainer=visuals.column(row,2);words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;words.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var title:String=item.name if current.items.size()==1 else {2:"双重成就",3:"三重成就",4:"四重成就"}.get(current.items.size(),str(current.items.size())+" 重成就")
	var name_label:Label=visuals.text(words,title,22,"on-panel",true,true);name_label.add_theme_color_override("font_color",Color("#f2f9e8"))
	if current.items.size()>1:visuals.text(words," · ".join(current.items.map(func(entry):return entry.name)),11,"on-panel",false,true)
	var bonus:Label=visuals.text(row,"+%sx" % String.num(current.bonus,2),40,"on-panel",true);bonus.add_theme_color_override("font_color",light);bonus.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	visuals.pointer_through(self)
	if not reduced:preload("res://src/ui/motion.gd").pulse(mark,1.18)
