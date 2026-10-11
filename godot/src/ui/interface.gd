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
const MODAL_BLUR=preload("res://src/ui/modal_blur.gdshader")
const WEB_MODAL_BLUR=preload("res://src/ui/modal_blur_web.gdshader")
const Reel=preload("res://src/ui/reel.gd")
const Flights=preload("res://src/ui/coin_flights.gd")
var visuals := Presentation.new()
var pages := Pages.new()
var report_view := Report.new()
var frame: Dictionary = {}
var catalog: Dictionary = {}
var panel: PanelContainer
var scrim: ColorRect
var modal_content: VBoxContainer
var modal_kind := ""
var restore_pause := false
var draft_key := ""
var choosing := false
var hud_nodes: Dictionary = {}
var queue: HBoxContainer
var queue_key := ""
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
var detail_state:=""
var rolling:=false
var motion_layer:Control
var hud_values:Dictionary={}
var modal_enter_pending:=false
var sheet_serial:=0
var morph_from:=Rect2()

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
	charge_key="";charge_tab=null
	boss_key="";boss_bar=null
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
	_line(Vector2(321,104),Vector2(75,3))
	_text("arrow_tag","",Vector2(72,99),9,"text-2")
	_text("score_bonus","",Vector2(160,121),10,"gold-ink",true)
	_text("core_label","◇  核心解锁",Vector2(16,149),10,"text-3")
	var progress := ProgressBar.new();progress.position=Vector2(103,154);progress.size=Vector2(229,4);progress.show_percentage=false;progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override("background",visuals.box(visuals.color("surface-3"),Color.TRANSPARENT,2))
	progress.add_theme_stylebox_override("fill",visuals.box(visuals.color("accent-bar"),Color.TRANSPARENT,2));add_child(progress);hud_nodes.progress=progress
	progress.add_theme_font_size_override("font_size",1)
	progress.set_deferred("size",Vector2(229,4))
	_text("core_value","0 / 0",Vector2(346,148),13,"text-3")
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

func _line(at: Vector2,dimensions: Vector2) -> void:
	var line := ColorRect.new();line.color=visuals.color("line");line.position=at;line.size=dimensions;line.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(line)

func _text(key: String,text: String,at: Vector2,size: int,token: String,bold: bool=false) -> void:
	var label := visuals.label(text,size,token,bold);label.position=at;add_child(label);hud_nodes[key]=label

