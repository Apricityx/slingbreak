extends SceneTree
## Exercise actual GUI hit testing, including labels/art inside composite buttons.
var app: Node
var failures:=0

func _initialize() -> void:
	call_deferred("_run")

func settle() -> void:
	for i in range(5):await process_frame
	await create_timer(.42).timeout

func click(control: Control) -> void:
	var point:=control.get_global_rect().get_center()
	var move:=InputEventMouseMotion.new();move.position=point;root.push_input(move)
	var down:=InputEventMouseButton.new();down.position=point;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;root.push_input(down)
	var up:=InputEventMouseButton.new();up.position=point;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;root.push_input(up)
	await settle()
	await create_timer(1.5).timeout

func _run() -> void:
	app=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);root.add_child(app);await settle()
	var ui:Control=app.interface
	var chosen:String=app.session.frame.draft.options[0]
	ui._settings();await settle();ui._close();await settle()
	await create_timer(1.5).timeout
	check(ui.modal_kind=="draft" and ui.modal_content!=null,"settings over draft returns to a valid draft")
	var button:Button=ui.modal_content.find_child("Skill_"+chosen,true,false)
	await click(button)
	check(chosen in app.session.frame.skills,"clicking skill card through art/text commits pick")
	check(ui.panel==null,"pick closes draft")
	app.session.runtime.board_entrance=null;app.session.runtime.entrance_held=false;app.session.runtime.phase="ready";app.session.runtime.state.coins=1000
	app.session.command("pause",{"paused":false})
	ui._shop();await settle()
	var before:int=app.session.frame.up.power
	await click(ui.modal_content.find_child("Buy_power",true,false))
	check(app.session.frame.up.power==before+1,"shop purchase button reaches original upgrade rule")
	ui._close();ui._settings();await settle()
	var dark:Button=ui.modal_content.find_child("Theme_dark",true,false)
	await click(dark)
	check(app.session.frame.theme=="dark","clicking theme preview selects dark mode")
	check(ui.modal_kind=="settings" and ui.panel!=null,"theme rebuild retains settings")
	var check_box:CheckBox=ui.modal_content.find_child("Performance",true,false)
	await click(check_box)
	check(app.session.frame.performanceMode,"performance checkbox is interactive")
	ui._detail(chosen);await settle()
	ui._close();check(ui.modal_kind=="settings" and app.session.frame.paused,"detail returns to paused settings")
	ui._close();check(not app.session.frame.paused,"final modal unpauses")
	ui._equipment();ui._library();ui._settings();await settle()
	await click(ui.modal_content.find_child("Theme_light",true,false))
	ui._close();check(ui.modal_kind=="library" and is_instance_valid(ui.panel),"theme change preserves stacked library")
	ui._close();check(ui.modal_kind=="equipment" and is_instance_valid(ui.panel),"library returns to equipment after theme change")
	ui._close();check(not app.session.frame.paused,"three nested modals restore simulation")
	app.session.runtime.state.rerolls=1;app.session.command("pause",{"paused":false})
	ui._detail(chosen);await settle()
	var reroll:Button=ui.modal_content.find_child("Reroll",true,false)
	await click(reroll)
	check(app.session.frame.swapOffer is Dictionary,"reroll composite button creates swap candidates")
	if app.session.frame.swapOffer is Dictionary:
		var candidate:String=app.session.frame.swapOffer.options[0]
		await click(ui.modal_content.find_child("Swap_"+candidate,true,false))
		check(candidate in app.session.frame.skills and chosen not in app.session.frame.skills,"swap card commits replacement")
	ui._close_all()
	# Long descriptions and a full loadout must scroll without widening the sheet.
	app.session.command("configure",{"performanceMode":false})
	app.session.command("reset",{})
	var dense:Dictionary=ui.frame.duplicate(true)
	dense.slots=4;dense.skills=dense.draft.options.duplicate();dense.skills.append(chosen)
	for id in dense.draft.options:ui.catalog[id].description="这是用来验证长技能说明可以换行和滚动的文本。".repeat(14)
	ui.present(dense);ui._draft();await settle()
	check(ui.panel.size.x==396 and ui.panel.size.y<=883,"long draft stays inside stage")
	check(ui.modal_content.size.y>ui.modal_scroll.size.y,"long draft has real vertical scrolling")
	ui.modal_scroll.scroll_vertical=9999;await settle()
	check(ui.modal_scroll.scroll_vertical>0,"long draft scroll reaches content below fold")
	ui._close_all();app.session.runtime.phase="ready";app.session.command("pause",{"paused":false})
	app.session.command("pause",{"paused":true});await settle()
	check(ui.pause_layer!=null,"pause shows original card")
	app.session.command("pause",{"paused":false});check(ui.pause_layer==null,"resume hides pause card")
	ui._reset_confirmation();await settle();ui._close();check(app.session.frame.level==1,"cancel reset preserves progress")
	app.audio.shutdown();await create_timer(.1).timeout;app.queue_free();await settle();app=null
	print("Godot UI input checks: %d failure(s)" % failures);quit(1 if failures else 0)

func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
