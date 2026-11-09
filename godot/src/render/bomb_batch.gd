extends MultiMeshInstance2D
## Shared brick/skill blasts: smoke, shock ring, fireball lobes, flame jets, core
## flash, casing chunks and embers per event, from one immutable template in a
## single batched draw. Pieces collapse to zero area once spent, so the late
## tail only shades the smoke that is still visible.
const Geometry=preload("res://src/render/effect_mesh.gd")
const SHADER=preload("res://src/render/bomb_blast.gdshader")
const CAPACITY:=16
const LIFE:=1.1
static var template:ArrayMesh

func setup() -> void:
	if template==null:
		var geometry:=Geometry.new()
		var quad:=PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)])
		# Draw order inside the batch: smoke and shock behind the fire, hot
		# core above it, solid debris and embers on top.
		for index in range(5):geometry.polygon(quad,Vector2(index,6))
		geometry.polygon(quad,Vector2(0,2))
		for index in range(7):geometry.polygon(quad,Vector2(index,1))
		for index in range(6):geometry.polygon(quad,Vector2(index,3))
		geometry.polygon(quad,Vector2(0,0))
		for index in range(6):geometry.polygon(quad,Vector2(index,4))
		for index in range(12):geometry.polygon(quad,Vector2(index,5))
		template=geometry.build()
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_2D
	multimesh.use_colors=true;multimesh.use_custom_data=true;multimesh.mesh=template
	multimesh.instance_count=CAPACITY;multimesh.visible_instance_count=0
	var mat:=ShaderMaterial.new();mat.shader=SHADER;material=mat

func present(g:RefCounted) -> void:
	var used:=0
	var bounds:=Rect2()
	var casing:=Color(g.content.palette(g.theme).brickInk.get("bomb","#7e2f1f"))
	for event in g.fx.bombs:
		var age:float=g.fx.visual_time-event.born
		if age<0 or age>=LIFE:continue
		if used>=CAPACITY:break
		var radius:float=event.radius
		multimesh.set_instance_transform_2d(used,Transform2D(0,event.position))
		multimesh.set_instance_color(used,casing)
		# Seeds stay small: custom data is half float on GL Compatibility.
		multimesh.set_instance_custom_data(used,Color(age,fposmod(float(event.seed)*2.399963,TAU),radius,event.intensity))
		# Vertex shader reach: shock ring to radius+8, chunks ~1.4 radius
		# sideways and ~2.2 radius down by end of life, smoke rises ~1 radius.
		var area:=Rect2(event.position-Vector2(radius*1.5,radius*1.4),Vector2(radius*3.0,radius*3.7))
		bounds=area if used==0 else bounds.merge(area)
		used+=1
	multimesh.visible_instance_count=used
	multimesh.custom_aabb=AABB(Vector3(bounds.position.x,bounds.position.y,-1),Vector3(bounds.size.x,bounds.size.y,2))
	visible=g.phase!="draft"
	material.set_shader_parameter("dark",g.theme=="dark")
	material.set_shader_parameter("reduced",g.reduced)
	material.set_shader_parameter("pixel",1.0/maxf(get_global_transform().get_scale().x,0.01))
