extends SceneTree
var failures:=0

func _initialize() -> void:call_deferred("_run")

func _run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/boot.tscn","lightweight production entry")
	_check(ProjectSettings.get_setting("application/boot_splash/image")=="res://assets/boot/splash.png","engine and scene share branded art")
	_check(ProjectSettings.get_setting("application/boot_splash/minimum_display_time")==0,"no artificial wait")
	var boot:Node=load("res://scenes/boot.tscn").instantiate()
	boot.reveal_started.connect(func():boot.set_process(false))
	boot.set_meta("test_mode",true);root.add_child(boot)
	_check(boot.cover.modulate.a==1,"cover opaque before resources load")
	_check(boot.cover.mouse_filter==Control.MOUSE_FILTER_STOP,"cover guards incoming input")
	var ticks:=0
	while not boot.revealing and not boot.failed and ticks<600:
		await process_frame;ticks+=1
	_check(boot.revealing,"real session readiness releases cover")
	if boot.app!=null and boot.app.session.ready:
		boot.set_process(false)
		_check(boot.app.session.runtime.intro_active,"simulation guarded until handoff")
		_check(boot.app.interface.startup_covered,"draft reels held behind cover")
		boot.reduced=false;boot.elapsed=0;boot._process(.16)
		_check(boot.cover.modulate.a>0 and boot.cover.modulate.a<1,"continuous crossfade")
		_check(boot.app.interface.visible and boot.app.arena.visible,"complete UI is beneath cover")
		boot._process(.5)
		_check(not boot.app.session.runtime.intro_active,"handoff unlocks simulation")
		_check(not boot.app.interface.startup_covered,"draft released with handoff")
		_check(boot.app.interface.modulate.a==1 and boot.app.arena.modulate.a==1,"incoming frame fully restored")
		boot.app.audio.shutdown()
	await create_timer(.1).timeout
	boot.queue_free();await create_timer(.1).timeout
	# Reduced motion uses the same actual-ready gate but no reveal animation.
	var quiet:Node=load("res://scenes/boot.tscn").instantiate()
	quiet.set_meta("test_mode",true)
	quiet.reveal_started.connect(func():quiet.set_process(false))
	root.add_child(quiet)
	while not quiet.revealing and not quiet.failed:await process_frame
	_check(quiet.cover.modulate.a==1,"reduced mode does not bypass preparation gate")
	quiet.reduced=true;quiet._process(0)
	_check(not quiet.app.session.runtime.intro_active,"reduced mode has no minimum animation time")
	quiet.app.audio.shutdown();await create_timer(.1).timeout
	quiet.queue_free();await create_timer(.1).timeout
	print("Godot boot checks: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _check(ok:bool,message:String) -> void:
	if not ok:failures+=1;push_error(message)
