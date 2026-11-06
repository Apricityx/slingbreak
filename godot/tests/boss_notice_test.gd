extends SceneTree
## Boss footer callouts stay hidden without suppressing the entrance introduction.
var failures:=0

func _initialize() -> void:call_deferred("run")

func check(ok:bool,message:String) -> void:
	if not ok:failures+=1;push_error(message)

func run() -> void:
	var app:Node=load("res://scenes/main.tscn").instantiate()
	app.set_meta("test_mode",true);root.add_child(app)
	await process_frame
	app.session.command("enterBoss",{"id":"eye"})
	for i in range(240):app.session.update(1.0/60.0)
	app.set_process(false)
	var ui:Control=app.interface
	var notice:Control=ui.notices
	for mode in ["light","dark"]:
		app.session.command("configure",{"theme":mode})
		for reduced in [false,true]:
			var value:Dictionary=app.session.frame.duplicate(true)
			value.reduced=reduced
			value.notices=[{"key":"test-status","kind":"rift-callout","tone":"weak","kicker":"SEAL BROKEN","title":"失神","note":"巨眼暴露 · 伤害 ×3"}]
			notice.present(value)
			await create_timer(.3).timeout
			check(notice.cards.is_empty() and notice.get_child_count()==0,"boss footer callouts are not created")
			if not reduced and DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://../agent-tmp/godot/preview")
				root.get_texture().get_image().save_png("res://../agent-tmp/godot/preview/boss-status-"+mode+".png")
			value.notices=[];notice.present(value)
			await create_timer(.3).timeout
			check(notice.cards.is_empty() and notice.get_child_count()==0,"expired status fully retires")
			value.notices=[{"key":"test-intro","kind":"rift-intro","kicker":"BOSS","title":"深渊之眼","note":""}]
			notice.present(value)
			check(notice.cards.has("test-intro"),"boss entrance introduction is preserved")
			value.notices=[];notice.present(value)
			await create_timer(.3).timeout
	app.audio.shutdown();app.queue_free();await process_frame
	print("Boss notice checks: %d failure(s)" % failures)
	quit(1 if failures else 0)
