extends SceneTree
## Deterministic offline mesh bake; runtime never builds stroke geometry.
const Signatures=preload("res://src/render/signatures.gd")
const StrokeMesh=preload("res://tools/stroke_mesh.gd")
func build_frame(paths:Array) -> Array:
	var groups:Array=[];var batch:Array=[];var secondary:=false
	for path in paths:
		if path.fill:push_error("Filled contours need a separate mesh bake");continue
		if not batch.is_empty() and path.secondary!=secondary:
			groups.append({"mesh":StrokeMesh.build(batch),"secondary":secondary});batch=[]
		secondary=path.secondary;batch.append(path)
	if not batch.is_empty():groups.append({"mesh":StrokeMesh.build(batch),"secondary":secondary})
	return groups
func _initialize() -> void:
	var art:=Signatures.new()
	DirAccess.make_dir_recursive_absolute("res://assets/strokes")
	var count:=0
	var manifest:Dictionary={"version":1,"contourSha256":FileAccess.get_sha256("res://assets/signatures.json"),"meshes":{}}
	for id in art.shapes:
		var frames:Array=[]
		for index in range(24):frames.append(build_frame(art.shapes[id][index]))
		var bundle:=Resource.new();bundle.set_meta("frames",frames)
		var result:=ResourceSaver.save(bundle,"res://assets/strokes/"+id+".res",ResourceSaver.FLAG_COMPRESS)
		if result!=OK:push_error("Failed to bake strokes: "+id);quit(1);return
		manifest.meshes[id]=FileAccess.get_sha256("res://assets/strokes/"+id+".res")
		count+=1
	var file:=FileAccess.open("res://assets/strokes/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  "));file.close()
	print("Baked stroke resources: "+str(count));quit()
