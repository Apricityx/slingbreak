extends SceneTree
## Real danger-button input, cancel/focus/stack behavior and durable reset with
## old autosaves pending. All writes are isolated from the player's save.
const Session=preload("res://src/core/session.gd")
const Upgrades=preload("res://src/core/upgrade_tree.gd")
var failures:=0
var checks:=0
var resets:=0
var app:Node
var ui:Control
var directory:String

func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Settings reset input requires --gui (Xvfb is supported)");quit(1);return
	call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func settle() -> void:
	for i in range(4):await process_frame
	await create_timer(.6).timeout

func click(control:Control) -> void:
	check(control!=null,"expected control exists")
	if control==null:return
	var point:Vector2=control.get_global_transform()*(control.size/2)
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event)
	await settle()

func escape() -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=pressed;root.push_input(event)
	await settle()

func capture(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory+"/"+name+".png")==OK,"capture "+name)

func run() -> void:
	directory=ProjectSettings.globalize_path("res://../agent-tmp/godot/settings-reset")
	DirAccess.make_dir_recursive_absolute(directory)
	app=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);app.session.save_path=directory+"/progress.json";root.add_child(app)
	await settle();ui=app.interface
	ui.action.connect(func(method,_input):
		if method=="reset":resets+=1
	)
	for mode in ["light","dark"]:
		for reduced in [false,true]:
			ui._close_all()
			var g:RefCounted=app.session.runtime
			g.state.level=100;g.state.coins=987654;g.state.total=6789;g.state.best=24;g.state.up=Upgrades.CAPS.duplicate()
			g.state.mastery={"arrow":37,"brick":29,"comboCap":51};g.state.skills={"mint":1,"titan":1};g.state.skillChosenLevel=100;g.state.draft=null
			g.state.achievements={"double":12,"bank":5};g.state.rerolls=4;g.state.rerollGrantLevel=99;g.state.variantSeen=["cadence"]
			g.state.bossOverride={"level":100,"boss":"eye"};g.phase="ready";g.generate()
			app.session.command("configure",{"theme":mode,"performanceMode":reduced,"volume":37})
			if not reduced:g.clear()
			var arrow:RefCounted=g.launch(g.origin,Vector2.UP*24)
			g.active_arrow=arrow;g.skills.later(60,arrow,func():g.state.coins+=123)
			g.freeze_until=g.time+30;g.locked_until=g.clock+30
			app.session.command("snapshot")
			var before:Dictionary=g.export_progress().state
			check(app.session.save(),"seed private progress")
			var original:=FileAccess.get_file_as_string(app.session.save_path)
			var count:=resets
			ui._settings();await settle()
			var settings_panel:Control=ui.panel
			var entry:Button=ui.modal_content.find_child("ResetGameData",true,false)
			ui.modal_scroll.ensure_control_visible(entry);await settle()
			var scroll:int=ui.modal_scroll.scroll_vertical
			check(ui.modal_scroll.get_global_rect().encloses(entry.get_global_rect()),"danger entry is fully reachable in settings")
			check(entry.get_theme_color("font_color").r>entry.get_theme_color("font_color").g,"danger entry uses red text in "+mode)
			if not reduced:await capture("settings-"+mode)
			await click(entry)
			check(ui.modal_kind=="reset" and ui.modal_stack.back().panel==settings_panel,"first click opens a second modal over retained settings")
			if ui.modal_kind!="reset":await finish();return
			check(g.export_progress().state==before and resets==count,"opening confirmation does not reset gameplay")
			check(FileAccess.get_file_as_string(app.session.save_path)==original,"opening confirmation does not overwrite progress")
			var cancel:Button=ui.modal_content.find_child("CancelReset",true,false)
			var confirm:Button=ui.modal_content.find_child("ConfirmReset",true,false)
			check(cancel.has_focus(),"confirmation initially focuses cancel")
			check(cancel.get_theme_color("font_focus_color")==ui.visuals.color("ink"),"focused cancel text remains legible in "+mode)
			check(ui.modal_scroll.get_global_rect().encloses(confirm.get_global_rect()),"confirmation action fits the sheet")
			if not reduced:await capture("confirmation-"+mode)
			await click(cancel)
			check(ui.modal_kind=="settings" and ui.panel==settings_panel and g.paused,"cancel restores paused settings")
			check(ui.modal_scroll.scroll_vertical==scroll and entry.has_focus(),"cancel restores scroll and opener focus")
			check(g.export_progress().state==before and FileAccess.get_file_as_string(app.session.save_path)==original,"cancel preserves all gameplay and disk data")
			await click(entry);await escape()
			check(ui.modal_kind=="settings" and resets==count,"Escape cancels without reset")
			await click(entry)
			# Exercise the production persistence route, not the test-mode bypass.
			app.session.request_save();app.session.request_save()
			app.set_meta("test_mode",false)
			await click(ui.modal_content.find_child("ConfirmReset",true,false))
			app.set_meta("test_mode",true);await settle()
			check(resets==count+1,"confirmation dispatches exactly one reset")
			check(g.state.level==1 and g.state.coins==0 and g.state.total==0 and g.state.best==0,"reset clears level, wallet and records")
			check(g.state.up.values().all(func(n):return n==0) and g.state.mastery.values().all(func(n):return n==0),"reset clears foundation and endless ranks")
			check(g.state.skills.is_empty() and g.state.achievements.is_empty() and g.state.rerolls==0 and g.state.rerollGrantLevel==0,"reset clears skills, achievements and refresh inventory")
			check(g.state.get("variantSeen",[]).is_empty() and g.bosses.fight.is_empty(),"reset clears content history and the Boss encounter")
			check(g.skills.jobs.is_empty() and g.active_arrow==null and g.arrows.is_empty(),"old arrows and delayed payouts are retired")
			check(g.wipe==null and g.report==null and g.freeze_until==0 and g.locked_until==0,"old clear transitions and attack locks are retired")
			check(g.phase=="draft" and not g.paused and ui.modal_kind=="draft" and ui.modal_stack.is_empty(),"reset returns directly to the first draft")
			check(g.theme_mode==mode and g.state.volume==37 and g.state.performanceMode==reduced,"reset retains display/audio preferences")
			check(app.session.save_thread==null and app.session.queued_save=="","reset drains previous autosaves before it completes")
			var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(app.session.save_path))
			check(Session.Progress.valid(saved) and saved.state.level==1 and saved.state.coins==0 and saved.state.mastery.arrow==0,"new run is already durable on disk")
			var back:=Session.new();back.save_path=app.session.save_path
			check(back.start(45,back.load_progress()) and back.frame.level==1 and back.frame.coins==0 and back.frame.skills.is_empty(),"relaunch cannot restore the erased progress")
			back.runtime.dispose()
	# A fast keyboard/touch confirm may close the sheet before deferred calls.
	ui._settings();ui._reset_confirmation()
	ui.modal_content.find_child("ConfirmReset",true,false).pressed.emit()
	await settle()
	check(ui.modal_kind=="draft" and app.session.frame.level==1,"same-frame confirmation leaves no deferred focus on a removed sheet")
	await finish()

func finish() -> void:
	app.audio.shutdown();app.queue_free();await settle()
	print("Settings reset: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