func _button(text: String,at: Vector2,dimensions: Vector2,callback: Callable) -> Button:
	var button := Button.new();button.text=text;button.position=at;button.size=dimensions;button.pressed.connect(callback);add_child(button);return button

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
	hud_nodes.level.text="%02d" % (value.transition.report.level if value.phase=="clearing" and value.transition.report is Dictionary else value.level)
	hud_nodes.wallet.text=pages.fmt(value.coins)
	hud_nodes.receipt.text="+%d" % achievement.get("paid",0)
	hud_nodes.combo.text=str(achievement.get("kills",0))
	hud_nodes.mult.text="×%s" % _compact(achievement.get("baseMult",1.0))
	hud_nodes.arrow_tag.text="#%d" % achievement.id if not achievement.is_empty() else ""
	hud_nodes.receipt.modulate.a=1 if not achievement.is_empty() else .55
	var bonuses:=""
	if achievement.get("mult",1)>1:bonuses="✦ ×"+_compact(achievement.mult)
	if achievement.get("bountyMult",1)>1:bonuses+="  ¥ ×"+_compact(achievement.bountyMult)
	hud_nodes.score_bonus.text=bonuses
	hud_nodes.earnings.text="+ %d" % value.levelMoney
	var core_threshold:float=float(value.threshold) if value.threshold!=null else 0.0
	hud_nodes.progress.value=100.0*float(value.killed)/maxf(1.0,core_threshold)
	hud_nodes.core_label.text="◆  核心击破" if value.phase=="clearing" else "◆  核心已显现" if value.core!=null else "◇  核心解锁"
	hud_nodes.core_value.text="%d / %d" % [mini(value.killed,int(core_threshold)),int(core_threshold)]
	if value.bossStatus!=null:
		hud_nodes.core_label.text=value.bossStatus.name+" · "+value.bossStatus.text
		hud_nodes.core_value.text="%d / %d" % [value.boss.phase,value.bossStatus.phases]
		hud_nodes.progress.value=100.0*value.boss.hp/maxf(1,value.boss.max)
	var status := {"draft":"选择新技能 · 滚动构筑","ready":"就绪","entering":"砖块入场中","flying":"可继续射击","clearing":"下一关即将开始"}
	hud_nodes.status.text="已暂停" if value.paused else status.get(value.phase,"")
	if value.get("drag") is Dictionary:
		hud_nodes.power.text="POWER  %d%%" % mini(100,int(Vector2(value.drag.dx,value.drag.dy).length()))
		hud_nodes.status.text="蓄力中"
	else:hud_nodes.power.text="POWER  0%"
	var key := JSON.stringify([value.skills,value.slots])
	if queue_key!=key and not catalog.is_empty():
		queue_key=key
		for child in queue.get_children(): queue.remove_child(child);child.queue_free()
		for index in range(value.slots):
			var id: String=value.skills[index] if index<value.skills.size() else ""
			var slot:=Button.new();slot.name="LiveSlot%d" % index;slot.custom_minimum_size=Vector2(88,29);slot.add_theme_font_size_override("font_size",11);slot.disabled=id==""
			var outgoing:bool=index==0 and value.skills.size()>=value.slots
			slot.add_theme_stylebox_override("normal",visuals.box(visuals.color("warm-soft" if outgoing else "surface-2"),visuals.color("warm-line" if outgoing else "line-2"),5,5));slot.add_theme_stylebox_override("disabled",visuals.box(Color.TRANSPARENT,visuals.color("line-2"),5,5))
			queue.add_child(slot)
			var inset:MarginContainer=visuals.margin(slot,5,6,5,6);var line:HBoxContainer=visuals.row(inset,5)
			if id!="":visuals.image(line,catalog[id].icon,Color(catalog[id].color),Vector2(15,15));slot.pressed.connect(func():_detail(id))
			var name_label:Label=visuals.text(line,catalog[id].name if id!="" else "等待加入",11,"warm-ink" if outgoing else "text-2",true,true)
			name_label.custom_minimum_size.x=51
			visuals.pointer_through(inset)
	_update_charges(value)
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
	if achievement_cards!=null:
		achievement_cards.blocked=value.paused or modal_kind!=""
		achievement_cards.reduced=value.reduced
		if value.level<last_level:achievement_cards.clear()
	if not value.reduced:
		for token in ["receipt","combo","earnings","wallet","level"]:
			var text:String=hud_nodes[token].text
			if hud_values.has(token) and hud_values[token]!=text:Motion.pulse(hud_nodes[token],1.07 if token=="wallet" else 1.12)
			hud_values[token]=text
	last_level=value.level

func _process(delta: float) -> void:
	if toast_time>0:
		toast_time=maxf(0,toast_time-delta)
		if toast_time==0 and hud_nodes.has("toast"):hud_nodes.toast.text=""

func _update_boss(value: Dictionary) -> void:
	var active:bool=value.bossStatus is Dictionary
	for key in ["core_label","core_value","progress"]:hud_nodes[key].visible=not active
	if not active:
		if boss_bar!=null:boss_bar.queue_free();boss_bar=null
		boss_key="";return
	var key:=JSON.stringify([value.bossStatus,value.boss.hp,value.boss.phase,value.theme])
	if key==boss_key:return
	boss_key=key
	if boss_bar!=null:remove_child(boss_bar);boss_bar.queue_free()
	boss_bar=HBoxContainer.new();boss_bar.position=Vector2(16,149);boss_bar.size=Vector2(380,14);boss_bar.add_theme_constant_override("separation",8);add_child(boss_bar)
	var status:Dictionary=value.bossStatus
	var token:String={"forge":"warm-ink","serpent":"legend-frost","clock":"gold-ink"}.get(value.boss.boss,"legend-prism")
	visuals.text(boss_bar,"◆ "+status.name,10,token,true)
	visuals.text(boss_bar,"%d/%d %s" % [value.boss.phase,status.phases,status.phaseName],10,"text-3")
	var segments:HBoxContainer=visuals.row(boss_bar,3);segments.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	for i in range(int(status.phases)):
		var phase:int=int(status.phases)-i
		var meter:=ProgressBar.new();meter.show_percentage=false;meter.custom_minimum_size=Vector2(6,6);meter.size_flags_horizontal=Control.SIZE_EXPAND_FILL;meter.max_value=1;meter.value=0 if phase<value.boss.phase else 1 if phase>value.boss.phase else float(value.boss.hp)/maxf(1,value.boss.max)
		meter.add_theme_stylebox_override("background",visuals.box(visuals.mix(visuals.color(token),visuals.color("surface"),.18),Color.TRANSPARENT,2))
		meter.add_theme_stylebox_override("fill",visuals.box(visuals.color(token),Color.TRANSPARENT,2));segments.add_child(meter)
	visuals.text(boss_bar,status.text,10,"danger" if status.state in ["exposed","dying"] else token,true)
	if status.resist>=10:visuals.text(boss_bar,"减伤 %d%%" % status.resist,10,"text-3",true)
	visuals.pointer_through(boss_bar)

