extends Node2D
## Extend only the background for small aspect mismatches. All gameplay stays
## on the centered, uniformly scaled 412 x 915 design canvas.

const DESIGN_SIZE := Vector2i(412, 915)
const MAX_ASPECT_DEVIATION := 0.05

static func aspect_for_size(display_size: Vector2i) -> int:
	if display_size.x <= 0 or display_size.y <= 0:
		return Window.CONTENT_SCALE_ASPECT_KEEP
	var relative_aspect := (float(display_size.x) / display_size.y) / (float(DESIGN_SIZE.x) / DESIGN_SIZE.y)
	if absf(relative_aspect - 1.0) <= MAX_ASPECT_DEVIATION + 0.000001:
		return Window.CONTENT_SCALE_ASPECT_EXPAND
	return Window.CONTENT_SCALE_ASPECT_KEEP

func _ready() -> void:
	z_index=-100
	get_window().size_changed.connect(_update_aspect)
	_update_aspect()

var background := Color("#d5d9cc")
var board_background := Color("#fafbf7")
var footer_background := Color("#252e1c")
var last_window_size := Vector2i.ZERO
var last_extent := Vector2.ZERO

func _process(_delta: float) -> void:
	# With KEEP, resizing the physical window may leave the logical viewport
	# unchanged, so size_changed alone cannot detect crossing the threshold.
	if get_window().size != last_window_size or get_viewport_rect().size != last_extent:
		_update_aspect()

func present(frame: Dictionary) -> void:
	background=get_parent().interface.visuals.color("bg")
	footer_background=get_parent().interface.visuals.color("panel")
	board_background=Color("#1a1f17") if frame.get("theme")=="dark" else Color("#fafbf7")
	queue_redraw()

func _update_aspect() -> void:
	var window := get_window()
	var aspect := aspect_for_size(window.size)
	if window.content_scale_aspect != aspect:
		window.content_scale_aspect = aspect
	var extent := get_viewport_rect().size
	last_window_size=window.size
	last_extent=extent
	# EXPAND rounds the logical viewport to whole pixels. Compensate that
	# rounding too, so X/Y scaling stays identical even at fractional sizes.
	var display_size := Vector2(window.size)
	var uniform_scale := minf(display_size.x/DESIGN_SIZE.x,display_size.y/DESIGN_SIZE.y)
	var desired := Transform2D.IDENTITY.scaled(Vector2.ONE*uniform_scale)
	desired.origin=(display_size-Vector2(DESIGN_SIZE)*uniform_scale)*.5
	window.canvas_transform=window.get_final_transform().affine_inverse()*desired
	queue_redraw()

func _draw() -> void:
	var bounds := get_window().canvas_transform.affine_inverse()*get_viewport_rect()
	draw_rect(bounds,background)
	# Continue the battlefield's own background at its left and right edges.
	draw_rect(Rect2(Vector2(bounds.position.x,238),Vector2(bounds.size.x,572)),board_background)
	draw_rect(Rect2(Vector2(bounds.position.x,810),Vector2(bounds.size.x,maxf(0,bounds.end.y-810))),footer_background)
