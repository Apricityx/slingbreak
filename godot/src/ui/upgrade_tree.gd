extends Control
## A retained astrolabe: seven asymmetric constellations per chapter, with a
## separate endless orbit. Only confirmed session transactions create effects.
const Icons=preload("res://src/ui/upgrade_icons.gd")
const FX=preload("res://src/ui/upgrade_tree_fx.gd")
const INKS:=[Color("#8ad7c3"),Color("#abcfff"),Color("#efcd8f")]
const PAPER:=Color("#e8eee9")
const MUTED:=Color("#8eaaa9")
const GOLD:=Color("#dfbf82")
const POSITIONS:={"power":Vector2(.18,.23),"arrow":Vector2(.50,.06),"brick":Vector2(.82,.29),"draw":Vector2(.18,.64),"comboCap":Vector2(.82,.64),"slots":Vector2(.43,.90),"rerollCap":Vector2(.81,.96)}
const CHAPTERS:=["启程","精铸","传奇","无尽"]
var ui:Control
var v:RefCounted
var frame:Dictionary={}
var items:Dictionary={}
var buttons:Dictionary={}
var selected:="power_1"
var graph:Control
var buy:Button
var feedback:Label
var close:Button
var effects:Control
var stages:Array[Button]=[]
var elapsed:=0.0
var note_until:=0.0
var pulses:Dictionary={}
var detail_signature:=""
var shown_stage:=0

func setup(owner:Control) -> void:
	ui=owner;v=ui.visuals;name="UpgradeTree";custom_minimum_size.y=ui.content_height-ui.content_top;size_flags_horizontal=SIZE_EXPAND_FILL
	graph=Control.new();graph.name="TreeGraph";graph.mouse_filter=MOUSE_FILTER_PASS;add_child(graph)
	graph.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	graph.draw.connect(_draw_graph);resized.connect(_layout)
	effects=FX.new();effects.name="UpgradeEffects";effects.z_index=2;graph.add_child(effects)
	for index in range(4):
		var stage:Button=v.button(self,["Ⅰ  启程","Ⅱ  精铸","Ⅲ  传奇","∞  无尽"][index],_show_stage.bind(index),"",44)
		for state in ["normal","hover","pressed","focus"]:stage.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		stage.add_theme_font_size_override("font_size",12);stages.append(stage)
		stage.focus_entered.connect(graph.queue_redraw);stage.focus_exited.connect(graph.queue_redraw)
	close=v.button(self,"",ui._close,"x",44);close.name="CloseTree";close.tooltip_text="返回游戏";close.icon=v.icon("x",MUTED)
	for state in ["normal","hover","pressed"]:close.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	close.add_theme_stylebox_override("focus",v.box(Color.TRANSPARENT,Color(MUTED,.4),22))
	buy=v.button(self,"",_purchase,"",46);buy.add_theme_font_size_override("font_size",13)
	for state in ["font_color","font_hover_color","font_pressed_color"]:buy.add_theme_color_override(state,PAPER)
	buy.add_theme_color_override("font_disabled_color",MUTED)
	buy.add_theme_stylebox_override("disabled",v.box(Color("#16272d"),Color("#34474c"),24,8))
	buy.add_theme_stylebox_override("focus",v.box(Color.TRANSPARENT,PAPER,24,8))
	feedback=v.text(self,"",10,"text-3",false,true);feedback.custom_minimum_size.y=18
	feedback.add_theme_color_override("font_color",MUTED);feedback.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	refresh(owner.frame)
	# Reopening follows the player's journey, never lands on a fully spent page.
	var initial:=3 if frame.masteryUnlocked else 0
	if initial!=3:
		for item in items.values():
			if not item.infinite and item.available:initial=item.tier-1;break
	_show_stage(initial,false)

func _process(delta:float) -> void:
	elapsed+=delta
	for id in pulses.keys():
		buttons[id].queue_redraw()
		if effects.clock-float(pulses[id])>.6:pulses.erase(id)
	if note_until>0 and elapsed>=note_until:note_until=0;_resting_note()

func _resting_note() -> void:
	feedback.text="无限阶位 · 每 10 阶触发星耀" if shown_stage==3 and frame.masteryUnlocked else "点满 21 个基础节点，开启无尽星环" if shown_stage==3 else "点击星点查看提升 · 金币铸造永久成长"

