extends RefCounted
## Reference page structure. Interface owns navigation, motion and game actions.
var ui: Control
var v: RefCounted
var f: Dictionary
var root: VBoxContainer
const Charges=preload("res://src/ui/charges.gd")
const Art=preload("res://src/ui/skill_art.gd")
const Preview=preload("res://src/ui/theme_preview.gd")
const Motion=preload("res://src/ui/motion.gd")
const Slot=preload("res://src/ui/motion_slot.gd")

func _motion_slot(node:Control) -> void:
	var parent:Node=node.get_parent();var index:=node.get_index()
	parent.remove_child(node)
	var slot:=Slot.new();slot.size_flags_horizontal=node.size_flags_horizontal;slot.size_flags_vertical=node.size_flags_vertical;slot.size_flags_stretch_ratio=node.size_flags_stretch_ratio
	slot.mouse_filter=Control.MOUSE_FILTER_IGNORE if node.mouse_filter==Control.MOUSE_FILTER_IGNORE else Control.MOUSE_FILTER_PASS
	parent.add_child(slot);parent.move_child(slot,index);slot.adopt(node)

func setup(owner: Control) -> void:
	ui=owner;v=ui.visuals;f=ui.frame;root=ui.modal_content if is_instance_valid(ui.modal_content) else null

func fmt(value: float) -> String:
	if value>=1000000:return "%.1fm" % (value/1000000)
	if value>=10000:return "%.1fk" % (value/1000)
	return str(int(value))

func heading(title: String,kicker: String="",size: int=22,close: bool=true,parent: Control=null) -> HBoxContainer:
	var row:HBoxContainer=v.row(root if parent==null else parent,12)
	var words:VBoxContainer=v.column(row,6);words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if kicker!="":v.text(words,kicker,10,"text-3",true)
	v.text(words,title,size,"ink",true)
	if close:
		var button:Button=v.button(row,"",ui._close,"x",44);button.custom_minimum_size.x=44;button.tooltip_text="返回游戏";button.add_theme_constant_override("icon_max_width",17)
		button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		button.add_theme_stylebox_override("normal",v.box(Color.TRANSPARENT,v.color("line"),6))
	return row

func rarity(parent: Control,item: Dictionary,ribbon: bool=false) -> Control:
	var edge:Color=tier_edge(item)
	var row:HBoxContainer
	var host:Control=parent
	if ribbon:
		var badge:=PanelContainer.new();badge.add_theme_stylebox_override("panel",v.box(v.color("gold-soft" if item.tier=="gold" else "surface"),v.color("gold-line") if item.tier=="gold" else edge,20,4));parent.add_child(badge);host=badge
	row=v.row(host,3)
	var dot:=Panel.new();dot.custom_minimum_size=Vector2(8,8);dot.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	dot.add_theme_stylebox_override("panel",v.box(Color("#edbf42" if item.tier=="gold" else "#439be8" if item.tier=="blue" else "#f4f6f0"),Color("#ac801c" if item.tier=="gold" else "#2875b9" if item.tier=="blue" else "#9aa294"),4));row.add_child(dot)
	v.text(row,{"white":"普通","blue":"稀有","gold":"传说"}[item.tier],10,"gold-ink" if item.tier=="gold" else "text-2",ribbon)
	return host if ribbon else row

func tier_edge(item: Dictionary) -> Color:
	return v.mix(Color("#439be8"),v.color("line-2"),.45) if item.tier=="blue" else v.mix(Color("#e0ad2c"),v.color("line-2"),.7) if item.tier=="gold" else v.color("line-2")

func emblem(parent: Control,item: Dictionary,dimension: int=46,icon_size: int=24,radius: int=12,tint: float=0) -> PanelContainer:
	var ink:=Color(item.color)
	var mark:=PanelContainer.new();mark.name="Emblem";mark.custom_minimum_size=Vector2(dimension,dimension);mark.size_flags_vertical=Control.SIZE_SHRINK_CENTER;mark.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	var style:StyleBoxFlat=v.box(v.mix(ink,v.color("surface"),tint),v.mix(ink,v.color("line-2"),.4),radius)
	if dimension==46:style.shadow_color=Color(ink.r,ink.g,ink.b,.18);style.shadow_size=5
	mark.add_theme_stylebox_override("panel",style);parent.add_child(mark)
	var center:=CenterContainer.new();mark.add_child(center);v.image(center,item.icon,v.mix(ink,v.color("ink"),.72),Vector2(icon_size,icon_size))
	_motion_slot(mark)
	return mark

func charges(parent: Control,ghost: int=0,pip: int=12,gap: int=6) -> Control:
	var gauge:=Charges.new();gauge.visuals=v;gauge.count=int(f.rerolls);gauge.capacity=int(f.rerollCap);gauge.ghost=ghost;gauge.pip=pip;gauge.gap=gap;gauge.progress=f.get("rerollProgress",0.0);gauge.reduced=f.reduced;parent.add_child(gauge)
	if ui.panel!=null and ui.panel.is_ancestor_of(gauge):
		var gauges:Array=ui.panel.get_meta("gauges",[]);gauges.append(gauge);ui.panel.set_meta("gauges",gauges)
	return gauge

