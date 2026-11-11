extends SceneTree
## Capture the production page and real confirmed purchases, not a fake FX
## board. Frame stepping is deterministic; all UI effects use their own clock.
var config:Dictionary

func _initialize() -> void:
	config=JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name()=="headless":push_error("Tree GIF needs real graphics");quit(1);return
	var app:Node=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);root.add_child(app)
	await process_frame
	var g:RefCounted=app.session.runtime
	g.state.draft=null;g.state.skills={};g.state.skillChosenLevel=1;g.phase="ready";g.state.coins=500000
	g.theme_mode=config.theme;g.resolve_theme();g.state.performanceMode=config.reduced
	var id:String=config.skills[0];var selected:="power_1"
	if id=="upgrade_unlock":g.state.up.power=3
	if id=="upgrade_breakthrough":
		g.state.up={"power":16,"arrow":23,"brick":20,"draw":10,"comboCap":12,"slots":2,"rerollCap":2};selected="arrow_3"
	app.interface._close_all();app.session.command("snapshot")
	app.interface._shop()
	await create_timer(.7).timeout
	var page:Control=app.interface.modal_content.find_child("UpgradeTree",true,false)
	page._select(selected,false)
	if id=="upgrade_breakthrough":page.scroll.scroll_vertical=606
	await process_frame
	await create_timer(.4).timeout
	page.set_process(false);page.effects.set_process(false);page.effects.reset()
	var count:=0
	for frame in range(config.frames):
		var time:float=(frame/float(config.fps)-.2)*config.speed
		var target:int=mini(3,1+floori(time/.18)) if id=="upgrade_rank" else 1
		page.effects.advance(maxf(0,time)-page.effects.clock)
		while time>=0 and count<target:
			app.session.command("buy",{"key":"arrow" if id=="upgrade_breakthrough" else "power","node":selected});count+=1
			if page.effects.bursts.is_empty():push_error("Purchase did not reach UI feedback");quit(1);return
		for button in page.buttons.values():button.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var path:String=config.out+"/frame-%04d.png" % frame
		if root.get_texture().get_image().save_png(path)!=OK:push_error("Cannot save "+path);quit(1);return
	app.audio.shutdown();app.queue_free();await process_frame;quit()
