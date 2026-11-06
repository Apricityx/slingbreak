extends SceneTree
## Deterministic real-rendered animation; encode the PNG sequence with ffmpeg.
const Launcher=preload("res://src/core/launcher.gd")
const Dock=preload("res://src/ui/launcher_dock.gd")
var controller: Node
var dock: CanvasLayer

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(412,915)
	var app:Node=load("res://scenes/main.tscn").instantiate()
	app.set_meta("test_mode",true);root.add_child(app)
	app.session.command("configure",{"reduced":true})
	app.interface._close_all()
	app.session.command("choose",{"id":app.session.frame.draft.options[0]})
	app.session.runtime.phase="ready";app.session.runtime.board_entrance=null
	app.session.command("snapshot")
	controller=Launcher.new();controller.set_process(false)
	dock=Dock.new();dock.launcher=controller;root.add_child(dock)
	var out:="res://../agent-tmp/godot/launcher-ring/symmetric-frames"
	DirAccess.make_dir_recursive_absolute(out)
	# Manually advance the visual timeline, so capture speed cannot alter motion.
	dock.set_process(false)
	for frame in range(180):
		var t:=float(frame)/30.0
		var theme:="dark" if t>=3.8 else "light"
		if dock.current_theme!=theme:
			app.session.command("configure",{"theme":theme});dock.set_theme_mode(theme)
		var progress:=minf(100,t/3.0*100)
		var ready:=t>=3.0
		dock.state={"progress":int(progress),"message":"正在准备主游戏…","ready":ready,"phase":"ready" if ready else "loading"}
		dock.enter.visible=ready;dock.enter.text="启动";dock.play_icon.visible=true
		dock._set_progress(progress)
		dock._set_reveal(clampf((t-3.36)/.32,0,1))
		dock.ink.set_shader_parameter("clock",t);dock.ink.set_shader_parameter("ready_age",maxf(0,t-3.0))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/%04d.png" % frame)
		if frame in [60,110,165]:
			root.get_texture().get_image().save_png("res://../agent-tmp/godot/launcher-ring/"+["loading-light.png","ready-light.png","ready-dark.png"][[60,110,165].find(frame)])
	app.audio.shutdown();app.queue_free();dock.queue_free();controller.free()
	await process_frame
	print("Launcher ring preview: 180 frames, 30 fps")
	quit()