func reroll(parent: Control,callback: Callable,disabled: bool) -> Button:
	var center:=CenterContainer.new();parent.add_child(center)
	var button:Button=v.button(center,"",callback,"",38);button.name="Reroll";button.tooltip_text="刷新技能 %d / %d" % [f.rerolls,f.rerollCap];button.disabled=disabled
	button.add_theme_stylebox_override("normal",v.box(v.color("accent-soft"),v.color("accent-line"),20))
	button.add_theme_stylebox_override("disabled",v.box(v.color("surface-2"),v.color("line-2"),20))
	var margin:MarginContainer=v.margin(button,6,6,14,6)
	var row:HBoxContainer=v.row(margin,10);row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var circle:=PanelContainer.new();circle.custom_minimum_size=Vector2(24,24);circle.add_theme_stylebox_override("panel",v.box(v.color("surface"),v.color("line-2" if disabled else "accent-line"),12));row.add_child(circle)
	var icon_center:=CenterContainer.new();circle.add_child(icon_center);v.image(icon_center,"refresh-cw",v.color("text-3" if disabled else "accent-ink"),Vector2(14,14));charges(row)
	button.set_meta("charge_icon",circle);button.set_meta("charge_gauge",row.get_child(row.get_child_count()-1))
	margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.custom_minimum_size.x=44+int(f.rerollCap)*18
	return button

func draft() -> void:
	var header_inset:MarginContainer=v.margin(root,16,18,16,0)
	var header:HBoxContainer=v.row(header_inset,16);header.name="DraftHeader";header.alignment=BoxContainer.ALIGNMENT_END
	var words:VBoxContainer=v.column(header,6);words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	v.text(words,"第 %d 关 · 三选一" % f.level,11,"accent-ink",true)
	v.text(words,"加入下一块拼图",22,"ink",true)
	var count:Control=v.badge(header,"%d / %d 已装备" % [f.skills.size(),f.slots],v.color("surface-2"),v.color("line-2"),v.color("text-2"),11,20);count.size_flags_vertical=Control.SIZE_SHRINK_END
	var loadout_inset:MarginContainer=v.margin(root,16,14,16,0)
	var loadout:=PanelContainer.new();loadout.name="Loadout";loadout.add_theme_stylebox_override("panel",v.box(v.color("surface-2"),Color.TRANSPARENT,10,8));loadout_inset.add_child(loadout)
	var row:HBoxContainer=v.row(loadout,5)
	for i in range(int(f.slots)):
		var id:String=f.skills[i] if i<f.skills.size() else ""
		var outgoing:bool=i==0 and f.skills.size()>=f.slots
		var slot:=PanelContainer.new();slot.name="Slot%d" % i;slot.size_flags_horizontal=Control.SIZE_EXPAND_FILL;slot.custom_minimum_size.y=32
		slot.add_theme_stylebox_override("panel",v.box(v.color("warm-soft" if outgoing else "surface" if id!="" else "surface-2"),v.color("warm-line" if outgoing else "line-2"),7,6));row.add_child(slot)
		var line:HBoxContainer=v.row(slot,5)
		if id!="":v.image(line,ui.catalog[id].icon,v.mix(Color(ui.catalog[id].color),v.color("ink"),.7),Vector2(15,15))
		v.text(line,ui.catalog[id].name if id!="" else "等待加入",11,"warm-ink" if outgoing else "text-3" if id=="" else "ink",true,true)
		if outgoing:slot.tooltip_text="最早 · 将替换"
		_motion_slot(slot)
	v.space(root,16)
	var options_inset:MarginContainer=v.margin(root,16,0,16,0)
	var options:VBoxContainer=v.column(options_inset,10);options.name="DraftOptions"
	for id in f.draft.options:skill_card(options,id,func():ui._select(id))
	var reroll_inset:MarginContainer=v.margin(root,16,12,16,16)
	reroll(reroll_inset,func():ui._reroll(),f.rerolls<=0)

func skill_card(parent: Control,id: String,callback: Callable) -> Button:
	var item:Dictionary=ui.catalog[id]
	var slot:=Slot.new();slot.size_flags_horizontal=Control.SIZE_EXPAND_FILL;slot.gap=10;parent.add_child(slot)
	var card:=Button.new();card.pressed.connect(callback);slot.adopt(card);card.name="Skill_"+id;card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.clip_contents=true
	card.add_theme_stylebox_override("normal",v.box(v.color("surface-2"),tier_edge(item),11))
	card.add_theme_stylebox_override("hover",v.box(v.color("surface-2"),v.mix(Color(item.color),v.color("line-2"),.65),11))
	card.add_theme_stylebox_override("pressed",v.box(v.color("surface-2"),Color(item.color),11))
	# Web cards deliberately have no persistent focus outline. Godot's shared
	# button theme would otherwise add an accent frame to the first focused card.
	card.add_theme_stylebox_override("focus",v.box(v.color("surface-2"),tier_edge(item),11))
	var layout:=HBoxContainer.new();layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layout.add_theme_constant_override("separation",0);layout.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(layout)
	var art:=Art.new();art.visuals=v;art.ink=Color(item.color);art.custom_minimum_size.x=76;art.size_flags_vertical=Control.SIZE_EXPAND_FILL;layout.add_child(art)
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);center.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.add_child(center);emblem(center,item)
	var content:VBoxContainer=v.column(layout);content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var inset:MarginContainer=v.margin(content,14,6,14,0)
	var words:VBoxContainer=v.column(inset);words.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var ribbon:=HBoxContainer.new();words.add_child(ribbon)
	var badge:Control=rarity(ribbon,item,true);badge.name="CardRarity";_motion_slot(badge)
	v.space(words,0);v.text(words,item.name,17,"ink",true);v.space(words,4);v.text(words,item.family+" · 跨关生效",10,"text-3")
	v.space(words,8)
	var desc:Label=v.text(words,item.description,11,"text-2",false,true);desc.custom_minimum_size.x=238;desc.add_theme_constant_override("line_spacing",5)
	words.name="CardWords"
	v.space(words,0);v.text(words,"本轮出现率 %.2f%%" % (f.chances.get(id,0)*100),10,"text-3");v.space(words,10)
	v.rule(content)
	var footer:MarginContainer=v.margin(content,14,9,14,9);var pick:HBoxContainer=v.row(footer,8)
	footer.name="CardFooter"
	var outgoing:bool=f.skills.size()>=f.slots
	var text:Label=v.text(pick,"替换「%s」" % ui.catalog[f.skills[0]].name if outgoing else "加入技能槽",12,"warm-ink" if outgoing else "accent-ink",true);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	v.image(pick,"arrow-left-right" if outgoing else "arrow-up-right",v.color("warm-ink" if outgoing else "accent-ink"),Vector2(15,15))
	card.custom_minimum_size=Vector2(0,0)
	content.minimum_size_changed.connect(func():card.custom_minimum_size.y=content.get_combined_minimum_size().y+2)
	v.pointer_through(layout)
	_motion_slot(words);_motion_slot(footer)
	card.mouse_entered.connect(func():ui._preview_skill(id))
	card.focus_entered.connect(func():ui._preview_skill(id))
	card.mouse_exited.connect(func():ui._preview_skill(""))
	card.focus_exited.connect(func():ui._preview_skill(""))
	if not f.reduced:
		Motion.prepare_deal(card);words.modulate.a=0;footer.modulate.a=0
	return card

