extends SceneTree
## Exercise the real (non-test-mode) composition root, including the preparation
## gate. Saves are redirected to an ignored test file, never the user's progress.
const Main=preload("res://src/main.gd")
const Warmup=preload("res://src/render/effect_warmup.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var app:=Main.new()
	app.session.save_path="res://../agent-tmp/godot/startup-test-progress.json"
	root.add_child(app)
	if DisplayServer.get_name()!="headless":
		check(not app.session.ready and not app.is_processing(),"live simulation waits for shader preparation")
		check(not app.arena.visible and not app.interface.visible,"interactive views hidden during preparation")
		check(not Warmup.complete,"preparation starts in this fresh process")
	for i in range(120):
		if app.session.ready:break
		await process_frame
	check(app.session.ready,"real startup finishes after finite preparation")
	app.set_process(false);app.audio.shutdown()
	check(DisplayServer.get_name()=="headless" or Warmup.complete,"graphics warmup completes before gameplay")
	check(app.session.runtime.fx.skill_events.is_empty() and app.session.runtime.fx.explosions.is_empty(),"preparation leaves no fake live effects")
	check(app.save_clock<1,"preparation time never advances gameplay/save clock")
	if not app.session.frame.reduced:
		var intro:Control=app.get_node("StartupIntro")
		intro.set_process(false)
		check(app.interface.panel==null,"initial draft waits behind startup cover")
		intro.leave();intro.leave()
		check(app.arena.visible and app.interface.visible,"incoming game is mounted before cover retires")
		intro.advance(.28)
		check(not intro.done and intro.size==Vector2(412,915),"crossfade retains full-screen pointer guard")
		check(app.arena.modulate.a>0 and app.interface.modulate.a>0,"game is visible during outgoing cover fade")
		for i in range(3):await process_frame
		# Every level first names its rule; dismissing the card deals the draft.
		check(app.interface.modal_kind=="variant","level rule card opens during visible handoff")
		app.interface._close()
		for i in range(3):await process_frame
		check(app.interface.modal_kind=="draft" and app.interface.rolling,"draft animation starts during visible handoff")
		var clock:float=app.session.runtime.time
		app.session.update(.2)
		check(app.session.runtime.intro_active and app.session.runtime.time==clock,"handoff holds simulation until settled")
		intro.advance(.37)
		check(intro.done and not app.session.runtime.intro_active,"skip releases startup gate once settled")
		check(app.arena.position==Vector2(0,238) and app.interface.position==Vector2.ZERO,"handoff restores exact layout origins")
		check(app.arena.modulate.a==1 and app.interface.modulate.a==1,"handoff leaves no residual transparency")
	app.queue_free();await process_frame
	print("Native effect startup: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
