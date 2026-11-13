extends SceneTree
## Real controls: ticking HUD without pointer activity, paused rule re-open,
## remembered intros, nested draft return and both palette layouts.
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("_run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func _run() -> void:
	var app:Node=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);app.set_meta("variant_cards",true);root.add_child(app)
	await process_frame
	var ui:Control=app.interface;var g:RefCounted=app.session.runtime
	check(ui.modal_kind=="variant","first encounter opens the full rule card")
	check(g.state.get("variantSeen",[]).has("rush"),"shown introduction is acknowledged")
	ui.modal_content.find_child("VariantContinue",true,false).pressed.emit()
	await process_frame;await process_frame
	check(ui.modal_kind=="draft" and ui.modal_content.find_child("DraftVariant",true,false)!=null,"draft keeps a rule entry")
	ui.modal_content.find_child("DraftVariant",true,false).pressed.emit()
	check(ui.modal_kind=="variant","draft rule entry reopens full explanation")
	ui._close();await process_frame
	check(ui.modal_kind=="draft","closing explanation returns to draft")
	ui._close_all();g.state.level=30;g.state.skillChosenLevel=30;g.state.skills={"piercer":1};g.state.board=null
	g.state.variantOverride={"level":30,"id":"rush"};g.generate();g.phase="ready";g.paused=false
	app.session.command("snapshot")
	check(ui.hud_nodes.variant.visible,"live rule status is visible")
	app.session.command("shoot",{"dx":70,"dy":70})
	for i in range(30):app.session.update(1.0/60)
	var before:String=ui.hud_nodes.variant_status.text
	for i in range(30):app.session.update(1.0/60)
	check(before!=ui.hud_nodes.variant_status.text and ui.hud_nodes.variant_status.text.contains("剩余"),"real HUD countdown ticks without pointer input")
	ui.hud_nodes.variant.pressed.emit()
	check(g.paused and ui.modal_kind=="variant","reading live rules pauses the level")
	var clock:float=g.variants.rule.data.clock
	for i in range(60):app.session.update(1.0/60)
	check(g.variants.rule.data.clock==clock,"rule reading does not spend a timer")
	ui._close()
	check(not g.paused,"closing rules restores live play")
	for theme in ["light","dark"]:
		app.session.command("configure",{"theme":theme})
		for id in g.variants.ORDER:
			g.state.variantOverride={"level":30,"id":id};g.generate();g.phase="ready"
			if id in ["seal","bulwark","banked"]:g.spawn_core(true)
			app.session.command("snapshot")
			await process_frame
			check(ui.hud_nodes.variant_status.text==g.variants.rule.status(),"HUD follows "+id+" in "+theme)
			check(ui.hud_nodes.variant.get_rect().end.x<=412 and ui.hud_nodes.variant.get_rect().end.y<=90,"rule stays in the level header")
			check(ui.hud_nodes.variant_status.get_minimum_size().x<=236,"rule status fits without clipping: "+id)
			if id=="seal":
				check(ui.hud_nodes.core_label.text=="核心封印","sealed core label never looks unlocked")
				check(ui.hud_nodes.progress.state=="blocked" and ui.hud_nodes.core_value.text=="剩 3","sealed core shows remaining seals, not a full ready bar")
			elif id=="bulwark":
				check(ui.hud_nodes.progress.state=="blocked" and ui.hud_targets.progress==0,"armoured core begins with an empty armour-removal track")
			elif id=="banked":
				check(ui.hud_nodes.core_label.text=="核心需折射" and ui.hud_nodes.core_value.text=="先反弹","banked core keeps its actual hit condition")
			if DisplayServer.get_name()!="headless":
				var out:="res://../agent-tmp/godot/variant-ui/"
				DirAccess.make_dir_recursive_absolute(out)
				await create_timer(0.12).timeout
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(out+id+"-"+theme+".png")
			ui.hud_nodes.variant.pressed.emit()
			if DisplayServer.get_name()!="headless":await create_timer(.55).timeout
			else:
				for i in range(3):await process_frame
			var note:PanelContainer=ui.modal_content.find_child("VariantNote",true,false)
			var words:Label=note.get_child(0)
			var go:Button=ui.modal_content.find_child("VariantContinue",true,false)
			check(words.text==g.variants.rule.note() and words.size.y>=words.get_minimum_size().y,"full rule text is laid out without truncation: "+id+" in "+theme)
			check(words.position.x+words.size.x<=note.size.x and ui.modal_content.size.x<=ui.modal_scroll.size.x+.1,"rule explanation fits the sheet width: "+id)
			check(go.position.y+go.size.y<=ui.modal_scroll.size.y+.1,"rule return action is visible without scrolling: "+id)
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../agent-tmp/godot/variant-ui/"+id+"-"+theme+"-rules.png")
			ui._close()
			if id=="bulwark":
				g.variants.core_hit(null);app.session.command("snapshot")
				check(ui.hud_nodes.progress.state=="blocked" and ui.hud_targets.progress==50,"first armour hit shows actual halfway progress")
				g.variants.rule.data.guard=0;g.variants.core_hit(null);app.session.command("snapshot")
				check(ui.hud_nodes.progress.state=="ready" and ui.hud_targets.progress==100,"last armour plate exposes a ready core")
	ui._close_all();g.state.variantOverride={"level":30,"id":"rush"};g.state.skillChosenLevel=29;g.state.draft=null;g.generate()
	app.session.command("snapshot");await process_frame
	check(ui.modal_kind=="draft","remembered rule skips the blocking intro")
	# A new run on the same level/id must not inherit a UI-only suppression key.
	ui._close_all();g.state.erase("variantSeen");g.generate();app.session.command("snapshot")
	check(ui.modal_kind=="variant","fresh run can introduce the same rule again")
	app.audio.shutdown();app.queue_free();await process_frame
	print("Native variant UI: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