func update_draft() -> void:
	var options:Control=root.find_child("DraftOptions",true,false)
	if options==null:return
	ui.panel.set_meta("deal_generation",int(ui.panel.get_meta("deal_generation",0))+1)
	if not f.reduced:
		for card in Motion.cards(options):ui._retire_copy(card,.22)
	for child in options.get_children():options.remove_child(child);child.queue_free()
	if options.has_meta("dealt"):options.remove_meta("dealt")
	for id in f.draft.options:skill_card(options,id,func():ui._select(id))
	var slot:Control=root.find_child("Slot%d" % (0 if f.skills.size()>=f.slots else f.skills.size()),true,false)
	if slot!=null:ui._preview_skill("",true)
	update_reroll(root.find_child("Reroll",true,false),true)

func update_reroll(button:Button,draft:bool=false) -> void:
	if button==null:return
	button.disabled=ui.choosing or ui.rolling or bool(ui.panel.get_meta("rolling",false)) or f.rerolls<=0 or not draft and not f.get("canSwap",false)
	button.tooltip_text="刷新技能 %d / %d" % [f.rerolls,f.rerollCap]
	var circle:Control=button.get_meta("charge_icon") if button.has_meta("charge_icon") else null
	if circle!=null:
		if f.reduced:circle.modulate.a=.5 if button.disabled else 1.0
		elif not circle.has_meta("waiting") or circle.get_meta("waiting")!=button.disabled:
			circle.set_meta("waiting",button.disabled);Motion.fade(circle,.5 if button.disabled else 1.0,.2)

func shop() -> void:
	heading("整装，再出发","UPGRADE SHOP",23)
	v.space(root,12);v.text(root,"花费本轮金币，强化下一支箭的能力。",12,"text-2");v.space(root,20);v.rule(root)
	var balance:MarginContainer=v.margin(root,0,14,0,14);var wallet:HBoxContainer=v.row(balance)
	var label:Label=v.text(wallet,"可用金币",12,"text-2");label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var balance_value:Label=v.text(wallet,"¥ "+fmt(f.coins),23,"ink-2",true);balance_value.name="ShopBalance";v.rule(root);v.space(root,6)
	for i in range(f.shop.size()):
		var item:Dictionary=f.shop[i]
		var pad:MarginContainer=v.margin(root,0,18,0,0 if i==f.shop.size()-1 else 18)
		var slot:=Slot.new();slot.size_flags_horizontal=Control.SIZE_EXPAND_FILL;pad.add_child(slot)
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);slot.adopt(row);row.name="Upgrade_"+item.key
		var icon_center:=CenterContainer.new();icon_center.custom_minimum_size=Vector2(36,44);row.add_child(icon_center);v.image(icon_center,item.icon,v.color("text-2"),Vector2(24,24))
		var words:VBoxContainer=v.column(row,5);words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;words.custom_minimum_size.x=168
		var title:HBoxContainer=v.row(words,8);v.text(title,item.name,14,"ink",true)
		var level_label:Label=v.text(title,item.get("levelLabel","LV. %d" % (item.level+1)),10,"text-3");level_label.size_flags_vertical=Control.SIZE_SHRINK_CENTER;level_label.name="UpgradeLevel"
		var details:VBoxContainer=v.column(words,5);details.name="UpgradeDetails"
		_shop_details(details,item)
		row.set_meta("detail_key",JSON.stringify([item.level,item.locked,item.maxed,item.description,f.rerollCap,f.slots]))
		var buy:Button=v.button(row,"",func():ui.action.emit("buy",{"key":item.key}),"plus",44)
		buy.name="Buy_"+item.key;buy.custom_minimum_size.x=100;buy.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		buy.add_theme_stylebox_override("normal",v.box(v.color("buy"),v.color("buy-line"),6,8));buy.add_theme_stylebox_override("hover",v.box(v.color("buy-hover"),v.color("buy-line"),6,8));buy.add_theme_color_override("font_color",v.color("on-buy"))
		buy.add_theme_stylebox_override("pressed",v.box(v.color("buy-hover"),v.color("buy-line"),6,8))
		for state in ["font_hover_color","font_pressed_color","font_hover_pressed_color"]:buy.add_theme_color_override(state,v.color("on-buy"))
		buy.icon=null;_shop_button(buy,item)
		if i<f.shop.size()-1:v.rule(root)

