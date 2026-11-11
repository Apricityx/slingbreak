extends Control
## Local HUD accents and arena heat, driven by semantic state at render cadence.
var visuals:RefCounted
var heat:=0
var warmth:=0.0
var core_state:="locked"
var reduced:=false
var paused:=false
var age:=0.0
var gem_fill:=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	size=Vector2(412,810)

func present(tier:int,state:String,still:bool,held:bool) -> void:
	if heat==tier and core_state==state and reduced==still and paused==held:return
	heat=tier;core_state=state;reduced=still;paused=held
	if reduced:
		warmth=float(heat);gem_fill=0.0 if state in ["locked","blocked"] else 1.0
	set_process(not reduced)
	queue_redraw()

func _process(delta:float) -> void:
	if not paused:age=fmod(age+delta,8.0)
	var next_warmth:=lerpf(warmth,float(heat),1-exp(-delta/.12))
	var next_fill:=lerpf(gem_fill,0.0 if core_state in ["locked","blocked"] else 1.0,1-exp(-delta/.1))
	var moving:=absf(next_warmth-warmth)>.001 or absf(next_fill-gem_fill)>.001
	warmth=next_warmth;gem_fill=next_fill
	if moving or core_state=="ready" and not paused:queue_redraw()

func _draw() -> void:
	if visuals==null:return
	if core_state!="boss":
		var center:=Vector2(21,156)
		var pulse:=0.0 if reduced or core_state!="ready" else .5-.5*cos(age*TAU/1.6)
		if gem_fill>.001:
			var halo:Color=visuals.color("accent-soft");halo.a*=gem_fill
			_diamond(center,8+2*pulse,halo,true)
		var edge:Color=visuals.mix(visuals.color("accent-line"),visuals.color("line-2"),gem_fill)
		var fill:Color=visuals.color("accent-bar");fill.a*=gem_fill
		_diamond(center,5,fill,true);_diamond(center,5,edge,false)
	# Match the browser's inset amber/red glow, confined to the arena.
	if warmth>1.01:
		var strength:=clampf(warmth-1,0,1)
		var ink:=Color("#e0ad2c").lerp(Color("#f0a13a"),clampf(warmth-2,0,1))
		var depth:=lerpf(20,30,clampf(warmth-2,0,1))
		for i in range(int(depth)):
			ink.a=strength*.13*pow(1-float(i)/depth,2)
			draw_rect(Rect2(Vector2(i+.5,238+i+.5),Vector2(411-i*2,571-i*2)),ink,false,1)

func _diamond(center:Vector2,radius:float,ink:Color,filled:bool) -> void:
	var points:=PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0)])
	if filled:draw_colored_polygon(points,ink)
	else:points.append(points[0]);draw_polyline(points,ink,1.5,true)
