extends Control
## Grouped achievements slide over earnings; their age freezes behind dialogs.
const Motion=preload("res://src/ui/motion.gd")
const Easing=preload("res://src/ui/easing.gd")
const Slot=preload("res://src/ui/motion_slot.gd")
var visuals: RefCounted
var pending: Array=[]
var current: Dictionary={}
var age:=0.0
var hold:=.76
var blocked:=false
var card: PanelContainer
var reduced:=false
var nodes:Dictionary={}
var display_bonus:=0.0
var leaving_at:=-1.0
var leave_alpha:=1.0
var leave_x:=0.0
var leave_y:=0.0
var leave_scale:=Vector2.ONE
var entry_age:=0.0
var entry_position:=Vector2(0,10)
var entry_scale:=Vector2.ONE*.88
var entry_alpha:=0.0

func _ready() -> void:
	position=Vector2(10,818);size=Vector2(392,89);z_index=3;mouse_filter=Control.MOUSE_FILTER_IGNORE

func accept(event: Dictionary) -> void:
	if not current.is_empty() and current.arrow==event.arrow:
		if leaving_at>=0 and card!=null:
			entry_position=card.position;entry_scale=card.scale;entry_alpha=card.modulate.a;entry_age=0.0;leaving_at=-1.0
		current.items.append(event);current.bonus+=event.bonus;hold=maxf(hold,age+.52);_paint();return
	for group in pending:
		if group.arrow==event.arrow:group.items.append(event);group.bonus+=event.bonus;return
	pending.append({"arrow":event.arrow,"items":[event],"bonus":event.bonus})
	if pending.size()>32:pending.pop_front()

func _process(delta: float) -> void:
	if blocked:
		_set_motion_paused(true)
		return
	_set_motion_paused(false)
	if not current.is_empty():
		age+=delta*minf(2,1+pending.size()*.35)
		if age>=hold:
			current={}
			if card!=null:card.queue_free();card=null;nodes.clear()
			leaving_at=-1.0
	if current.is_empty() and not pending.is_empty():
		current=pending.pop_front();age=0;hold=.76;_paint()
	if card==null:return
	var leaving:=age>=hold-.16
	if reduced:
		card.position=Vector2.ZERO;card.scale=Vector2.ONE;card.modulate.a=1.0
		Motion.stop(nodes.mark);nodes.mark.scale=Vector2.ONE;nodes.mark.set_meta("paused_motion",[])
	elif leaving:
		if leaving_at<0:leaving_at=age;leave_alpha=card.modulate.a;leave_x=card.position.x;leave_y=card.position.y;leave_scale=card.scale
		var p:=clampf((age-leaving_at)/maxf(.001,hold-leaving_at),0,1)
		var ease:=p*p*(3-2*p)
		card.position.x=lerpf(leave_x,30.0,ease);card.modulate.a=leave_alpha*(1-ease)
		card.position.y=lerpf(leave_y,-4.0,ease);card.scale=leave_scale.lerp(Vector2.ONE*.985,ease)
	else:
		leaving_at=-1.0
		entry_age+=delta
		var p:=clampf(entry_age/.42,0,1)
		var spring:=Easing.bezier(p,.2,1.35,.4,1)
		card.position=entry_position.lerp(Vector2.ZERO,spring);card.scale=entry_scale.lerp(Vector2.ONE,spring)
		card.modulate.a=lerpf(entry_alpha,1.0,Easing.bezier(clampf(entry_age/.24,0,1),.22,1,.36,1))
	display_bonus=lerpf(display_bonus,float(current.bonus),1-exp(-delta*20)) if not reduced else float(current.bonus)
	if absf(display_bonus-float(current.bonus))<.005:display_bonus=current.bonus
	nodes.bonus.text="+%sx" % String.num(display_bonus,2)

func _set_motion_paused(value:bool) -> void:
	if nodes.is_empty():return
	var mark:Control=nodes.mark
	var paused:Array=mark.get_meta("paused_motion",[])
	if value:
		for property in ["scale","alpha"]:
			var key:String="motion_"+property
			var tween:Tween=mark.get_meta(key) if mark.has_meta(key) else null
			if tween!=null and tween.is_valid() and tween.is_running():
				tween.pause();paused.append(tween)
	else:
		for tween in paused:
			if tween.is_valid():tween.play()
		paused.clear()
	mark.set_meta("paused_motion",paused)

func clear() -> void:
	pending.clear();current={}
	if card!=null:card.queue_free();card=null
	nodes.clear()
	leaving_at=-1.0

func _paint() -> void:
	var item:Dictionary=current.items.back();var accent:=Color(visuals.manifest.achievements[item.id].color)
	var light:Color=visuals.mix(accent,Color("#eaffb9"),.3)
	if current.bonus>=1 or current.items.size()>=3:light=Color("#ffe39a")
	if card==null:
		card=PanelContainer.new();card.size=size;add_child(card)
		card.position=Vector2(0,10 if not reduced else 0);card.modulate.a=0 if not reduced else 1
		card.pivot_offset=size/2;card.scale=Vector2.ONE*.88 if not reduced else Vector2.ONE
		entry_age=0.0;entry_position=card.position;entry_scale=card.scale;entry_alpha=card.modulate.a
		var row:HBoxContainer=visuals.row(card,12)
		var holder:=Slot.new();holder.size_flags_vertical=Control.SIZE_SHRINK_CENTER;row.add_child(holder)
		var mark:=PanelContainer.new();mark.custom_minimum_size=Vector2(56,56);holder.adopt(mark);nodes.mark=mark
		var center:=CenterContainer.new();mark.add_child(center);nodes.icon=visuals.image(center,"achievement-"+item.id,light,Vector2(37,37))
		var words:VBoxContainer=visuals.column(row,2);words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;words.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		nodes.title=visuals.text(words,"",22,"on-panel",true,true);nodes.title.add_theme_color_override("font_color",Color("#f2f9e8"))
		nodes.names=visuals.text(words,"",11,"on-panel",false,true)
		nodes.bonus=visuals.text(row,"",40,"on-panel",true);nodes.bonus.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		display_bonus=current.bonus
	card.add_theme_stylebox_override("panel",visuals.box(visuals.mix(accent,Color("#1d281a"),.18),visuals.mix(light,Color("#34452b"),.6),9,12))
	nodes.mark.add_theme_stylebox_override("panel",visuals.box(visuals.mix(accent,Color("#283822"),.25),light,13))
	nodes.icon.texture=visuals.icon("achievement-"+item.id,light)
	var title:String=item.name if current.items.size()==1 else {2:"双重成就",3:"三重成就",4:"四重成就"}.get(current.items.size(),str(current.items.size())+" 重成就")
	nodes.title.text=title
	nodes.names.visible=current.items.size()>1;nodes.names.text=" · ".join(current.items.map(func(entry):return entry.name))
	nodes.bonus.text="+%sx" % String.num(display_bonus,2);nodes.bonus.add_theme_color_override("font_color",light)
	visuals.pointer_through(self)
	if not reduced:Motion.pulse.call_deferred(nodes.mark,1.18)
