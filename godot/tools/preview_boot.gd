extends SceneTree
## Actual production entry and GL warmup, captured at a deterministic 30 fps.
func _initialize() -> void:call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(412,915)
	var boot:Node=load("res://scenes/boot.tscn").instantiate()
	var dark:="--dark" in OS.get_cmdline_user_args()
	var reduced:="--reduced" in OS.get_cmdline_user_args()
	boot.reveal_started.connect(func():
		boot.app.session.command("configure",{"theme":"dark" if dark else "light","reduced":reduced})
		boot.reduced=reduced
	)
	root.add_child(boot)
	var out:="res://../agent-tmp/godot/boot/"+("dark" if dark else "light")+("-reduced" if reduced else "")
	DirAccess.make_dir_recursive_absolute(out)
	for frame in range(120):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/%04d.png" % frame)
	if boot.failed:push_error("Boot preview failed")
	if boot.app!=null:boot.app.audio.shutdown()
	await create_timer(.1).timeout
	boot.queue_free();await create_timer(.1).timeout
	print("Boot preview: 120 real-rendered frames, including production warmup")
	quit()
