extends VBoxContainer
## Retained, keyboard/touch accessible graph. Purchases only go through the
## session; visual pulses are derived from confirmed rank changes.
const Icons=preload("res://src/ui/upgrade_icons.gd")
const FX=preload("res://src/ui/upgrade_tree_fx.gd")
var ui:Control
var v:RefCounted
var frame:Dictionary={}
var items:Dictionary={}
var buttons:Dictionary={}
var selected:="power_1"
var graph:Control
var scroll:ScrollContainer
var wallet:Label
var progress:Label
var detail:VBoxContainer
var buy:Button
var feedback:Label
var effects:Control
var stages:Array[Button]=[]
var elapsed:=0.0
var note_until:=0.0
var pulses:Dictionary={}
var detail_signature:=""
var shown_stage:=-1
const ROW:=101.0
const TOP:=65.0
const INKS:=[Color("#6da89e"),Color("#87abcf"),Color("#d6ae63")]

func setup(owner:Control) -> void:
	ui=owner;v=ui.visuals;name="UpgradeTree";add_theme_constant_override("separation",10)
	var balance:HBoxContainer=v.row(self,8)
	wallet=v.text(balance,"",24,"ink",true);wallet.name="ShopBalance";wallet.size_flags_horizontal=SIZE_EXPAND_FILL
	progress=v.text(balance,"",10,"text-3");progress.size_flags_vertical=SIZE_SHRINK_CENTER
	var tabs:HBoxContainer=v.row(self,6)
	for index in range(3):
		var stage:Button=v.button(tabs,["Ⅰ · 启程","Ⅱ · 精铸","Ⅲ · 传奇"][index],func():scroll.scroll_vertical=int(index*3*ROW),"",32)
		stage.size_flags_horizontal=SIZE_EXPAND_FILL;stages.append(stage)
	var lanes:HBoxContainer=v.row(self)
	for index in range(3):
		var label:Label=v.text(lanes,["迅捷","武装","财富"][index],10,"text-2",true);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.size_flags_horizontal=SIZE_EXPAND_FILL
	var map_panel:=PanelContainer.new();map_panel.add_theme_stylebox_override("panel",v.box(v.color("surface-2"),v.color("line"),12,0));add_child(map_panel)
	scroll=ScrollContainer.new();scroll.custom_minimum_size.y=345;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;map_panel.add_child(scroll)
	graph=Control.new();graph.name="TreeGraph";graph.custom_minimum_size=Vector2(0,TOP+9*ROW+16);graph.size_flags_horizontal=SIZE_EXPAND_FILL;graph.mouse_filter=MOUSE_FILTER_PASS;scroll.add_child(graph)
	graph.draw.connect(_draw_graph);graph.resized.connect(_layout)
	effects=FX.new();effects.name="UpgradeEffects";effects.z_index=2;graph.add_child(effects)
	var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",v.box(v.color("surface-2"),v.color("line-2"),10,12));add_child(card)
	detail=v.column(card,6);detail.name="TreeDetail";detail.custom_minimum_size.y=128
	buy=v.button(self,"",_purchase,"",44);buy.add_theme_font_size_override("font_size",13)
	buy.add_theme_stylebox_override("normal",v.box(v.color("buy"),v.color("buy-line"),9,8))
	for state in ["font_color","font_hover_color","font_pressed_color"]:buy.add_theme_color_override(state,v.color("on-buy"))
	feedback=v.text(self,"选择节点查看提升 · 滑动探索整棵树",10,"text-3",false,true);feedback.custom_minimum_size.y=28
	refresh(owner.frame)

func _process(delta:float) -> void:
	elapsed+=delta
	for id in pulses.keys():
		buttons[id].queue_redraw()
		if effects.clock-float(pulses[id])>.6:pulses.erase(id)
	if note_until>0 and elapsed>=note_until:
		note_until=0;feedback.text="选择节点查看提升 · 滑动探索整棵树"
	if is_instance_valid(scroll):
		var stage:=clampi(int((scroll.scroll_vertical+100)/(3*ROW)),0,2)
		if stage!=shown_stage:
			shown_stage=stage
			for i in range(3):stages[i].add_theme_stylebox_override("normal",v.box(v.color("accent-soft" if i==stage else "surface-2"),v.color("accent-line" if i==stage else "line"),7,4))

