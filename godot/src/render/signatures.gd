extends RefCounted
## Native vector contours, sampled from the reference and stored as content.
## Playback draws CanvasItem polygons/lines; no JavaScript or Canvas emulation.
static var shapes: Dictionary={}
const STROKE_SHADER=preload("res://src/render/signature_stroke.gdshader")
static var meshes:Dictionary={}
static var mesh_order:Array=[]
static var pending:Array=[]
const MESH_LIMIT=32

func attach(canvas:CanvasItem,scale_value:float) -> void:
	var stroke:=ShaderMaterial.new();stroke.shader=STROKE_SHADER;stroke.set_shader_parameter("board_scale",scale_value);canvas.material=stroke

func prepare(ids:Array) -> void:
	for id in ids:
		if not shapes.has(id) or meshes.has(id) or id in pending:continue
		var path:="res://assets/strokes/"+str(id)+".res"
		if ResourceLoader.load_threaded_request(path)==OK:pending.append(id)

func collect() -> void:
	for id in pending.duplicate():
		var path:="res://assets/strokes/"+str(id)+".res"
		var status:=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			while mesh_order.size()>=MESH_LIMIT:meshes.erase(mesh_order.pop_front())
			meshes[id]=ResourceLoader.load_threaded_get(path);mesh_order.append(id);pending.erase(id)
		elif status==ResourceLoader.THREAD_LOAD_FAILED or status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			pending.erase(id);push_error("Invalid baked signature: "+id)

func finish_loading() -> void:
	# ResourceLoader owns a reference to unfinished requests until get().
	# Drain only at scene teardown, never from the active render loop.
	for id in pending.duplicate():
		var path:="res://assets/strokes/"+str(id)+".res"
		var bundle:Resource=ResourceLoader.load_threaded_get(path)
		if bundle!=null:
			while mesh_order.size()>=MESH_LIMIT:meshes.erase(mesh_order.pop_front())
			meshes[id]=bundle;mesh_order.append(id)
		pending.erase(id)

func frame_mesh(id:String,index:int) -> Array:
	if not meshes.has(id):return[]
	return meshes[id].get_meta("frames")[index]

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
	if canvas.material is ShaderMaterial and canvas.material.shader==STROKE_SHADER and meshes.has(id):
		var groups:Array=frame_mesh(id,index)
		# Canvas display lists store mesh RIDs, not Resource ownership. Keep
		# the bundle alive for retained bricks even after cache eviction.
		var keep:Array=canvas.get_meta("stroke_meshes",[]);keep.append(meshes[id]);canvas.set_meta("stroke_meshes",keep)
		for group in groups:
			var color:Color=accent if group.secondary else ink;color.a*=alpha
			canvas.draw_mesh(group.mesh,null,Transform2D.IDENTITY,color)
		canvas.draw_set_transform(Vector2.ZERO);return
	if canvas.material is ShaderMaterial and canvas.material.shader==STROKE_SHADER:prepare([id])
	for path in frames[index]:
		var color:Color=accent if path.secondary else ink
		color.a*=path.alpha*alpha
		if path.fill:
			if path.validFill:canvas.draw_colored_polygon(path.points,color)
		# Baked widths are absolute Canvas pixels (the reference divides them by
		# r before scaling). Only coordinates grow with the effect radius.
		else:canvas.draw_polyline(path.points,color,maxf(0.5,path.width)/radius,true)
	canvas.draw_set_transform(Vector2.ZERO)
