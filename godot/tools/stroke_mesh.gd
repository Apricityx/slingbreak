extends RefCounted
## Build reusable antialiased stroke triangles. Mirrors Godot's clamped miter,
## feather and end caps, preserving each path's order and every contour sample.

static func edge(direction:Vector2,previous:Vector2) -> Vector2:
	var bisector:Vector2=(previous*direction.length()-direction*previous.length()).normalized()
	var sine:=sin(atan2(bisector.cross(previous),bisector.dot(previous)))
	var length_value:=1.0
	if not is_zero_approx(sine) and not direction.is_equal_approx(previous):length_value=clampf(1.0/sine,-3,3)
	else:bisector=direction.orthogonal()
	if bisector.is_zero_approx():bisector=direction.orthogonal()
	return bisector*length_value

static func build(paths:Array) -> ArrayMesh:
	var vertices:=PackedVector2Array();var offsets:=PackedVector2Array();var colors:=PackedColorArray();var custom:=PackedFloat32Array();var indices:=PackedInt32Array()
	for path in paths:
		var points:PackedVector2Array=path.points
		if points.size()<2:continue
		var loop:=points[0].is_equal_approx(points[points.size()-1])
		var first:=Vector2.ZERO;var last:=Vector2.ZERO
		for i in range(1,points.size()):
			first=(points[i]-points[i-1]).normalized()
			if not first.is_zero_approx():break
		for i in range(points.size()-1,0,-1):
			last=(points[i]-points[i-1]).normalized()
			if not last.is_zero_approx():break
		# Middle, left feather, right feather, in the original command order.
		for strip in range(3):
			var start:=vertices.size();var previous:=Vector2.ZERO
			if not loop:
				for side in range(2):
					var sign_value:=1.0 if side==0 else -1.0
					if strip>0:sign_value=1.0 if strip==1 else -1.0
					append_vertex(vertices,offsets,colors,custom,points[0],first.orthogonal()*sign_value,-first,path.width,2.0 if strip>0 and side==1 else 1.0,0)
			for i in range(points.size()):
				var direction:Vector2=(points[i+1]-points[i]).normalized() if i<points.size()-1 else previous
				if direction.is_zero_approx():direction=previous
				if i==0 and loop:previous=last
				elif i==points.size()-1 and loop:previous=first
				var normal:=first.orthogonal() if i==0 and not loop else last.orthogonal() if i==points.size()-1 and not loop else edge(direction,previous)
				for side in range(2):
					var sign_value:=1.0 if side==0 else -1.0
					if strip>0:sign_value=1.0 if strip==1 else -1.0
					var outer:=strip>0 and side==1
					append_vertex(vertices,offsets,colors,custom,points[i],normal*sign_value,Vector2.ZERO,path.width,2.0 if outer else 1.0,0.0 if outer else path.alpha)
				previous=direction
			if not loop:
				var normal:=last.orthogonal()*(1 if strip!=2 else -1)
				if strip==0:
					for side in [1,-1]:append_vertex(vertices,offsets,colors,custom,points[points.size()-1],normal*side,last,path.width,1,0)
				else:
					append_vertex(vertices,offsets,colors,custom,points[points.size()-1],normal,Vector2.ZERO,path.width,1,path.alpha)
					append_vertex(vertices,offsets,colors,custom,points[points.size()-1],normal,last,path.width,2,0)
					append_vertex(vertices,offsets,colors,custom,points[points.size()-1],normal,last,path.width,1,0)
			for i in range(start+2,vertices.size()):
				indices.append(i-2);indices.append(i-1);indices.append(i)
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=offsets;arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_CUSTOM0]=custom;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	mesh.custom_aabb=AABB(Vector3(-4,-4,-1),Vector3(8,8,2))
	return mesh

static func append_vertex(vertices:PackedVector2Array,offsets:PackedVector2Array,colors:PackedColorArray,custom:PackedFloat32Array,point:Vector2,normal:Vector2,cap:Vector2,width:float,role:float,opacity:float) -> void:
	vertices.append(point);offsets.append(normal);colors.append(Color(1,1,1,opacity))
	custom.append(cap.x);custom.append(cap.y);custom.append(width);custom.append(role)
