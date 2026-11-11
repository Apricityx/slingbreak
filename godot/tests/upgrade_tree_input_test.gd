extends SceneTree
## Real input routing and retained graph state in both themes and motion modes.
var failures:=0
var app:Node

func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	if not ok:failures+=1;push_error(message)

func click(control:Control) -> void:
	var point:Vector2=control.get_global_transform()*(control.size/2)
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event)
	await process_frame

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);root.add_child(app)
	await process_frame
	var ui:Control=app.interface;var g:RefCounted=app.session.runtime
	g.state.draft=null;g.state.skillChosenLevel=1;g.state.skills={};g.phase="ready";g.state.coins=100000
	ui._close_all()
	for mode in ["light","dark"]:
		for reduced in [false,true]:
			app.session.command("configure",{"theme":mode,"performanceMode":reduced})
			ui._shop();await create_timer(.65).timeout
			var tree:Control=ui.modal_content.find_child("UpgradeTree",true,false)
			check(tree!=null and tree.buttons.size()==21,"production page contains all nodes")
			check(ui.panel.size.x<=388 and ui.panel.get_rect().end.y<=907,"sheet fits phone grid")
			check(tree.buy.size.y>=44 and tree.graph.size.x<=356,"touch purchase and map fit width")
			await click(tree.buttons.arrow_1)
			check(tree.selected=="arrow_1" and tree.buy.name=="Buy_arrow","node selects without spending")
			var before:int=g.state.up.arrow;var coins:float=g.state.coins;var price:float=g.cost("arrow")
			await click(tree.buy)
			check(g.state.up.arrow==before+1 and is_equal_approx(coins-g.state.coins,price),"real click buys exactly one rank")
			check(tree.effects.bursts.size()>0,"confirmed purchase reaches real UI FX")
			check(tree.selected=="arrow_1","purchase retains selection")
			await click(tree.stages[2]);await process_frame
			check(tree.scroll.scroll_vertical>=600,"stage tab navigates to legendary nodes")
			tree.buttons.arrow_3.grab_focus();await process_frame
			check(tree.selected=="arrow_3" and tree.buy.disabled,"keyboard reaches locked nodes and explains gate")
			var offset:int=tree.scroll.scroll_vertical
			g.state.coins+=1;app.session.command("snapshot");await process_frame
			check(tree.scroll.scroll_vertical==offset,"wallet updates retain map position")
			check(tree.effects.bursts.size()<=8 and tree.effects.paths.size()<=12,"page uses bounded effect queues")
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../agent-tmp/godot/checks/tree-"+mode+("-reduced" if reduced else "")+".png")
			ui._close_all();await create_timer(.3).timeout
	app.audio.shutdown();app.queue_free();await process_frame
	print("Upgrade tree GUI checks: %d failures" % failures);quit(1 if failures else 0)