func _update_report(value: Dictionary) -> void:
	var report=value.transition.report
	if value.phase!="clearing" or not report is Dictionary:
		if report_layer!=null: report_layer.queue_free();report_layer=null
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
	if charge_tab!=null:charge_tab.queue_free()
	charge_tab=PanelContainer.new();charge_tab.position=Vector2(350-int(value.rerollCap)*12,173);charge_tab.z_index=2
	charge_tab.add_theme_stylebox_override("panel",visuals.box(visuals.color("surface"),visuals.color("line-2"),10,3));add_child(charge_tab)
	var line:HBoxContainer=visuals.row(charge_tab,5);visuals.image(line,"refresh-cw",visuals.color("accent-ink"),Vector2(11,11))
	pages.setup(self);var gauge:Control=pages.charges(line,0,9);gauge.gap=3
	visuals.pointer_through(charge_tab)

func _update_pause(value: Dictionary) -> void:
	if not value.paused or modal_kind!="" or value.phase=="draft":
		if pause_layer!=null:pause_layer.queue_free();pause_layer=null
		return
	if pause_layer!=null:return
	pause_layer=ColorRect.new();pause_layer.color=visuals.color("overlay");pause_layer.position=Vector2(0,238);pause_layer.size=Vector2(412,572);pause_layer.z_index=9;add_child(pause_layer)
	if DisplayServer.get_name()!="headless":
		var material:=ShaderMaterial.new();material.shader=WEB_MODAL_BLUR if OS.has_feature("web") else MODAL_BLUR;material.set_shader_parameter("tint",visuals.color("overlay"));material.set_shader_parameter("blur",3.0);pause_layer.material=material
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);pause_layer.add_child(center)
	var column:VBoxContainer=visuals.column(center,12)
	for item in [["TAKE A BREATH",10,"text-3"],["暂停一下",28,"ink"],["这一箭，等你回来。",12,"text-3"]]:
		var label:Label=visuals.text(column,item[0],item[1],item[2],item[1]==28);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	visuals.space(column,12)
	var resume:Button=visuals.button(column,"继续游戏",func():action.emit("pause",{"paused":false}),"play",44);resume.add_theme_stylebox_override("normal",visuals.box(visuals.color("accent"),Color.TRANSPARENT,5,10));resume.add_theme_color_override("font_color",visuals.color("on-accent"));resume.add_theme_color_override("font_focus_color",visuals.color("on-accent"));resume.icon=visuals.icon("play",visuals.color("on-accent"));resume.grab_focus()
	if not value.reduced:Motion.enter(pause_layer)

func _preview_skill(id: String) -> void:
	if modal_kind!="draft" or modal_content==null:return
	var loadout:Control=modal_content.get_node_or_null("Loadout")
	if loadout==null:return
	var at:int=0 if frame.skills.size()>=frame.slots else frame.skills.size()
	var slot:PanelContainer=loadout.find_child("Slot%d" % at,true,false)
	if slot==null:return
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

