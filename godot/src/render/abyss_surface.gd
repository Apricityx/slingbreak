extends Node2D
## Two retained relic eyes, at the original 360×168 world-space footprint.
const SHADER=preload("res://src/render/abyss_eye.gdshader")
const Rig=preload("res://src/render/abyss_rig.gd")
var surfaces:Array[Polygon2D]=[]
var guidance:=Label.new()
func _ready() -> void:
	for index in range(2):
		var node:=Polygon2D.new()
		node.polygon=PackedVector2Array([Vector2(-180,-84),Vector2(180,-84),Vector2(180,84),Vector2(-180,84)])
		var mat:=ShaderMaterial.new();mat.shader=SHADER;node.material=mat
		add_child(node);surfaces.append(node)
	# A retained, material-free label: the FX stroke shader is not a font-atlas
	# shader and cannot carry the board-space Chinese counter-shot guidance.
	guidance.add_theme_font_override("font",preload("res://src/ui/presentation.gd").load_font("cjk"))
	guidance.add_theme_font_size_override("font_size",20)
	guidance.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	guidance.position=Vector2(140,803);guidance.size=Vector2(500,30);add_child(guidance)
func present(g:RefCounted) -> void:
	guidance.visible=false
	visible=g!=null and g.bosses.boss_id=="eye" and not g.bosses.exploded and g.phase not in ["draft","clearing"]
	if not visible:return
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	var pose:=Rig.pose(g)
	var mirage:bool=m.move.get("id")=="mirage"
	var shift_age:float=g.presentation_time-m.phase_at
	var merging:bool=pose.shifting and m.phase_from_mirage
	var points:Array=[pose.origin]
	if mirage:points=[Vector2(170,Rig.CENTER.y),Vector2(610,Rig.CENTER.y)]
	elif merging and shift_age<0.7:points.append(Vector2(610 if m.phase_origin.x<390 else 170,Rig.CENTER.y))
	for i in range(2):
		var node:=surfaces[i];node.visible=i<points.size()
		if not node.visible:continue
		node.position=points[i]+Vector2(0,pose.lift);node.scale=Vector2.ONE*pose.size
		var mat:ShaderMaterial=node.material
		var real_eye:bool=not mirage or points[i].x==m.move.real
		var target:Vector2=g.pointer if g.pointer!=null else g.origin
		var look:Vector2=(target-points[i]).limit_length(8) if real_eye else Vector2.ZERO
		if m.move.get("id")=="gaze":look=Vector2.from_angle(m.beam_angle())*7*pose.focus
		if m.exposed():look=Vector2.ZERO
		for key in ["opening","presence","spread","morph","stage","flash","ritual","upper_lid","lower_lid","focus","fracture","recoil","rift_open","emergence","heat","laser_pulse","dilate","ward","ward_show","ward_flash","damage"]:mat.set_shader_parameter(key,pose[key])
		mat.set_shader_parameter("wound",m.broken_direction)
		if merging and i==1:mat.set_shader_parameter("presence",pose.presence*(1-smoothstep(0.0,0.7,shift_age)))
		mat.set_shader_parameter("clock",0.0 if g.reduced else g.presentation_time)
		mat.set_shader_parameter("look",look)
		mat.set_shader_parameter("light_theme",g.theme=="light")
		mat.set_shader_parameter("violet",Color(g.content.palette(g.theme).rift.iris))
		mat.set_shader_parameter("charge",m.charge())
