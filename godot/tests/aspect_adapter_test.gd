extends SceneTree

const Adapter = preload("res://src/ui/aspect_adapter.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for dimensions in [Vector2i(412,915), Vector2i(824,1830), Vector2i(432,915), Vector2i(392,915), Vector2i(412,880), Vector2i(412,950)]:
		_check(Adapter.aspect_for_size(dimensions)==Window.CONTENT_SCALE_ASPECT_EXPAND,"small deviation extends background: "+str(dimensions))
	for dimensions in [Vector2i(440,915), Vector2i(380,915), Vector2i(412,1000), Vector2i(915,412), Vector2i(0,915), Vector2i(412,0)]:
		_check(Adapter.aspect_for_size(dimensions)==Window.CONTENT_SCALE_ASPECT_KEEP,"large or invalid size keeps aspect: "+str(dimensions))
	var app=load("res://scenes/main.tscn").instantiate()
	app.set_meta("test_mode",true)
	root.add_child(app)
	await process_frame
	for dimensions in [Vector2i(412,915), Vector2i(432,915), Vector2i(392,915), Vector2i(412,950), Vector2i(600,915), Vector2i(412,915)]:
		root.size=dimensions
		await create_timer(.15).timeout
		for i in range(4): await process_frame
		_check(root.content_scale_aspect==Adapter.aspect_for_size(dimensions),"resize updates scaling: "+str(dimensions)+" actual size="+str(root.size)+" aspect="+str(root.content_scale_aspect))
		_check(app.interface.size==Vector2(412,915),"UI layout stays fixed")
		_check(app.arena.position==Vector2(0,238) and app.arena.scale==Vector2.ONE,"board layout stays fixed")
		var transform:=root.get_final_transform()*root.canvas_transform
		var origin:=transform*Vector2.ZERO
		var end:=transform*Vector2(412,915)
		_check(is_equal_approx(transform.x.length(),transform.y.length()),"scaling is always uniform: "+str(dimensions))
		_check(origin.x>=-.01 and origin.y>=-.01 and end.x<=dimensions.x+.01 and end.y<=dimensions.y+.01,"design canvas is never cropped")
		_check(((origin+end)*.5).distance_to(Vector2(dimensions)*.5)<1.5,"design canvas stays centered")
		var point:=Vector2(206,500)
		_check((transform.affine_inverse()*(transform*point)).is_equal_approx(point),"pointer maps back to design coordinates")
		var viewport_point:=root.canvas_transform*point
		var expected_world:Vector2=(point-app.arena.position-app.arena.VIEW_OFFSET)/app.arena.VIEW_SCALE
		_check(app.arena._world(viewport_point).is_equal_approx(expected_world),"aiming accounts for expanded canvas offset")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var output:="res://../agent-tmp/godot/aspect"
			DirAccess.make_dir_recursive_absolute(output)
			root.get_texture().get_image().save_png(output+"/%dx%d.png"%[dimensions.x,dimensions.y])
	app.audio.shutdown()
	app.queue_free()
	await process_frame
	print("Native aspect adapter checks: ",failures," failures")
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures+=1
		push_error(message)
