extends Node2D
## One local quad and one material for the core's Gaussian silhouette.
## No screen readback, raster upload or full-stage blur pass is needed.
const SHADER = preload("res://src/render/core_glow.gdshader")
var glow_material := ShaderMaterial.new()
var extent := 55.0

static func pose(time: float, born: float) -> Dictionary:
	var t := clampf((time-born-0.25)/0.85, 0, 1)
	return {"scale":1.0 if t>=1 else 0.0 if t<=0 else pow(2,-10*t)*sin((t*10-0.75)*TAU/3)+1,
		"spin":-(1-minf(1,t*1.4))*PI/2, "pulse":sin(time*3)}

func _init() -> void:
	show_behind_parent = true
	glow_material.shader = SHADER
	material = glow_material
	visible = false

func present(simulation: RefCounted) -> void:
	visible = simulation != null and simulation.core != null and not simulation.reduced and simulation.phase not in ["draft", "clearing"]
	if not visible:
		return
	var motion := pose(simulation.presentation_time, simulation.core.born)
	position = simulation.core_display_position()
	rotation = PI/4+motion.spin
	scale = Vector2.ONE*motion.scale
	var blur: float = 18.0+motion.pulse*6.0
	var sigma: float = blur*0.5
	extent = 21.0+sigma*4.0
	glow_material.set_shader_parameter("tint", Color(simulation.content.palette(simulation.theme).core.glow))
	glow_material.set_shader_parameter("sigma", sigma)
	glow_material.set_shader_parameter("extent", extent)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ONE*-extent, Vector2.ONE*extent*2.0), Color.WHITE)
