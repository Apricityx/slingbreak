extends RefCounted
## An arrow owns its damage attribution even after it leaves the visible board.
var id := 0
## Motion stays in 64-bit values. Vector2 is only the 32-bit view used by
## rendering and swept collision; writing that view quantises the motion.
var px := 0.0
var py := 0.0
var vx := 0.0
var vy := 0.0
var position: Vector2:
	get:
		return Vector2(px, py)
	set(value):
		px = value.x
		py = value.y
var velocity: Vector2:
	get:
		return Vector2(vx, vy)
	set(value):
		vx = value.x
		vy = value.y
var previous := Vector2.ZERO
## Display snapshots are independent of the swept-collision origin.
var display_previous := Vector2.ZERO
var display_previous_angle := 0.0
var display_previous_trail := PackedVector2Array()
var damage := 2.0
var base_damage := 2.0
var scale := 1.0
var pierce := 2
var life := 0.0
var kills := 0
var trail := PackedVector2Array()
var hit: Dictionary = {}
var overlap: Dictionary = {}
var flags: Dictionary = {}
var color := Color.TRANSPARENT
var visual:=""
var source: RefCounted
var achievement: Dictionary = {}

func capture_display() -> void:
	display_previous=position
	display_previous_angle=velocity.angle()
	display_previous_trail=trail.duplicate()

func reset_display() -> void:
	capture_display()

func display_position(fraction: float) -> Vector2:
	return display_previous.lerp(position,clampf(fraction,0,1))

func display_angle(fraction: float) -> float:
	return lerp_angle(display_previous_angle,velocity.angle(),clampf(fraction,0,1))

func display_trail(fraction: float) -> PackedVector2Array:
	var points:=PackedVector2Array()
	var amount:=clampf(fraction,0,1)
	# A cleared trail denotes a rebound/teleport. Never join across that cut.
	if trail.is_empty():return points
	if trail.size()<display_previous_trail.size():
		points.append(display_position(amount));return points
	for index in range(trail.size()):
		var from:Vector2=display_previous_trail[index] if index<display_previous_trail.size() else display_previous
		points.append(from.lerp(trail[index],amount))
	return points

func take(key: String, limit: int=1) -> bool:
	var used:=int(flags.get(key,0))
	if used>=limit:return false
	flags[key]=used+1
	return true
