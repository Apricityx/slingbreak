extends MultiMeshInstance2D
## Normal brick breaks: flash, 8 grid fragments, 6 sparks and a shock arc per
## event, all from one immutable template in a single batched draw.
const Geometry=preload("res://src/render/effect_mesh.gd")
const SHADER=preload("res://src/render/brick_shatter.gdshader")
const CAPACITY:=72
const LIFE:=0.5
static var template:ArrayMesh

func setup() -> void:
	if template==null:
		var geometry:=Geometry.new()
		var quad:=PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)])
		# Draw order inside the batch: shock arc under the flash, then debris.
		geometry.polygon(quad,Vector2(0,3))
		geometry.polygon(quad,Vector2(0,0))
		for index in range(8):geometry.polygon(quad,Vector2(index,1))
		for index in range(6):geometry.polygon(quad,Vector2(index,2))
		template=geometry.build()
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_2D
	multimesh.use_colors=true;multimesh.use_custom_data=true;multimesh.mesh=template
	multimesh.instance_count=CAPACITY;multimesh.visible_instance_count=0
	var mat:=ShaderMaterial.new();mat.shader=SHADER;material=mat

func present(g:RefCounted) -> void:
	var used:=0
	var bounds:=Rect2()
	for event in g.fx.normal_breaks:
		var age:float=g.fx.visual_time-event.born
		if age<0 or age>=LIFE:continue
		if used>=CAPACITY:break
		var heading:Vector2=event.heading
		var color:Color=event.color
		color.a=fposmod(heading.angle(),TAU)/TAU
		multimesh.set_instance_transform_2d(used,Transform2D(0,event.position))
		multimesh.set_instance_color(used,color)
		# Seeds stay small: custom data is half float on GL Compatibility.
		multimesh.set_instance_custom_data(used,Color(age,fposmod(float(event.seed)*2.399963,TAU),event.size.x,event.size.y))
		# Vertex shader reach: fragments fly ~70 px, fall ~65 px by end of life.
		var area:=Rect2(event.position-Vector2(150,130),Vector2(300,280))
		bounds=area if used==0 else bounds.merge(area)
		used+=1
	multimesh.visible_instance_count=used
	multimesh.custom_aabb=AABB(Vector3(bounds.position.x,bounds.position.y,-1),Vector3(bounds.size.x,bounds.size.y,2))
	material.set_shader_parameter("dark",g.theme=="dark")
	material.set_shader_parameter("reduced",g.reduced)
	material.set_shader_parameter("pixel",1.0/maxf(get_global_transform().get_scale().x,0.01))
