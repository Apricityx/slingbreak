extends SceneTree
## Non-reduced draft/swap/reroll paths and interruption of modal-owned motion.
const Motion = preload("res://src/ui/motion.gd")
var app:Node
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("_run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func wait_ui(seconds:float=1.6) -> void:
	await create_timer(seconds).timeout
	for i in range(3):await process_frame
func ready_board() -> void:
	app.session.runtime.phase="ready";app.session.runtime.board_entrance=null;app.session.runtime.entrance_held=false
	app.session.command("pause",{"paused":false})
func _run() -> void:
	app=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);root.add_child(app)
	app.session.command("configure",{"performanceMode":false});await wait_ui()
	var ui:Control=app.interface
	# Palette HTML values remain sRGB; interpolation must not gamma-convert them.
	var mixed:Color=app.arena.board._srgb_mix(Color("#f67b65"),Color("#4f7d2d"),.5)
	check(absf(mixed.r-162.5/255.0)<.00001 and absf(mixed.g-124.0/255.0)<.00001,"aim colour interpolation keeps sRGB channel weights")
	var card:=Button.new();card.size=Vector2(344,190);ui.motion_layer.add_child(card)
	Motion.glint(card,0,Color("#fff8d8d0"));await process_frame
	check(card.has_node("DealGlint") and card.get_node("DealGlint").size==card.size,"glint follows card layout")
	await wait_ui(.85)
	check(not card.has_node("DealGlint"),"completed glint retires its overlay")
	Motion.glint(card,0,Color("#dff0ffc0"));card.queue_free();await process_frame
	await wait_ui(.85)
	check(ui.motion_layer.get_child_count()==0,"interrupting glint does not leave motion nodes")
	# Match the reference landing beat: no sheen until a tier reel has locked.
	app.session.runtime.state.draft.options=["titan","rapid","piercer"]
	app.session.command("snapshot");ui._draft();await wait_ui(.25)
	var tier_card:Button=ui.modal_content.find_child("Skill_titan",true,false)
	check(not tier_card.has_node("DealGlint"),"deal sheen waits for final reel icon")
	await capture("reel-before-lock")
	await wait_ui(.5)
	check(tier_card.has_node("DealGlint"),"tier reel lock triggers landing sheen")
	await capture("reel-landing-glint")
	await wait_ui()
	await capture("reel-settled")
	check(not ui.rolling,"initial reel releases draft input")
	app.session.runtime.state.rerolls=2;app.session.command("snapshot")
	var previous:Array=app.session.frame.draft.options.duplicate()
	ui._reroll();await wait_ui(2.2)
	check(app.session.frame.rerolls==1 and app.session.frame.draft.options!=previous,"full-motion reroll consumes one charge and changes offer")
	check(not ui.rolling,"reroll deal releases input")
	var chosen:String=app.session.frame.draft.options[0]
	await ui._select(chosen)
	check(chosen in app.session.frame.skills and not ui.choosing and not app.session.runtime.entrance_held,"draft flight lands and releases board entrance")
	ready_board();ui._detail(chosen)
	ui._reroll(chosen);await wait_ui(2.2)
	check(app.session.frame.swapOffer is Dictionary and not ui.rolling,"animated replacement candidates become interactive")
	var candidate:String=app.session.frame.swapOffer.options[0]
	await ui._swap(chosen,candidate)
	check(candidate in app.session.frame.skills and chosen not in app.session.frame.skills,"animated swap commits native replacement")
	check(ui.panel==null and not ui.choosing and not app.session.frame.paused,"swap returns to ready input")
	app.session.command("reset",{});await wait_ui(.25)
	ui._settings();await wait_ui(.25);ui._close();await wait_ui()
	check(ui.modal_kind=="draft" and not ui.rolling,"closing settings during reel restarts and unlocks the restored draft")
	app.session.runtime.state.rerolls=2;app.session.command("snapshot")
	ui._reroll();await wait_ui(.1);ui._settings();await wait_ui(.55);ui._close();await wait_ui()
	check(not ui.rolling and ui.modal_kind=="draft","interrupted reroll leaves a usable draft")
	ui._close_all();ready_board();ui._reset_confirmation();await wait_ui(.2)
	await ui._reset_run();await wait_ui()
	check(ui.modal_kind=="draft" and not ui.rolling and not ui.choosing,"reset curtain returns to unlocked native draft")
	check(ui.motion_layer.get_child_count()==0,"finished flights and rewind overlays retire")
	app.audio.shutdown();app.queue_free();await process_frame
	print("Native motion: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func capture(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	var out:="res://../agent-tmp/godot/motion-native/"
	DirAccess.make_dir_recursive_absolute(out)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+name+".png")
