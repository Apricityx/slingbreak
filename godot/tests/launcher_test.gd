extends SceneTree
## Real Controls + a deterministic native bridge stand-in; no Android dependency.
const Launcher=preload("res://src/core/launcher.gd")
var failures:=0

class Bridge extends Node:
	var progress:=0
	var message:=""
	var host_ready:=false
	var leaving:=false
	var overlay:=true
	var events:Array[String]=[]
	func get_progress() -> int:return progress
	func get_message() -> String:return message
	func is_ready() -> bool:return host_ready
	func is_launcher_mode() -> bool:return overlay
	func should_leave() -> bool:return leaving
	func report(event: String) -> void:events.append(event)

class Save extends RefCounted:
	var succeeds:=false
	var calls:=0
	func save() -> bool:calls+=1;return succeeds

class JavaMethodTable extends RefCounted:
	# Mirrors JNISingleton's separate method registry, not a normal GDScript method.
	var methods:Array[String]=["get_progress","get_message","is_ready","should_leave","report","is_launcher_mode"]
	func has_java_method(method: String) -> bool:return methods.has(method)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var invalid:=Launcher.new();invalid.bridge=Node.new()
	var unsupported:Object=invalid.bridge
	check(not invalid.discover(),"incomplete bridge is ignored")
	unsupported.free();invalid.free()
	var java_bridge:=JavaMethodTable.new();var java_controller:=Launcher.new();java_controller.bridge=java_bridge
	check(not java_bridge.has_method("get_progress") and java_bridge.has_java_method("get_progress"),"JNI fixture exposes Java methods outside Object.has_method")
	check(java_controller.discover() and java_controller.has_bridge_method("is_launcher_mode"),"Android JNI method table supports discovery and standalone-mode detection")
	java_bridge.methods.erase("is_ready")
	check(not java_controller.discover(),"incomplete JNI protocol is still rejected")
	java_controller.free()
	var bridge:=Bridge.new();var save:=Save.new();var controller:=Launcher.new()
	controller.bridge=bridge;controller.session=save;root.add_child(controller);controller.set_process(false)
	check(bridge.events==["ready","launcher_ui_ready"],"reports upstream ready and native UI ownership")
	bridge.progress=150;bridge.message="正在准备主游戏";controller.poll()
	check(controller.state.progress==100 and not controller.state.ready,"clamps percentage without manufacturing ready")
	controller.request_enter();check(not bridge.events.has("enter_requested"),"100 percent cannot enable entry")
	bridge.progress=-20;bridge.message="";controller.poll()
	check(controller.state.progress==0 and controller.state.message!="","bounds negative progress and supplies status text")
	bridge.progress=99;bridge.host_ready=true;controller.poll()
	check(controller.state.ready and controller.state.phase=="ready","authoritative ready works at 99 percent")
	bridge.host_ready=false;controller.request_enter()
	check(not bridge.events.has("enter_requested"),"button rechecks readiness before sending")
	bridge.host_ready=true;controller.request_enter();controller.request_enter()
	check(bridge.events.count("enter_requested")==1 and save.calls==0,"double tap sends one request and waits for native acknowledgement")
	bridge.leaving=true;controller.poll();controller.poll()
	check(save.calls==1 and controller.state.phase=="save_error","failed save does not spin on held leave flag")
	check(bridge.events.has("save_failed") and not bridge.events.has("saved") and not paused,"failed save neither leaves nor pauses the tree")
	save.succeeds=true;controller.retry_save();controller.poll()
	check(save.calls==2 and bridge.events.count("saved")==1 and paused,"retry saves once, pauses, then confirms")
	paused=false;controller.queue_free();bridge.free();await process_frame
	await _ui()
	print("Godot launcher checks: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _ui() -> void:
	var app:Node=load("res://scenes/main.tscn").instantiate()
	var bridge:=Bridge.new();bridge.progress=62;bridge.message="正在扫描可用补丁…"
	app.set_meta("test_mode",true);app.set_meta("launcher_bridge",bridge)
	var save_path:="user://launcher-test-%d.json" % Time.get_ticks_usec()
	app.session.save_path=save_path;root.add_child(app)
	await create_timer(2.0).timeout
	app.launcher.set_process(false)
	var dock:CanvasLayer=app.launcher_dock
	var market:Button=app.interface.hud_nodes.market
	check(dock!=null and dock.body.position==Vector2(16,722) and dock.body.size==market.size,"launch and market share a 46px face on the same gameplay row")
	check(dock.body.position.y==market.position.y and dock.body.position.x+market.position.x+market.size.x==412,"paired actions mirror each other around the stage centerline")
	check(dock.ink.get_shader_parameter("plate_color")==market.get_theme_stylebox("normal").bg_color,"both actions use the same panel fill")
	check(is_equal_approx(dock.displayed_progress,62) and dock.body.tooltip_text==bridge.message and not dock.enter.visible,"loading shows host percentage without an active button")
	check(dock.percent.text=="62%" and is_equal_approx(dock.ink.get_shader_parameter("progress"),.62),"ring and number present the same eased progress")
	check(app.interface.hud_nodes.brand.visible and app.interface.content_height==915 and app.interface.content_top==0,"floating control preserves original header and content height")
	check(dock.body.mouse_filter==Control.MOUSE_FILTER_IGNORE and dock.ring.mouse_filter==Control.MOUSE_FILTER_IGNORE,"loading decorations do not steal gameplay input")
	check(dock.enter._has_point(Vector2(23,23)) and not dock.enter._has_point(Vector2.ZERO),"round button leaves transparent corners clickable underneath")
	await _capture("loading-light")
	bridge.progress=100;bridge.host_ready=false;app.launcher.poll();await create_timer(.7).timeout
	check(dock.target_progress==99 and dock.percent.text=="99%" and not dock.enter.visible and dock.enter.disabled,"reported 100 percent without ready cannot show launch")
	bridge.progress=99;bridge.host_ready=true;app.launcher.poll()
	if DisplayServer.get_name()!="headless":check(dock.enter.disabled,"button stays disabled while the full-ring reveal is animating")
	await create_timer(.8).timeout
	check(not dock.enter.disabled and dock.enter.visible and dock.enter.text=="启动","full ring transforms into launch after authoritative ready")
	check(dock.percent.text=="100%" and dock.target_progress==100 and is_equal_approx(dock.ready_mix,1),"completion settles to a full ring and finished reveal")
	check(app.launcher.state.progress==99 and dock.enter.size==market.size,"market-sized round target does not mutate host readiness or progress")
	app.session.command("configure",{"theme":"dark"})
	await create_timer(1.5).timeout
	check(dock.current_theme=="dark" and is_instance_valid(dock.enter),"theme/HUD rebuild preserves launcher state")
	check(dock.ink.get_shader_parameter("plate_color")==app.interface.hud_nodes.market.get_theme_stylebox("normal").bg_color,"dark-theme HUD rebuild keeps the paired faces consistent")
	await _capture("ready-dark")
	app.session.command("configure",{"theme":"light"});await create_timer(.5).timeout
	await _capture("ready-light")
	app.session.command("configure",{"theme":"dark"});await create_timer(.5).timeout
	dock.set_reduced(true)
	check(dock.ink.get_shader_parameter("reduced_motion") and dock.displayed_progress==100 and dock.body.scale==Vector2.ONE,"reduced motion settles ring and disables orbit/pulse/scale animations")
	bridge.host_ready=false;app.launcher.poll()
	check(dock.enter.disabled and not dock.enter.visible and dock.ready_mix==0,"revoking ready immediately removes entry even after reveal")
	bridge.host_ready=true;app.launcher.poll()
	# Test real GUI hit testing even while the draft's modal scrim is present.
	var point:Vector2=dock.enter.get_global_rect().get_center()
	if DisplayServer.get_name()=="headless":
		dock.enter.pressed.emit()
	else:
		var move:=InputEventMouseMotion.new();move.position=point;root.push_input(move)
		for pressed_value in [true,false]:
			var click:=InputEventMouseButton.new();click.position=point;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed_value;root.push_input(click)
	await process_frame
	check(bridge.events.count("enter_requested")==1,"entry button requests native entry (GUI mode also tests modal hit routing)")
	# Disk failure must be visible and retryable, without changing the old save.
	app.session.save_path="user://missing-launcher-test-%d/progress.json" % Time.get_ticks_usec()
	bridge.leaving=true;app.launcher.poll()
	check(app.launcher.state.phase=="save_error" and not dock.enter.disabled,"disk failure offers a working retry button")
	check(dock.enter.text=="重试" and dock.message.visible and dock.ink.get_shader_parameter("failed"),"save error uses amber ring and an explicit retry action")
	await _capture("save-error-dark")
	app.session.save_path=save_path;dock.enter.pressed.emit()
	check(FileAccess.file_exists(save_path) and bridge.events.count("saved")==1,"retry flushes real SlingSession save before host confirmation")
	var payload:Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(payload is Dictionary and payload.get("format")=="slingbreak-progress","saved output is a real upstream progress file")
	paused=false;app.audio.shutdown();app.queue_free();await create_timer(.15).timeout;bridge.free()
	DirAccess.remove_absolute(save_path)
	# Standalone native host still handles save/return, but shows no launcher dock.
	var solo:Node=load("res://scenes/main.tscn").instantiate();bridge=Bridge.new();bridge.overlay=false
	solo.set_meta("test_mode",true);solo.set_meta("launcher_bridge",bridge);solo.session.save_path=save_path
	root.add_child(solo);await process_frame
	check(solo.launcher!=null and solo.launcher_dock==null and solo.interface.content_height==915 and solo.interface.content_top==0 and solo.interface.hud_nodes.brand.visible,"standalone native mode keeps original layout and save bridge")
	check(bridge.events==["ready"],"standalone does not claim launcher chrome")
	solo.audio.shutdown();solo.queue_free();await create_timer(.15).timeout;bridge.free()

func _capture(tag: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://../agent-tmp/godot/native")
	root.get_texture().get_image().save_png("res://../agent-tmp/godot/native/launcher-"+tag+".png")

func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
