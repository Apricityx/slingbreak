extends MultiMeshInstance2D
## The same arc/coin geometry, shared instead of rebuilt for every display frame.
const Geometry=preload("res://src/render/effect_mesh.gd")
const ARC_SHADER=preload("res://src/render/arc_batch.gdshader")
const GOLD_SHADER=preload("res://src/render/coin_batch.gdshader")
static var templates:Dictionary={}
var type:="lightning"
class CoinGlyphs extends Node2D:
	var font:Font
	var items:Array=[]
	func _draw() -> void:
		var width:=font.get_string_size("¥",HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		for item in items:
			draw_string(font,item.point+Vector2(-6-width/2,7),"¥",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(Color("#7b5413"),item.fade))
var glyphs:CoinGlyphs

func setup(id:String) -> void:
	type=id
	if not templates.has(type):
		var geometry:=Geometry.new()
		if type=="lightning":
			for arc in range(8):
				for layer in range(4):geometry.path(Vector2(arc,layer),5)
				if arc%2==0:
					for layer in range(3):geometry.path(Vector2(arc,4+layer),1)
				# Preserve the eight alpha-over passes of the original central
				# flash. Removing duplicates outright would darken the peak.
				for layer in range(4):geometry.circle(Vector2(arc,7+layer),32)
		else:
			for layer in range(2):geometry.circle(Vector2(0,layer),48)
			geometry.path(Vector2(0,2),28);geometry.path(Vector2(0,3),20)
			for glint in range(4):geometry.path(Vector2(glint,4),1)
			for shard in range(10):
				geometry.path(Vector2(shard,5),4)
				if shard%2==0:geometry.path(Vector2(shard,6),1)
		templates[type]=geometry.build()
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data=true;multimesh.use_colors=true;multimesh.mesh=templates[type]
	multimesh.instance_count=48;multimesh.visible_instance_count=0
	var mat:=ShaderMaterial.new();mat.shader=ARC_SHADER if type=="lightning" else GOLD_SHADER;material=mat
	if type=="gold":
		glyphs=CoinGlyphs.new();glyphs.font=preload("res://src/ui/presentation.gd").load_font("bold");add_child(glyphs)

func present(g:RefCounted) -> void:
	var used:=0
	var bounds:=Rect2()
	if glyphs!=null:glyphs.items.clear()
	for event in g.fx.specials:
		if event.type!=type:continue
		var progress:float=1.0-clampf(event.life/event.max,0,1)
		# Skip only the exactly transparent tail, never shorten the visible beat.
		if progress>=(0.42 if type=="lightning" else 0.58):continue
		if used>=multimesh.instance_count:break
		multimesh.set_instance_transform_2d(used,Transform2D(0,event.position))
		multimesh.set_instance_custom_data(used,Geometry.event_data(progress,event.seed,event.intensity))
		multimesh.set_instance_color(used,event.color)
		# The CPU cannot see vertex-shader expansion. Include the full reach,
		# including hits whose emitter is just outside the viewport.
		var extent:=210.0 if type=="lightning" else 85.0
		var area:=Rect2(event.position-Vector2.ONE*extent,Vector2.ONE*extent*2)
		bounds=area if used==0 else bounds.merge(area)
		if glyphs!=null:glyphs.items.append({"point":event.position,"fade":1.0-smoothstep(0.2,0.58,progress)})
		used+=1
	multimesh.visible_instance_count=used
	multimesh.custom_aabb=AABB(Vector3(bounds.position.x,bounds.position.y,-1),Vector3(bounds.size.x,bounds.size.y,2))
	visible=g.phase!="draft"
	material.set_shader_parameter("dark",g.theme=="dark")
	material.set_shader_parameter("pixel",1.0/maxf(get_global_transform().get_scale().x,0.01))
	if glyphs!=null:glyphs.queue_redraw()