func _shop_details(words:Control,item:Dictionary) -> void:
	match item.key:
		"comboCap":
			if item.locked:
				var lock:HBoxContainer=v.row(words,5);v.image(lock,"lock-keyhole",v.color("text-3"),Vector2(11,11));v.text(lock,"砖块 LV.6",10,"text-3")
			else:
				metric(words,"增幅","+"+ui._compact(f.preview.comboStep),"+"+ui._compact(f.preview.comboStep+.025));metric(words,"上限","×"+ui._compact(f.preview.comboCap),"×"+ui._compact(f.preview.comboCap+.5))
		"slots":
			if item.maxed:v.text(words,"已解锁全部 %d 个技能槽。" % f.get("slotMax",4),10,"accent-ink",false,true)
			else:metric(words,"技能槽",str(int(f.slots)),str(int(f.slots)+1))
		"rerollCap":charges(words,0 if item.maxed else 1,13)
		_:v.text(words,item.description,11,"text-3",false,true).add_theme_constant_override("line_spacing",3)

func _shop_button(buy:Button,item:Dictionary) -> void:
	buy.text="＋  "+("已满级" if item.maxed else "—" if item.locked else fmt(item.cost))
	buy.disabled=item.maxed or item.locked or not item.affordable or f.phase!="ready" or f.paused

func update_shop() -> void:
	# Coins and affordability change during a volley. Update the existing
	# controls so their scroll, focus and in-progress motion remain intact.
	var balance:Label=root.find_child("ShopBalance",true,false)
	if balance!=null:balance.text="¥ "+fmt(f.coins)
	var poses:Dictionary={}
	var changed:=false
	for item in f.shop:
		var row:Control=root.find_child("Upgrade_"+item.key,true,false)
		if row!=null:poses[row]=Motion.pose_in(ui.motion_layer,row)
	for item in f.shop:
		var row:Control=root.find_child("Upgrade_"+item.key,true,false)
		if row==null:continue
		var key:=JSON.stringify([item.level,item.locked,item.maxed,item.description,f.rerollCap,f.slots])
		if row.get_meta("detail_key","")!=key:
			changed=true
			row.set_meta("detail_key",key)
			var level_label:Label=row.find_child("UpgradeLevel",true,false)
			level_label.text=item.levelLabel
			var details:Control=row.find_child("UpgradeDetails",true,false)
			if not f.reduced:ui._retire_copy(details,.2)
			for child in details.get_children():details.remove_child(child);child.queue_free()
			_shop_details(details,item)
			if not f.reduced:
				details.modulate.a=0;Motion.fade(details,1.0,.24);Motion.pulse(level_label,1.12)
		var buy:Button=row.find_child("Buy_"+item.key,true,false)
		_shop_button(buy,item)
		if item.key=="rerollCap":
			var details:Control=row.find_child("UpgradeDetails",true,false)
			for gauge in details.get_children():
				if gauge.get_script()==Charges:gauge.set_amount(int(f.rerolls),float(f.rerollProgress),f.reduced)
	if changed and not f.reduced:ui._restore_layout.call_deferred(poses)

func metric(parent: Control,title: String,before: String,after: String) -> void:
	var row:HBoxContainer=v.row(parent,4);v.text(row,title,9,"text-3").custom_minimum_size.x=26
	v.text(row,before,12,"text-3").size_flags_horizontal=Control.SIZE_EXPAND_FILL
	v.image(row,"arrow-right",v.color("text-3"),Vector2(11,11));v.text(row,after,12,"accent-ink",true).size_flags_horizontal=Control.SIZE_EXPAND_FILL

func detail(id: String) -> void:
	root.set_meta("shown_detail",id)
	var item:Dictionary=ui.catalog[id];var head:HBoxContainer=v.row(root,13);head.name="DetailHeader"
	emblem(head,item,40,22,8,.12)
	var words:VBoxContainer=v.column(head,4);words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var title:Label=v.text(words,item.name,19,"ink",true);title.name="DetailName"
	var family:Label=v.text(words,item.family+" · 跨关生效",10,"text-3");family.name="DetailFamily"
	var close:Button=v.button(head,"",ui._close,"x",44);close.custom_minimum_size.x=44;close.tooltip_text="关闭技能说明";close.add_theme_stylebox_override("normal",v.box(Color.TRANSPARENT,v.color("line"),6))
	close.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	v.space(root,11);var ribbon:Control=rarity(root,item);ribbon.name="DetailRarity";v.space(root,11)
	var description:Label=v.text(root,item.description,12,"text-2",false,true);description.name="DetailDescription";description.add_theme_constant_override("line_spacing",8)
	_motion_slot(head);_motion_slot(description)
	if id not in f.skills:return
	v.space(root,18);v.rule(root,"line-2");v.space(root,14)
	var options:VBoxContainer=v.column(root,0);options.name="SwapOptions"
	reroll(root,func():ui._reroll(id),f.rerolls<=0 or not f.get("canSwap",f.phase=="ready"))
	update_detail(id)

