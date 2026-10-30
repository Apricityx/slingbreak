extends RefCounted
## Small immutable triangle templates, shared by all instances of a family.
## Vertex alpha supplies a one-pixel feather without CanvasItem line commands.
var vertices:=PackedVector2Array()
var colors:=PackedColorArray()
var uv:=PackedVector2Array()
var indices:=PackedInt32Array()

static func event_data(age:float,seed:float,value:float) -> Color:
	# GL Compatibility stores custom channels as half floats. Trig consumers
	# wrap the seed and split it into two exactly
	# representable parts rather than losing precision as the serial grows.
	var wrapped:=fposmod(seed,TAU)
	var high:=floorf(wrapped*256.0)/256.0
	return Color(age,high,value,wrapped-high)

static func noise_data(age:float,seed:float,value:float) -> Color:
	# Noise is NOT TAU-periodic. Preserve the original early-game seed and
	# bound long-session inputs explicitly, with high/low half-float parts.
	var wrapped:=fposmod(seed,4096.0)
	var high:=floorf(wrapped/4.0)*4.0
	return Color(age,high,value,wrapped-high)

func polygon(points:PackedVector2Array,tag:Vector2,ink:Color=Color.WHITE) -> void:
	var first:=vertices.size()
	for point in points:vertices.append(point);colors.append(ink);uv.append(tag)
	for i in range(1,points.size()-1):indices.append_array(PackedInt32Array([first,first+i,first+i+1]))

func circle(tag:Vector2,segments:int=16) -> void:
	# Radius 1 is the opaque disk, radius 1.5 the feather (shader scales the
	# extra half-unit to a screen pixel rather than growing it with the disk).
	var first:=vertices.size()
	vertices.append(Vector2.ZERO);colors.append(Color.WHITE);uv.append(tag)
	for ring in range(2):
		for i in range(segments):
			vertices.append(Vector2.from_angle(i*TAU/segments)*(1.0 if ring==0 else 1.5))
			colors.append(Color(1,1,1,1 if ring==0 else 0));uv.append(tag)
	for i in range(segments):
		var a:=first+1+i;var b:=first+1+(i+1)%segments
		var c:=a+segments;var d:=b+segments
		indices.append_array(PackedInt32Array([first,a,b,a,c,b,b,c,d]))

func line(tag:Vector2) -> void:
	# Unit-length segment with an opaque core and feathered edges/end caps.
	var first:=vertices.size()
	for x in [-0.5,0.0,1.0,1.5]:
		for y in [-1.0,-0.5,0.5,1.0]:
			vertices.append(Vector2(x,y));uv.append(tag)
			colors.append(Color(1,1,1,1 if x>=0 and x<=1 and absf(y)<=0.5 else 0))
	for x in range(3):
		for y in range(3):
			var a:=first+x*4+y
			indices.append_array(PackedInt32Array([a,a+4,a+1,a+1,a+4,a+5]))

func path(tag:Vector2,segments:int) -> void:
	var first:=vertices.size()
	for i in range(-1,segments+2):
		for side in [-1.0,-0.5,0.5,1.0]:
			vertices.append(Vector2(i,side));uv.append(tag)
			colors.append(Color(1,1,1,1 if i>=0 and i<=segments and absf(side)<=0.5 else 0))
	for i in range(segments+2):
		for j in range(3):
			var a:=first+i*4+j
			indices.append_array(PackedInt32Array([a,a+4,a+1,a+1,a+4,a+5]))

func ribbon(tag:Vector2,segments:int) -> void:
	# One strip, not four overlapping feather/core strips. The fragment shader
	# resolves the cross-section in screen pixels, including antialiasing.
	var first:=vertices.size()
	for i in range(segments+1):
		for side in [-1.0,1.0]:vertices.append(Vector2(i,side));uv.append(tag);colors.append(Color.WHITE)
	for i in range(segments):
		var a:=first+i*2
		indices.append_array(PackedInt32Array([a,a+2,a+1,a+1,a+2,a+3]))

func disc(tag:Vector2,segments:int=20) -> void:
	var first:=vertices.size()
	vertices.append(Vector2.ZERO);uv.append(tag);colors.append(Color.WHITE)
	for i in range(segments):vertices.append(Vector2.from_angle(i*TAU/segments));uv.append(tag);colors.append(Color.WHITE)
	for i in range(segments):indices.append_array(PackedInt32Array([first,first+1+i,first+1+(i+1)%segments]))

func build() -> ArrayMesh:
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
