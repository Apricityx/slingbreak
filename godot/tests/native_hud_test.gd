extends SceneTree
## Exercise live HUD handoffs rather than only the settled screenshot.
var app:Node
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("_run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func _run() -> void:
	app=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);root.add_child(app)
	await process_frame
	var ui:Control=app.interface
	ui._close_all()
	app.session.command("choose",{"id":app.session.frame.draft.options[0]})
	app.session.runtime.phase="ready";app.session.runtime.board_entrance=null
	app.session.command("snapshot")
	var frame:Dictionary=app.session.frame.duplicate(true)
	frame.phase="flying";frame.paused=false;frame.reduced=false;frame.draft=null
	var out:="res://../agent-tmp/godot/hud-native/"
	DirAccess.make_dir_recursive_absolute(out)
	for mode in ["light","dark"]:
		app.session.command("configure",{"theme":mode})
		frame.theme=mode;frame.phase="flying";frame.core=null;frame.killed=0
		frame.achievement={"id":31,"kills":4,"capKills":12,"baseMult":1.3,"paid":320}
		ui.present(frame);await create_timer(.4).timeout
		check(is_equal_approx(ui.hud_nodes.combo_progress.value,100.0/3),"combo meter follows the scoring arrow")
		frame.achievement.kills=12;frame.achievement.baseMult=3.5
		frame.killed=frame.threshold;frame.core={"x":390,"y":100}
		ui.present(frame);await create_timer(.4).timeout
		check(ui.hud_nodes.combo_progress.value==100 and ui.hud_nodes.combo_spark.modulate.a==1,"capped combo fills and reveals spark")
		check(ui.hud_feedback.heat==3 and ui.hud_nodes.progress.state=="ready","core reveal and heat use independent state")
		await capture(out+"capped-"+mode+".png")
		# A different arrow must reset, not animate from the previous arrow's cap.
		frame.achievement={"id":32,"kills":1,"capKills":20,"baseMult":1,"paid":10}
		ui.present(frame)
		check(ui.hud_nodes.combo_progress.value==5,"switching scoring arrow snaps its own meter")
		await create_timer(.06).timeout
		frame.reduced=true;ui.present(frame)
		check(ui.hud_nodes.combo.scale==Vector2.ONE and ui.hud_nodes.combo.position==Vector2(294,110) and ui.hud_nodes.combo.modulate.a==1,"reduced motion interrupts count handoff at resting pose")
		check(not ui.hud_feedback.is_processing() and not ui.hud_nodes.progress.is_processing(),"reduced motion stops decorative loops")
		frame.phase="ready";frame.core=null;frame.killed=0;ui.present(frame)
		check(ui.hud_feedback.heat==0 and ui.hud_feedback.gem_fill==0,"next board clears heat and core readiness")
		frame.levelMoney=12345678;ui.present(frame)
		check(ui.hud_nodes.earnings.text=="+ 12.35M","long earnings use the shared compact money format")
		await capture(out+"idle-"+mode+".png")
		ui._settings();await create_timer(.5).timeout
		var button:Button=ui.modal_content.find_child("Theme_dark",true,false)
		check(button.get_theme_stylebox("normal").corner_radius_top_left==button.get_theme_stylebox("hover").corner_radius_top_left,"custom button retains radius on hover")
		ui._close_all();frame.reduced=false
	app.audio.shutdown();app.queue_free();await process_frame
	print("Native HUD: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func capture(path:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
