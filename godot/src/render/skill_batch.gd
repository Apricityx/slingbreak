extends MultiMeshInstance2D
## One immutable carrier per frequent effect family; animation stays on the GPU.
## Event snapshots and the shared 64-slot FX queue remain authoritative.
const Geometry=preload("res://src/render/effect_mesh.gd")
const SHADER=preload("res://src/render/skill_batch.gdshader")
const IDS=["echo","piercer","seeking","ricochet","storm"]
static var templates:Dictionary={}
static var shaders:Dictionary={}
var id:=""
var reduced_mode:=false

func setup(effect:String) -> void:
	id=effect
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data=true;multimesh.use_colors=true;multimesh.instance_count=64
	multimesh.visible_instance_count=0
	if not shaders.has(id):
		var shader:=Shader.new()
		# Specialize before compilation: a uniform selector leaves five large
		# branches live in GL drivers and triggers expensive first-use variants.
		shader.code=SHADER.code.replace("uniform int effect=0;","const int effect=%d;" % IDS.find(id))
		shaders[id]=shader
	var mat:=ShaderMaterial.new();mat.shader=shaders[id];material=mat
	multimesh.mesh=template(id,false)

static func template(effect:String,reduced:bool) -> ArrayMesh:
	var key:=effect+str(reduced)
	if templates.has(key):return templates[key]
	var geometry:=Geometry.new()
	match effect:
		"echo":
			for i in range(2 if reduced else 3):
				geometry.ribbon(Vector2(i,0),1)
				geometry.polygon(PackedVector2Array([Vector2(0,0),Vector2(1,-1),Vector2(1,1)]),Vector2(i,1))
			for i in range(2 if reduced else 3):geometry.ribbon(Vector2(i,2),12)
		"piercer":
			geometry.ribbon(Vector2(0,0),1)
			geometry.polygon(PackedVector2Array([Vector2(0,0),Vector2(1,-1),Vector2(1,1)]),Vector2(0,1))
			for i in range(2 if reduced else 4):geometry.ribbon(Vector2(i,2),1)
		"seeking":
			geometry.ribbon(Vector2(0,0),1)
			for i in range(4):geometry.ribbon(Vector2(i,1),1)
			quad(geometry,Vector2(0,2))
		"ricochet":
			for i in range(2 if reduced else 3):geometry.ribbon(Vector2(i,0),1)
			quad(geometry,Vector2(0,1))
		"storm":
			geometry.ribbon(Vector2(0,0),3 if reduced else 5)
			quad(geometry,Vector2(0,1));quad(geometry,Vector2(0,2))
			if not reduced:geometry.ribbon(Vector2(0,3),1)
	templates[key]=geometry.build()
	return templates[key]

static func quad(geometry:RefCounted,tag:Vector2) -> void:
	geometry.polygon(PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]),tag)

func present(g:RefCounted) -> void:
	if reduced_mode!=g.reduced:
		reduced_mode=g.reduced;multimesh.mesh=template(id,reduced_mode)
	var used:=0
	var bounds:=Rect2()
	for event in g.fx.skill_events:
		if event.id!=id:continue
		if id=="seeking" and event.target==Vector2.ZERO:continue
		var age:float=g.fx.visual_time-event.born
		if age<0 or age>=event.max:continue
		var progress:float=clampf(age/event.max,0,1)
		if id=="storm" and 1.0-smoothstep(0.18,1.0,progress)<0.005:continue
		var delta:Vector2=event.target-event.position
		var axis:Vector2=delta.normalized() if id in ["seeking","storm"] and delta.length_squared()>0.01 else event.direction
		var reach:float=delta.length() if id in ["seeking","storm"] else 0.0
		if used>=64:break
		multimesh.set_instance_transform_2d(used,Transform2D(axis,axis.orthogonal(),event.position))
		# Echo's arcs were authored in world angles, independently of its arrows.
		# Vector2.orthogonal() is clockwise, so this instance basis reflects Y.
		var phase:float=axis.angle()-event.seed*0.12 if id=="echo" else event.seed
		multimesh.set_instance_custom_data(used,Color(progress,fposmod(phase,TAU),reach,event.max))
		multimesh.set_instance_color(used,Color(event.color,event.strength))
		var area:=Rect2(event.position-Vector2.ONE*100,Vector2.ONE*200)
		if id in ["seeking","storm"]:area=area.expand(event.target-Vector2.ONE*24).expand(event.target+Vector2.ONE*24)
		bounds=area if used==0 else bounds.merge(area)
		used+=1
	multimesh.visible_instance_count=used
	multimesh.custom_aabb=AABB(Vector3(bounds.position.x,bounds.position.y,-1),Vector3(bounds.size.x,bounds.size.y,2))
	visible=g.phase!="draft"
	material.set_shader_parameter("accent",Color(g.content.effect_profiles[id].accent))
	material.set_shader_parameter("dark",g.theme=="dark")
	material.set_shader_parameter("reduced",g.reduced)
	material.set_shader_parameter("pixel",1.0/maxf(get_global_transform().get_scale().x,0.01))
