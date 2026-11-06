extends RefCounted
## Settlement information, arranged from transitions.js reportMarkup + juice.css.
const Motion=preload("res://src/ui/motion.gd")
const Slot=preload("res://src/ui/motion_slot.gd")
var v: RefCounted

func build(layer: Control,report: Dictionary,bonus: float) -> void:
	var stamp:=VBoxContainer.new();stamp.name="Stamp";stamp.position.x=36;stamp.size.x=340;stamp.add_theme_constant_override("separation",2);layer.add_child(stamp)
	var level:Label=v.text(stamp,"L E V E L  %02d" % int(report.level),12,"accent-ink",true);level.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var clear:Label=v.text(stamp,"CLEAR",44,"accent-ink-strong",true);clear.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var spaced:=FontVariation.new();spaced.base_font=v.fonts[1];spaced.spacing_glyph=4;clear.add_theme_font_override("font",spaced)
	var center:=CenterContainer.new();stamp.add_child(center)
	v.badge(center,"+ "+_fmt(bonus),v.color("panel"),Color.TRANSPARENT,v.color("accent-hover"),18,5).get_child(0).add_theme_font_override("font",v.fonts[1])
	var card:=PanelContainer.new();card.name="ReportCard";card.position.x=36;card.size=Vector2(340,0)
	var face:Color=v.color("surface");face.a=.95
	card.add_theme_stylebox_override("panel",v.box(face,v.color("line-2"),9));layer.add_child(card)
	var pad:MarginContainer=v.margin(card,14,12,14,10)
	var content:VBoxContainer=v.column(pad)
	var head:HBoxContainer=v.row(content,10);var title:Label=v.text(head,"本关收益",11,"text-3");title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var amount:Label=v.text(head,_fmt(report.total),24,"accent-ink-strong",true);amount.name="Total"
	v.space(content,12)
	var bar:HBoxContainer=v.row(content);bar.name="IncomeBar";bar.custom_minimum_size.y=8
	var total:=0.0
	for part in report.parts:total+=part.value
	for part in report.parts:
		var holder:=Slot.new();holder.size_flags_horizontal=Control.SIZE_EXPAND_FILL;holder.size_flags_stretch_ratio=maxf(.001,float(part.value)/maxf(1,total));holder.mouse_filter=Control.MOUSE_FILTER_IGNORE;bar.add_child(holder)
		var segment:=ColorRect.new();segment.color=Color(part.color);segment.mouse_filter=Control.MOUSE_FILTER_IGNORE;segment.custom_minimum_size.y=8;holder.adopt(segment)
	v.space(content,8)
	var legend:=GridContainer.new();legend.name="Legend";legend.columns=2;legend.add_theme_constant_override("h_separation",14);legend.add_theme_constant_override("v_separation",4);content.add_child(legend)
	for part in report.parts:
		var row:HBoxContainer=v.row(legend,6);row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var dot:=Panel.new();dot.custom_minimum_size=Vector2(8,8);dot.size_flags_vertical=Control.SIZE_SHRINK_CENTER;dot.add_theme_stylebox_override("panel",v.box(Color(part.color),Color.TRANSPARENT,2));row.add_child(dot)
		v.text(row,part.label,11,"text-2").size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var number:Label=v.text(row,_fmt(part.value),11,"ink-2",true);number.set_meta("amount",part.value)
	v.space(content,12);v.rule(content,"surface-3");v.space(content,12)
	var stats:HBoxContainer=v.row(content,8);stats.name="Stats"
	for index in range(3):
		var column:VBoxContainer=v.column(stats,2);column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.size_flags_stretch_ratio=1.4 if index==0 else 1
		v.text(column,["最佳一箭","射出","击碎"][index],10,"text-3")
		var row:HBoxContainer=v.row(column,6)
		v.text(row,["%d 连" % report.bestKills,str(int(report.shots)),str(int(report.bricks))][index],17,"ink-2",true)
		if index==0 and report.get("record",false):
			var tag:Control=v.badge(row,"新纪录",Color("#e8c34a"),Color.TRANSPARENT,Color("#3a2e0a"),9,3);tag.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		v.text(column,["+"+_fmt(report.bestMoney),"箭","块"][index],10,"text-3")
	if report.get("rift") is Dictionary:
		v.space(content,10);var rift:=HFlowContainer.new();rift.add_theme_constant_override("h_separation",6);rift.add_theme_constant_override("v_separation",6);content.add_child(rift)
		v.text(rift,report.rift.title,10,"text-3")
		for item in report.rift.items:v.badge(rift,item,v.color("legend-prism-bg"),Color.TRANSPARENT,v.color("legend-prism"),10,3)
	if report.get("variant") is Dictionary:
		v.space(content,10);var variant:=HFlowContainer.new();variant.name="Variant";variant.add_theme_constant_override("h_separation",6);variant.add_theme_constant_override("v_separation",6);content.add_child(variant)
		v.text(variant,report.variant.title,10,"text-3")
		for item in report.variant.items:v.badge(variant,item,v.color("accent-soft"),Color.TRANSPARENT,v.color("accent-ink-strong"),10,3)
	if not report.get("skills",[]).is_empty():
		v.space(content,10);var skills:=HFlowContainer.new();skills.name="Skills";skills.add_theme_constant_override("h_separation",6);skills.add_theme_constant_override("v_separation",6);content.add_child(skills)
		v.text(skills,"主力技能",10,"text-3")
		for item in report.skills:
			var chip:=PanelContainer.new();chip.add_theme_stylebox_override("panel",v.box(v.color("surface-2"),v.color("line-2"),4,3));skills.add_child(chip)
			var row:HBoxContainer=v.row(chip,4)
			if item.has("icon"):v.image(row,item.icon,v.color("text-2"),Vector2(12,12))
			v.text(row,item.name,11,"text-2");v.text(row,"×%d" % int(item.count),11,"text-3",true)
	v.space(content,10)
	if report.get("reroll") is Dictionary:
		var charge:=PanelContainer.new();charge.name="EarnedCharge";charge.add_theme_stylebox_override("panel",v.box(v.color("accent-soft"),v.color("accent-line"),6,7));content.add_child(charge)
		var charge_center:=CenterContainer.new();charge.add_child(charge_center);var charge_row:HBoxContainer=v.row(charge_center,10)
		v.image(charge_row,"refresh-cw",v.color("accent-ink"),Vector2(15,15))
		var gauge:=preload("res://src/ui/charges.gd").new();gauge.visuals=v;gauge.count=report.reroll.count;gauge.capacity=report.reroll.capacity;charge_row.add_child(gauge)
		v.space(content,10)
	var hint:Label=v.text(content,"点击继续",10,"text-3");hint.name="Continue";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	card.minimum_size_changed.connect(func():layout.call_deferred(layer))
	layout.call_deferred(layer)