func morph_detail(id:String,content_root:Control=null) -> void:
	var scope:Control=root if content_root==null else content_root
	var item:Dictionary=ui.catalog[id]
	var head:Control=scope.find_child("DetailHeader",true,false)
	if head==null or scope.get_meta("shown_detail","")==id:return
	var description:Label=scope.find_child("DetailDescription",true,false)
	var ribbon:Control=scope.find_child("DetailRarity",true,false)
	if not f.reduced:
		for node in [head,description,ribbon]:ui._retire_copy(node,.2)
	scope.set_meta("shown_detail",id)
	var mark:PanelContainer=head.find_child("Emblem",true,false)
	var ink:=Color(item.color)
	mark.add_theme_stylebox_override("panel",v.box(v.mix(ink,v.color("surface"),.12),v.mix(ink,v.color("line-2"),.4),8))
	var image:TextureRect=mark.get_child(0).get_child(0);image.texture=v.icon(item.icon,v.mix(ink,v.color("ink"),.72))
	var title:Label=scope.find_child("DetailName",true,false);title.text=item.name
	var family:Label=scope.find_child("DetailFamily",true,false);family.text=item.family+" · 跨关生效"
	description.text=item.description
	var parent:Control=ribbon.get_parent();var at:=ribbon.get_index();parent.remove_child(ribbon);ribbon.queue_free()
	var replacement:Control=rarity(parent,item);replacement.name="DetailRarity";parent.move_child(replacement,at)
	if not f.reduced:
		for node in [head,description]:
			# The retiring copy keeps the old visible pose while the changed
			# content enters again, including after an interrupted replacement.
			Motion.cancel(node,["position","alpha"])
			node.position=node.get_meta("reveal_position",Vector2.ZERO)
			if node.has_meta("motion_revealed"):node.remove_meta("motion_revealed")
		Motion.reveal(head,0,.34,Vector2(0,4));Motion.reveal(description,.04,.3,Vector2(0,4));Motion.settle_scale(mark,1.12)
		replacement.modulate.a=0;Motion.fade(replacement,1.0,.24)
	else:
		for node in [head,description]:Motion.cancel(node,["position","alpha"]);node.position=Vector2.ZERO;node.modulate.a=1.0
		Motion.cancel(mark,["scale"]);mark.scale=Vector2.ONE

func update_detail(id:String) -> bool:
	var options:Control=root.find_child("SwapOptions",true,false)
	if options==null:return false
	var ids:Array=f.swapOffer.options if f.swapOffer is Dictionary and f.swapOffer.target==id else []
	var key:=JSON.stringify(ids)
	var changed:bool=key!=options.get_meta("offer_key","")
	if changed:
		ui.panel.set_meta("deal_generation",int(ui.panel.get_meta("deal_generation",0))+1)
		options.set_meta("offer_key",key)
		if options.has_meta("dealt"):options.remove_meta("dealt")
		if not f.reduced:
			for card in Motion.cards(options):ui._retire_copy(card,.22)
		for child in options.get_children():options.remove_child(child);child.queue_free()
		for candidate in ids:swap_card(options,id,candidate)
		if ids.is_empty():
			ui.panel.set_meta("rolling",false);ui.rolling=false
	for card in Motion.cards(options):card.disabled=ui.choosing or ui.rolling or bool(ui.panel.get_meta("rolling",false)) or not f.canSwap
	update_reroll(root.find_child("Reroll",true,false))
	return changed and not ids.is_empty()

func swap_card(parent: Control,target: String,id: String) -> void:
	var item:Dictionary=ui.catalog[id]
	var slot:=Slot.new();slot.size_flags_horizontal=Control.SIZE_EXPAND_FILL;slot.gap=8;parent.add_child(slot)
	var button:=Button.new();button.pressed.connect(func():ui._swap(target,id));slot.adopt(button);button.name="Swap_"+id;button.clip_contents=true
	button.add_theme_stylebox_override("normal",v.box(v.mix(Color(item.color),v.color("surface"),.09),tier_edge(item),10))
	var pad:MarginContainer=v.margin(button,12,10,12,10);var row:HBoxContainer=v.row(pad,12)
	emblem(row,item,40,20,11)
	var words:VBoxContainer=v.column(row,4);words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;words.custom_minimum_size.x=205
	words.name="CardWords"
	var title:HBoxContainer=v.row(words,8);v.text(title,item.name,14,"ink",true);var ribbon:Control=rarity(title,item);ribbon.name="CardRarity"
	_motion_slot(ribbon)
	v.text(words,item.description,11,"text-2",false,true).add_theme_constant_override("line_spacing",4)
	v.image(row,"arrow-left-right",v.color("text-3"),Vector2(16,16))
	button.custom_minimum_size.y=100;pad.mouse_filter=Control.MOUSE_FILTER_IGNORE
	words.minimum_size_changed.connect(func():button.custom_minimum_size.y=pad.get_combined_minimum_size().y)
	v.pointer_through(pad)
	_motion_slot(words)
	if not f.reduced:Motion.prepare_deal(button);words.modulate.a=0

func library() -> void:
	heading("我的构筑","",21);v.space(root,16)
	v.text(root,"按获得顺序排列 · 跨关生效 · 满槽时自动替换最早的技能",11,"text-3",false,true);v.space(root,18)
	var grid:VBoxContainer=v.column(root,10);grid.name="LibraryGrid"
	_library_cards(grid)
	root.set_meta("library_key",JSON.stringify([f.skills,f.slots,f.theme]))

