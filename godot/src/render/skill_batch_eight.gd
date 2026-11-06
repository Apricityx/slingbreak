extends MultiMeshInstance2D
## Immutable per-family GPU geometry; even Jackpot kill chains remain one draw.
const IDS=["nova","crossfire","jackpot","supernova"]
const Geometry=preload("res://src/render/effect_mesh.gd")
const SHADER=preload("res://src/render/skill_batch_eight.gdshader")
const CAPACITY=128
static var templates:Dictionary={}
static var shaders:Dictionary={}
var id:=""
var reduced_mode:=false

func setup(effect:String) -> void:
	id=effect
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data=true;multimesh.use_colors=true;multimesh.instance_count=CAPACITY
	multimesh.visible_instance_count=0
	if not shaders.has(id):
		var shader:=Shader.new()
		shader.code=SHADER.code.replace("uniform int effect=0;","const int effect=%d;" % IDS.find(id))
		shaders[id]=shader
	var mat:=ShaderMaterial.new();mat.shader=shaders[id];material=mat
	multimesh.mesh=template(id,false)

static func template(effect:String,reduced:bool) -> ArrayMesh:
	var key:=effect+str(reduced)
	if templates.has(key):return templates[key]
	var mesh:=Geometry.new()
	quad(mesh,Vector2(0,0))
	for i in range({"nova":3,"crossfire":4,"jackpot":1,"supernova":8}[effect]):quad(mesh,Vector2(i,1))
	for i in range(4 if reduced else 10):quad(mesh,Vector2(i,2))
	for i in range(4):quad(mesh,Vector2(i,3))
	templates[key]=mesh.build()
	return templates[key]

static func quad(mesh:RefCounted,tag:Vector2) -> void:
	mesh.polygon(PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]),tag)

func present(g:RefCounted) -> void:
	if reduced_mode!=g.reduced:
		reduced_mode=g.reduced;multimesh.mesh=template(id,reduced_mode)
	var used:=0
	var bounds:=Rect2()
	# Main silhouettes get priority, then hit confirmations; burst chains are bounded.
	for target_pass in [false,true]:
		for event in g.fx.skill_events:
			if event.id!=id:continue
			var age:float=g.fx.visual_time-event.born
			if age<0 or age>=event.max:continue
			var targets:PackedVector2Array=event.get("targets",PackedVector2Array())
			var points:=targets if target_pass else PackedVector2Array([event.position])
			if target_pass and id in ["nova","jackpot"]:continue
			for point in points:
				if used>=CAPACITY:break
				multimesh.set_instance_transform_2d(used,Transform2D(0,point))
				var outcome:float=-1.0 if target_pass else float(targets.size()) if id=="nova" else event.get("outcome",1.0)
				multimesh.set_instance_custom_data(used,Color(age/event.max,fposmod(event.seed,TAU),outcome,event.max))
				multimesh.set_instance_color(used,event.color)
				var area:=Rect2(point-Vector2.ONE*170,Vector2.ONE*340)
				bounds=area if used==0 else bounds.merge(area);used+=1
	multimesh.visible_instance_count=used
	multimesh.custom_aabb=AABB(Vector3(bounds.position.x,bounds.position.y,-1),Vector3(bounds.size.x,bounds.size.y,2))
	visible=g.phase!="draft"
	material.set_shader_parameter("accent",Color(g.content.effect_profiles[id].accent))
	material.set_shader_parameter("dark",g.theme=="dark")
	material.set_shader_parameter("reduced",g.reduced)
