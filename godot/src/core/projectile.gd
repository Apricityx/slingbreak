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

func take(key: String, limit: int=1) -> bool:
	var used:=int(flags.get(key,0))
	if used>=limit:return false
	flags[key]=used+1
	return true
