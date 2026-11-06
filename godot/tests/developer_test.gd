extends SceneTree
const Simulation=preload("res://src/core/simulation.gd")
const Interface=preload("res://src/ui/interface.gd")
const Progress=preload("res://src/core/progress.gd")
var failures:=0

func _initialize() -> void:call_deferred("_run")

func check(ok:bool,message:String) -> void:
	if not ok:failures+=1;push_error(message)

func _run() -> void:
	var s:=Simulation.new();s.start(9128)
	var dev:RefCounted=s.developer
	check(not dev.apply(s,{"operation":"enable","value":true}),"locked commands rejected")
	check(not dev.apply(s,{"operation":"boss","id":"eye"}),"locked boss command rejected")
	for i in range(6):check(not dev.tap(1000+i*100),"not unlocked early")
	check(not dev.tap(3000),"slow taps reset")
	for i in range(6):dev.tap(3100+i*100)
	check(dev.unlocked,"seven rapid taps unlock")
	check(dev.apply(s,{"operation":"enable","value":true}),"enable")
	check(dev.apply(s,{"operation":"override","key":"damage","value":123}),"override accepted")
	check(s.damage()==123,"damage takes effect")
	check(not dev.apply(s,{"operation":"override","key":"speed","value":NAN}),"reject NaN")
	check(not dev.apply(s,{"operation":"override","key":"drawInterval","value":0}),"reject zero interval")
	check(not dev.apply(s,{"operation":"override","key":"penetration","value":1.5}),"integer required")
	check(dev.apply(s,{"operation":"state","key":"slots","value":3}),"slots")
	check(dev.apply(s,{"operation":"skills","ids":["railgun","titan","decay","growing"]}),"any skill at level one")
	check(s.rank("railgun")==1 and s.phase=="ready","skills equipped without draft")
	check(not dev.apply(s,{"operation":"skills","ids":["titan","titan"]}),"duplicate skills rejected")
	check(dev.apply(s,{"operation":"count","level":1,"value":77}),"77 bricks accepted")
	check(dev.apply(s,{"operation":"level","value":1}),"rebuild")
	check(s.initial==77 and s.bricks.size()==77,"exact count even at level one")
	check(dev.apply(s,{"operation":"count","level":42,"value":1}),"per level count")
	dev.apply(s,{"operation":"level","value":42})
	check(s.initial==1,"one brick level")
	check(not dev.apply(s,{"operation":"level","value":100001}),"invalid level rejected")
	check(not dev.apply(s,{"operation":"boss","id":"unknown"}),"invalid boss rejected")
	dev.enabled=false
	check(not dev.apply(s,{"operation":"boss","id":"eye"}),"disabled boss command rejected")
	dev.enabled=true
	var equipped:Dictionary=s.state.skills.duplicate()
	var coins:float=s.state.coins
	var deck:Array=s.state.get("bossDeck",[]).duplicate()
	for id in Progress.BOSSES:
		check(dev.apply(s,{"operation":"boss","id":id}),"boss command accepted: "+id)
		check(s.bosses.boss_id==id and s.bosses.fight.phase==1 and s.phase=="ready","selected boss starts immediately: "+id)
		check(s.state.level==42 and s.state.skills==equipped and s.state.coins==coins,"boss preserves level, equipment and coins")
		check(s.state.get("bossDeck",[])==deck,"forced boss does not consume normal deck")
		check(Progress.valid(s.export_progress()),"forced boss save valid: "+id)
		var boss_restored:=Simulation.new();boss_restored.start(1,s.export_progress(),{"developer":dev.config()})
		check(boss_restored.bosses.boss_id==id,"forced boss restores: "+id)
		boss_restored.dispose()
	dev.apply(s,{"operation":"level","value":42})
	check(s.bosses.fight.is_empty() and s.state.bossOverride==null,"level rebuild clears forced boss")
	check(Progress.valid(s.export_progress()),"debugged progress still valid")
	var restored:=Simulation.new();restored.start(1,s.export_progress(),{"developer":dev.config()})
	check(restored.developer.enabled and restored.damage()==123 and restored.rank("railgun"),"config and unrestricted skills restore")
	var ui:=Interface.new();ui.size=Vector2(412,915);root.add_child(ui);ui.set_catalog(s.content.catalog)
	ui.action.connect(func(method:String,input:Dictionary):
		if method=="pause":s.paused=input.paused
		elif method=="developer":dev.apply(s,input)
		ui.present(s.snapshot())
	)
	ui.present(s.snapshot());ui._settings()
	check(ui.modal_content.find_child("OpenDeveloper",true,false)!=null,"unlocked settings button")
	ui._developer()
	await process_frame
	check(ui.modal_content.find_child("DeveloperValue_damage",true,false)!=null,"numeric fields built")
	check(ui.modal_content.find_child("DeveloperSkill3",true,false)!=null,"all skill slots built")
	var field:SpinBox=ui.modal_content.find_child("DeveloperValue_damage",true,false)
	field.value=321
	var apply:Button=field.get_parent().get_child(1);apply.pressed.emit()
	await process_frame
	check(is_equal_approx(s.damage(),321),"UI apply callback works: %s" % s.damage())
	var boss_select:OptionButton=ui.modal_content.find_child("DeveloperBoss",true,false)
	check(boss_select!=null and boss_select.item_count==4,"all four bosses available in UI")
	boss_select.select(2)
	var chosen_boss:String=boss_select.get_item_metadata(boss_select.selected)
	var start_boss:Button=ui.modal_content.find_child("DeveloperStartBoss",true,false)
	start_boss.pressed.emit()
	await process_frame
	check(s.bosses.boss_id==chosen_boss and ui.modal_kind=="" and not s.paused,"UI starts selected boss and closes paused panels")
	for mode in ["light","dark"]:
		s.theme_mode=mode;s.resolve_theme();ui.present(s.snapshot());ui._developer()
		await create_timer(.8).timeout
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var path:=ProjectSettings.globalize_path("res://../agent-tmp/godot/preview/developer-"+mode+".png")
			DirAccess.make_dir_recursive_absolute(path.get_base_dir());root.get_texture().get_image().save_png(path)
	ui._close_all()
	check(not s.paused,"modal restores pause")
	dev.apply(s,{"operation":"reset"})
	check(not dev.enabled and dev.overrides.is_empty() and dev.counts.is_empty() and dev.unlocked,"reset keeps unlock only")
	check(s.damage()!=321,"default formula restored")
	s.state.skillChosenLevel=0;s.state.board=null;s.generate();ui.present(s.snapshot())
	check(ui.modal_kind=="draft","draft displayed")
	ui._settings();ui._developer()
	dev.enabled=true;dev.apply(s,{"operation":"skills","ids":["titan"]});ui.present(s.snapshot())
	ui._close();ui._close()
	check(ui.modal_kind=="" and not s.paused,"rebuild does not resurrect obsolete draft")
	ui.free();s.dispose();restored.dispose()
	print("Godot developer checks: %d failure(s)" % failures)
	quit(1 if failures else 0)