func _point(item:Dictionary) -> Vector2:
	if item.infinite:
		var point:Vector2={"arrow":Vector2(.50,.16),"brick":Vector2(.78,.79),"comboCap":Vector2(.22,.79)}[item.key]
		return _map_point(point)
	var point:Vector2=POSITIONS[item.key]
	return _map_point(point)

func _map_point(point:Vector2) -> Vector2:return Vector2(graph.size.x*point.x,145+point.y*(graph.size.y-420))
func _center() -> Vector2:return _map_point(Vector2(.48,.48))

func _layout() -> void:
	if effects==null:return
	graph.size=size
	effects.size=graph.size
	for id in buttons:buttons[id].position=_point(items[id])-Vector2(50,42)
	for index in range(4):stages[index].position=Vector2(20+index*(size.x-40)/4,87);stages[index].size=Vector2((size.x-40)/4,44)
	close.position=Vector2(size.x-55,19);close.size=Vector2(44,44)
	buy.position=Vector2(24,size.y-81);buy.size=Vector2(size.x-48,46)
	feedback.position=Vector2(20,size.y-26);feedback.size=Vector2(size.x-40,18)
	graph.queue_redraw()

func _show_stage(index:int,sound:bool=true) -> void:
	shown_stage=index
	if sound:ui.action.emit("cue",{"type":"tap","ui":true})
	if not items.has(selected) or items[selected].tier!=index+1:
		var candidates:Array=items.values().filter(func(n):return n.tier==index+1)
		selected=candidates[0].id
		for item in candidates:
			if item.available:selected=item.id;break
	effects.reset();pulses.clear()
	_update_chapter();_details();_resting_note()

func _update_chapter() -> void:
	for index in range(4):
		var active:=index==shown_stage
		for state in ["font_color","font_hover_color","font_pressed_color"]:stages[index].add_theme_color_override(state,GOLD if active else MUTED)
	for id in buttons:
		buttons[id].visible=items[id].tier==shown_stage+1
		buttons[id].queue_redraw()
	graph.queue_redraw()

func refresh(value:Dictionary) -> void:
	frame=value;effects.reduced=value.reduced
	var old:Dictionary=items;items={}
	for item in value.upgradeTree:
		items[item.id]=item
		if not buttons.has(item.id):
			var button:=Button.new();button.name="Node_"+item.id;button.size=Vector2(100,112);button.mouse_default_cursor_shape=CURSOR_POINTING_HAND
			for state in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
			graph.add_child(button);buttons[item.id]=button
			button.draw.connect(_draw_node.bind(button,item.id));button.pressed.connect(_select.bind(item.id))
			button.focus_entered.connect(func():_select(item.id,false))
			button.mouse_entered.connect(button.queue_redraw);button.mouse_exited.connect(button.queue_redraw)
		var node:Button=buttons[item.id]
		node.tooltip_text=item.name+(" · 无尽 %d 阶" % item.rank if item.infinite else " · %d / %d" % [item.rank,item.maxRank])+(" · 已完成" if item.complete else "" if item.available else " · "+"、".join(item.requirements))
		if old.has(item.id) and item.rank>old[item.id].rank and item.tier==shown_stage+1:
			pulses[item.id]=effects.clock
			var major:bool=item.rank/10>old[item.id].rank/10 if item.infinite else item.complete and item.tier==3
			effects.fire(_point(item),INKS[item.col],2 if major else 1 if item.complete else 0)
			for next in value.upgradeTree:
				if next.tier==item.tier and next.available and old.has(next.id) and not old[next.id].available:effects.connect_path(_point(item),_point(next),INKS[next.col],_route(item,next))
			feedback.text=("星耀突破 · " if major else "星点铸成 · " if item.complete else "无尽进阶 · " if item.infinite else "强化成功 · ")+item.name
			note_until=elapsed+2.6
	if not old.is_empty() and frame.masteryUnlocked and not old.mastery_arrow.available:
		effects.fire(_center(),GOLD,2);feedback.text="全星图点亮 · 无尽星环已开启";note_until=elapsed+4
	_layout();_update_chapter();_details()

