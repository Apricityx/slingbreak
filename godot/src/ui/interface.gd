extends Control
## Native Controls consume semantic state. No damage, rewards or draw weights
## are calculated here. Modal input and prior pause state have a single owner.
signal action(method: String,input: Dictionary)
const Presentation = preload("res://src/ui/presentation.gd")
const Pages = preload("res://src/ui/pages.gd")
const Report = preload("res://src/ui/report.gd")
const Notices = preload("res://src/ui/notices.gd")
const AchievementCards = preload("res://src/ui/achievement_cards.gd")
const Motion=preload("res://src/ui/motion.gd")
const Easing=preload("res://src/ui/easing.gd")
const Sheet=preload("res://src/ui/sheet.gd")
const MODAL_BLUR=preload("res://src/ui/modal_blur.gdshader")
const WEB_MODAL_BLUR=preload("res://src/ui/modal_blur_web.gdshader")
const Reel=preload("res://src/ui/reel.gd")
const Flights=preload("res://src/ui/coin_flights.gd")
const Charges=preload("res://src/ui/charges.gd")
const CoreMeter=preload("res://src/ui/core_meter.gd")
const HudFeedback=preload("res://src/ui/hud_feedback.gd")
var visuals := Presentation.new()
var pages := Pages.new()
var report_view := Report.new()
var frame: Dictionary = {}
var catalog: Dictionary = {}
var panel: Sheet
var scrim: ColorRect
var modal_content: VBoxContainer
var modal_kind := ""
var restore_pause := false
var draft_key := ""
var choosing := false
var hud_nodes: Dictionary = {}
var queue: HBoxContainer
var queue_key := ""
var queue_ghosts:Dictionary={}
var queue_motion_serial:=0
var current_theme := ""
var file_dialog: FileDialog
var modal_scroll: ScrollContainer
var report_layer: Control
var report_key := ""
var wipe_layer: Control
var wipe_key := ""
var modal_stack: Array = []
var modal_padding := 16
var modal_width := 380
var detail_id := ""
var pause_layer: Control
var toast_time := 0.0
var charge_key := ""
var charge_tab: PanelContainer
var notices: Control
var boss_bar: HBoxContainer
var boss_key := ""
var achievement_cards: Control
var last_level:=0
var shop_state:=""
var shop_theme:=""
var detail_state:=""
var rolling:=false
var motion_layer:Control
var hud_values:Dictionary={}
var modal_enter_pending:=false
var sheet_serial:=0
var morph_from:=Rect2()
var morph_scroll:=-1
var hud_targets:Dictionary={}
var hud_shown:Dictionary={}
var boss_nodes:Dictionary={}
var charge_gauge:Control
var wipe_age:=0.0
var detail_theme:=""
var preview_id:=""
var opening_control:Control
var layout_pending:=false
var level_ghost:Control
var toast_ghost:Control
var pending_swap_id:=""
var pending_swap_from:=""
var hud_feedback:Control
var combo_stamp:=""
var combo_ink:=Color.TRANSPARENT

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	pages.setup(self)
	motion_layer=Control.new();motion_layer.name="Motion";motion_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;motion_layer.size=Vector2(412,915);motion_layer.z_index=30;add_child(motion_layer)
	_build_hud()
	notices=Notices.new();notices.visuals=visuals;add_child(notices)
	achievement_cards=AchievementCards.new();achievement_cards.visuals=visuals;add_child(achievement_cards)

func _build_hud() -> void:
	for child in get_children():
		var stacked:=false
		for item in modal_stack:if child==item.panel or child==item.scrim:stacked=true
		if not stacked and child not in [panel,scrim,file_dialog,report_layer,wipe_layer,pause_layer,notices,achievement_cards,motion_layer]:child.queue_free()
	hud_nodes.clear();queue_key=""
	hud_values.clear()
	combo_stamp="";combo_ink=Color.TRANSPARENT
	hud_targets.erase("progress")
	_clear_queue_motion()
	charge_key="";charge_tab=null;charge_gauge=null
	boss_key="";boss_bar=null;boss_nodes.clear()
	visuals.apply(self)
	var background := ColorRect.new();background.color=visuals.color("bg");background.size=Vector2(412,238);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
	var mark := _button("",Vector2(12,14),Vector2(29,29),func():_equipment())
	mark.icon=visuals.icon("move-up-right",visuals.color("on-accent"));mark.expand_icon=true
	mark.add_theme_stylebox_override("normal",visuals.box(visuals.color("accent"),visuals.color("accent"),8))
	_text("brand","弓引力",Vector2(49,18),18,"ink",true)
	_icon_button("settings",Vector2(260,7),func():_settings())
	_icon_button("maximize",Vector2(304,7),func():_fullscreen())
	var wallet := _button("0",Vector2(352,15),Vector2(48,27),func():_equipment());wallet.icon=visuals.icon("wallet",visuals.color("text-2"));wallet.expand_icon=true;wallet.add_theme_font_size_override("font_size",10);hud_nodes.wallet=wallet
	_line(Vector2(0,57),Vector2(412,1))
	_text("level_tag","LEVEL",Vector2(16,67),10,"text-3")
	_text("level","01",Vector2(58,56),30,"ink",true)
	_text("infinity","∞",Vector2(109,61),18,"text-3")
	_line(Vector2(0,89),Vector2(412,1))
	_text("receipt_label","单箭收益",Vector2(16,99),10,"text-3")
	_text("receipt","+0",Vector2(16,110),26,"accent-ink-strong")
	_line(Vector2(278,98),Vector2(1,44))
	_text("combo_label","连击",Vector2(294,99),10,"text-3")
	_text("combo","0",Vector2(294,110),26,"text-3")
	_text("mult","×1",Vector2(358,121),17,"text-3")
	hud_nodes.mult.size.x=38;hud_nodes.mult.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var combo_meter:=ProgressBar.new();combo_meter.position=Vector2(321,104);combo_meter.size=Vector2(75,3);combo_meter.show_percentage=false;combo_meter.mouse_filter=Control.MOUSE_FILTER_IGNORE
	combo_meter.step=0.0;combo_meter.add_theme_font_size_override("font_size",1)
	combo_meter.add_theme_stylebox_override("background",visuals.box(visuals.color("line"),Color.TRANSPARENT,2))
	combo_meter.add_theme_stylebox_override("fill",visuals.box(visuals.color("heat-0"),Color.TRANSPARENT,2));add_child(combo_meter);hud_nodes.combo_progress=combo_meter
	for style in ["background","fill"]:combo_meter.get_theme_stylebox(style).set_border_width_all(0)
	combo_meter.set_deferred("size",Vector2(75,3))
	_text("combo_spark","✦",Vector2(335,121),10,"gold-ink");hud_nodes.combo_spark.modulate.a=0
	_text("arrow_tag","",Vector2(72,99),9,"text-2")
	_text("score_bonus","",Vector2(160,121),10,"gold-ink",true)
	_text("core_label","核心解锁",Vector2(34,149),10,"text-3")
	var progress := CoreMeter.new();progress.visuals=visuals;progress.position=Vector2(103,154);progress.size=Vector2(237,5);progress.show_percentage=false;progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
	progress.step=0.0
	progress.add_theme_stylebox_override("background",visuals.box(visuals.color("surface-3"),Color.TRANSPARENT,2))
	progress.add_theme_stylebox_override("fill",visuals.box(visuals.color("accent-bar"),Color.TRANSPARENT,2));add_child(progress);hud_nodes.progress=progress
	for style in ["background","fill"]:progress.get_theme_stylebox(style).set_border_width_all(0)
	progress.add_theme_font_size_override("font_size",1)
	progress.set_deferred("size",Vector2(237,5))
	_text("core_value","0 / 0",Vector2(346,148),13,"text-3")
	hud_nodes.core_value.size.x=50;hud_nodes.core_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hud_feedback=HudFeedback.new();hud_feedback.visuals=visuals;add_child(hud_feedback)
	_line(Vector2(0,172),Vector2(412,1))
	var queue_panel := Panel.new();queue_panel.position=Vector2(10,181);queue_panel.size=Vector2(392,49);queue_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;queue_panel.add_theme_stylebox_override("panel",visuals.box(Color.TRANSPARENT,visuals.color("line"),7));add_child(queue_panel)
	queue=HBoxContainer.new();queue.position=Vector2(20,191);queue.size=Vector2(372,29);queue.add_theme_constant_override("separation",5);add_child(queue)
	var shop := _button("",Vector2(350,722),Vector2(46,46),func():_shop());shop.icon=visuals.icon("store",visuals.color("on-panel"));shop.expand_icon=true;shop.tooltip_text="打开升级商店";shop.add_theme_stylebox_override("normal",visuals.box(visuals.color("panel"),visuals.color("panel"),23,12))
	_text("status","就绪",Vector2(16,788),9,"text-3")
	_text("power","POWER  0%",Vector2(337,788),9,"text-3")
	var earnings := ColorRect.new();earnings.position=Vector2(0,810);earnings.size=Vector2(412,105);earnings.color=visuals.color("panel");earnings.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(earnings)
	_text("earnings_label","本关收益",Vector2(30,831),10,"on-panel")
	_text("earnings","+ 0",Vector2(30,850),44,"accent",true)
	_text("toast","",Vector2(150,67),10,"text-2",true);hud_nodes.toast.size.x=246;hud_nodes.toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;hud_nodes.toast.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	visuals.button_states(self)

func _line(at: Vector2,dimensions: Vector2) -> void:
	var line := ColorRect.new();line.color=visuals.color("line");line.position=at;line.size=dimensions;line.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(line)

