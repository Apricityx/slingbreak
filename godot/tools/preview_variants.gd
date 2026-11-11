extends SceneTree
## Full production game/HUD, deterministic input and simulation. No saved run
## is read or written. Use preview_effects.py to encode the captured GPU frames.
var config:Dictionary

func _initialize() -> void:
	config=JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name()=="headless":push_error("Variant previews need real graphics");quit(1);return
	var app:Node=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);root.add_child(app)
	await process_frame
	var g:RefCounted=app.session.runtime
	app.interface._close_all()
	var id:String=String(config.skills[0]).trim_prefix("variant_")
	g.state.level=30;g.state.skillChosenLevel=30;g.state.skills={"piercer":1};g.state.board=null
	g.state.variantOverride={"level":30,"id":id};g.generate();g.phase="ready";g.paused=false
	g.theme_mode=config.theme;g.resolve_theme();g.state.performanceMode=config.reduced
	g.fx.reset();g.variants.announced=true;g.events.clear();g.state.variantSeen=[id]
	var targets:Array=[]
	if id=="seal":
		g.spawn_core(true);targets=g.variants.rule.seals().duplicate()
	elif id=="fortress":targets=g.bricks.filter(func(b):return b.flags.get("fortressWeak",false))
	app.session.command("snapshot")
	await create_timer(0.6).timeout
	var fired:=false;var hits:=0;var advanced:=0.0;var shots:=0
	for frame in range(config.frames):
		var time:float=maxf(0,(frame/float(config.fps)-0.2)*config.speed)
		while advanced+1.0/60<=time+0.00001:
			if id=="cadence":
				if not fired:
					g.shoot(50,95);fired=true;shots=1
				elif g.variants.rule.available() and shots<4 and g.time>=g.next_shot_at:
					g.shoot(-50 if shots%2 else 50,95);shots+=1
			elif hits<targets.size() and advanced>=0.8+hits*0.9:
				var target:RefCounted=targets[hits];hits+=1
				g.hit(target,1e9)
			app.session.update(1.0/60);advanced+=1.0/60
		await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(config.out+"/frame-%04d.png" % frame)!=OK:
			push_error("Cannot save variant frame");quit(1);return
	app.audio.shutdown();app.queue_free();await process_frame;quit()