func update_library() -> void:
	var key:=JSON.stringify([f.skills,f.slots,f.theme])
	if root.get_meta("library_key","")==key:return
	root.set_meta("library_key",key)
	var grid:Control=root.find_child("LibraryGrid",true,false)
	if grid==null:return
	if not f.reduced:ui._retire_copy(grid,.22)
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	_library_cards(grid)
	if not f.reduced:grid.modulate.a=0;Motion.fade(grid,1.0,.28)

func _library_cards(grid:Control) -> void:
	if f.skills.is_empty():v.text(grid,"尚未装备技能。每关选择一个，逐步组成你的 %d 技能构筑。" % f.slots,12,"text-3",false,true)
	for id in f.skills:
		var item:Dictionary=ui.catalog[id];var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",v.box(v.color("surface-2"),v.color("line-2"),7,20));grid.add_child(card)
		var content:VBoxContainer=v.column(card,10);v.text(content,item.family,10,"text-3")
		var mark:PanelContainer=emblem(content,item,40,22,8,.1);mark.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		(mark.get_parent() as Control).size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		v.space(content,8);v.text(content,item.name,19,"ink",true);rarity(content,item)
		v.text(content,item.description,12,"text-2",false,true).add_theme_constant_override("line_spacing",7)

func equipment(expanded: bool=false) -> void:
	root.set_meta("expanded",expanded)
	heading("装备与技能","",18);v.space(root,8);v.rule(root);v.space(root,14)
	v.text(root,"YOUR BALANCE",10,"text-3",true);v.space(root,10)
	var balance:HBoxContainer=v.row(root,10);v.text(balance,"¥",18,"accent-ink").size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var wallet:Label=v.text(balance,fmt(f.coins),42,"ink",true);wallet.name="EquipmentBalance"
	v.space(root,4)
	var stats:HBoxContainer=v.row(root,12);v.text(stats,"累计击碎  "+fmt(f.total),10,"text-3").size_flags_horizontal=Control.SIZE_EXPAND_FILL;v.text(stats,"单箭最佳  "+str(int(f.best)),10,"text-3");v.space(root,14);v.rule(root);v.space(root,14)
	var skills:Button=v.button(root,"我的构筑",ui._library,"sparkles",44);skills.alignment=HORIZONTAL_ALIGNMENT_LEFT;skills.name="OpenLibrary";skills.add_theme_constant_override("icon_max_width",16)
	var count:Label=v.text(skills,"%d / %d  ›" % [f.skills.size(),f.slots],10,"text-2");count.name="EquipmentSkillCount";count.position=Vector2(276,15)
	v.space(root,9)
	var tags:=HFlowContainer.new();tags.name="EquipmentSkills";tags.add_theme_constant_override("h_separation",5);root.add_child(tags)
	_equipment_tags(tags)
	root.set_meta("equipment_skills",JSON.stringify([f.skills,f.slots]))
	v.space(root,14)
	var equipment_root:=root
	var achievements:Button=v.button(root,"精彩操作图鉴",func():ui._equipment(not bool(equipment_root.get_meta("expanded",false))),"chevron-down" if expanded else "chevron-right",44);achievements.name="AchievementToggle";achievements.alignment=HORIZONTAL_ALIGNMENT_LEFT;achievements.add_theme_stylebox_override("normal",v.box(Color.TRANSPARENT,Color.TRANSPARENT,0))
	var earned:=0
	for n in f.achievementHistory.values():if n>0:earned+=1
	var reading:Label=v.text(achievements,"%d / 12" % earned,11,"accent-ink",true);reading.position=Vector2(287,16)
	var reveal:=Slot.new();reveal.name="AchievementSection";reveal.size_flags_horizontal=Control.SIZE_EXPAND_FILL;reveal.clip_contents=true;root.add_child(reveal)
	var achievement_body:=VBoxContainer.new();achievement_body.add_theme_constant_override("separation",0);reveal.adopt(achievement_body)
	if expanded:achievement_list(achievement_body)
	else:reveal.extent=0.0;reveal.hide()
	v.space(root,10);v.rule(root);v.space(root,16)
	var core:HBoxContainer=v.row(root,8);v.image(core,"diamond",v.color("accent-bar"),Vector2(14,14));v.text(core,"一击终结",13,"ink",true);v.space(root,12)
	v.text(root,"击碎 %d 块后，顶部核心出现。\n命中核心，清空本关。" % f.threshold,10,"text-3").add_theme_constant_override("line_spacing",8)
	v.space(root,14);var reward:HBoxContainer=v.row(root);v.text(reward,"独立通关奖金",10,"text-3").size_flags_horizontal=Control.SIZE_EXPAND_FILL;v.text(reward,"+ "+fmt(f.preview.bonus),14,"accent-ink",true)
	v.space(root,16);v.text(root,"不止是方块",13,"ink",true);v.space(root,14)
	var grid:=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);root.add_child(grid)
	for special in [["爆破","引爆周围方块","asterisk","bomb"],["电弧","跃击最近的 5 块","zap","lightning"],["冰晶","无视穿透 · 命中不消耗次数","snowflake","frost"],["分裂","分出三支箭","split","prism"],["金矿","本块金币 ×3","coins","gold"],["合金障碍","无法击碎 · 箭矢反弹","shield-minus","metal"]]:
		var line:HBoxContainer=v.row(grid,8);line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var mark:=PanelContainer.new();mark.custom_minimum_size=Vector2(26,26);mark.add_theme_stylebox_override("panel",v.box(v.color("legend-"+special[3]+"-bg"),Color.TRANSPARENT,3));line.add_child(mark);var center:=CenterContainer.new();mark.add_child(center);v.image(center,special[2],v.color("legend-"+special[3]),Vector2(14,14))
		var words:VBoxContainer=v.column(line,4);v.text(words,special[0],10);v.text(words,special[1],10,"text-3",false,true)
	v.space(root,20);v.rule(root);v.space(root,12)
	var footer:HBoxContainer=v.row(root);v.text(footer,"每一关，都是新的可能。",10,"text-3").size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var reset:Button=v.button(footer,"",ui._reset_confirmation,"rotate-ccw",44);reset.custom_minimum_size.x=44;reset.tooltip_text="重新开始";reset.add_theme_stylebox_override("normal",v.box(Color.TRANSPARENT,Color.TRANSPARENT,0))

