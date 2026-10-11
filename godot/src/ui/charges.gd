extends Control
## Shared static charge gauge: banked, partially earned and next-upgrade slots.
var visuals: RefCounted
var count:=0
var capacity:=1
var ghost:=0
var progress:=0.0
var pip:=12.0
var gap:=6.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2((capacity+ghost)*(pip+gap)-gap,pip+6)

func _draw() -> void:
	for i in range(capacity+ghost):
		var center:=Vector2(pip/2+i*(pip+gap),size.y/2)
		var radius:=pip*.4
		var points:=PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0)])
		var edge: Color=visuals.color("text-3" if i>=capacity else "accent-ink" if i<count else "line-2")
		var face: Color=visuals.color("accent-bar" if i<count else "surface")
		if i>=capacity:face.a=0;edge.a=.6
		draw_colored_polygon(points,face)
		if i==count and i<capacity and progress>0:
			var cut:=center.y+radius-2*radius*progress
			var left:=center.x-radius+absf(cut-center.y)
			var right:=center.x+radius-absf(cut-center.y)
			var fill:=PackedVector2Array([Vector2(left,cut),Vector2(right,cut)])
			if cut<center.y:fill.append(center+Vector2(radius,0))
			fill.append(center+Vector2(0,radius))
			if cut<center.y:fill.append(center+Vector2(-radius,0))
			draw_colored_polygon(fill,visuals.color("accent-bar"))
		points.append(points[0]);draw_polyline(points,edge,1.2,true)