func _select(id:String,sound:bool=true) -> void:
	if selected==id:return
	selected=id
	if items[id].tier!=shown_stage+1:_show_stage(items[id].tier-1,false)
	if sound:ui.action.emit("cue",{"type":"tap","ui":true})
	for button in buttons.values():button.queue_redraw()
	graph.queue_redraw();_details()

func _purchase() -> void:
	var item:Dictionary=items[selected]
	ui.action.emit("buy",{"key":item.key,"node":item.id})

func _details() -> void:
	if not items.has(selected):return
	var signature:=JSON.stringify([selected,items[selected],frame.phase,frame.paused,frame.coins])
	if signature==detail_signature:return
	detail_signature=signature
	var item:Dictionary=items[selected]
	buy.name="Buy_"+item.key
	buy.disabled=item.complete or not item.available or not item.affordable or frame.phase!="ready" or frame.paused
	for state in ["normal","hover","pressed"]:buy.add_theme_stylebox_override(state,v.box(Color("#253d3c") if state=="normal" else Color("#34544f"),INKS[item.col].darkened(.3),24,8))
	if item.complete:buy.text="✓  星点已铸成"
	elif not item.available:buy.text="点满基础树，开启无尽星环" if item.infinite else "需 "+"、".join(item.requirements) if not item.requirements.is_empty() else "需完成前一阶段"
	elif frame.phase!="ready" or frame.paused:buy.text="等待本箭结束或继续游戏后升级"
	elif not item.affordable:buy.text="还差 ¥ "+ui.pages.fmt(item.cost-frame.coins)
	else:buy.text=("无尽进阶 +%d" % (3 if item.forge else 1) if item.infinite else "锻造 +%d" % mini(3,item.maxRank-item.rank) if item.forge else "铸造 +1")+"   ·   ¥ "+ui.pages.fmt(item.cost)
	buy.tooltip_text="本次价格 ¥ "+ui.pages.fmt(item.cost)
	graph.queue_redraw()

func _route(parent:Dictionary,item:Dictionary) -> PackedVector2Array:
	var a:=_point(parent);var b:=_point(item)
	var bend:Vector2=(a+b)*.5
	if parent.key=="arrow" and item.key=="slots":bend=_map_point(Vector2(.13,.48))
	if parent.key=="comboCap" and item.key=="rerollCap":bend.x+=10
	var points:=PackedVector2Array()
	for i in range(25):
		var t:=i/24.0;points.append(a*(1-t)*(1-t)+bend*2*(1-t)*t+b*t*t)
	return points

func _draw_graph() -> void:
	var width:=graph.size.x;var center:=_center()
	graph.draw_rect(Rect2(Vector2.ZERO,graph.size),Color("#0d1c24"))
	for i in range(24):
		graph.draw_circle(center,320-i*10,Color("#275255",.009))
	# Engraved celestial instrument: deterministic stars and quiet orbital ticks.
	for i in range(120):
		var point:=Vector2(12+fmod(i*71.31,maxf(1,width-24)),12+fmod(i*i*19.71,maxf(1,graph.size.y-24)))
		graph.draw_circle(point,.65 if i%5 else 1.15,Color(MUTED,.16 if i%5 else .35))
	for r in [87,159,174]:
		var orbit:=PackedVector2Array()
		for i in range(121):orbit.append(center+Vector2(cos(i*TAU/120)*r,sin(i*TAU/120)*r*1.36))
		graph.draw_polyline(orbit,Color(GOLD,.07 if r==87 else .13),1,true)
	for i in range(72):
		var dir:=Vector2(cos(i*TAU/72),sin(i*TAU/72)*1.36)
		graph.draw_line(center+dir*170,center+dir*(175 if i%6==0 else 172),Color(GOLD,.25),1,true)
	for item in items.values():
		if item.tier!=shown_stage+1:continue
		var source:bool=item.parents.is_empty() or item.infinite
		for id in item.parents:
			var parent:Dictionary=items[id]
			if parent.tier!=item.tier:source=true;continue
			var route:=_route(parent,item)
			var bright:bool=parent.complete
			graph.draw_polyline(route,Color(INKS[item.col],.07 if bright else .025),7,true)
			graph.draw_polyline(route,Color(INKS[item.col],.66 if bright else .19),1.5 if bright else 1,true)
			var middle:Vector2=route[12];_diamond(graph,middle,3,Color(INKS[item.col],.7 if bright else .28))
		if source:
			var point:=_point(item);var direction:Vector2=(point-center).normalized()
			graph.draw_line(center+direction*62,point,Color(INKS[item.col],.45 if item.available or item.complete else .14),1,true)
	_draw_core(center)
	_draw_inscription()