func _equipment_tags(tags:Control) -> void:
	if f.skills.is_empty():v.text(tags,"技能跨关保留，满 %d 个后自动替换最早获得的技能" % f.slots,10,"text-3")
	for id in f.skills:
		var tag:=PanelContainer.new();tag.add_theme_stylebox_override("panel",v.box(v.color("surface-2"),Color.TRANSPARENT,3,4));tags.add_child(tag)
		var line:HBoxContainer=v.row(tag,4);v.image(line,ui.catalog[id].icon,Color(ui.catalog[id].color),Vector2(13,13));v.text(line,ui.catalog[id].name,10,"text-2")

func update_equipment() -> void:
	var wallet:Label=root.find_child("EquipmentBalance",true,false)
	if wallet!=null:wallet.text=fmt(f.coins)
	var key:=JSON.stringify([f.skills,f.slots])
	if root.get_meta("equipment_skills","")==key:return
	root.set_meta("equipment_skills",key)
	var count:Label=root.find_child("EquipmentSkillCount",true,false)
	if count!=null:count.text="%d / %d  ›" % [f.skills.size(),f.slots]
	var tags:Control=root.find_child("EquipmentSkills",true,false)
	if tags==null:return
	if not f.reduced:ui._retire_copy(tags,.22)
	for child in tags.get_children():tags.remove_child(child);child.queue_free()
	_equipment_tags(tags)
	if not f.reduced:tags.modulate.a=0;Motion.fade(tags,1.0,.28)

