extends Node2D
## Pooled GPU fire volumes; deterministic ballistic debris uses the same visual
## clock. No screen copy, CPU texture upload, or gameplay RNG consumption.
const SHADER=preload("res://src/render/explosion.gdshader")
const CAPACITY=16
var simulation:RefCounted
var pool:Array=[]
var debris:=preload("res://src/render/debris_batch.gd").new()

func _init() -> void:add_child(debris)

func _ready() -> void:debris.setup(false,CAPACITY)

func present(g:RefCounted) -> void:
	simulation=g
	while pool.size()<mini(CAPACITY,g.fx.explosions.size()):
		var quad:=Polygon2D.new()
		quad.polygon=PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)])
		quad.uv=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
		var shader_material:=ShaderMaterial.new();shader_material.shader=SHADER
		quad.material=shader_material;add_child(quad);pool.append(quad)
	for index in range(pool.size()):
		var quad:Polygon2D=pool[index]
		quad.visible=index<g.fx.explosions.size() and g.phase!="draft"
		if not quad.visible:continue
		var event:Dictionary=g.fx.explosions[index]
		quad.position=event.position;quad.scale=Vector2.ONE*event.radius*1.65
		quad.material.set_shader_parameter("age",g.fx.visual_time-event.born)
		quad.material.set_shader_parameter("seed",event.seed)
		quad.material.set_shader_parameter("strength",event.intensity)
		quad.material.set_shader_parameter("reduced",g.reduced)
	debris.present(g.fx.explosions,g.fx.visual_time,g.reduced)
	queue_redraw()

func _draw() -> void:
	# Child MultiMesh owns the unchanged ballistic tail/disk geometry.
	debris.visible=simulation!=null and simulation.phase!="draft"