func _draw_inscription() -> void:
	var width:=graph.size.x
	graph.draw_string(v.fonts[0],Vector2(24,27),"THE ASTRAL FORGE",HORIZONTAL_ALIGNMENT_LEFT,-1,9,GOLD)
	graph.draw_string(v.fonts[1],Vector2(24,56),"星铸命盘",HORIZONTAL_ALIGNMENT_LEFT,-1,24,PAPER)
	graph.draw_string(v.fonts[1],Vector2(190,53),"¥ "+ui.pages.fmt(frame.get("coins",0)),HORIZONTAL_ALIGNMENT_RIGHT,width-254,18,GOLD)
	var completed:int=items.values().filter(func(n):return n.complete).size()
	graph.draw_string(v.fonts[0],Vector2(24,76),"永久成长   /   %d · 21 星点铸成" % completed,HORIZONTAL_ALIGNMENT_LEFT,-1,10,MUTED)
	var x:=20+(shown_stage+.5)*(width-40)/4
	graph.draw_line(Vector2(x-25,128),Vector2(x+25,128),Color(GOLD,.45),1,true);_diamond(graph,Vector2(x,128),3,GOLD)
	for stage in stages:
		if stage.has_focus():graph.draw_arc(stage.position+stage.size/2,24,0,TAU,48,Color(PAPER,.5),1,true)
	if not items.has(selected):return
	# Information is ink on the chart, with only a soft legibility falloff. No
	# separate wallet, tab cards or detail panel compete with the constellation.
	var y:=graph.size.y-201
	for i in range(20):graph.draw_rect(Rect2(0,y-35+i*12,width,12),Color("#0d1c24",minf(.98,i/8.0)))
	var item:Dictionary=items[selected];var ink:Color=INKS[item.col]
	graph.draw_line(Vector2(24,y-6),Vector2(49,y-6),Color(ink,.7),2,true)
	graph.draw_string(v.fonts[1],Vector2(24,y+18),item.name,HORIZONTAL_ALIGNMENT_LEFT,-1,19,PAPER)
	var status:="∞ %d 阶" % item.rank if item.infinite else "已铸成" if item.complete else "%d / %d" % [item.rank,item.maxRank]
	graph.draw_string(v.fonts[0],Vector2(width-140,y+17),status,HORIZONTAL_ALIGNMENT_RIGHT,116,12,ink)
	var paragraph:=TextParagraph.new();paragraph.width=width-48;paragraph.add_string(item.description,v.fonts[0],11)
	paragraph.draw(graph.get_canvas_item(),Vector2(24,y+29),MUTED)
	for i in range(item.before.size()):
		var mx:float=24+i*(width-48)/2
		graph.draw_string(v.fonts[0],Vector2(mx,y+78),item.before[i][0],HORIZONTAL_ALIGNMENT_LEFT,-1,10,MUTED)
		var value:String=item.before[i][1]
		if not item.complete and value!=item.after[i][1]:value+="  →  "+item.after[i][1]
		graph.draw_string(v.fonts[1],Vector2(mx,y+98),value,HORIZONTAL_ALIGNMENT_LEFT,(width-48)/2,14,ink)

func _diamond(canvas:CanvasItem,center:Vector2,radius:float,ink:Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0)]),ink)

