extends RefCounted
var id := 0
var x := 0.0
var y := 0.0
var w := 84.0
var h := 44.0
var hp := 3.0
var max_hp := 3.0
var type := "normal"
var frozen := false
## Transient presentation state; deliberately excluded from saves.
var frost_born := -1.0
var frost_direction := Vector2.RIGHT
var flash := 0.0
var flags: Dictionary = {}
var position: Vector2:
	get:return Vector2(x,y)
	set(value):x=value.x;y=value.y
var bounds: Rect2:
	get:return Rect2(x-w/2,y-h/2,w,h)

func serialize() -> Dictionary:
	return {"x":x,"y":y,"w":w,"h":h,"hp":hp,"max":max_hp,"type":type,"frozen":frozen,"nativeFlags":flags.duplicate(true)}