func _text(key: String,text: String,at: Vector2,size: int,token: String,bold: bool=false) -> void:
	var label := visuals.label(text,size,token,bold);label.position=at;add_child(label);hud_nodes[key]=label

func _button(text: String,at: Vector2,dimensions: Vector2,callback: Callable) -> Button:
	var button := Button.new();button.text=text;button.position=at;button.size=dimensions
	button.pressed.connect(func():
		opening_control=button;callback.call()
		if opening_control==button:opening_control=null
	)
	add_child(button);return button

func _icon_button(id: String,at: Vector2,callback: Callable) -> void:
	var button := _button("",at,Vector2(44,44),callback);button.icon=visuals.icon(id,visuals.color("text-3"));button.expand_icon=true
	button.add_theme_stylebox_override("normal",visuals.box(Color.TRANSPARENT,Color.TRANSPARENT,6,12))
	button.tooltip_text="设置" if id=="settings" else "进入全屏"

func set_catalog(entries: Array) -> void:
	for item in entries: catalog[item.id]=item

func present(value: Dictionary) -> void:
	frame=value
	if current_theme!=value.theme:
		current_theme=value.theme;visuals.mode=current_theme;_build_hud()
	if hud_nodes.is_empty(): return
	var achievement: Dictionary=value.achievement if value.get("achievement") is Dictionary else {}
	_set_level("%02d" % (value.transition.report.level if value.phase=="clearing" and value.transition.report is Dictionary else value.level),value.reduced)
	_count_target("wallet",float(value.coins),value.reduced)
	_count_target("receipt",float(achievement.get("paid",0)),value.reduced or achievement.get("id",0)!=hud_targets.get("arrow_id",0))
	hud_targets.arrow_id=achievement.get("id",0)
	_update_combo(value,achievement)
	hud_nodes.arrow_tag.text="#%d" % achievement.id if not achievement.is_empty() else ""
	hud_nodes.receipt.modulate.a=1 if not achievement.is_empty() else .55
	var bonuses:=""
	if achievement.get("mult",1)>1:bonuses="✦ ×"+_compact(achievement.mult)
	if achievement.get("bountyMult",1)>1:bonuses+="  ¥ ×"+_compact(achievement.bountyMult)
	hud_nodes.score_bonus.text=bonuses
	_count_target("earnings",float(value.levelMoney),value.reduced)
	var core_threshold:float=float(value.threshold) if value.threshold!=null else 0.0
	var progress_value:=100.0*float(value.killed)/maxf(1.0,core_threshold)
	if not hud_targets.has("progress") or hud_targets.progress!=progress_value:
		Motion.meter(hud_nodes.progress,progress_value,.22,value.reduced or not hud_targets.has("progress"))
		hud_targets.progress=progress_value
	var core_state:="boss" if value.bossStatus is Dictionary else "cleared" if value.phase=="clearing" else "ready" if value.core!=null else "locked"
	hud_nodes.core_label.text="核心击破" if core_state=="cleared" else "核心已显现" if core_state=="ready" else "核心解锁"
	if hud_values.get("core_state","")!=core_state:
		for token in ["core_label","core_value"]:hud_nodes[token].add_theme_color_override("font_color",visuals.color("accent-ink-strong" if core_state in ["ready","cleared"] else "text-3"))
		hud_values.core_state=core_state
	hud_nodes.progress.present(core_state,value.reduced or value.paused)
	hud_feedback.present(_combo_heat(value,achievement),core_state,value.reduced,value.paused)
	hud_nodes.core_value.text="%d / %d" % [mini(value.killed,int(core_threshold)),int(core_threshold)]
	var status := {"draft":"选择新技能 · 滚动构筑","ready":"就绪","entering":"砖块入场中","flying":"可继续射击","clearing":"下一关即将开始"}
	hud_nodes.status.text="已暂停" if value.paused else status.get(value.phase,"")
	if value.get("drag") is Dictionary:
		hud_nodes.power.text="POWER  %d%%" % mini(100,int(Vector2(value.drag.dx,value.drag.dy).length()))
		hud_nodes.status.text="蓄力中"
	else:hud_nodes.power.text="POWER  0%"
	var key := JSON.stringify([value.skills,value.slots])
	if queue_key!=key and not catalog.is_empty():
		queue_key=key
		var old_slots:Dictionary={}
		var old_faces:Dictionary={}
		var reusable:Dictionary={}
		for child in queue.get_children():
			var old_id:String=child.get_meta("skill_id","")
			if old_id!="":
				var displayed:Control=queue_ghosts.get(old_id,child)
				old_slots[old_id]=Motion.pose_in(motion_layer,displayed)
				# A hidden layout slot still represents a fully visible card.
				if displayed==child:old_slots[old_id].alpha=1.0
				if old_id in value.skills:
					reusable[old_id]=child
					if not value.reduced:
						old_faces[old_id]=Motion.copy(displayed)
						var outgoing_next:bool=value.skills.find(old_id)==0 and value.skills.size()>=value.slots
						old_faces[old_id].set_meta("queue_crossfade",child.get_meta("queue_outgoing",false)!=outgoing_next)
		_clear_queue_motion()
		for child in queue.get_children():
			var old_id:String=child.get_meta("skill_id","")
			if old_id!="" and old_id not in value.skills and not value.reduced:
				Motion.mount(motion_layer,child,old_slots[old_id]);_ignore_pointer(child)
				if old_id==pending_swap_from:Motion.fold(child,0);Motion.fade(child,0.0,.26).tween_callback(child.queue_free)
				else:Motion.dismiss(child,0,-1,.42);Motion.fade(child,0.0,.42).tween_callback(child.queue_free)
		for child in queue.get_children():
			queue.remove_child(child)
			if not reusable.has(child.get_meta("skill_id","")):child.queue_free()
		for index in range(value.slots):
			var id: String=value.skills[index] if index<value.skills.size() else ""
			var outgoing:bool=index==0 and value.skills.size()>=value.slots
			var slot:Button=reusable.get(id)
			var fresh:=slot==null
			if fresh:
				slot=Button.new();slot.custom_minimum_size=Vector2(88,29);slot.add_theme_font_size_override("font_size",11);slot.disabled=id==""
			slot.name="LiveSlot%d" % index
			queue.add_child(slot)
			if fresh:
				slot.set_meta("skill_id",id)
				var inset:MarginContainer=visuals.margin(slot,5,6,5,6);var line:HBoxContainer=visuals.row(inset,5)
				if id!="":visuals.image(line,catalog[id].icon,Color(catalog[id].color),Vector2(15,15));slot.pressed.connect(func():opening_control=slot;_detail(id))
				var name_label:Label=visuals.text(line,catalog[id].name if id!="" else "等待加入",11,"warm-ink" if outgoing else "text-2",true,true)
				name_label.name="SlotTitle";name_label.custom_minimum_size.x=51
				visuals.pointer_through(inset)
			if fresh or slot.get_meta("queue_outgoing",false)!=outgoing:
				slot.set_meta("queue_outgoing",outgoing)
				slot.add_theme_stylebox_override("normal",visuals.box(visuals.color("warm-soft" if outgoing else "surface-2"),visuals.color("warm-line" if outgoing else "line-2"),5,5));slot.add_theme_stylebox_override("disabled",visuals.box(Color.TRANSPARENT,visuals.color("line-2"),5,5))
				var title:Label=slot.find_child("SlotTitle",true,false);title.add_theme_color_override("font_color",visuals.color("warm-ink" if outgoing else "text-2"))
			slot.modulate.a=1.0
			if not value.reduced and old_slots.has(id):
				var ghost:Control=old_faces[id]
				Motion.mount(motion_layer,ghost,old_slots[id]);_ignore_pointer(ghost)
				queue_ghosts[id]=ghost;slot.modulate.a=0
			elif not value.reduced and choosing and value.phase=="entering" and id!="":slot.modulate.a=0
			elif not value.reduced and id!="" and id==pending_swap_id:
				slot.set_meta("swap_arrival",true);slot.modulate.a=0
		for old_id in old_faces:
			if not queue_ghosts.has(old_id) and is_instance_valid(old_faces[old_id]):old_faces[old_id].queue_free()
		if not value.reduced:_move_queue.call_deferred(queue_motion_serial,key)
		pending_swap_id="";pending_swap_from=""
	_update_charges(value)
	_update_modal_gauges(value)
	_update_boss(value)
	if notices!=null:notices.present(value)
	if value.phase=="draft" and not value.transition.holdDraft and not catalog.is_empty() and not choosing:
		var next_key := JSON.stringify(value.draft)
		if modal_kind in ["","draft"] and (next_key!=draft_key or modal_kind==""): draft_key=next_key;_draft()
	elif modal_kind=="draft" and not choosing: _close()
	_update_report(value)
	_update_wipe(value)
	_update_pause(value)
	if modal_kind=="shop" and shop_state!=JSON.stringify([value.shop,value.coins,value.phase,value.paused,value.theme]):_shop()
	if modal_kind=="detail" and detail_state!=JSON.stringify([value.swapOffer,value.rerolls,value.canSwap,value.theme]):_detail(detail_id)
	if modal_kind=="library":pages.setup(self);pages.update_library()
	if modal_kind in ["equipment","achievements"]:pages.setup(self);pages.update_equipment()
	if achievement_cards!=null:
		achievement_cards.blocked=value.paused or modal_kind!=""
		achievement_cards.reduced=value.reduced
		if value.level<last_level:achievement_cards.clear()
	last_level=value.level

