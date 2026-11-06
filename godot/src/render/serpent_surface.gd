extends Node2D
## 星渊巨蟒 body: shader-lit ribbon meshes rebuilt from the model's segment points
## each frame, drawn above the masonry and below arrows and the vector head. A
## veil child darkens the board during the star-eclipse; the guidance label sits
## under the river. pose() is the single envelope source for body and vectors.
const SHADER=preload("res://src/render/serpent_body.gdshader")
const Serpent=preload("res://src/bosses/serpent.gd")
const SHADOW:=Vector2(5,9)
var veil:=Polygon2D.new()
var body:=Ribbons.new()
var guidance:=Label.new()

class Ribbons extends Node2D:
	var meshes:Array=[]
	func _draw() -> void:
		for mesh in meshes:RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),mesh.indices,mesh.points,mesh.colors,mesh.uvs)

func _ready() -> void:
	veil.polygon=PackedVector2Array([Vector2(0,0),Vector2(780,0),Vector2(780,1100),Vector2(0,1100)]);add_child(veil)
	var mat:=ShaderMaterial.new();mat.shader=SHADER;body.material=mat;add_child(body)
	guidance.add_theme_font_override("font",preload("res://src/ui/presentation.gd").load_font("cjk"))
	guidance.add_theme_font_size_override("font_size",20)
	guidance.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	guidance.position=Vector2(140,878);guidance.size=Vector2(500,30)

static func pose(g:RefCounted) -> Dictionary:
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	var t:float=g.presentation_time
	var stun:=0.0;var front:=2.0
	if m.exposed():stun=clampf((t-m.broke_at)/0.3,0,1)*clampf((m.stunned_until-t)/0.4,0,1);front=-1.0
	elif t<m.refill_until:front=clampf(1-(m.refill_until-t)/Serpent.REFILL_SECONDS,0,1)
	var stage:String=m.move.get("stage","")
	var dark:=clampf(minf((t-m.move.at)/0.8,(m.move.at+6-t)/0.5),0,1) if stage=="dark" else 0.0
	var heat:=0.0
	if stage=="aim":heat=clampf((t-m.move.at)/0.5,0,1)
	elif stage in ["lunge","maw","rend"]:heat=1.0
	var dissolve:=clampf((t-d.dying_at)/1.3,0,1) if d.dying_at>=0 else 0.0
	return {"stun":stun,"front":front,"dark":dark,"heat":heat,"dissolve":dissolve,"dying":d.dying_at>=0}

func present(g:RefCounted) -> void:
	visible=g!=null and g.bosses.boss_id=="serpent" and g.bosses.model!=null and not g.bosses.exploded and g.phase not in ["draft","clearing"]
	guidance.visible=false
	if not visible:return
	var d:RefCounted=g.bosses;var m:RefCounted=d.model;var p:Dictionary=d.palette()
	var pose:=pose(g)
	var t:float=0.0 if g.reduced else g.presentation_time
	veil.color=Color(p.dark,0.74*pose.dark);veil.visible=pose.dark>0.01
	var mat:ShaderMaterial=body.material
	mat.set_shader_parameter("clock",t)
	mat.set_shader_parameter("stun",pose.stun);mat.set_shader_parameter("armour_front",pose.front)
	mat.set_shader_parameter("dark",pose.dark);mat.set_shader_parameter("heat",pose.heat);mat.set_shader_parameter("dissolve",pose.dissolve)
	mat.set_shader_parameter("light_theme",g.theme=="light")
	for pair in [["body","body"],["body_light","bodyLight"],["belly","belly"],["deep","dark"],["glow","glow"],["star","star"],["twin","twin"],["weak","weak"]]:
		mat.set_shader_parameter(pair[0],Color(p[pair[1]]))
	var writhe:float=clampf((g.presentation_time-d.dying_at)/0.4,0,1) if pose.dying else 0.0
	var meshes:Array=[]
	var drawn:Array=[]
	for snake in m.ghosts:drawn.append([snake,0.0,clampf(1-(g.time-snake.gate.born)/2.0,0,1)])
	for snake in m.snakes:drawn.append([snake,0.5 if snake.step<0 else 0.0,snake.fade])
	for item in drawn:ribbons(meshes,item[0],1.0,item[2],SHADOW,writhe,t)
	for item in drawn:ribbons(meshes,item[0],item[1],item[2],Vector2.ZERO,writhe,t)
	body.meshes=meshes;body.queue_redraw()

