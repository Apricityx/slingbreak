extends SceneTree
var failures := 0
var app: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	app=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);root.add_child(app)
	await create_timer(.1).timeout
	await process_frame
	await process_frame
	_check(app.session.ready,"UI runtime boots")
	var ui: Control=app.interface
	_check(ui.modal_kind=="draft","first draft is modal")
	_check(ui.panel.position.x==16 and ui.panel.size.x==380,"reference dialog width: "+str(ui.panel.size))
	_check(ui.panel.position.y>=8 and ui.panel.position.y+ui.panel.size.y<=907,"dialog fits stage")
	_check(ui.panel.size.y<=ui.modal_content.get_combined_minimum_size().y+35,"draft hugs its content")
	_check(ui.hud_nodes.progress.size.y<=4,"core progress bar stays four pixels high")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../agent-tmp/godot/native/draft-ui.png")
	var chosen: String=app.session.frame.draft.options[0]
	await create_timer(1.5).timeout
	await ui._select(chosen)
	_check(app.session.frame.phase=="entering","draft commits original skill rule")
	_check(ui.panel==null,"draft closes after selection")
	for i in range(60): app.session.update(1.0/60.0)
	ui._settings()
	_check(app.session.frame.paused,"settings pauses simulation")
	ui._detail(chosen)
	ui._close()
	_check(app.session.frame.paused and ui.modal_kind=="settings","nested modal returns to settings and keeps pause")
	ui._close()
	_check(not app.session.frame.paused,"final modal restores original pause state")
	ui._shop()
	_check(not app.session.frame.paused,"shop leaves gameplay live like browser")
	ui._close()
	ui._equipment()
	_check(app.session.frame.paused,"equipment pauses simulation")
	ui._achievements()
	_check(ui.modal_content.get_child_count()>=24,"all 12 achievements shown")
	ui._close()
	app.session.command("configure",{"theme":"dark"})
	_check(ui.visuals.mode=="dark","UI follows canvas palette")
	ui._settings()
	await process_frame
	await process_frame
	_check(ui.panel.position.y>=8 and ui.panel.position.y+ui.panel.size.y<=907,"settings scrolls within stage")
	ui._close()
	app.session.command("configure",{"theme":"light"})
	_check(ui.visuals.mode=="light","UI restores light palette")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../agent-tmp/godot/native/board-ui.png")
	app.audio.shutdown()
	await create_timer(.1).timeout
	app.queue_free();await create_timer(.1).timeout
	print("Godot UI checks: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _check(ok: bool,message: String) -> void:
	if not ok: failures+=1;push_error(message)
