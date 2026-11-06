extends RefCounted
const Developer=preload("res://src/core/developer.gd")
var ui:Control
var v:RefCounted
var root:Control

func number(parent:Control,value:float,low:float,high:float,step:float=1) -> SpinBox:
	var field:=SpinBox.new();field.min_value=low;field.max_value=high;field.step=step;field.value=value
	field.custom_minimum_size=Vector2(130,40);field.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var edit:=field.get_line_edit()
	edit.add_theme_stylebox_override("normal",v.box(v.color("surface-2"),v.color("line-2"),6,8))
	edit.add_theme_stylebox_override("focus",v.box(v.color("surface-2"),v.color("accent-ink"),6,8))
	edit.add_theme_color_override("font_color",v.color("ink"));edit.add_theme_color_override("caret_color",v.color("accent-ink"))
	for direction in ["up","down"]:
		var image:=Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12"><path d="%s" fill="none" stroke="#%s" stroke-width="1.5"/></svg>' % ["M3 8 6 5 9 8" if direction=="up" else "M3 4 6 7 9 4",v.color("text-2").to_html(false)])
		field.add_theme_icon_override(direction,ImageTexture.create_from_image(image))
	parent.add_child(field)
	return field

func section(title:String) -> void:
	v.space(root,16);v.rule(root);v.space(root,12);v.text(root,title,14,"ink",true)

func build(owner:Control) -> void:
	ui=owner;v=ui.visuals;root=ui.modal_content
	var f:Dictionary=ui.frame;var dev:Dictionary=f.developer
	ui.pages.heading("开发者模式","DEVELOPER")
	v.text(root,"覆盖值单独保存。金币、升级、技能与跳关会改变当前存档；建议先导出备份。",11,"text-3",false,true)
	var enabled:=CheckBox.new();enabled.text="启用数值覆盖与调试操作";enabled.button_pressed=dev.enabled;root.add_child(enabled)
	enabled.toggled.connect(func(value):ui._developer_command({"operation":"enable","value":value}))
	v.button(root,"停用并清除全部覆盖",func():ui._developer_command({"operation":"reset"}),"",40)
	if not dev.enabled:return
	section("直接触发 Boss 战")
	v.text(root,"在当前关卡挑战所选 Boss，保留金币、升级与装备技能。会清空本关战斗，关闭面板后立即开战。",11,"text-3",false,true)
	var boss:=OptionButton.new();boss.name="DeveloperBoss";boss.custom_minimum_size.y=42
	for id in preload("res://src/bosses/director.gd").NAMES:
		boss.add_item(preload("res://src/bosses/director.gd").NAMES[id]);boss.set_item_metadata(boss.item_count-1,id)
	root.add_child(boss)
	var start:Button=v.button(root,"立即开始 Boss 战",func():ui._developer_command({"operation":"boss","id":boss.get_item_metadata(boss.selected)}),"",44)
	start.name="DeveloperStartBoss"
	section("关卡与砖块数量")
	v.text(root,"关卡 1–100000；普通关砖块 1–77（不改变 Boss 专属布局）。跳关 / 重建会清空本关战斗。",11,"text-3",false,true)
	v.text(root,"目标关卡",12,"text-2")
	var level:SpinBox=number(root,f.level,1,100000);level.name="DeveloperLevel"
	v.text(root,"该关砖块数量",12,"text-2")
	var count:SpinBox=number(root,dev.counts.get(str(int(f.level)),f.initial),1,77);count.name="DeveloperCount"
	level.value_changed.connect(func(value):count.value=dev.counts.get(str(int(value)),70))
	v.button(root,"保存该关砖块数量",func():ui._developer_command({"operation":"count","level":level.value,"value":count.value}))
	v.button(root,"恢复该关默认数量",func():ui._developer_command({"operation":"count","level":level.value,"value":null}))
	v.button(root,"跳转 / 重建所选关卡",func():ui._developer_command({"operation":"level","value":level.value}))
	section("存档数值与升级")
	var labels:Dictionary={"coins":"金币","total":"累计收益","best":"最佳收益","rerolls":"刷新次数","power":"弹弓等级","arrow":"箭矢等级","brick":"砖块等级","draw":"拉弦等级","comboCap":"连击升级","slots":"额外槽位","rerollCap":"额外刷新容量"}
	for key in labels:
		v.text(root,labels[key],12,"text-2")
		var row:HBoxContainer=v.row(root,6)
		var maximum:float={"draw":10,"slots":3,"rerollCap":4,"rerolls":f.rerollCap}.get(key,10000 if f.up.has(key) else 1e18)
		var field:=number(row,f.up[key] if f.up.has(key) else f.get(key,0),0,maximum)
		field.name="DeveloperState_"+key
		v.button(row,"应用",func():ui._developer_command({"operation":"state","key":key,"value":field.value}))
	section("战斗数值覆盖")
	v.text(root,"未覆盖时跟随正常公式。生命 / 特殊比例在重建关卡后生效，其余用于后续计算。",11,"text-3",false,true)
	for key in Developer.FIELDS:
		var spec:Array=Developer.FIELDS[key]
		v.text(root,spec[0]+(" · 已覆盖" if dev.overrides.has(key) else " · 默认"),12,"text-2")
		var row:HBoxContainer=v.row(root,6)
		var field:=number(row,dev.values[key],spec[1],spec[2],spec[3]);field.name="DeveloperValue_"+key
		v.button(row,"应用",func():ui._developer_command({"operation":"override","key":key,"value":field.value}))
		v.button(row,"恢复",func():ui._developer_command({"operation":"override","key":key,"value":null}))
	section("任意技能配置")
	v.text(root,"忽略技能解锁关卡；顺序即装备顺序。不能重复，应用后重建本关以清理旧技能效果。",11,"text-3",false,true)
	var selectors:Array=[]
	for i in range(int(f.slots)):
		var select:=OptionButton.new();select.name="DeveloperSkill%d" % i;select.custom_minimum_size.y=42;select.add_item("空槽",0);select.set_item_metadata(0,"")
		for id in ui.catalog:
			select.add_item(ui.catalog[id].name+" · "+id);select.set_item_metadata(select.item_count-1,id)
			if i<f.skills.size() and id==f.skills[i]:select.select(select.item_count-1)
		root.add_child(select);selectors.append(select)
	var status:Label=v.text(root,"",11,"text-3")
	v.button(root,"应用技能并重建本关",func():
		var ids:Array=[]
		for select in selectors:
			var id:String=select.get_item_metadata(select.selected)
			if id=="":continue
			if id in ids:status.text="同一技能不能重复装备";return
			ids.append(id)
		ui._developer_command({"operation":"skills","ids":ids})
	,"",44)
