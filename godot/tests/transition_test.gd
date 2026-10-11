extends SceneTree
var failures:=0
var app:Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	app=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);root.add_child(app)
	await create_timer(.1).timeout
	var session:SlingSession=app.session
	_check(session.ready,"transition session boots")
	DirAccess.make_dir_recursive_absolute("res://../agent-tmp/godot/native/")
	for theme in ["light","dark"]:
		session.command("configure",{"theme":theme})
		var art=load("res://src/ui/intro_art.gd").new();art.visuals=app.interface.visuals;art.size=Vector2(412,296);root.add_child(art)
		for at in [0,200,920,1100,1160,1400,1800]:
			art.age=at/1000.0;art.queue_redraw();await process_frame
			_check(is_instance_valid(art),"native intro frame: %s %d" % [theme,at])
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				var image:Image=root.get_texture().get_image()
				var base:String="res://../agent-tmp/godot/native/intro-%s-%d" % [theme,at]
				image.save_png(base+".png")
				var state:=FileAccess.open(base+".json",FileAccess.WRITE)
				state.store_string(JSON.stringify({"theme":theme,"milliseconds":at}));state.close()
		art.queue_free();await process_frame
	# Intro blocks firing even when the board behind it is ready, and is skippable.
	var chosen:String=session.frame.draft.options[0]
	await create_timer(1.5).timeout
	await app.interface._select(chosen)
	for i in range(70):session.update(1.0/60.0)
	session.runtime.intro_active=true
	_check(not session.command("shoot",{"dx":0,"dy":100}).accepted,"intro locks gameplay input")
	var intro=load("res://src/ui/intro.gd").new();intro.session=session;intro.visuals=app.interface.visuals;root.add_child(intro);intro.set_process(false)
	intro.advance(1.1)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../agent-tmp/godot/native/intro-ui.png")
	intro.leave();intro.advance(.65)
	_check(intro.done,"intro skip completes curtain lifetime")
	session.runtime.intro_active=false
	session.command("configure",{"theme":"light"})
	# Trigger the original clear entry point without bypassing its wrappers.
	var expected_level:int=session.frame.level
	session.runtime.clear()
	session.command("pause",{"paused":false})
	_check(session.frame.phase=="clearing","original clear transitions to settlement")
	_check(session.frame.transition.report.level==expected_level,"report retains cleared level before rules advance")
	_check(app.interface.report_layer!=null,"native report visible")
	_check(session.frame.transition.report.total==session.frame.levelMoney,"report uses original accounting")
	await process_frame
	await process_frame
	var card:PanelContainer=app.interface.report_layer.get_node("ReportCard")
	_check(is_equal_approx(card.size.x,340),"report retains reference width")
	_check(card.size.y<250,"short report hugs content")
	var continue_hint:Label=card.find_child("Continue",true,false)
	_check(continue_hint!=null,"continue hint is inside report like original")
	_check(card.position.y+card.size.y<=572,"report fits arena")
	var before:float=session.frame.time
	for i in range(5):session.update(1.0/60.0)
	_check(session.frame.time==before,"original core hit-stop holds simulation for 130 ms")
	session.command("skipClear",{})
	_check(session.frame.phase=="clearing","early skip cannot bypass coin landing")
	for i in range(55):session.update(1.0/60.0)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../agent-tmp/godot/native/report-ui.png")
	# A dense UI-only fixture covers every report section without changing the
	# simulation's rewards. Test both palettes and settings over the report.
	for theme in ["light","dark"]:
		session.command("configure",{"theme":theme})
		var dense:Dictionary=session.frame.duplicate(true)
		dense.transition.report={"level":100,"total":123456,"bestKills":32,"bestMoney":98765,"shots":16,"bricks":60,"record":true,"parts":[{"label":"基础砖块","value":30000,"color":"#9bcc5d"},{"label":"倍率加成","value":28000,"color":"#e0ad2c"},{"label":"核心奖金","value":40000,"color":"#5f8a2f"},{"label":"技能与其他","value":20456,"color":"#8d78b9"},{"label":"此前进度","value":5000,"color":"#b9c2ad"}],"skills":[{"name":"连击狂热","count":32},{"name":"雷霆连锁","count":15},{"name":"核心猎手","count":3}],"rift":{"title":"裂隙之眼","items":["1 第一阶段 · 晶环/凝视","2 第二阶段 · 泪滴/幻象","3 第三阶段 · 末日/守望者"]}}
		app.interface._update_report(dense)
		await process_frame
		await process_frame
		card=app.interface.report_layer.get_node("ReportCard")
		continue_hint=card.find_child("Continue",true,false)
		_check(is_equal_approx(card.size.x,340),"dense report width: "+theme)
		_check(card.position.y+card.size.y<=572,"dense report fits arena: "+theme)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../agent-tmp/godot/native/report-dense-%s-ui.png" % theme)
	app.interface._settings()
	_check(app.interface.panel.z_index>app.interface.report_layer.z_index,"settings draws above settlement")
	app.interface._close()
	session.command("configure",{"theme":"light"})
	session.command("skipClear",{})
	for i in range(8):session.update(1.0/60.0)
	_check(session.frame.transition.holdDraft,"curtain holds next draft")
	_check(app.interface.modal_kind!="draft","draft cannot appear under incoming curtain")
	_check(app.interface.wipe_layer!=null,"native curtain visible")
	_check(not session.command("shoot",{"dx":0,"dy":100}).accepted,"curtain locks shooting")
	for i in range(70):session.update(1.0/60.0)
	_check(not session.frame.transition.holdDraft,"curtain releases next draft")
	_check(session.frame.transition.wipe==null,"curtain state retires")
	_check(app.interface.report_layer==null,"settlement view retires")
	_check(session.ready,"transition runtime stays healthy: "+session.error)
	app.audio.shutdown();await create_timer(.1).timeout
	app.queue_free();await create_timer(.1).timeout
	print("Godot transition checks: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _check(ok:bool,message:String) -> void:
	if not ok:failures+=1;push_error(message)
