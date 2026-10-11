extends Control
## Static art band from draft.css: skill tint, diagonal hatch and emblem halo.
var visuals: RefCounted
var ink: Color

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),visuals.mix(ink,visuals.color("surface"),.09))
	var hatch:=ink;hatch.a=.07
	for x in range(-int(size.y),int(size.x)+int(size.y),13):
		draw_line(Vector2(x,0),Vector2(x-size.y,size.y),hatch,1,true)
	var center:=size/2
	for r in range(44,0,-1):
		var glow:=ink;glow.a=.013*(1-float(r)/44);draw_circle(center,r,glow)
	draw_line(Vector2(size.x-1,0),Vector2(size.x-1,size.y),visuals.mix(ink,visuals.color("line"),.18),1)
	# Control clipping is rectangular; cover the left corner wedges explicitly.
	for corner in [0,1]:
		var polygon:=PackedVector2Array([Vector2(0,0 if corner==0 else size.y)])
		for i in range(17):
			var angle:=PI+(PI/2)*float(i)/16 if corner==0 else PI/2+(PI/2)*float(i)/16
			polygon.append(Vector2(11,11 if corner==0 else size.y-11)+Vector2(cos(angle),sin(angle))*11)
		draw_colored_polygon(polygon,visuals.color("surface"))