func _point(item:Dictionary) -> Vector2:
	return Vector2(graph.size.x*(.17+.33*item.col),TOP+item.row*ROW)

func _layout() -> void:
	effects.size=graph.size
	for id in buttons:
		buttons[id].position=_point(items[id])-Vector2(43,34)
	graph.queue_redraw()

func refresh(value:Dictionary) -> void:
	frame=value;effects.reduced=value.reduced
	var old:Dictionary=items;items={}
	var completed:=0
	for item in value.upgradeTree:
		items[item.id]=item
		if item.complete:completed+=1
		if not buttons.has(item.id):
			var button:=Button.new();button.name="Node_"+item.id;button.size=Vector2(86,91);button.mouse_default_cursor_shape=CURSOR_POINTING_HAND
			for state in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
			graph.add_child(button);buttons[item.id]=button
			button.draw.connect(_draw_node.bind(button,item.id));button.pressed.connect(_select.bind(item.id))
			button.focus_entered.connect(func():_select(item.id,false))
			button.mouse_entered.connect(button.queue_redraw);button.mouse_exited.connect(button.queue_redraw)
		var node:Button=buttons[item.id]
		node.tooltip_text=item.name+" · %d / %d" % [item.rank,item.maxRank]+(" · 已完成" if item.complete else "" if item.available else " · "+"、".join(item.requirements))
		node.queue_redraw()
		if old.has(item.id) and item.rank>old[item.id].rank:
			pulses[item.id]=effects.clock
			effects.fire(_point(item),INKS[item.col],2 if item.complete and item.tier==3 else 1 if item.complete else 0)
			for next in value.upgradeTree:
				if next.available and old.has(next.id) and not old[next.id].available:
					effects.connect_path(_point(item),_point(next),INKS[next.col])
			feedback.text=("传奇铸成 · " if item.complete and item.tier==3 else "节点完成 · 新路线已点亮" if item.complete else "强化成功 · ")+item.name
			note_until=elapsed+2.6
	wallet.text="¥ "+ui.pages.fmt(value.coins);progress.text="%d / 21 节点完成" % completed
	_layout();_details()

func _select(id:String,sound:bool=true) -> void:
	if selected==id:return
	selected=id
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
	for child in detail.get_children():detail.remove_child(child);child.queue_free()
	var item:Dictionary=items[selected]
	var title:HBoxContainer=v.row(detail,8)
	var icon:=TextureRect.new();icon.texture=Icons.texture(item.key,item.tier);icon.custom_minimum_size=Vector2(36,36);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;title.add_child(icon)
	var words:VBoxContainer=v.column(title,2);v.text(words,item.name,16,"ink",true)
	v.text(words,"%s · %d / %d%s" % [["启程","精铸","传奇"][item.tier-1],item.rank,item.maxRank," · 已完成" if item.complete else ""],10,"text-3")
	var description:Label=v.text(detail,item.description,11,"text-2",false,true);description.custom_minimum_size.y=32
	for i in range(item.before.size()):
		var metric:HBoxContainer=v.row(detail,6)
		v.text(metric,item.before[i][0],10,"text-3").size_flags_horizontal=SIZE_EXPAND_FILL
		v.text(metric,item.before[i][1],12,"text-2")
		if not item.complete:
			v.text(metric,"→",12,"text-3");v.text(metric,item.after[i][1],12,"accent-ink",true)
	buy.name="Buy_"+item.key
	buy.disabled=item.complete or not item.available or not item.affordable or frame.phase!="ready" or frame.paused
	if item.complete:buy.text="✓  节点已完成"
	elif not item.available:buy.text="需 "+"、".join(item.requirements) if not item.requirements.is_empty() else "需完成前一阶段"
	elif frame.phase!="ready" or frame.paused:buy.text="等待本箭结束或继续游戏后升级"
	elif not item.affordable:buy.text="还差 ¥ "+ui.pages.fmt(item.cost-frame.coins)
	else:buy.text=("锻造 +%d  ·  ¥ " % mini(3,item.maxRank-item.rank) if item.forge else "强化 +1  ·  ¥ ")+ui.pages.fmt(item.cost)
	buy.tooltip_text="本次价格 ¥ "+ui.pages.fmt(item.cost)