func _combo_heat(value:Dictionary,score:Dictionary) -> int:
	if value.phase!="flying":return 0
	var kills:=int(score.get("kills",0))
	var cap:=int(score.get("capKills",value.preview.capKills))
	return 3 if kills>=cap else 2 if kills>=maxi(5,int(ceil(cap*.66))) else 1 if kills>=4 else 0

func _update_combo(value:Dictionary,score:Dictionary) -> void:
	var kills:=int(score.get("kills",0));var cap:=maxi(1,int(score.get("capKills",value.preview.capKills)))
	var active:bool=kills>0 and value.phase in ["ready","flying"]
	var capped:=kills>=cap
	var heat:=_combo_heat(value,score)
	var ink:Color=visuals.color("text-3" if not active else "heat-%d" % heat if heat>0 else "gold-ink" if capped else "heat-0")
	var count:Label=hud_nodes.combo
	var stamp:="%s:%d" % [score.get("id",0),kills]
	var fresh:=combo_stamp==""
	var switched:=fresh or combo_stamp.get_slice(":",0)!=stamp.get_slice(":",0)
	count.text=str(kills);hud_nodes.mult.text="×%s" % _compact(score.get("baseMult",1.0))
	if stamp!=combo_stamp or value.reduced:
		Motion.meter(hud_nodes.combo_progress,100.0*kills/cap,.32,value.reduced or switched)
		if value.reduced:
			Motion.stop(count);count.position=Vector2(294,110);count.scale=Vector2.ONE;count.modulate.a=1
		elif not fresh:
			Motion.pivot(count)
			if switched:
				count.position=Vector2(294,115);count.scale=Vector2.ONE*.85;count.modulate.a=.3
				Motion.travel(count,Vector2(294,110),.22);Motion.fade(count,1,.22)
			else:count.scale=Vector2.ONE*1.2
			var tween:=Motion.claim(count,["scale"])
			var start:=count.scale
			tween.tween_method(func(p:float):count.scale=start.lerp(Vector2.ONE,Easing.bezier(p,.2,.8,.2,1)),0.0,1.0,.22)
		combo_stamp=stamp
	if combo_ink!=ink or value.reduced:
		var start:=ink if combo_ink==Color.TRANSPARENT or value.reduced else count.get_theme_color("font_color")
		combo_ink=ink
		Motion.cancel(count,["ink"])
		if value.reduced or fresh:_paint_combo(ink)
		else:Motion.claim(count,["ink"]).tween_method(func(p:float):_paint_combo(start.lerp(ink,p)),0.0,1.0,.25)
	var spark:Label=hud_nodes.combo_spark
	var shown:=active and capped
	if spark.get_meta("shown",false)!=shown or value.reduced:
		spark.set_meta("shown",shown)
		if value.reduced:Motion.stop(spark);spark.modulate.a=1.0 if shown else 0.0;spark.scale=Vector2.ONE
		else:
			Motion.fade(spark,1.0 if shown else 0.0,.25)
			if shown:Motion.pulse(spark,1.3)

func _paint_combo(ink:Color) -> void:
	hud_nodes.combo.add_theme_color_override("font_color",ink)
	hud_nodes.mult.add_theme_color_override("font_color",ink)
	var fill:StyleBoxFlat=hud_nodes.combo_progress.get_theme_stylebox("fill")
	fill.bg_color=ink

func _process(delta: float) -> void:
	if achievement_cards!=null:
		var active:bool=achievement_cards.card!=null
		for token in ["earnings","earnings_label"]:
			if not hud_nodes.has(token):continue
			var node:Control=hud_nodes[token]
			var opacity:=0.0 if active else 1.0
			node.modulate.a=opacity if frame.get("reduced",false) else lerpf(node.modulate.a,opacity,1-exp(-delta/0.085))
			var target_y:=845.0 if active else 850.0
			if token=="earnings":node.position.y=target_y if frame.get("reduced",false) else lerpf(node.position.y,target_y,1-exp(-delta/0.085))
	for token in ["wallet","earnings","receipt"]:
		if not hud_targets.has(token) or not hud_nodes.has(token):continue
		var target:float=hud_targets[token]
		var shown:float=hud_shown[token]
		shown=lerpf(shown,target,1-exp(-delta/0.085))
		if absf(target-shown)<1:shown=target
		hud_shown[token]=shown
		var text:=_counter_text(token,shown)
		if hud_nodes[token].text!=text:hud_nodes[token].text=text
	if wipe_layer!=null:
		wipe_age+=delta
		_paint_wipe()
	if toast_time>0:
		toast_time=maxf(0,toast_time-delta)
		if toast_time==0 and hud_nodes.has("toast"):
			if frame.get("reduced",false):hud_nodes.toast.modulate.a=0
			else:Motion.fade(hud_nodes.toast,0,.22)
	if layout_pending:
		layout_pending=false;_center()

func _set_level(text:String,reduced:bool) -> void:
	var label:Label=hud_nodes.level
	if label.text==text:
		hud_values.level=text
		if reduced:Motion.stop(label);label.position=Vector2(58,56);label.scale=Vector2.ONE;label.modulate.a=1.0
		return
	if not hud_values.has("level") or reduced:
		Motion.stop(label);label.position=Vector2(58,56);label.scale=Vector2.ONE;label.modulate.a=1.0
		label.text=text;hud_values.level=text;return
	var direction:=1.0 if int(text)>=int(label.text) else -1.0
	if is_instance_valid(level_ghost):Motion.fade(level_ghost,0.0,.15).tween_callback(level_ghost.queue_free)
	var ghost:=Motion.copy(label)
	Motion.mount(motion_layer,ghost,Motion.pose_in(motion_layer,label));_ignore_pointer(ghost);level_ghost=ghost
	Motion.travel(ghost,ghost.position+Vector2(0,-direction*27),.42)
	Motion.fade(ghost,0.0,.42).tween_callback(ghost.queue_free)
	Motion.stop(label);label.scale=Vector2.ONE;label.rotation=0
	label.text=text;label.position=Vector2(58,56+direction*27);label.modulate.a=0
	Motion.travel(label,Vector2(58,56),.52,.07,true);Motion.fade(label,1.0,.3,.07)
	hud_values.level=text

func _retire_copy(node:Control,duration:float=.22) -> void:
	if not is_instance_valid(node):return
	var clip:=Rect2(Vector2.ZERO,motion_layer.size)
	var order:=node.z_index
	var relative:=node.z_as_relative
	var ancestor:=node.get_parent()
	while ancestor!=null:
		if ancestor is Control and ancestor.clip_contents:clip=clip.intersection(Motion.rect_in(motion_layer,ancestor))
		if relative and ancestor is CanvasItem:
			order+=ancestor.z_index;relative=ancestor.z_as_relative
		ancestor=ancestor.get_parent()
	if not clip.has_area():return
	var holder:=Control.new();holder.position=clip.position;holder.size=clip.size;holder.clip_contents=true;holder.mouse_filter=Control.MOUSE_FILTER_IGNORE
	holder.z_as_relative=false;holder.z_index=clampi(order,-4096,4096);motion_layer.add_child(holder)
	var ghost:=Motion.copy(node)
	Motion.mount(holder,ghost,Motion.pose_in(holder,node));_ignore_pointer(ghost)
	ghost.z_index=0
	ghost.z_as_relative=true
	Motion.fade(ghost,0.0,duration).tween_callback(holder.queue_free)

func _restore_layout(poses:Dictionary) -> void:
	await get_tree().process_frame
	for node in poses:
		if not is_instance_valid(node) or node.is_queued_for_deletion():continue
		var pose:Dictionary=poses[node]
		var parent:Control=node.get_parent()
		var center:Vector2=parent.get_global_transform().affine_inverse()*(motion_layer.get_global_transform()*pose.center)
		var old_position:Vector2=center-node.size/2
		var target_position:=Vector2.ZERO
		node.position=old_position
		Motion.travel(node,target_position,.28)

func _update_modal_gauges(value:Dictionary) -> void:
	var sheets:Array=[]
	if panel!=null:sheets.append(panel)
	for entry in modal_stack:sheets.append(entry.panel)
	for sheet in sheets:
		var gauges:Array=sheet.get_meta("gauges",[])
		for gauge in gauges:
			if is_instance_valid(gauge):gauge.set_amount(int(value.rerolls),float(value.rerollProgress),value.reduced)
	if panel!=null:
		pages.setup(self)
		pages.update_reroll(modal_content.find_child("Reroll",true,false),modal_kind=="draft")

func _count_target(token:String,value:float,reduced:bool) -> void:
	var fresh:=not hud_targets.has(token)
	var changed:bool=not fresh and hud_targets[token]!=value
	if fresh or reduced:hud_shown[token]=value
	hud_targets[token]=value
	if fresh or reduced:
		hud_nodes[token].text=_counter_text(token,value)
	elif changed:Motion.pulse(hud_nodes[token],1.07 if token=="wallet" else 1.12)

func _counter_text(token:String,value:float) -> String:
	return "+ "+pages.fmt(value) if token=="earnings" else "+"+pages.fmt(value) if token=="receipt" else pages.fmt(value)

func _clear_queue_motion() -> void:
	queue_motion_serial+=1
	for ghost in queue_ghosts.values():
		if is_instance_valid(ghost):Motion.stop(ghost);ghost.queue_free()
	queue_ghosts.clear()