func _ignore_pointer(node: Node) -> void:
	if node is Control:node.mouse_filter=Control.MOUSE_FILTER_IGNORE
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
		if wipe_layer!=null:wipe_layer.queue_free()
		wipe_layer=Control.new();wipe_layer.position=Vector2(0,238);wipe_layer.size=Vector2(412,572);wipe_layer.z_index=14;wipe_layer.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(wipe_layer)
		for i in range(2):
			var clip:=Control.new();clip.name="Clip%d" % i;clip.clip_contents=true;clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;wipe_layer.add_child(clip)
			var sheet:=ColorRect.new();sheet.size=Vector2(412,572);sheet.color=visuals.color("accent-bar" if i==0 else "panel");sheet.mouse_filter=Control.MOUSE_FILTER_IGNORE;clip.add_child(sheet)
			if i==1:
				var title:=visuals.label(info.eyebrow,13,"accent-bar",true);title.position=Vector2(0,218);title.size.x=412;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;sheet.add_child(title)
				var digits:=visuals.label("%02d  →  %02d" % [info.from,info.to],64,"on-panel",true);digits.position=Vector2(0,250);digits.size.x=412;digits.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;sheet.add_child(digits)
				var note:=visuals.label(info.note,12,"on-panel-2");note.position=Vector2(0,330);note.size.x=412;note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;sheet.add_child(note)
	for i in range(2):
		var clip:Control=wipe_layer.get_node("Clip%d" % i)
		var age:float=(value.transition.clock-info.at-i*70)/1050.0
		var p:float=Easing.bezier(clampf(age,0,1),.65,0,.35,1)
		var left:float=clampf((p-.62)/.38,0,1)*412
		var right:float=clampf(p/.34,0,1)*412
		clip.position=Vector2(left,0);clip.size=Vector2(maxf(0,right-left),572);clip.get_child(0).position.x=-left

func _compact(value: float) -> String:
	return String.num(value,3)

func _open(title: String,kind: String,pause_game: bool=false) -> void:
	var first := panel==null
	sheet_serial+=1
	morph_from=panel.get_rect() if panel!=null and kind!=modal_kind else Rect2()
	if first: restore_pause=bool(frame.get("paused",false))
	if panel!=null:
		if kind==modal_kind or kind in ["equipment","achievements"] and modal_kind in ["equipment","achievements"]:
			remove_child(panel);panel.queue_free();remove_child(scrim);scrim.queue_free()
		else:
			modal_stack.append({"panel":panel,"scrim":scrim,"content":modal_content,"scroll":modal_scroll,"kind":modal_kind,"padding":modal_padding,"width":modal_width})
	modal_kind=kind
	modal_enter_pending=first or kind not in ["shop","settings","detail","equipment","achievements"]
	modal_width=250 if kind=="reset" else 388 if kind=="shop" else 380
	modal_padding=31 if kind=="reset" else 25 if kind=="shop" else 23 if kind=="settings" else 21 if kind in ["equipment","achievements"] else 19 if kind=="detail" else 17
	var depth:=modal_stack.size()*2
	scrim=ColorRect.new();scrim.size=Vector2(412,915);scrim.z_index=11+depth;scrim.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(scrim)
	# Chromium 89 computes a transparent dialog backdrop: ::backdrop does not
	# inherit the custom properties. Preserve that measured reference here.
	var tint:=Color.TRANSPARENT
	scrim.color=tint
	if DisplayServer.get_name()!="headless":
		var material:=ShaderMaterial.new();material.shader=WEB_MODAL_BLUR if OS.has_feature("web") else MODAL_BLUR;material.set_shader_parameter("tint",tint);material.set_shader_parameter("blur",3.0 if kind=="draft" else 2.5);scrim.material=material
	scrim.gui_input.connect(func(event):if kind!="draft" and event is InputEventMouseButton and event.pressed:_close())
	panel=PanelContainer.new();panel.z_index=12+depth;panel.custom_minimum_size=Vector2(modal_width,0);panel.size=Vector2(modal_width,0);panel.position=Vector2((412-modal_width)/2,100);panel.add_theme_stylebox_override("panel",visuals.box(visuals.color("surface"),visuals.color("line-2" if kind in ["draft","library","detail"] else "line"),12 if kind=="draft" else 8,modal_padding));add_child(panel)
	modal_scroll=ScrollContainer.new();modal_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;modal_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER;modal_scroll.custom_minimum_size=Vector2(modal_width-modal_padding*2,0);panel.add_child(modal_scroll)
	modal_content=VBoxContainer.new();modal_content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;modal_content.add_theme_constant_override("separation",0);modal_scroll.add_child(modal_content)
	modal_content.minimum_size_changed.connect(func():_center.call_deferred())
	if title!="": _label(title,22,true)
	if pause_game and not frame.get("paused",false): action.emit("pause",{"paused":true})
	_center.call_deferred()

