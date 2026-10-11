extends RefCounted
## Invert the CSS cubic Bezier x coordinate, then evaluate its y coordinate.
## All animation owners share this helper without depending on a UI page.
static func bezier(x: float, x1: float, y1: float, x2: float, y2: float) -> float:
	if x <= 0:
		return 0.0
	if x >= 1:
		return 1.0
	var lo := 0.0
	var hi := 1.0
	for i in range(20):
		var t: float = (lo+hi)*0.5
		var at: float = 3*(1-t)*(1-t)*t*x1+3*(1-t)*t*t*x2+t*t*t
		if at < x:
			lo = t
		else:
			hi = t
	var t: float = (lo+hi)*0.5
	return 3*(1-t)*(1-t)*t*y1+3*(1-t)*t*t*y2+t*t*t
