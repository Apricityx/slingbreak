extends SceneTree
## Render the native pages at the independent browser fixtures' design size.
var app: Node
var failures:=0
var out:="res://../agent-tmp/godot/ui-native/"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	app=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);root.add_child(app)
	await process_frame
	var ui:Control=app.interface
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../agent-tmp/godot/ui-reference/fixture-light.json"))
	for mode in ["light","dark"]:
		ui._close_all()
		app.session.command("configure",{"theme":mode})
		app.session.runtime.state.draft.options=fixture.options.duplicate()
		app.session.command("pause",{"paused":false})
		await capture("draft",mode)
		await ui._select(fixture.options[0])
		app.session.runtime.board_entrance=null;app.session.runtime.phase="ready"
		app.session.command("pause",{"paused":false})
		ui._shop();await capture("shop",mode);ui._close()
		ui._settings();await capture("settings",mode);ui._close()
		ui._equipment();await capture("equipment",mode)
		ui._library();await capture("library",mode);ui._close();ui._close()
		ui._detail(fixture.options[0]);await capture("detail",mode);ui._close()
		app.session.runtime.state.rerolls=1;app.session.command("pause",{"paused":false})
		ui._detail(fixture.options[0]);app.session.command("offerSwap",{"id":fixture.options[0]});await capture("swap",mode);ui._close()
		ui._equipment(true);await capture("achievements",mode);ui._close()
		ui._reset_confirmation();await capture("reset",mode);ui._close()
		app.session.command("pause",{"paused":true});await capture("pause",mode)
		app.session.command("pause",{"paused":false})
		ui.receive_events([{"type":"achievement","id":"double","name":"一箭四雕","bonus":.25,"arrow":1}]);await capture("achievement",mode);ui.achievement_cards.clear()
		app.session.command("configure",{"theme":mode})
		var value:Dictionary=app.session.frame.duplicate(true)
		value.phase="clearing";value.transition.report={"level":1,"total":1280,"parts":[{"label":"砖块收入","value":820,"color":"#98b95a"},{"label":"成就追补","value":180,"color":"#b2934d"},{"label":"核心奖金","value":240,"color":"#7ba5a7"},{"label":"技能奖金","value":40,"color":"#b485a0"}],"bestKills":12,"bestMoney":520,"record":true,"shots":8,"bricks":42,"skills":[{"name":"连击狂热","icon":"flame","count":4},{"name":"雷神降临","icon":"zap-off","count":3}]}
		value.transition.bonus=240;ui._update_report(value);await capture("report",mode)
		app.session.command("reset",{})
		ui._close_all()
		app.session.command("enterBoss",{"id":"serpent"})
		for i in range(600):app.session.update(1.0/60.0)
		await capture("boss",mode)
		app.session.command("reset",{})
	app.audio.shutdown();await create_timer(.1).timeout
	app.queue_free();await process_frame
	app=null
	print("UI fixture captures: %d failure(s)" % failures);quit(1 if failures else 0)

func capture(page: String,mode: String) -> void:
	for i in range(8):await process_frame
	await create_timer(1.6 if page!="achievement" else .22).timeout
	var ui:Control=app.interface
	if ui.panel!=null:
		if ui.panel.size.x>ui.modal_width+1 or ui.panel.position.y+ui.panel.size.y>908:
			failures+=1;push_error("page overflows: %s %s %s" % [page,mode,str(ui.panel.size)])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+page+"-"+mode+".png")
	var data:=FileAccess.open(out+page+"-"+mode+".json",FileAccess.WRITE)
	data.store_string(JSON.stringify(dump(ui.panel if ui.panel!=null else ui.pause_layer if page=="pause" else ui)));data.close()

func dump(node: Node) -> Array:
	var result:Array=[]
	if node==null:return result
	if node is Control:
		var rect:Rect2=node.get_global_rect()
		result.append({"name":node.name,"type":node.get_class(),"x":rect.position.x,"y":rect.position.y,"w":rect.size.x,"h":rect.size.y,"text":node.text if node is Label or node is Button else ""})
	for child in node.get_children():result.append_array(dump(child))
	return result
