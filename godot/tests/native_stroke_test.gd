extends SceneTree
## Compare actual GPU raster output of the original polylines and baked meshes.
## Offscreen views avoid font/UI/background drift between the two draw paths.
const Art=preload("res://src/render/signatures.gd")
class Face extends Node2D:
	var art:RefCounted
	var id:="pulse"
	var age:=0.0
	var radius:=115.0
	var ink:=Color("#c07c39")
	var accent:=Color("#9db064")
	func _draw() -> void:
		set_meta("stroke_meshes",[])
		art.paint(self,id,Vector2(125,125),age,radius,ink,accent,.76)
var failures:=0
var fixtures:=0
var largest:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Stroke raster gate requires a graphics driver");quit(1);return
	var art:=Art.new();var views:Array=[];var faces:Array=[]
	for optimized in [false,true]:
		var view:=SubViewport.new();view.size=Vector2i(256,256);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);views.append(view)
		var face:=Face.new();face.art=art
		var host:=Node2D.new();host.scale=Vector2.ONE*.85;host.position=Vector2(18,18);view.add_child(host);host.add_child(face);faces.append(face)
		if optimized:art.attach(face,.85)
	for id in art.shapes:
		art.prepare([id])
		while id in art.pending:await process_frame;art.collect()
		var bundle:Resource=art.meshes.get(id)
		if bundle==null:failures+=1;push_error("Baked mesh missing: "+id);continue
		var frames:Array=bundle.get_meta("frames")
		if frames.size()!=24:failures+=1;push_error("Baked frame count: "+id);continue
		for groups in frames:
			for group in groups:
				if not group.mesh is ArrayMesh or group.mesh.get_surface_count()!=1:failures+=1;push_error("Baked geometry missing: "+id)
		for radius in [11.0,75.0,115.0]:
			for index in [0,8,12,23]:
				for face in faces:face.id=id;face.age=index/23.0;face.radius=radius;face.queue_redraw()
				await process_frame;await RenderingServer.frame_post_draw
				var a:PackedByteArray=views[0].get_texture().get_image().get_data()
				var b:PackedByteArray=views[1].get_texture().get_image().get_data()
				var peak:=0
				for i in range(a.size()):peak=maxi(peak,absi(int(a[i])-int(b[i])))
				largest=maxi(largest,peak);fixtures+=1
				if peak>2:
					failures+=1;push_error("Stroke pixel drift %s frame %d radius %d: %d" % [id,index,radius,peak])
	for view in views:view.queue_free()
	await process_frame
	print("Native stroke raster: %d fixtures, max channel delta %d/255, %d failures" % [fixtures,largest,failures]);quit(1 if failures else 0)
