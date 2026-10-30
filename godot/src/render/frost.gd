extends Node2D
## GPU frost fronts and persistent crystal shells. Pools own no brick references.
const SHADER=preload("res://src/render/frost.gdshader")
var pool:Array=[]
var g:RefCounted
var debris:=preload("res://src/render/debris_batch.gd").new()

func _init() -> void:add_child(debris)

func _ready() -> void:debris.setup(true,48)

func _quad(index:int) -> Polygon2D:
	if index==pool.size():
		var quad:=Polygon2D.new()
		# The carrier is deliberately oversized; the shader draws branching veins,
		# never a closed carrier-shaped wave, and fades before reaching its edge.
		quad.polygon=PackedVector2Array([Vector2(-2.5,-2.5),Vector2(2.5,-2.5),Vector2(2.5,2.5),Vector2(-2.5,2.5)])
		var mat:=ShaderMaterial.new();mat.shader=SHADER;quad.material=mat
		add_child(quad);pool.append(quad)
	return pool[index]

func present(simulation:RefCounted) -> void:
	g=simulation
	var used:=0
	if g.phase not in ["draft","clearing"]:
		for brick in g.bricks:
			if not brick.frozen and brick.type!="frost":continue
			if used>=240:break
			var quad:=_quad(used);used+=1;quad.visible=true
			quad.position=brick.position;quad.scale=(Vector2(brick.w,brick.h)*0.5+Vector2.ONE*4)/2.5
			# Use the same entrance transform as masonry; no floating shell before arrival.
			var opacity:=1.0
			if g.board_entrance!=null:
				var t:float=clampf((g.presentation_time-g.board_entrance.start-maxf(0,(brick.y-170)/60)*0.035-brick.x/780*0.045)/0.42,0,1)
				var eased:float=1-pow(1-t,3)
				quad.position.y-=26*(1-eased);quad.scale*=0.88+0.12*eased;opacity=t
			quad.modulate=Color(1,1,1,opacity)
			quad.material.set_shader_parameter("shell",true)
			quad.material.set_shader_parameter("size",Vector2(brick.w,brick.h))
			quad.material.set_shader_parameter("age",g.fx.visual_time-brick.frost_born if brick.frost_born>=0 else 2.0)
			quad.material.set_shader_parameter("direction",brick.frost_direction)
			quad.material.set_shader_parameter("clock",0.0 if g.reduced else g.fx.visual_time)
			quad.material.set_shader_parameter("seed",float(brick.id))
			quad.material.set_shader_parameter("dark",g.theme=="dark")
			quad.z_index=2
	for event in g.fx.specials:
		if event.type!="frost" or g.phase=="draft":continue
		var quad:=_quad(used);used+=1;quad.visible=true;quad.modulate=Color.WHITE
		# Leave room for the wave to travel beyond its gameplay radius while the
		# shader fades the front and its mist naturally.
		quad.position=event.position;quad.scale=Vector2.ONE*42.0/2.5
		quad.material.set_shader_parameter("shell",false)
		quad.material.set_shader_parameter("age",g.fx.visual_time-event.born)
		quad.material.set_shader_parameter("seed",event.seed)
		quad.material.set_shader_parameter("dark",g.theme=="dark")
		quad.z_index=3
	for index in range(used,pool.size()):pool[index].visible=false
	debris.present(g.fx.specials,g.fx.visual_time,g.reduced,g.theme=="dark")
	queue_redraw()

func _draw() -> void:
	debris.visible=g!=null and g.phase!="draft"
