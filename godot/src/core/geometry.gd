extends RefCounted
## Swept collision queries shared by simulation, skills and aim prediction.

static func sweep(rect: Rect2, start: Vector2, finish: Vector2, padding: float=2.5) -> Dictionary:
	var bounds := rect.grow(padding)
	# Reject disjoint segment bounds before allocating a slab-query result.
	# Keep inclusive edges and the same padded narrow-phase test.
	if maxf(start.x,finish.x)<bounds.position.x or minf(start.x,finish.x)>bounds.end.x or maxf(start.y,finish.y)<bounds.position.y or minf(start.y,finish.y)>bounds.end.y:return {}
	var delta := finish-start
	var enter := 0.0
	var leave := 1.0
	var normal := Vector2.ZERO
	for axis in range(2):
		if absf(delta[axis]) < 0.00000001:
			if start[axis] < bounds.position[axis] or start[axis] > bounds.end[axis]: return {}
			continue
		var first := (bounds.position[axis]-start[axis])/delta[axis]
		var last := (bounds.end[axis]-start[axis])/delta[axis]
		var near := minf(first,last)
		if near > enter:
			enter=near
			normal=Vector2.ZERO
			normal[axis]=-1 if delta[axis]>0 else 1
		leave=minf(leave,maxf(first,last))
		if enter>leave: return {}
	if leave<0 or enter>1: return {}
	return {"t":enter,"normal":normal}

static func circle(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> Dictionary:
	var relative := start-center
	var delta := finish-start
	var square := delta.length_squared()
	if relative.length_squared()<radius*radius:
		return {"t":0.0,"normal":relative.normalized() if relative.length_squared()>0.001 else -delta.normalized()}
	if square<0.000001: return {}
	var b := 2*relative.dot(delta)
	var c := relative.length_squared()-radius*radius
	var disc := b*b-4*square*c
	if disc<0: return {}
	var at := (-b-sqrt(disc))/(2*square)
	if at<0 or at>1: return {}
	return {"t":at,"normal":(start+delta*at-center).normalized()}

static func triangle(point: Vector2, vertices: Array) -> bool:
	if vertices.size()!=3: return false
	if absf((vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]))<1: return false
	var positive:=false
	var negative:=false
	for index in range(3):
		var sign:float=(vertices[(index+1)%3]-vertices[index]).cross(point-vertices[index])
		positive=positive or sign>0
		negative=negative or sign<0
	return not (positive and negative)
