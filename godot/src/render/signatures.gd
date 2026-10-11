extends RefCounted
## Native vector contours, sampled from the reference and stored as content.
## Playback draws CanvasItem polygons/lines; no JavaScript or Canvas emulation.
static var shapes: Dictionary={}

func _init() -> void:
	if not shapes.is_empty():return
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/signatures.json"))
	for id in data.shapes:
		var frames:Array=[]
		for sample in data.shapes[id]:
			var paths:Array=[]
			for command in sample:
				var points:=PackedVector2Array()
				for point in command.points:points.append(Vector2(point[0],point[1]))
				paths.append({"points":points,"fill":command.fill,"validFill":command.fill and Geometry2D.triangulate_polygon(points).size()>0,"secondary":command.color=="secondary","alpha":command.alpha,"width":command.width})
			frames.append(paths)
		shapes[id]=frames

func paint(canvas: CanvasItem,id: String,point: Vector2,t: float,radius: float,ink: Color,accent: Color,alpha: float=1) -> void:
	if not shapes.has(id):return
	var frames:Array=shapes[id]
	var index:=clampi(roundi(t*(frames.size()-1)),0,frames.size()-1)
	canvas.draw_set_transform(point,0,Vector2.ONE*radius)
	for path in frames[index]:
		var color:Color=accent if path.secondary else ink
		color.a*=path.alpha*alpha
		if path.fill:
			if path.validFill:canvas.draw_colored_polygon(path.points,color)
		# Baked widths are absolute Canvas pixels (the reference divides them by
		# r before scaling). Only coordinates grow with the effect radius.
		else:canvas.draw_polyline(path.points,color,maxf(0.5,path.width)/radius,true)
	canvas.draw_set_transform(Vector2.ZERO)
