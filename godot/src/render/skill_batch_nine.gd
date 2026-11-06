extends MultiMeshInstance2D
## Four fixed GPU families: only immutable event snapshots cross this boundary.
const Geometry=preload("res://src/render/effect_mesh.gd")
const SHADER=preload("res://src/render/skill_batch_nine.gdshader")
const IDS=["swarmqueen","railgun","frostfire","thunderlottery"]
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
		shader.code=SHADER.code.replace("uniform int effect=0;","const int effect=%d;" % IDS.find(id))
		shaders[id]=shader
	var mat:=ShaderMaterial.new();mat.shader=shaders[id];material=mat
	multimesh.mesh=template(id,false)

static func quad(mesh:RefCounted,index:int,kind:int) -> void:
	mesh.polygon(PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]),Vector2(index,kind))

static func template(effect:String,reduced:bool) -> ArrayMesh:
	var key:=effect+str(reduced)
	if templates.has(key):return templates[key]
	var mesh:=Geometry.new()
	match effect:
		"swarmqueen":
			quad(mesh,0,0);quad(mesh,0,1)
			for i in range(2):quad(mesh,i,2)
			if not reduced:quad(mesh,0,3)
		"railgun":
			for i in range(3):quad(mesh,i,0)
			for i in range(2 if reduced else 6):quad(mesh,i,1)
			quad(mesh,0,2)
		"frostfire":
			quad(mesh,0,0)
			for i in range(4 if reduced else 8):quad(mesh,i,1)
		"thunderlottery":
			quad(mesh,0,0)
			mesh.ribbon(Vector2(0,1),3 if reduced else 6)
			quad(mesh,0,2);quad(mesh,1,2)
			if not reduced:quad(mesh,0,3)
	templates[key]=mesh.build()
	return templates[key]

func present(g:RefCounted) -> void:
	if reduced_mode!=g.reduced:
		reduced_mode=g.reduced;multimesh.mesh=template(id,reduced_mode)
	var used:=0
	var bounds:=Rect2()
	for event in g.fx.skill_events:
		if event.id!=id:continue
		var age:float=g.fx.visual_time-event.born
		if age<0 or age>=event.max:continue
		var delta:Vector2=event.target-event.position
		var hop:bool=id=="thunderlottery" and event.strength>0.8
		var axis:Vector2=delta.normalized() if hop and delta.length_squared()>0.01 else event.direction
		var reach:float=delta.length() if hop else 0.0
		multimesh.set_instance_transform_2d(used,Transform2D(axis,axis.orthogonal(),event.position))
		multimesh.set_instance_custom_data(used,Color(age/event.max,fposmod(event.seed,TAU),reach,event.max))
		multimesh.set_instance_color(used,Color(event.color,event.strength))
		var area:=Rect2(event.position-Vector2.ONE*130,Vector2.ONE*260)
		if hop:area=area.expand(event.target-Vector2.ONE*24).expand(event.target+Vector2.ONE*24)
		bounds=area if used==0 else bounds.merge(area)
		used+=1
		if used==64:break
	multimesh.visible_instance_count=used
	multimesh.custom_aabb=AABB(Vector3(bounds.position.x,bounds.position.y,-1),Vector3(bounds.size.x,bounds.size.y,2))
	visible=g.phase!="draft"
	material.set_shader_parameter("dark",g.theme=="dark")
	material.set_shader_parameter("reduced",g.reduced)
	material.set_shader_parameter("pixel",1.0/maxf(get_global_transform().get_scale().x,0.01))
