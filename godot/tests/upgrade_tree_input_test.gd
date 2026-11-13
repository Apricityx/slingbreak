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
			check(tree!=null and tree.buttons.size()==24,"production page contains foundations and endless orbit")
			check(ui.panel.size.x==412 and ui.panel.get_rect().end.y<=915 and ui.panel.position.y==0,"star map fills the phone canvas")
			check(tree.buy.size.y>=44 and tree.graph.size==ui.panel.size,"touch purchase floats over a full-page map")
			check(tree.find_children("*","PanelContainer",true,false).is_empty(),"no stacked wallet, navigation or detail cards interrupt the tree")
			await click(tree.buttons.arrow_1)
			check(tree.selected=="arrow_1" and tree.buy.name=="Buy_arrow","node selects without spending")
			var before:int=g.state.up.arrow;var coins:float=g.state.coins;var price:float=g.cost("arrow")
			await click(tree.buy)
			check(g.state.up.arrow==before+1 and is_equal_approx(coins-g.state.coins,price),"real click buys exactly one rank")
			check(tree.effects.bursts.size()>0,"confirmed purchase reaches real UI FX")
			check(tree.selected=="arrow_1","purchase retains selection")
			await click(tree.stages[2]);await process_frame
			check(tree.shown_stage==2 and tree.buttons.arrow_3.visible and not tree.buttons.arrow_1.visible,"chapter navigates to a distinct legendary constellation")
			tree.buttons.arrow_3.grab_focus();await process_frame
			check(tree.selected=="arrow_3" and tree.buy.disabled,"keyboard reaches locked nodes and explains gate")
			var stage:int=tree.shown_stage
			g.state.coins+=1;app.session.command("snapshot");await process_frame
			check(tree.shown_stage==stage and tree.selected=="arrow_3","wallet updates retain chapter and selection")
			await click(tree.stages[3]);await process_frame
			check(tree.shown_stage==3 and tree.buy.disabled and tree.buttons.mastery_arrow.visible,"locked endless orbit is discoverable and explains its gate")
			check(tree.effects.bursts.size()<=8 and tree.effects.paths.size()<=12,"page uses bounded effect queues")
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../agent-tmp/godot/checks/tree-"+mode+("-reduced" if reduced else "")+".png")
			ui._close_all();await create_timer(.3).timeout
	g.state.up=preload("res://src/core/upgrade_tree.gd").CAPS.duplicate();g.state.coins=2000000
	app.session.command("snapshot");ui._shop();await create_timer(.65).timeout
	var tree:Control=ui.modal_content.find_child("UpgradeTree",true,false)
	check(tree.shown_stage==3 and not tree.buy.disabled,"completed save opens directly on its endless orbit")
	await click(tree.buttons.mastery_arrow);await click(tree.buy)
	check(g.state.mastery.arrow==1 and tree.items.mastery_arrow.rank==1 and tree.shown_stage==3,"real input purchases endless rank and retains the orbit")
	for id in tree.buttons:
		var node:Button=tree.buttons[id]
		if node.visible:check(node.get_rect().position.x>=0 and node.get_rect().end.x<=tree.graph.size.x and node.get_rect().end.y<=tree.graph.size.y,"orbit touch target fits its map")
	app.audio.shutdown();app.queue_free();await process_frame
	print("Upgrade tree GUI checks: %d failures" % failures);quit(1 if failures else 0)