func animate(layer:Control,report:Dictionary) -> void:
	if not is_instance_valid(layer):return
	if layer.get_meta("retiring",false):return
	if layer.get_meta("animated",false):return
	layer.set_meta("animated",true)
	layout(layer)
	Motion.enter(layer.get_node("Stamp"),.16)
	var card:Control=layer.get_node("ReportCard");Motion.enter(card,.48)
	var amount:Label=card.find_child("Total",true,false);amount.text="0"
	var tween:=Motion.claim(amount,["text"]);tween.tween_method(func(value:float):amount.text=_fmt(value),0.0,float(report.total),.9).set_delay(.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var bar:Control=card.find_child("IncomeBar",true,false)
	for holder in bar.get_children():
		var segment:Control=holder.get("content")
		segment.scale.x=0
		Motion.claim(segment,["scale"]).tween_property(segment,"scale:x",1.0,.75).set_delay(.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var legend:Control=card.find_child("Legend",true,false)
	for row in legend.get_children():
		var number:Label=row.get_child(2);var value:float=number.get_meta("amount");number.text="0"
		Motion.claim(number,["text"]).tween_method(func(n:float):number.text=_fmt(n),0.0,value,.8).set_delay(.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var hint:Label=card.find_child("Continue",true,false)
	var blink:=Motion.claim(hint,["alpha"]);blink.tween_interval(1.4)
	blink.tween_callback(func():
		if not is_instance_valid(hint):return
		var loop:=hint.create_tween().set_loops();hint.set_meta("motion_alpha",loop)
		loop.tween_property(hint,"modulate:a",.35,.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		loop.tween_property(hint,"modulate:a",1.0,.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)

func layout(layer: Control) -> void:
	if not is_instance_valid(layer):return
	if layer.get_meta("retiring",false):return
	var card:PanelContainer=layer.get_node("ReportCard");card.reset_size();card.size.x=340
	var stamp:VBoxContainer=layer.get_node("Stamp");stamp.reset_size();stamp.size.x=340
	var height:=stamp.size.y+8+card.size.y
	stamp.position.y=maxf(10,(572-height)/2)
	card.position.y=stamp.position.y+stamp.size.y+8
	Motion.pivot(stamp);Motion.pivot(card)

func _fmt(value: float) -> String:
	var digits:=str(int(value));var result:=""
	for i in range(digits.length()):
		if i>0 and (digits.length()-i)%3==0:result+=","
		result+=digits[i]
	return result