func expand_achievements(expanded:bool) -> void:
	root.set_meta("expanded",expanded)
	var holder:Slot=root.find_child("AchievementSection",true,false)
	if holder==null:return
	if holder.content.get_child_count()==0:achievement_list(holder.content)
	var destination:=holder.content.get_combined_minimum_size().y if expanded else 0.0
	if holder.extent<0:holder.extent=holder.size.y
	holder.show()
	if f.reduced:Motion.stop(holder);holder.extent=destination;holder.visible=expanded
	else:
		var tween:=Motion.claim(holder,["extent"])
		tween.tween_property(holder,"extent",destination,.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if not expanded:tween.tween_callback(holder.hide)
	var button:Button=root.find_child("AchievementToggle",true,false)
	if button!=null:button.icon=v.icon("chevron-down" if expanded else "chevron-right",v.color("text-2"))

func achievement_list(parent: Control) -> void:
	v.text(parent,"击碎才计连击，每支箭独立从 0 计数，不因命中间隔断连。分裂箭、齐射箭分别判定；连锁与延迟伤害归属触发箭。",11,"text-3",false,true).add_theme_constant_override("line_spacing",7)
	v.space(parent,12)
	v.text(parent,"第 1 块连击倍率 ×1，此后每块增加 %s，第 %d 块达到 ×%s 上限。砖块 LV.6 解锁连击强化，每级让每连增幅 +0.025、倍率上限 +0.5。" % [ui._compact(f.preview.comboStep),f.preview.capKills,ui._compact(f.preview.comboCap)],11,"text-3",false,true).add_theme_constant_override("line_spacing",7)
	v.space(parent,12)
	v.text(parent,"砖块收入 = 各块价值 × 各自连击倍率 × 财富技能，再按本箭成就倍率结算。连击与赏金不追补；成就从 ×1 开始，各项加成相加，每箭每项一次，新成就会补发本箭此前收入的差额。4 / 8 / 12 / 20 连分别奖励 +0.25 / +0.5 / +1 / +1.5 成就倍率。",11,"text-3",false,true).add_theme_constant_override("line_spacing",7)
	v.space(parent,12)
	v.text(parent,"面板标注最近得分箭：连击倍率用于该箭刚击碎的砖，成就倍率作用于整箭；箭号切换不代表断连。本轮累计合计所有箭与独立奖金，核心清场不增加连击。",11,"text-3",false,true).add_theme_constant_override("line_spacing",7)
	v.space(parent,12)
	for item in f.achievementCatalog:
		v.rule(parent);var pad:MarginContainer=v.margin(parent,0,12,0,12);var row:HBoxContainer=v.row(pad,10)
		var ink:=Color(v.manifest.achievements[item.id].color);var mark:=PanelContainer.new();mark.custom_minimum_size=Vector2(34,38);mark.add_theme_stylebox_override("panel",v.box(v.mix(ink,v.color("surface"),.07),v.color("line"),6));row.add_child(mark);var center:=CenterContainer.new();mark.add_child(center);v.image(center,"achievement-"+item.id,ink,Vector2(24,24))
		var words:VBoxContainer=v.column(row,4);words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;var count:int=f.achievementHistory.get(item.id,0)
		v.text(words,("✓ " if count>0 else "")+item.name,12,"ink",true);v.text(words,item.description,10,"text-3",false,true)
		var bonus:VBoxContainer=v.column(row,4);v.text(bonus,"+%s×" % ui._compact(item.bonus),19,"accent-ink",true);v.text(bonus,"%d 次" % count,10,"text-3")

func settings() -> void:
	heading("设置","SETTINGS");v.space(root,18);v.rule(root);v.space(root,16);v.text(root,"外观",13,"ink",true);v.space(root,12)
	var themes:HBoxContainer=v.row(root,10);themes.name="ThemeOptions"
	for mode in ["system","light","dark"]:
		var selected:bool=f.themeMode==mode
		var button:Button=v.button(themes,"",func():ui.action.emit("configure",{"theme":mode});ui._settings());button.name="Theme_"+mode;button.custom_minimum_size=Vector2(104,100);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.tooltip_text={"system":"跟随系统","light":"亮色","dark":"深色"}[mode]
		button.add_theme_stylebox_override("normal",v.box(v.color("accent-soft" if selected else "surface-2"),v.color("accent-ink" if selected else "line-2"),8))
		var pad:MarginContainer=v.margin(button,8,8,8,8);var words:VBoxContainer=v.column(pad,9);var preview:=Preview.new();preview.mode=mode;words.add_child(preview)
		var line:HBoxContainer=v.row(words,5);line.alignment=BoxContainer.ALIGNMENT_CENTER;v.image(line,{"system":"monitor","light":"sun","dark":"moon"}[mode],v.color("text-2"),Vector2(14,14));v.text(line,button.tooltip_text,12,"text-2",true)
		pad.mouse_filter=Control.MOUSE_FILTER_IGNORE
		v.pointer_through(pad)
	v.space(root,12);v.text(root,"跟随系统，当前为"+("深色" if f.theme=="dark" else "亮色") if f.themeMode=="system" else "始终使用"+("深色" if f.themeMode=="dark" else "亮色"),11,"text-3")
	v.space(root,18);v.rule(root);v.space(root,16)
	var performance:HBoxContainer=v.row(root,12);var check:=CheckBox.new();check.name="Performance";check.button_pressed=f.performanceMode;check.custom_minimum_size.x=18;check.toggled.connect(func(enabled):ui.action.emit("configure",{"performanceMode":enabled}));performance.add_child(check)
	var labels:VBoxContainer=v.column(performance,4);v.text(labels,"性能模式",13,"ink",true);v.text(labels,"减少动画和特效，适配低性能设备",11,"text-3")
	v.space(root,18);v.rule(root);v.space(root,16)
	var heading_row:HBoxContainer=v.row(root);v.text(heading_row,"声音大小",13,"ink",true).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var value:Label=v.text(heading_row,"%d%%" % f.volume,13,"accent-ink",true)
	v.space(root,12);var slider:=HSlider.new();slider.name="Volume";slider.min_value=0;slider.max_value=100;slider.step=1;slider.value=f.volume;slider.custom_minimum_size.y=18
	var track:StyleBoxFlat=v.box(v.color("line-2"),Color.TRANSPARENT,2);track.set_content_margin_all(0);track.content_margin_top=2;track.content_margin_bottom=2
	var fill:StyleBoxFlat=v.box(v.color("accent-ink"),Color.TRANSPARENT,2);fill.set_content_margin_all(0);fill.content_margin_top=2;fill.content_margin_bottom=2
	slider.add_theme_stylebox_override("slider",track);slider.add_theme_stylebox_override("grabber_area",fill);slider.add_theme_stylebox_override("grabber_area_highlight",fill)
	slider.add_theme_icon_override("grabber",v.circle_icon("circle",v.color("accent-ink"),14));slider.add_theme_icon_override("grabber_highlight",v.circle_icon("circle",v.color("accent-ink"),14))
	slider.value_changed.connect(func(number):value.text="%d%%" % number;ui.action.emit("configure",{"volume":int(number)}));root.add_child(slider)
	v.space(root,9);var scale:HBoxContainer=v.row(root);v.text(scale,"静音",11,"text-3").size_flags_horizontal=Control.SIZE_EXPAND_FILL;v.text(scale,"最大",11,"text-3")
	v.space(root,18);v.rule(root);v.space(root,16)
	var progress:HBoxContainer=v.row(root,8);v.text(progress,"游戏进度",13,"ink",true).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	v.button(progress,"导出进度",func():ui._file(false));v.button(progress,"导入进度",func():ui._file(true));v.space(root,8)
	v.text(root,"将当前存档保存为文件，或从其他设备恢复存档。",11,"text-3",false,true)

func reset() -> void:
	v.text(root,"从第一箭重新开始？",20,"ink",true);v.space(root,18);v.text(root,"当前关卡、金币与升级将被清空。",12,"text-3");v.space(root,28)
	var actions:HBoxContainer=v.row(root,10);actions.alignment=BoxContainer.ALIGNMENT_END
	var cancel:Button=v.button(actions,"取消",ui._close,"",44);cancel.custom_minimum_size.x=76;cancel.add_theme_stylebox_override("normal",v.box(v.color("surface-2"),Color.TRANSPARENT,5,8))
	var confirm:Button=v.button(actions,"重新开始",ui._reset_run,"",44)
	confirm.custom_minimum_size.x=102;confirm.add_theme_stylebox_override("normal",v.box(v.color("accent"),Color.TRANSPARENT,5,8))
