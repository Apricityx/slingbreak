extends MultiMeshInstance2D
## Immutable shard geometry + per-event custom data; no per-frame triangulation.
const Geometry=preload("res://src/render/effect_mesh.gd")
const SHADER=preload("res://src/render/debris.gdshader")
static var templates:Dictionary={}
var ice:=false

func setup(is_ice:bool,capacity:int) -> void:
	ice=is_ice
	if not templates.has(ice):
		var geometry:=Geometry.new()
		for index in range(10 if ice else 18):
			if ice:
				for layer in range(2):geometry.polygon(PackedVector2Array([Vector2.LEFT,Vector2.UP,Vector2.RIGHT,Vector2.DOWN]),Vector2(index,layer))
				geometry.line(Vector2(index,2))
			else:
				geometry.line(Vector2(index,0));geometry.circle(Vector2(index,1))
		templates[ice]=geometry.build()
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data=true;multimesh.mesh=templates[ice];multimesh.instance_count=capacity
	multimesh.visible_instance_count=0
	var mat:=ShaderMaterial.new();mat.shader=SHADER;mat.set_shader_parameter("ice",ice);material=mat

func present(events:Array,time:float,reduced:bool,dark:bool=false) -> void:
	var used:=0
	var bounds:=Rect2()
	for event in events:
		if ice and event.type!="ice_shards":continue
		var age:float=time-event.born
		var fade:float=event.life/event.max if ice else 1-age/1.2
		if fade<=0 or age<0:continue
		if used>=multimesh.instance_count:break
		multimesh.set_instance_transform_2d(used,Transform2D(0,event.position))
		multimesh.set_instance_custom_data(used,Geometry.event_data(age,event.seed,fade if ice else event.radius))
		var extent:float=40.0 if ice else event.radius*2.0+160.0
		var area:=Rect2(event.position-Vector2.ONE*extent,Vector2.ONE*extent*2)
		bounds=area if used==0 else bounds.merge(area)
		used+=1
	multimesh.visible_instance_count=used
	multimesh.custom_aabb=AABB(Vector3(bounds.position.x,bounds.position.y,-1),Vector3(bounds.size.x,bounds.size.y,2))
	material.set_shader_parameter("dark",dark)
	material.set_shader_parameter("reduced",reduced)
	material.set_shader_parameter("pixel",1.0/maxf(get_global_transform().get_scale().x,0.01))
