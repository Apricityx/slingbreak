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
	g.state.mastery={"arrow":10000,"brick":10000,"comboCap":10000};g.state.skills={"forge":1,"bargain":1};g.state.skillRuntime.forge=false;g.state.coins=1e14
	app.session.command("snapshot");await process_frame
	for id in ["mastery_brick","mastery_combo","mastery_arrow"]:
		await click(tree.buttons[id])
		check(tree.buy.text.contains("+2"),"button displays the real two-rank forge purchase")
		var item:Dictionary=tree.items[id]
		for index in range(item.before.size()):
			var text:String=item.before[index][1]
			if text!=item.after[index][1]:text+="  →  "+item.after[index][1]
			check(tree.v.fonts[1].get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x<=(tree.graph.size.x-48)/2,"late-game precision fits the real metric column")
	var before:int=g.state.mastery.arrow;var coins:float=g.state.coins;var price:float=g.mastery_cost("arrow")
	await click(tree.buy)
	check(g.state.mastery.arrow==before+2 and g.state.coins==coins-price,"real late-game click matches forge preview and discounted price")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../agent-tmp/godot/checks/tree-balance-endless.png")
	g.state.mastery={"arrow":0,"brick":0,"comboCap":0};g.state.up.rerollCap=2;g.state.rerolls=0
	app.session.command("snapshot");await click(tree.stages[2]);await click(tree.buttons.reroll_3);await click(tree.buy)
	check(g.state.rerolls==1 and tree.items.reroll_3.before[1][1]=="每 4 关","capacity purchase gives a charge and displays the refill interval")
	await click(tree.buy)
	check(g.state.rerolls==2 and tree.items.reroll_3.before[1][1]=="每 3 关","final capacity rank improves the actual refill interval")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../agent-tmp/godot/checks/tree-balance-refresh.png")
	app.audio.shutdown();app.queue_free();await process_frame
	print("Upgrade tree GUI checks: %d failures" % failures);quit(1 if failures else 0)
