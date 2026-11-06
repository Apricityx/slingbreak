extends Node2D
## 时之君主 dial: one retained shader quad behind the masonry plus a material-free
## guidance label. pose() is the single envelope source for the dial and the
## vector hands/core in boss_art, sampled on the presentation clock.
const SHADER=preload("res://src/render/clock_dial.gdshader")
const Clock=preload("res://src/bosses/clock.gd")
var dial:=Polygon2D.new()
var guidance:=Label.new()

func _ready() -> void:
	dial.polygon=PackedVector2Array([Vector2(-390,-380),Vector2(390,-380),Vector2(390,380),Vector2(-390,380)])
	dial.position=Clock.CENTER
	var mat:=ShaderMaterial.new();mat.shader=SHADER;dial.material=mat;add_child(dial)
	guidance.add_theme_font_override("font",preload("res://src/ui/presentation.gd").load_font("cjk"))
	guidance.add_theme_font_size_override("font_size",20)
	guidance.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	guidance.position=Vector2(140,848);guidance.size=Vector2(500,30)

static func pose(g:RefCounted) -> Dictionary:
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	var t:float=g.presentation_time
	var intro_span:float=0.4 if g.reduced else Clock.INTRO_SECONDS-0.8
	var rise:=clampf((t-d.intro_at)/intro_span,0,1) if d.fight.intro else 0.0
	var shift:=clampf(1-(d.shift_until-t)/Clock.SHIFT_SECONDS,0,1) if t<d.shift_until else 0.0
	var phase:float=d.fight.phase
	if t<d.shift_until:phase-=1-smoothstep(0.7,0.95,shift)
	var stall:=0.0
	if m.exposed():stall=clampf((t-m.jammed_at)/0.35,0,1)*clampf((m.stunned_until-t)/0.5,0,1)
	var id:String=m.move.get("id","")
	var freeze:=1.0 if not m.frozen.is_empty() else 0.0
	if id=="stop":freeze=0.35*clampf((t-m.move.start)/maxf(0.01,m.move.end-m.move.start),0,1)
	var crack:=clampf((t-d.dying_at)/1.6,0,1) if d.dying_at>=0 else 0.0
	return {"rise":rise,"shift":shift,"phase":phase,"stall":stall,"freeze":freeze,"crack":crack,
		"rewind":1.0 if id=="rewind" else 0.0,
		"midnight":clampf((t-m.move.start)/1.2,0,1) if id=="midnight" else 0.0,
		"haste":1.0 if id=="haste" and t>=m.move.live else 0.0,
		"dying":d.dying_at>=0,"open":smoothstep(0,1,stall)}

func present(g:RefCounted) -> void:
	visible=g!=null and g.bosses.boss_id=="clock" and g.bosses.model!=null and not g.bosses.exploded and g.phase not in ["draft","clearing"]
	guidance.visible=false
	if not visible:return
	var d:RefCounted=g.bosses;var m:RefCounted=d.model;var p:Dictionary=d.palette()
	var pose:=pose(g)
	var mat:ShaderMaterial=dial.material
	for key in ["rise","shift","phase","stall","freeze","rewind","midnight","haste","crack"]:mat.set_shader_parameter(key,pose[key])
	mat.set_shader_parameter("clock",0.0 if g.reduced else g.presentation_time)
	mat.set_shader_parameter("spin",0.0 if g.reduced else m.spin)
	mat.set_shader_parameter("lit_angle",m.hour_index*PI/6)
	mat.set_shader_parameter("light_theme",g.theme=="light")
	for pair in [["face","face"],["rim","rim"],["brass","brass"],["brass_deep","brassDeep"],["gem","gem"],["weak","weak"],["stop","stop"],["ghost","ghost"]]:
		mat.set_shader_parameter(pair[0],Color(p[pair[1]]))

static func hint(g:RefCounted) -> String:
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	if d.dying_at>=0 or g.time<d.shift_until or g.time<d.intro_at+Clock.INTRO_SECONDS:return ""
	if m.exposed():return "停摆 %.1f 秒 · 击中时核 伤害 ×3" % maxf(0,m.stunned_until-g.time)
	if not m.frozen.is_empty():return "时间静止 · 箭矢即将倒流"
	match m.move.get("id",""):
		"stop":return "击碎发条钥 · %.1f 秒" % maxf(0,m.move.end-g.time)
		"toll":return "钟响 %d / 3 前击中巨钟" % m.move.rung
		"pendulum":return "摆锤 %d / %d · 摆杆会挡箭" % [m.move.hits,4 if d.rage else 3]
		"rewind":return "射中晶壳 · 打断倒流"
		"haste":return "疾走 · 正点刻度一击停摆"
		"midnight":return "晶壳 %d / 3 · 第 %d 响" % [m.move.hits,m.move.rung]
	if d.fight.clock<25:
		if not m.gears.is_empty():return "卡住齿轮标记 · 或射中亮起的刻度"
		return "射中亮起的刻度 · 抽空发条"
	return ""