func _move_queue(serial_value:int,key:String) -> void:
	await get_tree().process_frame
	if queue_key!=key or serial_value!=queue_motion_serial:return
	for slot in queue.get_children():
		var id:String=slot.get_meta("skill_id","")
		if slot.get_meta("swap_arrival",false):
			slot.remove_meta("swap_arrival")
			var ghost:Control=Motion.copy(slot)
			var pose:=Motion.pose_in(motion_layer,slot);pose.alpha=1.0
			Motion.mount(motion_layer,ghost,pose);Motion.prepare_deal(ghost);Motion.deal(ghost,0)
			queue_ghosts[id]=ghost
			var arrival:Tween=Motion.claim(ghost,["arrival"])
			arrival.tween_interval(.44)
			arrival.tween_callback(func():
				if serial_value==queue_motion_serial:
					if is_instance_valid(slot):slot.modulate.a=1.0
					queue_ghosts.erase(id)
				if is_instance_valid(ghost):ghost.queue_free()
			)
			continue
		if not queue_ghosts.has(id):continue
		var previous_face:Control=queue_ghosts[id]
		var after:=Motion.rect_in(motion_layer,slot)
		if not previous_face.get_meta("queue_crossfade",false):
			var move:=Motion.claim(previous_face,["position","scale","rotation"]).set_parallel()
			move.tween_property(previous_face,"position",after.get_center()-previous_face.size/2,.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			move.tween_property(previous_face,"scale",after.size/previous_face.size.max(Vector2.ONE),.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			move.tween_property(previous_face,"rotation",0.0,.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			move.chain().tween_callback(func():
				if serial_value==queue_motion_serial:
					if is_instance_valid(slot):slot.modulate.a=1.0
					queue_ghosts.erase(id)
				if is_instance_valid(previous_face):previous_face.queue_free()
			)
			continue
		# Move a neutral shell. The old outgoing-slot tint dissolves into the
		# new resting face while both share exactly the same moving transform.
		var ghost:=Control.new();ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var pose:=Motion.pose_in(motion_layer,previous_face);pose.alpha=1.0
		Motion.mount(motion_layer,ghost,pose)
		var visible_pose:=Motion.pose_in(ghost,previous_face)
		Motion.mount(ghost,previous_face,visible_pose);previous_face.z_index=0
		var next_face:=Motion.copy(slot);next_face.size=slot.size;next_face.position=(ghost.size-next_face.size)/2;next_face.pivot_offset=next_face.size/2
		next_face.scale=ghost.size/next_face.size.max(Vector2.ONE);next_face.modulate.a=0;ghost.add_child(next_face)
		queue_ghosts[id]=ghost
		Motion.fade(previous_face,0.0,.18,.2);Motion.fade(next_face,1.0,.18,.2)
		var tween:=Motion.claim(ghost,["position","scale","rotation"]).set_parallel()
		tween.tween_property(ghost,"position",after.get_center()-ghost.size/2,.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(ghost,"scale",after.size/ghost.size.max(Vector2.ONE),.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(ghost,"rotation",0.0,.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.chain().tween_callback(func():
			if serial_value==queue_motion_serial:
				if is_instance_valid(slot):slot.modulate.a=1
				queue_ghosts.erase(id)
			if is_instance_valid(ghost):ghost.queue_free()
		)

func _update_boss(value: Dictionary) -> void:
	var active:bool=value.bossStatus is Dictionary
	for key in ["core_label","core_value","progress"]:hud_nodes[key].visible=not active
	if not active:
		if boss_bar!=null:boss_bar.queue_free();boss_bar=null
		boss_key="";return
	var status:Dictionary=value.bossStatus
	var token:String={"forge":"warm-ink","serpent":"legend-frost","clock":"gold-ink"}.get(value.boss.boss,"legend-prism")
	var key:=JSON.stringify([value.boss.boss,status.phases,value.theme])
	var fresh:=boss_bar==null or boss_key!=key
	if fresh:
		boss_key=key;boss_nodes.clear()
		if boss_bar!=null:remove_child(boss_bar);boss_bar.queue_free()
		boss_bar=HBoxContainer.new();boss_bar.position=Vector2(16,149);boss_bar.size=Vector2(380,14);boss_bar.add_theme_constant_override("separation",8);add_child(boss_bar)
		visuals.text(boss_bar,"◆ "+status.name,10,token,true)
		boss_nodes.phase=visuals.text(boss_bar,"",10,"text-3")
		var segments:HBoxContainer=visuals.row(boss_bar,3);segments.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		boss_nodes.meters=[]
		for i in range(int(status.phases)):
			var meter:=ProgressBar.new();meter.show_percentage=false;meter.custom_minimum_size=Vector2(6,6);meter.size_flags_horizontal=Control.SIZE_EXPAND_FILL;meter.max_value=1
			meter.add_theme_stylebox_override("background",visuals.box(visuals.mix(visuals.color(token),visuals.color("surface"),.18),Color.TRANSPARENT,2))
			meter.add_theme_stylebox_override("fill",visuals.box(visuals.color(token),Color.TRANSPARENT,2));segments.add_child(meter);boss_nodes.meters.append(meter)
		boss_nodes.status=visuals.text(boss_bar,"",10,token,true)
		boss_nodes.resist=visuals.text(boss_bar,"",10,"text-3",true)
		visuals.pointer_through(boss_bar)
	boss_nodes.phase.text="%d/%d %s" % [value.boss.phase,status.phases,status.phaseName]
	boss_nodes.status.text=status.text
	boss_nodes.status.add_theme_color_override("font_color",visuals.color("danger" if status.state in ["exposed","dying"] else token))
	boss_nodes.resist.visible=status.resist>=10;boss_nodes.resist.text="减伤 %d%%" % status.resist
	for i in range(boss_nodes.meters.size()):
		var phase:int=int(status.phases)-i
		var target:float=0 if phase<value.boss.phase else 1 if phase>value.boss.phase else float(value.boss.hp)/maxf(1,value.boss.max)
		var meter:ProgressBar=boss_nodes.meters[i]
		if meter.get_meta("target",-1.0)!=target:
			Motion.meter(meter,target,.12,value.reduced or fresh);meter.set_meta("target",target)

func _update_report(value: Dictionary) -> void:
	var report=value.transition.report
	if value.phase!="clearing" or not report is Dictionary:
		if report_layer!=null:
			_ignore_pointer(report_layer)
			if value.reduced:report_layer.queue_free()
			else:Motion.leave(report_layer,.24)
			report_layer=null
		report_key=""
		return
	var key=JSON.stringify([report,value.theme])
	if key==report_key:return
	report_key=key
	if report_layer!=null:report_layer.queue_free()
	report_layer=Control.new();report_layer.position=Vector2(0,238);report_layer.size=Vector2(412,572);report_layer.z_index=8;report_layer.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(report_layer)
	report_view.v=visuals;report_view.build(report_layer,report,value.transition.get("bonus",value.preview.bonus))
	if not value.reduced:
		report_view.animate.call_deferred(report_layer,report)
		var coins:=Flights.new();coins.setup(Vector2(206,500),hud_nodes.wallet.get_rect().get_center());motion_layer.add_child(coins)
	_ignore_pointer(report_layer)
	report_layer.mouse_filter=Control.MOUSE_FILTER_STOP
	report_layer.gui_input.connect(func(event):if event is InputEventMouseButton and event.pressed:_skip_clear())

func _update_charges(value: Dictionary) -> void:
	var key:=JSON.stringify([value.rerolls,value.rerollCap,value.rerollProgress,value.theme])
	if key==charge_key:return
	charge_key=key
	if charge_tab==null or charge_tab.get_meta("capacity",0)!=int(value.rerollCap) or charge_tab.get_meta("theme","")!=value.theme:
		if charge_tab!=null:charge_tab.queue_free()
		charge_tab=PanelContainer.new();charge_tab.position=Vector2(350-int(value.rerollCap)*12,173);charge_tab.z_index=2
		charge_tab.set_meta("capacity",int(value.rerollCap));charge_tab.set_meta("theme",value.theme)
		charge_tab.add_theme_stylebox_override("panel",visuals.box(visuals.color("surface"),visuals.color("line-2"),10,3));add_child(charge_tab)
		var line:HBoxContainer=visuals.row(charge_tab,5);visuals.image(line,"refresh-cw",visuals.color("accent-ink"),Vector2(11,11))
		pages.setup(self);charge_gauge=pages.charges(line,0,9,3)
		visuals.pointer_through(charge_tab)
	charge_gauge.set_amount(int(value.rerolls),float(value.rerollProgress),value.reduced)

func _update_pause(value: Dictionary) -> void:
	if not value.paused or modal_kind!="" or value.phase=="draft":
		if pause_layer!=null:
			_ignore_pointer(pause_layer)
			if value.reduced:pause_layer.queue_free()
			else:
				var content:Control=pause_layer.get_meta("pause_content") if pause_layer.has_meta("pause_content") else null
				if content!=null:Motion.fade(content,0.0,.2)
				Motion.backdrop(pause_layer,0.0,.24,true)
			pause_layer=null
		return
	if pause_layer!=null:return
	pause_layer=ColorRect.new();pause_layer.color=visuals.color("overlay");pause_layer.position=Vector2(0,238);pause_layer.size=Vector2(412,572);pause_layer.z_index=9;add_child(pause_layer)
	if DisplayServer.get_name()!="headless":
		var material:=ShaderMaterial.new();material.shader=WEB_MODAL_BLUR if OS.has_feature("web") else MODAL_BLUR;material.set_shader_parameter("tint",visuals.color("overlay"));material.set_shader_parameter("blur",3.0);pause_layer.material=material;pause_layer.color=Color.WHITE
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);pause_layer.add_child(center)
	var column:VBoxContainer=visuals.column(center,12)
	pause_layer.set_meta("pause_content",column)
	for item in [["TAKE A BREATH",10,"text-3"],["暂停一下",28,"ink"],["这一箭，等你回来。",12,"text-3"]]:
		var label:Label=visuals.text(column,item[0],item[1],item[2],item[1]==28);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	visuals.space(column,12)
	var resume:Button=visuals.button(column,"继续游戏",func():action.emit("pause",{"paused":false}),"play",44);resume.add_theme_stylebox_override("normal",visuals.box(visuals.color("accent"),Color.TRANSPARENT,5,10));resume.add_theme_color_override("font_color",visuals.color("on-accent"));resume.add_theme_color_override("font_focus_color",visuals.color("on-accent"));resume.icon=visuals.icon("play",visuals.color("on-accent"));resume.grab_focus()
	if not value.reduced:
		pause_layer.set_meta("backdrop_amount",0.0)
		if pause_layer.material!=null:pause_layer.material.set_shader_parameter("amount",0.0)
		else:pause_layer.modulate.a=0.0
		Motion.backdrop(pause_layer,1.0,.32);Motion.enter(column)

func _preview_skill(id: String,force:bool=false) -> void:
	if modal_kind!="draft" or modal_content==null:return
	if not force and (choosing or rolling or preview_id==id):return
	preview_id=id
	var loadout:Control=modal_content.get_node_or_null("Loadout")
	if loadout==null:return
	var at:int=0 if frame.skills.size()>=frame.slots else frame.skills.size()
	var slot:PanelContainer=loadout.find_child("Slot%d" % at,true,false)
	if slot==null:return
	if not frame.reduced:_retire_copy(slot,.16)
	for child in slot.get_children():slot.remove_child(child);child.queue_free()
	var outgoing:bool=frame.skills.size()>=frame.slots
	var original:String=frame.skills[at] if at<frame.skills.size() else ""
	var shown:String=id if id!="" else original
	var face:Color=visuals.color("warm-soft" if outgoing else "surface-2" if shown=="" else "surface")
	var edge:Color=visuals.color("warm-line" if outgoing else "line-2")
	if id!="":face=visuals.mix(Color(catalog[id].color),visuals.color("surface"),.10);edge=visuals.mix(Color(catalog[id].color),visuals.color("line-2"),.60)
	slot.add_theme_stylebox_override("panel",visuals.box(face,edge,7,6))
	var row:HBoxContainer=visuals.row(slot,5)
	if shown!="":visuals.image(row,catalog[shown].icon,Color(catalog[shown].color),Vector2(15,15))
	visuals.text(row,catalog[shown].name if shown!="" else "等待加入",11,"warm-ink" if outgoing else "text-2",true,true)
	if id!="" or outgoing:
		var tip:=PanelContainer.new();tip.position=Vector2(maxf(0,slot.size.x-70),-10);tip.add_theme_stylebox_override("panel",visuals.box(visuals.color("surface"),edge,8,2));slot.add_child(tip)
		visuals.text(tip,"换入" if outgoing and id!="" else "将替换" if outgoing else "放这里",9,"ink",true)
	if not frame.reduced:
		slot.modulate.a=0;Motion.fade(slot,1.0,.18)

func _ignore_pointer(node: Node) -> void:
	if node is Control:
		node.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if node.has_focus():node.release_focus()
		node.focus_mode=Control.FOCUS_NONE
	for child in node.get_children():_ignore_pointer(child)

func _skip_clear() -> void:
	action.emit("skipClear",{})

func _update_wipe(value:Dictionary) -> void:
	var info=value.transition.wipe
	if not info is Dictionary:
		if wipe_layer!=null:wipe_layer.queue_free();wipe_layer=null
		wipe_key="";return
	var key=JSON.stringify(info)
	if wipe_key!=key:
		wipe_key=key
		wipe_age=maxf(0,(float(value.transition.clock)-float(info.at))/1000.0)
		if wipe_layer!=null:wipe_layer.queue_free()
		wipe_layer=Control.new();wipe_layer.position=Vector2(0,238);wipe_layer.size=Vector2(412,572);wipe_layer.z_index=14;wipe_layer.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(wipe_layer)
		for i in range(2):
			var clip:=Control.new();clip.name="Clip%d" % i;clip.clip_contents=true;clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;wipe_layer.add_child(clip)
			var sheet:=ColorRect.new();sheet.size=Vector2(412,572);sheet.color=visuals.color("accent-bar" if i==0 else "panel");sheet.mouse_filter=Control.MOUSE_FILTER_IGNORE;clip.add_child(sheet)
			if i==1:
				var title:=visuals.label(info.eyebrow,13,"accent-bar",true);title.position=Vector2(0,218);title.size.x=412;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;sheet.add_child(title)
				var digits:=visuals.label("%02d  →  %02d" % [info.from,info.to],64,"on-panel",true);digits.position=Vector2(0,250);digits.size.x=412;digits.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;sheet.add_child(digits)
				var note:=visuals.label(info.note,12,"on-panel-2");note.position=Vector2(0,330);note.size.x=412;note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;sheet.add_child(note)
	_paint_wipe()

func _paint_wipe() -> void:
	if wipe_layer==null:return
	for i in range(2):
		var clip:Control=wipe_layer.get_node("Clip%d" % i)
		var age:float=(wipe_age-i*.07)/1.05
		var p:float=Easing.bezier(clampf(age,0,1),.65,0,.35,1)
		var left:float=clampf((p-.62)/.38,0,1)*412
		var right:float=clampf(p/.34,0,1)*412
		clip.position=Vector2(left,0);clip.size=Vector2(maxf(0,right-left),572);clip.get_child(0).position.x=-left

func _compact(value: float) -> String:
	return String.num(value,3)

func _open(title: String,kind: String,pause_game: bool=false) -> void:
	var first := panel==null
	var retained_opener:=Rect2()
	var backdrop_from:float=0.0 if first else scrim.get_meta("backdrop_amount",1.0)
	sheet_serial+=1
	morph_from=Motion.rect_in(self,panel) if panel!=null else Rect2()
	morph_scroll=modal_scroll.scroll_vertical if panel!=null and kind==modal_kind else 0
	if first: restore_pause=bool(frame.get("paused",false))
	if panel!=null:
		if kind==modal_kind or kind in ["equipment","achievements"] and modal_kind in ["equipment","achievements"]:
			var original_opener:Variant=panel.get_meta("opener") if panel.has_meta("opener") else null
			opening_control=original_opener if is_instance_valid(original_opener) and not original_opener.is_queued_for_deletion() else null
			retained_opener=panel.get_meta("opener_rect",Rect2())
			if not frame.get("reduced",false):_retire_copy(panel,.22)
			remove_child(panel);panel.queue_free();remove_child(scrim);scrim.queue_free()
		else:
			# Covered sheets keep their nodes and transform. Returning to them
			# does not reconstruct content or restart unfinished card reels.
			var focus:Control=get_viewport().gui_get_focus_owner()
			if focus!=null and panel.is_ancestor_of(focus):focus.release_focus()
			Motion.focus_gate(panel,true)
			if not frame.get("reduced",false):
				var cover:=Motion.claim(panel,["scale"])
				cover.tween_property(panel,"scale",Vector2.ONE*.94,.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				Motion.fade(panel,.92,.32)
			modal_stack.append({"panel":panel,"scrim":scrim,"content":modal_content,"scroll":modal_scroll,"kind":modal_kind,"padding":modal_padding,"width":modal_width,"focus":focus})
			morph_from=Rect2()
			backdrop_from=0.0
	rolling=false
	modal_kind=kind
	modal_enter_pending=not morph_from.has_area()
	modal_width=250 if kind=="reset" else 388 if kind=="shop" else 380
	modal_padding=31 if kind=="reset" else 25 if kind=="shop" else 23 if kind=="settings" else 21 if kind in ["equipment","achievements"] else 19 if kind=="detail" else 17
	var depth:=modal_stack.size()*2
	scrim=ColorRect.new();scrim.size=Vector2(412,915);scrim.z_index=11+depth;scrim.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(scrim)
	# Chromium 89 computes a transparent dialog backdrop: ::backdrop does not
	# inherit the custom properties. Preserve that measured reference here.
	var tint:=Color.TRANSPARENT
	scrim.color=tint
	if DisplayServer.get_name()!="headless":
		var material:=ShaderMaterial.new();material.shader=WEB_MODAL_BLUR if OS.has_feature("web") else MODAL_BLUR;material.set_shader_parameter("tint",tint);material.set_shader_parameter("blur",3.0 if kind=="draft" else 2.5);scrim.material=material;scrim.color=Color.WHITE
	if not frame.get("reduced",false):
		scrim.set_meta("backdrop_amount",backdrop_from)
		if scrim.material!=null:scrim.material.set_shader_parameter("amount",backdrop_from)
		else:scrim.modulate.a=backdrop_from
		Motion.backdrop(scrim,1.0,.26)
	scrim.gui_input.connect(func(event):if kind!="draft" and event is InputEventMouseButton and event.pressed:_close())
	panel=Sheet.new();panel.z_index=12+depth;panel.position=Vector2((412-modal_width)/2,100);add_child(panel)
	panel.setup(visuals.box(visuals.color("surface"),visuals.color("line-2" if kind in ["draft","library","detail"] else "line"),12 if kind=="draft" else 8,0),modal_width,modal_padding)
	modal_scroll=panel.scroll;modal_content=panel.content
	var source:Control=opening_control if is_instance_valid(opening_control) else visuals.last_trigger if is_instance_valid(visuals.last_trigger) else get_viewport().gui_get_focus_owner()
	if retained_opener.has_area():
		panel.set_meta("opener_rect",retained_opener)
		if is_instance_valid(opening_control):panel.set_meta("opener",opening_control)
	elif is_instance_valid(source) and not panel.is_ancestor_of(source):
		panel.set_meta("opener",source);panel.set_meta("opener_rect",Motion.rect_in(self,source))
	opening_control=null;visuals.last_trigger=null
	modal_content.minimum_size_changed.connect(func():layout_pending=true)
	if not frame.get("reduced",false):panel.modulate.a=0
	if title!="": _label(title,22,true)
	if pause_game and not frame.get("paused",false): action.emit("pause",{"paused":true})
	_center.call_deferred()

func _center() -> void:
	if is_instance_valid(panel):visuals.button_states(panel)
	if panel==null: return
	var dimensions:Vector2=panel.desired_size()
	var destination:=Vector2((412-modal_width)/2,maxf(8,(915-dimensions.y)/2))
	var previous:Vector2=panel.get_meta("layout_size",Vector2.ZERO)
	panel.set_meta("layout_position",destination);panel.set_meta("layout_size",dimensions)
	if frame.get("reduced",false):
		Motion.stop(panel);panel.size=dimensions;panel.pivot_offset=dimensions/2;panel.position=destination;panel.scale=Vector2.ONE;panel.modulate.a=1;modal_enter_pending=false
	elif modal_enter_pending:
		panel.size=dimensions;panel.pivot_offset=dimensions/2;panel.position=destination
		panel.set_meta("motion_entered",true)
		var opener:Variant=panel.get_meta("opener") if panel.has_meta("opener") else null
		var rect:Rect2=Motion.rect_in(self,opener) if is_instance_valid(opener) else panel.get_meta("opener_rect",Rect2())
		if rect.has_area() and modal_kind!="draft":
			var k:=clampf(maxf(rect.size.x/dimensions.x,rect.size.y/maxf(1,dimensions.y)),.08,.6)
			panel.position=rect.get_center()-dimensions/2;panel.scale=Vector2.ONE*k
			Motion.travel(panel,destination,.46,0,true)
			var scaling:=Motion.claim(panel,["scale"])
			var start_scale:=panel.scale
			var sheet:=panel
			scaling.tween_method(func(p:float):sheet.scale=start_scale.lerp(Vector2.ONE,Easing.bezier(p,.2,1.3,.4,1)),0.0,1.0,.46)
			Motion.fade(panel,1.0,.16)
		else:
			panel.position+=Vector2(0,12);panel.scale=Vector2.ONE*.96
			Motion.travel(panel,destination,.38,0,true);Motion.enter(panel)
		modal_enter_pending=false
	elif morph_from.has_area() or not previous.is_equal_approx(dimensions):
		var sheet:=panel
		if not morph_from.has_area() and Motion.layout_active(modal_content) and (sheet.position+sheet.size/2).is_equal_approx(destination+dimensions/2):
			# The content's extent tween already supplies a smooth timeline.
			# Follow it once instead of restarting a second resize each frame.
			Motion.cancel(panel,["position","size"])
			sheet.size=dimensions;sheet.pivot_offset=dimensions/2;sheet.position=destination
			return
		if morph_from.has_area():
			sheet.size=Vector2(dimensions.x,morph_from.size.y);sheet.pivot_offset=sheet.size/2;sheet.position=morph_from.get_center()-sheet.size/2;sheet.modulate.a=0
		var start_size:=sheet.size
		var start_center:=sheet.position+sheet.size/2
		var end_center:=destination+dimensions/2
		var tween:=Motion.claim(sheet,["position","size"])
		tween.tween_method(func(p:float):
			var t:=Easing.bezier(p,.22,1,.36,1)
			sheet.size=start_size.lerp(dimensions,t);sheet.pivot_offset=sheet.size/2;sheet.position=start_center.lerp(end_center,t)-sheet.size/2
		,0.0,1.0,.32)
		if morph_from.has_area():Motion.fade(sheet,1.0,.24)
	morph_from=Rect2()
	if morph_scroll>=0:
		modal_scroll.set_deferred("scroll_vertical",morph_scroll);morph_scroll=-1

func _close(force_fold:bool=false) -> void:
	var was_paused := restore_pause
	var closing_kind:=modal_kind
	sheet_serial+=1;rolling=false
	morph_from=Rect2();morph_scroll=-1;modal_enter_pending=false
	modal_kind=""
	if panel!=null:
		if not frame.get("reduced",false):
			Motion.stop(panel);panel.set_meta("retiring",true)
			_ignore_pointer(panel)
			var opener:Variant=panel.get_meta("opener") if panel.has_meta("opener") else null
			var target:Rect2=Motion.rect_in(self,opener) if is_instance_valid(opener) and opener.is_visible_in_tree() else panel.get_meta("opener_rect",Rect2())
			if (not choosing or force_fold) and target.has_area() and closing_kind!="draft":
				var k:=clampf(maxf(target.size.x/maxf(1,panel.size.x),target.size.y/maxf(1,panel.size.y)),.08,.6)
				Motion.travel(panel,target.get_center()-panel.size/2,.25)
				Motion.claim(panel,["scale"]).tween_property(panel,"scale",Vector2.ONE*k,.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				Motion.fade(panel,0.0,.25).tween_callback(panel.queue_free)
			else:Motion.leave(panel,.22)
		else:remove_child(panel);panel.queue_free()
		panel=null
	if scrim!=null:
		# Fade the screen copy through the same retirement beat as the sheet.
		scrim.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if frame.get("reduced",false):remove_child(scrim);scrim.queue_free()
		else:Motion.backdrop(scrim,0.0,.25,true)
		scrim=null
	if not modal_stack.is_empty():
		var previous:Dictionary=modal_stack.pop_back()
		panel=previous.panel;scrim=previous.scrim;modal_content=previous.content;modal_scroll=previous.scroll;modal_kind=previous.kind;modal_padding=previous.padding;modal_width=previous.width
		Motion.focus_gate(panel,false)
		rolling=panel.get_meta("rolling",false)
		if modal_kind=="detail":
			detail_id=panel.get_meta("detail_id","");detail_theme=panel.get_meta("detail_theme",frame.theme);detail_state=""
		if modal_kind=="shop":
			pages.setup(self);pages.update_shop()
		elif modal_kind=="library":pages.setup(self);pages.update_library()
		elif modal_kind in ["equipment","achievements"]:pages.setup(self);pages.update_equipment()
		if not frame.get("reduced",false):
			var reveal:=Motion.claim(panel,["scale"])
			reveal.tween_property(panel,"scale",Vector2.ONE,.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Motion.fade(panel,1.0,.28)
		else:Motion.stop(panel);panel.scale=Vector2.ONE;panel.modulate.a=1
		var focus:Variant=previous.get("focus",null)
		if is_instance_valid(focus) and focus.is_visible_in_tree():_focus_card(focus)
		morph_scroll=-1
		_center.call_deferred()
		return
	modal_content=null;modal_scroll=null
	if frame.get("paused",false)!=was_paused: action.emit("pause",{"paused":was_paused})
	if pause_layer!=null:_update_pause(frame)

func _label(text: String,size: int=12,bold: bool=false) -> Label:
	var label := visuals.label(text,size,"ink",bold);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;modal_content.add_child(label);return label

func _choice(text: String,callback: Callable,disabled: bool=false) -> Button:
	var button := Button.new();button.text=text;button.custom_minimum_size=Vector2(360,42);button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.disabled=disabled;button.pressed.connect(callback);modal_content.add_child(button);return button

func _draft() -> void:
	preview_id=""
	if modal_kind=="draft" and panel!=null:
		pages.setup(self);pages.update_draft()
	else:
		_open("","draft")
		pages.setup(self);pages.draft()
		if not frame.reduced:_loadout_in.call_deferred(panel)
	_deal_cards.call_deferred(panel,"DraftOptions")

func _loadout_in(sheet:Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(sheet) or sheet!=panel:return
	var loadout:Control=sheet.find_child("Loadout",true,false)
	if loadout==null:return
	for index in range(int(frame.slots)):
		var slot:Control=loadout.find_child("Slot%d" % index,true,false)
		if slot!=null:Motion.enter(slot,.09+index*.045)

func _select(id: String) -> void:
	if choosing or rolling or modal_kind!="draft" or not frame.draft is Dictionary or not id in frame.draft.options:return
	choosing=true;action.emit("cue",{"type":"pick","n":{"blue":1,"gold":2}.get(catalog[id].tier,0)})
	var sheet:=panel
	var card:Button=modal_content.find_child("Skill_"+id,true,false)
	if frame.reduced or card==null:
		_close();action.emit("choose",{"id":id});choosing=false;return
	var options:Control=modal_content.find_child("DraftOptions",true,false)
	for other in Motion.cards(options):
		other.disabled=true;other.add_theme_stylebox_override("disabled",other.get_theme_stylebox("normal"))
		if other!=card:Motion.dismiss(other,0,-1 if other.get_parent().get_index()<card.get_parent().get_index() else 1)
	Motion.pulse(card,1.04);Motion.travel(card,Vector2(0,-10),.3,0,true)
	for name in ["DraftHeader","Loadout","Reroll"]:
		var node:Control=modal_content.find_child(name,true,false)
		if node!=null:Motion.fade(node,0.0,.22)
	await get_tree().create_timer(.39).timeout
	if not is_instance_valid(card) or sheet!=panel or modal_kind!="draft":
		if is_instance_valid(card) and is_instance_valid(sheet) and not sheet.get_meta("retiring",false):
			for other in Motion.cards(options):other.disabled=false;Motion.restore(other)
			for name in ["DraftHeader","Loadout","Reroll"]:
				var node:Control=sheet.find_child(name,true,false)
				if node!=null:Motion.fade(node,1.0,.18)
		choosing=false;return
	var from:=Motion.rect_in(motion_layer,card)
	var source:=Motion.pose_in(motion_layer,card)
	# The selected card is no longer used by the retiring sheet. Move its
	# already-shaped native controls instead of cloning/re-shaping Chinese
	# text on the exact frame the flight begins.
	var flying_card:Control=card
	Motion.stop(flying_card)
	Motion.mount(motion_layer,flying_card,source);flying_card.z_index=32;_ignore_pointer(flying_card)
	_close();action.emit("choose",{"id":id});action.emit("holdEntrance",{})
	var serial_value:=sheet_serial
	await get_tree().process_frame
	if serial_value!=sheet_serial or not is_instance_valid(flying_card):
		if is_instance_valid(flying_card):flying_card.queue_free()
		action.emit("landEntrance",{});choosing=false;return
	var at:int=frame.skills.size()-1
	var slot:Control=queue.get_node_or_null("LiveSlot%d" % at)
	if slot==null:flying_card.queue_free();action.emit("landEntrance",{});choosing=false;return
	var target:=Motion.rect_in(motion_layer,slot)
	slot.modulate.a=0
	action.emit("cue",{"type":"whoosh"})
	var slot_face:=Motion.copy(slot)
	_ignore_pointer(slot_face);slot_face.modulate.a=0
	var flight:=Motion.card_flight(motion_layer,flying_card,slot_face,from,target,.64,source)
	# A fixed lifetime also resolves an interrupted tween; kill() does not
	# emit finished, so awaiting that signal alone could strand choosing.
	await get_tree().create_timer(.64).timeout
	if is_instance_valid(flight):flight.queue_free()
	if not is_instance_valid(slot) or serial_value!=sheet_serial:
		if is_instance_valid(slot):slot.modulate.a=1
		action.emit("landEntrance",{});choosing=false;return
	slot.modulate.a=1
	action.emit("cue",{"type":"slot"});_land_slot(slot)
	action.emit("landEntrance",{});choosing=false

func _land_slot(slot:Control) -> void:
	# The HBox retains the real slot. Pulse a fixed-layout face above it so
	# another queue sort cannot reset the landing beat's scale or pivot.
	var ghost:=Motion.copy(slot)
	var pose:=Motion.pose_in(motion_layer,slot)
	Motion.mount(motion_layer,ghost,pose);slot.modulate.a=0
	var id:String=slot.get_meta("skill_id","")
	var serial_value:=queue_motion_serial
	queue_ghosts[id]=ghost;Motion.settle_scale(ghost,1.14)
	var tween:=Motion.claim(ghost,["arrival"])
	tween.tween_interval(.46)
	tween.tween_callback(func():
		if serial_value==queue_motion_serial and queue_ghosts.get(id)==ghost:
			if is_instance_valid(slot):slot.modulate.a=1.0
			queue_ghosts.erase(id)
		if is_instance_valid(ghost):ghost.queue_free()
	)

func _deal_cards(sheet:Variant,list_name:String) -> void:
	await get_tree().process_frame
	if not is_instance_valid(sheet) or sheet.is_queued_for_deletion() or sheet.get_meta("retiring",false):return
	var options:Control=sheet.find_child(list_name,true,false)
	if options==null:return
	if Motion.cards(options).is_empty():
		sheet.set_meta("rolling",false)
		if sheet==panel:rolling=false;pages.setup(self);pages.update_reroll(sheet.find_child("Reroll",true,false),list_name=="DraftOptions")
		return
	if options.get_meta("dealt",false):return
	options.set_meta("dealt",true)
	var generation:int=int(sheet.get_meta("deal_generation",0))+1
	sheet.set_meta("deal_generation",generation)
	if frame.reduced:
		for card in Motion.cards(options):
			Motion.stop(card);card.position=Vector2.ZERO;card.scale=Vector2.ONE;card.rotation=0.0;card.modulate.a=1.0
			card.disabled=list_name=="SwapOptions" and not frame.canSwap
			for name in ["CardWords","CardFooter"]:
				var words:Control=card.find_child(name,true,false)
				if words!=null:Motion.stop(words);words.position=Vector2.ZERO;words.modulate.a=1.0
		var reroll:Button=sheet.find_child("Reroll",true,false)
		if reroll!=null:reroll.disabled=frame.rerolls<=0 or list_name=="SwapOptions" and not frame.canSwap
		sheet.set_meta("rolling",false)
		if sheet==panel:
			rolling=false
			if not Motion.cards(options).is_empty():_focus_card(Motion.cards(options)[0])
		return
	sheet.set_meta("rolling",true)
	if sheet==panel:rolling=true
	action.emit("cue",{"type":"deal"})
	var icon_pool:Array=[]
	for item in catalog.values():icon_pool.append(item.icon)
	var button:Button=sheet.find_child("Reroll",true,false)
	if button!=null:button.disabled=true
	var cards:=Motion.cards(options)
	for index in range(cards.size()):
		var card:Button=cards[index];card.disabled=true;card.add_theme_stylebox_override("disabled",card.get_theme_stylebox("normal"))
		Motion.deal(card,index)
		var id:String=String(card.name).trim_prefix("Skill_").trim_prefix("Swap_")
		var emblem:Control=card.find_child("Emblem",true,false)
		if emblem==null:continue
		var reel:=Reel.new();reel.visuals=visuals;reel.icons=icon_pool;reel.final_icon=catalog[id].icon;reel.ink=Color(catalog[id].color);reel.delay=.12+index*.07;reel.duration=.52+index*.23
		reel.tick=func():
			if sheet==panel and is_instance_valid(sheet) and sheet.get_meta("deal_generation",0)==generation:action.emit("cue",{"type":"tick"})
		reel.locked.connect(func():
			if not is_instance_valid(sheet) or sheet.get_meta("retiring",false) or sheet.get_meta("deal_generation",0)!=generation or not is_instance_valid(card):return
			Motion.settle_scale(emblem,1.28)
			for name in ["CardWords","CardFooter"]:
				var words:Control=card.find_child(name,true,false)
				if words!=null:Motion.reveal(words)
			var rarity:Control=card.find_child("CardRarity",true,false)
			if rarity!=null:Motion.settle_scale(rarity,1.3)
			var tier:String=str(catalog[id].tier)
			if tier=="gold" or tier=="blue":
				Motion.glint(card,0.12,Color("#fff8d8d0" if tier=="gold" else "#dff0ffc0"))
			if sheet==panel:action.emit("cue",{"type":{"gold":"gold","blue":"chime"}.get(catalog[id].tier,"tap")})
		)
		emblem.add_child(reel)
	await get_tree().create_timer(1.4).timeout
	if not is_instance_valid(sheet) or sheet.is_queued_for_deletion() or sheet.get_meta("retiring",false) or sheet.get_meta("deal_generation",0)!=generation or not is_instance_valid(options):return
	sheet.set_meta("rolling",false)
	if sheet==panel:rolling=false
	for card in Motion.cards(options):card.disabled=list_name=="SwapOptions" and not frame.canSwap
	if is_instance_valid(button):button.disabled=frame.rerolls<=0 or list_name=="SwapOptions" and not frame.canSwap
	if sheet==panel:
		pages.setup(self);pages.update_reroll(button,list_name=="DraftOptions")
		if not Motion.cards(options).is_empty():_focus_card(Motion.cards(options)[0])

func _focus_card(card:Control) -> void:
	# Focusing should not undo the sheet's retained scroll position.
	if not is_instance_valid(card) or card.focus_mode==Control.FOCUS_NONE or card is BaseButton and card.disabled:return
	var scroll:=modal_scroll
	var offset:=scroll.scroll_vertical if scroll!=null else 0
	card.grab_focus()
	if is_instance_valid(scroll):scroll.set_deferred("scroll_vertical",offset)

func _reroll(target:String="") -> void:
	if choosing or rolling or panel==null or frame.rerolls<=0 or target!="" and not frame.canSwap:return
	rolling=true;var sheet:=panel
	var serial_value:=sheet_serial
	sheet.set_meta("rolling",true)
	var button:Button=modal_content.find_child("Reroll",true,false)
	var options:Control=modal_content.find_child("DraftOptions" if target=="" else "SwapOptions",true,false)
	action.emit("cue",{"type":"reroll"})
	if not frame.reduced:
		if button!=null:
			button.disabled=true;Motion.pulse(button,1.04)
			var start:=Motion.rect_in(motion_layer,button).get_center()
			var gauge:Charges=button.get_meta("charge_gauge") if button.has_meta("charge_gauge") else null
			if gauge!=null:start=motion_layer.get_global_transform().affine_inverse()*(gauge.get_global_transform()*gauge.spend())
			var sparks:=Flights.new();sparks.setup(start,Motion.rect_in(motion_layer,options if options!=null else panel).get_center(),1,true,visuals.color("accent-bar"));motion_layer.add_child(sparks)
		if options!=null:
			var cards:=Motion.cards(options);cards.reverse()
			for i in range(cards.size()):cards[i].disabled=true;Motion.fold(cards[i],i)
		await get_tree().create_timer(.48).timeout
		if not is_instance_valid(sheet) or sheet.is_queued_for_deletion() or sheet.get_meta("retiring",false):return
		if sheet!=panel or serial_value!=sheet_serial:
			# Cancel a covered reroll from the fold's current pose. The original
			# sheet remains usable when uncovered, without consuming a charge.
			sheet.set_meta("rolling",false)
			if is_instance_valid(options):
				for card in Motion.cards(options):Motion.restore(card);card.disabled=target!="" and not frame.canSwap
			if is_instance_valid(button):button.disabled=frame.rerolls<=0 or target!="" and not frame.canSwap
			if sheet==panel:rolling=false
			return
	if target=="":
		draft_key="_refresh";action.emit("reroll",{})
	else:
		if options!=null:options.set_meta("offer_key","_refresh")
		action.emit("offerSwap",{"id":target})
		if sheet==panel:_detail(target)
		_deal_cards.call_deferred(panel,"SwapOptions")
	if frame.reduced:
		if is_instance_valid(sheet):sheet.set_meta("rolling",false)
		rolling=false

func _swap(target:String,id:String) -> void:
	if choosing or rolling or not frame.canSwap:return
	choosing=true
	var sheet:=panel
	var card:Button=modal_content.find_child("Swap_"+id,true,false)
	action.emit("cue",{"type":"pick","n":{"blue":1,"gold":2}.get(catalog[id].tier,0)})
	if not frame.reduced and card!=null:
		var serial_value:=sheet_serial
		var options:Control=sheet.find_child("SwapOptions",true,false)
		var candidates:=Motion.cards(options)
		var index:=0
		for other in candidates:
			other.disabled=true;other.add_theme_stylebox_override("disabled",other.get_theme_stylebox("normal"))
			if other!=card:
				Motion.dismiss(other,index,-1 if index==0 else 1,.3);Motion.collapse(other,.28,.2+index*.04);index+=1
		Motion.pulse(card,1.03);Motion.travel(card,Vector2(0,-4),.22,0,true)
		await get_tree().create_timer(.52).timeout
		if not is_instance_valid(sheet) or sheet!=panel or serial_value!=sheet_serial:
			_restore_candidates(sheet,candidates);choosing=false;return
		var emblem:Control=card.find_child("Emblem",true,false)
		var head:Control=sheet.find_child("DetailHeader",true,false)
		var header:Control=head.find_child("Emblem",true,false)
		var ghost:=Motion.copy(emblem)
		var a:=Motion.rect_in(motion_layer,emblem);var b:=Motion.rect_in(motion_layer,header)
		Motion.flight(motion_layer,ghost,a,b,.52,Motion.pose_in(motion_layer,emblem),header)
		Motion.fade(emblem,0.0,.16);action.emit("cue",{"type":"whoosh"})
		await get_tree().create_timer(.52).timeout
		if is_instance_valid(ghost):ghost.queue_free()
		if not is_instance_valid(card) or sheet!=panel or modal_kind!="detail" or serial_value!=sheet_serial:
			_restore_candidates(sheet,candidates);choosing=false;return
		pages.setup(self);pages.morph_detail(id)
		Motion.dismiss(card,0,1,.22);Motion.collapse(card,.28,.08)
		var reroll:Control=sheet.find_child("Reroll",true,false)
		if reroll!=null:Motion.fade(reroll,0.0,.22)
		await get_tree().create_timer(.42).timeout
		if not is_instance_valid(sheet) or sheet!=panel or serial_value!=sheet_serial:
			_restore_candidates(sheet,candidates);choosing=false;return
	pending_swap_from=target;pending_swap_id=id
	_close(true);action.emit("swap",{"target":target,"id":id});choosing=false
	action.emit("cue",{"type":"slot"})

func _restore_candidates(sheet:Control,candidates:Array) -> void:
	if not is_instance_valid(sheet) or sheet.get_meta("retiring",false):return
	for other in candidates:
		if not is_instance_valid(other):continue
		Motion.restore(other);other.disabled=not frame.canSwap
		var emblem:Control=other.find_child("Emblem",true,false)
		if emblem!=null:Motion.fade(emblem,1.0,.18)
	var button:Button=sheet.find_child("Reroll",true,false)
	if button!=null:button.disabled=frame.rerolls<=0 or not frame.canSwap;Motion.fade(button,1.0,.18)
	var original:String=sheet.get_meta("detail_id","")
	if original!="":
		pages.setup(self);pages.morph_detail(original,(sheet as Sheet).content)

func _reset_run() -> void:
	if choosing:return
	choosing=true;_close_all();draft_key=""
	if not frame.reduced:
		var curtain:=ColorRect.new();curtain.color=visuals.color("panel");curtain.size=Vector2(412,915);curtain.mouse_filter=Control.MOUSE_FILTER_STOP;motion_layer.add_child(curtain)
		var label:=visuals.label("↶  重新开始",28,"on-panel",true);label.position=Vector2(90,410);curtain.add_child(label)
		curtain.modulate.a=0
		Motion.fade(curtain,1.0,.3)
		await get_tree().create_timer(.3).timeout
		if not is_instance_valid(curtain):choosing=false;return
		action.emit("reset",{})
		var tween:=Motion.claim(curtain,["position"]);tween.tween_property(curtain,"position:x",-412.0,.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT);tween.tween_callback(curtain.queue_free)
	else:action.emit("reset",{})
	choosing=false;present(frame)

func _shop() -> void:
	shop_state=JSON.stringify([frame.shop,frame.coins,frame.phase,frame.paused,frame.theme])
	if modal_kind=="shop" and panel!=null and shop_theme==frame.theme:
		pages.setup(self);pages.update_shop();return
	shop_theme=frame.theme
	_open("","shop")
	pages.setup(self);pages.shop()

func _detail(id: String) -> void:
	detail_state=JSON.stringify([frame.swapOffer,frame.rerolls,frame.canSwap,frame.theme])
	if modal_kind=="detail" and panel!=null and detail_id==id and detail_theme==frame.theme:
		pages.setup(self)
		if pages.update_detail(id):_deal_cards.call_deferred(panel,"SwapOptions")
		return
	detail_id=id;detail_theme=frame.theme
	_open("","detail",true)
	panel.set_meta("detail_id",id);panel.set_meta("detail_theme",frame.theme)
	pages.setup(self);pages.detail(id)
	if modal_content.find_child("SwapOptions",true,false)!=null:_deal_cards.call_deferred(panel,"SwapOptions")

func _library() -> void:
	_open("","library",true)
	pages.setup(self);pages.library()

func _equipment(expanded: bool=false) -> void:
	if modal_kind in ["equipment","achievements"] and panel!=null:
		modal_kind="achievements" if expanded else "equipment"
		pages.setup(self);pages.expand_achievements(expanded);return
	_open("","achievements" if expanded else "equipment",true)
	pages.setup(self);pages.equipment(expanded)

func _achievements() -> void:
	_open("","achievements",true)
	pages.setup(self);pages.equipment(true)

func _reset_confirmation() -> void:
	_open("","reset",true)
	pages.setup(self);pages.reset()

func _settings() -> void:
	_open("","settings",true)
	pages.setup(self);pages.settings()

func _close_all() -> void:
	var previously_choosing:=choosing
	choosing=true
	while panel!=null:_close()
	rolling=false
	choosing=previously_choosing

func _file(importing: bool) -> void:
	file_dialog=FileDialog.new();file_dialog.access=FileDialog.ACCESS_FILESYSTEM;file_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE;file_dialog.filters=PackedStringArray(["*.json ; Slingbreak progress"])
	file_dialog.file_selected.connect(func(path):action.emit("importFile" if importing else "exportFile",{"path":path});file_dialog.queue_free();file_dialog=null)
	file_dialog.canceled.connect(func():file_dialog.queue_free();file_dialog=null)
	add_child(file_dialog);file_dialog.popup_centered(Vector2i(390,650))

func _fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func show_error(message: String) -> void:
	_open("运行时错误","error");_label(message);_choice("关闭",_close)

func receive_events(events: Array) -> void:
	for event in events:
		if event.type=="toast" and hud_nodes.has("toast"):
			var label:Label=hud_nodes.toast
			if not frame.get("reduced",false) and label.text!=event.text:
				if is_instance_valid(toast_ghost):Motion.fade(toast_ghost,0.0,.12).tween_callback(toast_ghost.queue_free)
				var ghost:=Motion.copy(label);Motion.mount(motion_layer,ghost,Motion.pose_in(motion_layer,label));toast_ghost=ghost
				Motion.travel(ghost,ghost.position+Vector2(0,-5),.18)
				Motion.fade(ghost,0.0,.18).tween_callback(ghost.queue_free)
				Motion.stop(label);label.modulate.a=0.0
			label.text=event.text;toast_time=2.4
			Motion.fade(label,1.0,0.0 if frame.get("reduced",false) else .18)
		elif event.type=="achievement" and achievement_cards!=null:achievement_cards.accept(event)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if modal_kind=="" and frame.get("phase")=="clearing" and event.keycode in [KEY_SPACE,KEY_ENTER]:
		_skip_clear();get_viewport().set_input_as_handled()
	elif modal_kind=="draft":
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			var index:int=event.keycode-KEY_1
			if frame.draft is Dictionary and index<frame.draft.options.size():_select(frame.draft.options[index])
			get_viewport().set_input_as_handled()
		elif event.keycode==KEY_R: _reroll();get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
			var options:Control=modal_content.get_node("DraftOptions")
			var cards:Array=Motion.cards(options);var at:int=cards.find(get_viewport().gui_get_focus_owner())
			if cards.is_empty() or choosing or rolling:get_viewport().set_input_as_handled();return
			var step:=1 if event.keycode in [KEY_DOWN,KEY_RIGHT] else -1
			cards[posmod(at+step,cards.size()) if at>=0 else 0 if step>0 else cards.size()-1].grab_focus()
			get_viewport().set_input_as_handled()
		elif event.keycode==KEY_ESCAPE:get_viewport().set_input_as_handled()
	elif event.keycode==KEY_ESCAPE:
		if modal_kind!="": _close()
		else: action.emit("pause",{"paused":not frame.paused})
		get_viewport().set_input_as_handled()
