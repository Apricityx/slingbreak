extends Node2D
## 熔炉巨像 body: one retained shader quad behind the masonry plus a material-free
## guidance label. pose() is the single envelope source for the body shader and
## the vector fists, door, globs and props in forge_art.
const SHADER=preload("res://src/render/forge_body.gdshader")
const Forge=preload("res://src/bosses/forge.gd")
var body:=Polygon2D.new()
var guidance:=Label.new()

func _ready() -> void:
	# World-space quad: the shader reads VERTEX as board coordinates.
	body.polygon=PackedVector2Array([Vector2(30,50),Vector2(750,50),Vector2(750,900),Vector2(30,900)])
	var mat:=ShaderMaterial.new();mat.shader=SHADER;body.material=mat;add_child(body)
	guidance.add_theme_font_override("font",preload("res://src/ui/presentation.gd").load_font("cjk"))
	guidance.add_theme_font_size_override("font_size",20)
	guidance.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	guidance.position=Vector2(140,872);guidance.size=Vector2(500,30)

static func ramp(t:float,from:float,span:float) -> float:return clampf((t-from)/maxf(0.001,span),0,1)

static func pose(g:RefCounted) -> Dictionary:
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	var t:float=g.presentation_time
	var intro_span:float=0.4 if g.reduced else Forge.INTRO_SECONDS-0.8
	var rise:=ramp(t,d.intro_at,intro_span) if d.fight.intro else 0.0
	var shift:=clampf(1-(d.shift_until-t)/Forge.SHIFT_SECONDS,0,1) if t<d.shift_until else 0.0
	var phase:float=d.fight.phase
	if t<d.shift_until:phase-=1-smoothstep(0.55,0.9,shift)
	var id:String=m.move.get("id","")
	var vent:=0.0
	if m.exposed():vent=ramp(t,m.vented_at,0.35)*clampf((m.stunned_until-t)/0.5,0,1)
	var beat:=0.0
	if id=="meltdown" and t>=m.move.live:beat=1-clampf(fmod(t-m.move.live,m.beat_period())/0.3,0,1)
	var tilt:=0.0
	if id=="magma":tilt=(1.0 if m.move.side==1 else -1.0)*0.32*smoothstep(0,1,ramp(t,m.move.start,m.move.live-m.move.start))*clampf((m.move.end-t)/0.4,0,1)
	var draw:=[0.0,0.0]
	for side in range(2):
		draw[side]=maxf(0,1-(t-m.puffs[side])/0.5)
		if id=="bellows" and m.move.side==side:draw[side]=maxf(draw[side],ramp(t,m.move.start,m.move.live-m.move.start)*(0.6+0.4*sin(t*9)))
	var fists:=[m.fist_point(0),m.fist_point(1)]
	# Intro: each fist drops onto the pedestal on its clang.
	if d.fight.intro and t<d.intro_at+2.2:
		for side in range(2):fists[side].y-=90*(1-pow(ramp(t,d.intro_at+1.25+side*0.3,0.3),2))
	# Iron palm: the arm sweeps down to the socket that rides the floor.
	if id=="palm":
		var reach:=smoothstep(0,1,ramp(t,m.move.start,m.move.live-m.move.start))*clampf((m.move.end-t)/0.35,0,1)
		var x:float=m.palm_x() if t>=m.move.live else 390.0
		fists[m.move.side]=fists[m.move.side].lerp(Vector2(x,Forge.PALM_Y-6),reach)
	return {"rise":rise,"shift":shift,"phase":phase,"heat":1.0 if m.exposed() else m.heat()/100.0,"vent":vent,
		"cool":1-ramp(t,m.cooled_at,1.6),"beat":beat,"tilt":tilt,"bellows":Vector2(draw[0],draw[1]),
		"fist_l":fists[0],"fist_r":fists[1],"crack":ramp(t,d.dying_at,1.6) if d.dying_at>=0 else 0.0,"dying":d.dying_at>=0}

func present(g:RefCounted) -> void:
	visible=g!=null and g.bosses.boss_id=="forge" and g.bosses.model!=null and not g.bosses.exploded and g.phase not in ["draft","clearing"]
	guidance.visible=false
	if not visible:return
	var d:RefCounted=g.bosses;var p:Dictionary=d.palette()
	var pose:=pose(g)
	var mat:ShaderMaterial=body.material
	for key in ["rise","shift","phase","heat","vent","cool","beat","crack","tilt","bellows","fist_l","fist_r"]:mat.set_shader_parameter(key,pose[key])
	mat.set_shader_parameter("clock",0.0 if g.reduced else g.presentation_time)
	mat.set_shader_parameter("light_theme",g.theme=="light")
	for pair in [["iron","iron"],["iron_light","ironLight"],["soot","soot"],["ember","ember"],["molten","molten"],["core","core"],["weak","weak"],["smoke","smoke"]]:
		mat.set_shader_parameter(pair[0],Color(p[pair[1]]))

static func hint(g:RefCounted) -> String:
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	if d.dying_at>=0 or g.time<d.shift_until or g.time<d.intro_at+Forge.INTRO_SECONDS:return ""
	if m.exposed():return "过热 %.1f 秒 · 击中炉心 伤害 ×3" % maxf(0,m.stunned_until-g.time)
	if g.time<m.refill_until:return ""
	match m.move.get("id",""):
		"slam":return "锻锤蓄力 · 击中抬起的铁拳"
		"meteor":return "击落熔团 %d / %d" % [m.move.hits,m.move.count]
		"bellows":return "射入张开的%s风箱 · 回火" % ("左" if m.move.side==0 else "右")
		"palm":return "掌心炉口 %d / %d" % [m.move.hits,4 if d.rage else 3]
		"magma":return "射中倾倒的坩埚嘴 · 断流"
		"meltdown":return "心跳亮起时击中炉门 %d / 3" % m.move.hits
	if m.heat()<40:return "击碎熔岩燃料 · 炉温到 100% 开炉" if d.fight.phase<2 else "燃料与风箱都能升温"
	return ""
