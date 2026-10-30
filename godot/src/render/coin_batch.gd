extends MultiMeshInstance2D
## Compact coin geometry, shared instead of rebuilt for every display frame.
const Geometry=preload("res://src/render/effect_mesh.gd")
const GOLD_SHADER=preload("res://src/render/coin_batch.gdshader")
static var template:ArrayMesh
class CoinGlyphs extends Node2D:
	var font:Font
	var items:Array=[]
	func _draw() -> void:
		var width:=font.get_string_size("¥",HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		for item in items:
			draw_string(font,item.point+Vector2(-6-width/2,7),"¥",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(Color("#7b5413"),item.fade))
var glyphs:CoinGlyphs

func setup() -> void:
	if template==null:
		var geometry:=Geometry.new()
		geometry.disc(Vector2(0,0),24)
		for glint in range(4):geometry.ribbon(Vector2(glint,1),1)
		for shard in range(10):
			geometry.polygon(PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]),Vector2(shard,2))
			if shard%2==0:geometry.ribbon(Vector2(shard,3),1)
		template=geometry.build()
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data=true;multimesh.mesh=template
	multimesh.instance_count=48;multimesh.visible_instance_count=0
	var mat:=ShaderMaterial.new();mat.shader=GOLD_SHADER;material=mat
	glyphs=CoinGlyphs.new();glyphs.font=preload("res://src/ui/presentation.gd").load_font("bold");add_child(glyphs)

func present(g:RefCounted) -> void:
	var used:=0
	var bounds:=Rect2()
	glyphs.items.clear()
	for event in g.fx.specials:
		if event.type!="gold":continue
		var progress:float=1.0-clampf(event.life/event.max,0,1)
		# Skip only the exactly transparent tail, never shorten the visible beat.
		if progress>=0.58:continue
		if used>=multimesh.instance_count:break
		multimesh.set_instance_transform_2d(used,Transform2D(0,event.position))
		multimesh.set_instance_custom_data(used,Geometry.event_data(progress,event.seed,event.intensity))
		# The CPU cannot see vertex-shader expansion. Include the full reach,
		# including hits whose emitter is just outside the viewport.
		var extent:=85.0
		var area:=Rect2(event.position-Vector2.ONE*extent,Vector2.ONE*extent*2)
		bounds=area if used==0 else bounds.merge(area)
		glyphs.items.append({"point":event.position,"fade":1.0-smoothstep(0.2,0.58,progress)})
		used+=1
	multimesh.visible_instance_count=used
	multimesh.custom_aabb=AABB(Vector3(bounds.position.x,bounds.position.y,-1),Vector3(bounds.size.x,bounds.size.y,2))
	visible=g.phase!="draft"
	material.set_shader_parameter("pixel",1.0/maxf(get_global_transform().get_scale().x,0.01))
	glyphs.queue_redraw()