func _draw_core(center:Vector2) -> void:
	for i in range(8):graph.draw_circle(center,68-i*5,Color(GOLD,.012+i*.003))
	graph.draw_arc(center,59,0,TAU,80,Color(GOLD,.3),1,true)
	var shape:=PackedVector2Array()
	for i in range(16):shape.append(center+Vector2.from_angle(i*TAU/16-PI/2)*(51 if i%2==0 else 36))
	graph.draw_colored_polygon(shape,Color("#172b31"));shape.append(shape[0]);graph.draw_polyline(shape,Color(GOLD,.7),1,true)
	for i in range(4):
		var offset:=Vector2.from_angle(i*PI/2)*65;_diamond(graph,center+offset,2,GOLD)
	if shown_stage==3:
		var orbit:=PackedVector2Array()
		for i in range(65):
			var t:=i*TAU/64;orbit.append(center+Vector2(cos(t)*22,sin(2*t)*10)-Vector2(0,4))
		graph.draw_polyline(orbit,GOLD,2,true)
	else:
		graph.draw_texture_rect(Icons.texture("slots",shown_stage+1),Rect2(center-Vector2(32,39),Vector2(64,64)),false)
	graph.draw_string(v.fonts[1],center+Vector2(-40,35),CHAPTERS[shown_stage],HORIZONTAL_ALIGNMENT_CENTER,80,12,GOLD)

func _draw_node(button:Button,id:String) -> void:
	var item:Dictionary=items[id];var center:=Vector2(50,42);var ink:Color=INKS[item.col]
	var enabled:bool=item.available or item.complete or item.rank>0
	var active:bool=selected==id;var keystone:bool=item.key in ["slots","rerollCap"] or item.infinite
	var radius:=38.0 if keystone else 32.0
	var scale_factor:=1.0
	if pulses.has(id) and not frame.reduced:
		var age:float=effects.clock-float(pulses[id]);scale_factor=1+.15*sin(minf(1,age/.38)*PI)*exp(-age*2)
	if active or button.is_hovered() or item.available and item.affordable:
		for i in range(5):button.draw_circle(center,radius+9-i*2,Color(ink,.022 if not active else .045))
	button.draw_circle(center+Vector2(0,3),radius+1,Color("#080f15"))
	button.draw_circle(center,radius,Color("#20333d") if enabled else Color("#18272e"))
	button.draw_arc(center,radius,0,TAU,60,Color(ink,1 if enabled else .28),1.6 if active or item.complete else 1,true)
	button.draw_arc(center,radius-4,0,TAU,60,Color(ink,.16),1,true)
	if keystone:
		for i in range(4):_diamond(button,center+Vector2.from_angle(i*PI/2)*(radius+2),3,ink if enabled else Color(ink,.3))
	if not item.infinite:
		for i in range(item.maxRank):
			var start:float=PI*.15+i*(PI*.70/item.maxRank)
			button.draw_arc(center,radius+4,start,start+PI*.51/item.maxRank,5,Color(ink,1 if i<item.rank else .18),2,true)
	button.draw_texture_rect(Icons.texture(item.key,item.tier),Rect2(center-Vector2(30,30)*scale_factor,Vector2(60,60)*scale_factor),false,Color(1,1,1,1 if enabled else .36))
	if active:
		for sign_x in [-1,1]:
			for sign_y in [-1,1]:
				var corner:=center+Vector2(sign_x,sign_y)*(radius+6)
				button.draw_polyline(PackedVector2Array([corner-Vector2(sign_x*7,0),corner,corner-Vector2(0,sign_y*7)]),Color(ink,.85),1.3,true)
	if button.has_focus():button.draw_arc(center,radius+8,0,TAU,64,PAPER,1,true)
	if not enabled:button.draw_texture_rect(v.icon("lock-keyhole",MUTED),Rect2(74,62,12,12),false)
	elif item.complete:
		button.draw_circle(Vector2(78,66),6,ink);button.draw_polyline(PackedVector2Array([Vector2(75,66),Vector2(77,68),Vector2(82,63)]),Color("#102029"),1.6,true)
	button.draw_string(v.fonts[1],Vector2(0,96),item.name,HORIZONTAL_ALIGNMENT_CENTER,100,12,PAPER if enabled else MUTED)
	var rank_label:="∞  %d 阶" % item.rank if item.infinite else "已铸成" if item.complete else "%d / %d" % [item.rank,item.maxRank]
	button.draw_string(v.fonts[0],Vector2(0,110),rank_label,HORIZONTAL_ALIGNMENT_CENTER,100,10,ink if item.complete or item.infinite and item.available else MUTED)