func _center() -> void:
	if panel==null: return
	modal_scroll.custom_minimum_size.y=minf(883-modal_padding*2,modal_content.get_combined_minimum_size().y)
	panel.reset_size()
	panel.size.x=modal_width
	panel.position.y=maxf(8,(915-panel.size.y)/2)
	if morph_from.has_area() and not frame.get("reduced",false):
		var final_position:=panel.position
		panel.position=morph_from.position;panel.pivot_offset=panel.size/2
		panel.scale=Vector2(morph_from.size.x/panel.size.x,morph_from.size.y/panel.size.y)
		var tween:=panel.create_tween().set_parallel()
		tween.tween_property(panel,"position",final_position,.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel,"scale",Vector2.ONE,.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		modal_enter_pending=false
	morph_from=Rect2()
	if modal_enter_pending:
		modal_enter_pending=false
		if not frame.get("reduced",false):Motion.enter(panel)

func _close() -> void:
	var was_paused := restore_pause
	sheet_serial+=1;rolling=false
	modal_kind=""
	if panel!=null:
		if not choosing and not frame.get("reduced",false):_ignore_pointer(panel);Motion.leave(panel)
		else:remove_child(panel);panel.queue_free()
		panel=null
	if scrim!=null:remove_child(scrim);scrim.queue_free();scrim=null
	if not modal_stack.is_empty():
		var previous:Dictionary=modal_stack.pop_back()
		panel=previous.panel;scrim=previous.scrim;modal_content=previous.content;modal_scroll=previous.scroll;modal_kind=previous.kind;modal_padding=previous.padding;modal_width=previous.width
		if modal_kind in ["equipment","achievements"]:_equipment(modal_kind=="achievements")
		elif modal_kind=="library":_library()
		elif modal_kind=="settings":_settings()
		elif modal_kind=="shop":_shop()
		elif modal_kind=="draft":_deal_cards.call_deferred(panel,"DraftOptions")
		return
	modal_content=null;modal_scroll=null
	if frame.get("paused",false)!=was_paused: action.emit("pause",{"paused":was_paused})
	if pause_layer!=null:_update_pause(frame)

func _label(text: String,size: int=12,bold: bool=false) -> Label:
	var label := visuals.label(text,size,"ink",bold);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;modal_content.add_child(label);return label

func _choice(text: String,callback: Callable,disabled: bool=false) -> Button:
	var button := Button.new();button.text=text;button.custom_minimum_size=Vector2(360,42);button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.disabled=disabled;button.pressed.connect(callback);modal_content.add_child(button);return button

func _draft() -> void:
	_open("","draft")
	pages.setup(self);pages.draft()
	_deal_cards.call_deferred(panel,"DraftOptions")

func _select(id: String) -> void:
	if choosing or rolling or modal_kind!="draft" or not frame.draft is Dictionary or not id in frame.draft.options:return
	choosing=true;action.emit("cue",{"type":"pick","n":{"blue":1,"gold":2}.get(catalog[id].tier,0)})
	var card:Button=modal_content.find_child("Skill_"+id,true,false)
	if frame.reduced or card==null:
		_close();action.emit("choose",{"id":id});choosing=false;return
	for other in card.get_parent().get_children():
		other.disabled=true;other.add_theme_stylebox_override("disabled",other.get_theme_stylebox("normal"))
		if other!=card:other.create_tween().tween_property(other,"modulate:a",0.0,.18)
	Motion.pulse(card,1.03)
	await get_tree().create_timer(.18).timeout
	if not is_instance_valid(card) or modal_kind!="draft":choosing=false;return
	var from:=Rect2(motion_layer.get_global_transform().affine_inverse()*card.global_position,card.size)
	card.get_parent().remove_child(card);card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_close();action.emit("choose",{"id":id});action.emit("holdEntrance",{})
	var at:int=frame.skills.size()-1
	var slot:Control=queue.get_node("LiveSlot%d" % at)
	var target:=Rect2(motion_layer.get_global_transform().affine_inverse()*slot.global_position,slot.size)
	action.emit("cue",{"type":"whoosh"})
	var flight:=Motion.flight(motion_layer,card,from,target)
	await flight.finished
	if is_instance_valid(card):card.queue_free()
	action.emit("cue",{"type":"slot"});Motion.pulse(slot,1.22)
	action.emit("landEntrance",{});choosing=false

func _deal_cards(sheet:Variant,list_name:String) -> void:
	var serial_value:=sheet_serial
	await get_tree().process_frame
	if not is_instance_valid(sheet) or sheet!=panel or serial_value!=sheet_serial:return
	var options:Control=sheet.find_child(list_name,true,false)
	if options==null:return
	if frame.reduced:
		rolling=false
		if options.get_child_count()>0:options.get_child(0).grab_focus()
		return
	rolling=true;action.emit("cue",{"type":"deal"})
	var icon_pool:Array=[]
	for item in catalog.values():icon_pool.append(item.icon)
	var button:Button=sheet.find_child("Reroll",true,false)
	if button!=null:button.disabled=true
	for index in range(options.get_child_count()):
		var card:Button=options.get_child(index);card.disabled=true;card.add_theme_stylebox_override("disabled",card.get_theme_stylebox("normal"))
		Motion.deal(card,index)
		var id:String=String(card.name).trim_prefix("Skill_").trim_prefix("Swap_")
		var emblem:Control=card.find_child("Emblem",true,false)
		if emblem==null:continue
		var reel:=Reel.new();reel.visuals=visuals;reel.icons=icon_pool;reel.final_icon=catalog[id].icon;reel.ink=Color(catalog[id].color);reel.delay=.12+index*.07;reel.duration=.52+index*.23
		reel.tick=func():action.emit("cue",{"type":"tick"})
		reel.locked.connect(func():
			Motion.pulse(emblem,1.28)
			var tier:String=str(catalog[id].tier)
			if tier=="gold" or tier=="blue":
				Motion.glint(card,0.12,Color("#fff8d8d0" if tier=="gold" else "#dff0ffc0"))
			action.emit("cue",{"type":{"gold":"gold","blue":"chime"}.get(catalog[id].tier,"tap")})
		)
		emblem.add_child(reel)
	await get_tree().create_timer(1.4).timeout
	if not is_instance_valid(sheet) or sheet!=panel or serial_value!=sheet_serial:return
	rolling=false
	for card in options.get_children():card.disabled=false
	if button!=null:button.disabled=frame.rerolls<=0 or list_name=="SwapOptions" and not frame.canSwap
	if options.get_child_count()>0:options.get_child(0).grab_focus()

func _reroll(target:String="") -> void:
	if choosing or rolling or panel==null or frame.rerolls<=0 or target!="" and not frame.canSwap:return
	rolling=true;var sheet:=panel
	var button:Button=modal_content.find_child("Reroll",true,false)
	var options:Control=modal_content.find_child("DraftOptions" if target=="" else "SwapOptions",true,false)
	action.emit("cue",{"type":"reroll"})
	if not frame.reduced:
		if button!=null:
			button.disabled=true;Motion.pulse(button,1.04)
			var sparks:=Flights.new();sparks.setup(button.get_global_rect().get_center(),options.get_global_rect().get_center() if options!=null else panel.get_global_rect().get_center(),1,true,visuals.color("accent-bar"));motion_layer.add_child(sparks)
		if options!=null:
			var cards:=options.get_children();cards.reverse()
			for i in range(cards.size()):cards[i].disabled=true;Motion.fold(cards[i],i)
		await get_tree().create_timer(.48).timeout
		if not is_instance_valid(sheet) or sheet!=panel:rolling=false;return
	if target=="":action.emit("reroll",{})
	else:
		action.emit("offerSwap",{"id":target})
		_deal_cards.call_deferred(panel,"SwapOptions")
	if frame.reduced:rolling=false

func _swap(target:String,id:String) -> void:
	if choosing or rolling or not frame.canSwap:return
	choosing=true
	var card:Button=modal_content.find_child("Swap_"+id,true,false)
	action.emit("cue",{"type":"pick","n":{"blue":1,"gold":2}.get(catalog[id].tier,0)})
	if not frame.reduced and card!=null:
		for other in card.get_parent().get_children():
			other.disabled=true
			if other!=card:Motion.fold(other,0)
		var emblem:Control=card.find_child("Emblem",true,false)
		var header:Control=modal_content.find_child("Emblem",true,false)
		var ghost:=TextureRect.new();ghost.texture=visuals.icon(catalog[id].icon,Color(catalog[id].color));ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE;ghost.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;ghost.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var a:=emblem.get_global_rect();var b:=header.get_global_rect()
		var flight:=Motion.flight(motion_layer,ghost,a,b,.48)
		await flight.finished
		ghost.queue_free()
		if not is_instance_valid(card) or modal_kind!="detail":choosing=false;return
	action.emit("swap",{"target":target,"id":id});_close();choosing=false
	if not frame.reduced:
		for slot in queue.get_children():Motion.pulse(slot,1.14)
	action.emit("cue",{"type":"slot"})

func _reset_run() -> void:
	if choosing:return
	choosing=true;_close_all();draft_key=""
	if not frame.reduced:
		var curtain:=ColorRect.new();curtain.color=visuals.color("panel");curtain.size=Vector2(412,915);curtain.mouse_filter=Control.MOUSE_FILTER_STOP;motion_layer.add_child(curtain)
		var label:=visuals.label("↶  重新开始",28,"on-panel",true);label.position=Vector2(90,410);curtain.add_child(label)
		curtain.modulate.a=0
		var tween:=curtain.create_tween();tween.tween_property(curtain,"modulate:a",1.0,.3)
		await tween.finished
		action.emit("reset",{})
		tween=curtain.create_tween();tween.tween_property(curtain,"position:x",-412.0,.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT);tween.tween_callback(curtain.queue_free)
	else:action.emit("reset",{})
	choosing=false;present(frame)

func _shop() -> void:
	shop_state=JSON.stringify([frame.shop,frame.coins,frame.phase,frame.paused,frame.theme])
	_open("","shop")
	pages.setup(self);pages.shop()

func _detail(id: String) -> void:
	detail_id=id
	detail_state=JSON.stringify([frame.swapOffer,frame.rerolls,frame.canSwap,frame.theme])
	_open("","detail",true)
	pages.setup(self);pages.detail(id)

func _library() -> void:
	_open("","library",true)
	pages.setup(self);pages.library()

func _equipment(expanded: bool=false) -> void:
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
		if event.type=="toast" and hud_nodes.has("toast"):hud_nodes.toast.text=event.text;toast_time=2.4
		elif event.type=="achievement" and achievement_cards!=null:achievement_cards.accept(event)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if modal_kind=="" and frame.get("phase")=="clearing" and event.keycode in [KEY_SPACE,KEY_ENTER]:
		_skip_clear();get_viewport().set_input_as_handled()
	elif modal_kind=="draft":
		if event.keycode in [KEY_1,KEY_2,KEY_3]: _select(frame.draft.options[event.keycode-KEY_1]);get_viewport().set_input_as_handled()
		elif event.keycode==KEY_R: _reroll();get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
			var options:Control=modal_content.get_node("DraftOptions")
			var cards:Array=options.get_children();var at:int=cards.find(get_viewport().gui_get_focus_owner())
			var step:=1 if event.keycode in [KEY_DOWN,KEY_RIGHT] else -1
			cards[posmod(at+step,cards.size()) if at>=0 else 0 if step>0 else cards.size()-1].grab_focus()
			get_viewport().set_input_as_handled()
		elif event.keycode==KEY_ESCAPE:get_viewport().set_input_as_handled()
	elif event.keycode==KEY_ESCAPE:
		if modal_kind!="": _close()
		else: action.emit("pause",{"paused":not frame.paused})
		get_viewport().set_input_as_handled()