func ribbons(meshes:Array,snake:Dictionary,kind:float,opacity:float,offset:Vector2,writhe:float,t:float) -> void:
	if opacity<=0.01:return
	var points:PackedVector2Array=snake.points
	var run:=PackedVector2Array();var ks:=PackedFloat32Array()
	for k in range(points.size()+1):
		if k<points.size() and snake.hidden[k]==0:
			var point:Vector2=points[k]
			if writhe>0:
				var side:Vector2=(points[mini(k+1,points.size()-1)]-points[maxi(k-1,0)]).orthogonal().normalized()
				point+=side*sin(t*9+k*0.6)*writhe*7
			run.append(point+offset);ks.append(k);continue
		if run.size()>=2:meshes.append(ribbon(run,ks,snake,kind,opacity))
		run=PackedVector2Array();ks=PackedFloat32Array()

func ribbon(run:PackedVector2Array,ks:PackedFloat32Array,snake:Dictionary,kind:float,opacity:float) -> Dictionary:
	var samples:=PackedVector2Array();var kf:=PackedFloat32Array()
	for i in range(run.size()-1):
		var p0:Vector2=run[maxi(i-1,0)];var p1:Vector2=run[i];var p2:Vector2=run[i+1];var p3:Vector2=run[mini(i+2,run.size()-1)]
		for j in range(3):
			var u:float=j/3.0
			samples.append(0.5*((2*p1)+(-p0+p2)*u+(2*p0-5*p1+4*p2-p3)*u*u+(-p0+3*p1-3*p2+p3)*u*u*u));kf.append(lerpf(ks[i],ks[i+1],u))
	samples.append(run[run.size()-1]);kf.append(ks[ks.size()-1])
	var tail:bool=int(ks[ks.size()-1])==snake.points.size()-1
	if tail:
		var last:Vector2=samples[samples.size()-1]
		samples.append(last+(last-samples[samples.size()-2]).normalized()*12);kf.append(ks[ks.size()-1]+0.9)
	var n:int=samples.size()
	var first_normal:Vector2=(samples[mini(1,n-1)]-samples[0]).orthogonal().normalized()
	var flip:=1.0 if (samples[0]-Serpent.CENTER).dot(first_normal)>=0 else -1.0
	var points:=PackedVector2Array();var colors:=PackedColorArray();var uvs:=PackedVector2Array();var indices:=PackedInt32Array()
	points.resize(n*2);colors.resize(n*2);uvs.resize(n*2)
	var arc:=0.0
	for i in range(n):
		if i>0:arc+=samples[i].distance_to(samples[i-1])
		var tangent:Vector2=(samples[mini(i+1,n-1)]-samples[maxi(i-1,0)]).normalized()
		var normal:Vector2=tangent.orthogonal()*flip
		var radius:float=Serpent.segment_radius(snake,kf[i])
		if tail and i==n-1:radius=1.0
		var tint:=Color(clampf(kf[i]/maxf(1,snake.total-1),0,1),snake.flash,kind,opacity)
		points[i*2]=samples[i]+normal*radius;points[i*2+1]=samples[i]-normal*radius
		uvs[i*2]=Vector2(arc,-1);uvs[i*2+1]=Vector2(arc,1)
		colors[i*2]=tint;colors[i*2+1]=tint
		if i<n-1:indices.append_array([i*2,i*2+1,i*2+2,i*2+1,i*2+3,i*2+2])
	return {"points":points,"colors":colors,"uvs":uvs,"indices":indices}

static func hint(g:RefCounted) -> String:
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	if d.dying_at>=0 or d.busy:return ""
	if m.exposed():return "倒地 %.1f 秒 · 击中蛇首 伤害 ×3" % maxf(0,m.stunned_until-g.time)
	match m.move.get("stage",""):
		"aim":return "蓄力盘击 · 击中蛇首打断"
		"under":return "射中出口星门 · 拽出巨蟒"
		"maw":return "向巨口连射 %d / %d" % [m.move.hits,4 if d.rage else 3]
		"dark":return "星蚀 · 命中发光蛇首 %d / 2" % m.move.hits
		"rend","split":return "斩断星丝 · 或 0.8 秒内同时命中双首"
	if d.fight.clock<20 and g.time>=m.refill_until:return "鳞甲挡箭 · 击碎发光逆鳞"
	return ""
