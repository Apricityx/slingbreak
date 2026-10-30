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
	app.queue_free();await process_frame
	print("Native effect startup: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
