extends Node2D
## Pooled GPU fire volumes; deterministic ballistic debris uses the same visual
## clock. No screen copy, CPU texture upload, or gameplay RNG consumption.
const SHADER=preload("res://src/render/explosion.gdshader")
const CAPACITY=16
const Geometry=preload("res://src/render/effect_mesh.gd")
static var template:ArrayMesh
var simulation:RefCounted
var volumes:=MultiMeshInstance2D.new()
var debris:=preload("res://src/render/debris_batch.gd").new()

func _init() -> void:add_child(debris);add_child(volumes)

func _ready() -> void:
	debris.setup(false,CAPACITY)
	if template==null:
		var geometry:=Geometry.new();geometry.disc(Vector2.ZERO,12);template=geometry.build()
	volumes.multimesh=MultiMesh.new();volumes.multimesh.transform_format=MultiMesh.TRANSFORM_2D
	volumes.multimesh.use_custom_data=true;volumes.multimesh.mesh=template
	volumes.multimesh.instance_count=CAPACITY;volumes.multimesh.visible_instance_count=0
	var mat:=ShaderMaterial.new();mat.shader=SHADER;volumes.material=mat

func present(g:RefCounted) -> void:
	simulation=g
	var used:=0
	var bounds:=Rect2()
	for event in g.fx.explosions:
		var age:float=g.fx.visual_time-event.born
		if age<0 or age>=1.4:continue
		if used>=CAPACITY:break
		volumes.multimesh.set_instance_transform_2d(used,Transform2D(0,Vector2.ONE*event.radius*1.65,0,event.position))
		volumes.multimesh.set_instance_custom_data(used,Geometry.noise_data(age,event.seed,event.intensity))
		var extent:float=event.radius*1.8
		var area:=Rect2(event.position-Vector2.ONE*extent,Vector2.ONE*extent*2)
		bounds=area if used==0 else bounds.merge(area);used+=1
	volumes.multimesh.visible_instance_count=used
	volumes.multimesh.custom_aabb=AABB(Vector3(bounds.position.x,bounds.position.y,-1),Vector3(bounds.size.x,bounds.size.y,2))
	volumes.visible=g.phase!="draft"
	volumes.material.set_shader_parameter("reduced",g.reduced)
	debris.present(g.fx.explosions,g.fx.visual_time,g.reduced)
	queue_redraw()

func _draw() -> void:
	# Both fire and fragments use fixed shared meshes; no per-impact resources.
	debris.visible=simulation!=null and simulation.phase!="draft"