func _draw_graph() -> void:
	var width:=graph.size.x
	# Small shared origin opens into three independently investable routes.
	var center:=Vector2(width*.5,12)
	graph.draw_circle(center,4,v.color("accent-ink"))
	for i in range(3):
		var points:=PackedVector2Array([center,Vector2(width*(.17+.33*i),33),Vector2(width*(.17+.33*i),TOP-33)])
		graph.draw_polyline(points,v.mix(INKS[i],v.color("line-2"),.4),1.5,true)
	for item in items.values():
		for id in item.parents:
			var parent:Dictionary=items[id]
			var a:=_point(parent)+Vector2(0,53);var b:=_point(item)-Vector2(0,33)
			# Long dependencies travel beside the lane, clear of intervening nodes.
			var path:=PackedVector2Array([a,b])
			if item.row-parent.row>1 and item.col==parent.col:
				var x:float=a.x+(43 if item.col<2 else -43)
				path=PackedVector2Array([a,a+Vector2(0,6),Vector2(x,a.y+6),Vector2(x,b.y-8),b-Vector2(0,8),b])
			var ink:Color=v.mix(INKS[item.col],v.color("line-2"),.75 if parent.complete else .1)
			graph.draw_polyline(path,ink,2 if parent.complete else 1,true)
	for stage in range(1,3):
		var y:=TOP+stage*3*ROW-47
		graph.draw_line(Vector2(12,y),Vector2(width-12,y),v.color("line"),1,true)

func _hex(center:Vector2,radius:float) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for i in range(6):points.append(center+Vector2.from_angle(TAU*i/6-PI/2)*radius)
	return points

func _draw_node(button:Button,id:String) -> void:
	var item:Dictionary=items[id]
	var center:=Vector2(43,34);var ink:Color=INKS[item.col]
	var enabled:bool=item.available or item.complete or item.rank>0
	var active:bool=selected==id
	var scale_factor:=1.0
	if pulses.has(id) and not frame.reduced:
		var age:float=effects.clock-float(pulses[id])
		scale_factor=1+.19*sin(minf(1,age/.38)*PI)*exp(-age*2)
	if active or item.available and item.affordable:
		for r in range(40,32,-2):
			var glow:=ink;glow.a=.045 if not active else .085;button.draw_colored_polygon(_hex(center,r),glow)
	var outer:=_hex(center+Vector2(0,2),32);button.draw_colored_polygon(outer,v.mix(Color.BLACK,v.color("surface-3"),.3))
	var face:=_hex(center,31);button.draw_colored_polygon(face,v.mix(ink,v.color("surface"),.13 if enabled else .035))
	var outline:=face.duplicate();outline.append(face[0]);button.draw_polyline(outline,ink if enabled else v.color("line-2"),2 if active or item.complete else 1,true)
	var inner:=_hex(center,27);inner.append(inner[0]);button.draw_polyline(inner,v.mix(ink,v.color("surface"),.3),1,true)
	button.draw_texture_rect(Icons.texture(item.key,item.tier),Rect2(center-Vector2(25,25)*scale_factor,Vector2(50,50)*scale_factor),false,Color(1,1,1,1 if enabled else .46))
	if button.has_focus():button.draw_arc(center,35,0,TAU,36,v.color("ink"),1,true)
	if not enabled:
		button.draw_texture_rect(v.icon("lock-keyhole",v.color("text-2")),Rect2(61,49,12,12),false)
	elif item.complete:
		button.draw_circle(Vector2(66,53),7,v.color("accent-ink"))
		button.draw_polyline(PackedVector2Array([Vector2(62,53),Vector2(65,56),Vector2(70,50)]),v.color("surface"),1.6,true)
	var font:Font=v.fonts[1]
	button.draw_string(font,Vector2(0,77),item.name,HORIZONTAL_ALIGNMENT_CENTER,86,11,v.color("ink" if enabled else "text-3"))
	button.draw_string(v.fonts[0],Vector2(0,90),"%d / %d" % [item.rank,item.maxRank],HORIZONTAL_ALIGNMENT_CENTER,86,10,v.color("accent-ink" if item.complete else "text-3"))
