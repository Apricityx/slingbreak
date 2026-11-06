extends SceneTree
## Draw actual CanvasItems for every skill, Boss phase and selectable ability.
## Forced visual fixtures establish render coverage, not rule/visual parity.
const Sim=preload("res://src/core/simulation.gd")
var app:Node
var scenes:=0
var failures:=0
var out:="res://../agent-tmp/godot/render-native/"

func _initialize() -> void:call_deferred("_run")

func fresh(theme:String,ids:Array=[]) -> RefCounted:
	var sim:=Sim.new();sim.start(9128)
	sim.theme=theme;sim.theme_mode=theme;sim.state.level=100;sim.state.skillChosenLevel=100
	sim.state.bossOverride=null;sim.state.skills={};sim.state.up.slots=3
	for id in ids:sim.state.skills[id]=1
	sim.state.level=50;sim.state.skillChosenLevel=50;sim.generate();sim.phase="ready"
	return sim

func show(sim:RefCounted,name:String,save:bool=true) -> void:
	if app.session.runtime!=sim:app.session.runtime.dispose()
	app.arena.simulation=sim;app.session.runtime=sim;app.session.command("snapshot")
	for i in range(2):await process_frame
	await RenderingServer.frame_post_draw
	if save:root.get_texture().get_image().save_png(out+name+".png")
	scenes+=1

func _run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Render coverage needs an actual graphics driver");quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	app=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);root.add_child(app)
	app.audio.shutdown();app.interface._close_all()
	for theme in ["light","dark"]:
		var sim:=fresh(theme)
		await show(sim,"board-"+theme)
		sim.drag={"dx":25,"dy":95};sim.spawn_core(true)
		await show(sim,"aim-core-"+theme)
		var full_glow:=root.get_texture().get_image()
		# Isolate the halo rather than changing performance mode, which also
		# changes aim/aura rendering and could mask a missing shader output.
		app.arena.board.core_glow.visible=false
		app.arena.board.set_process(false)
		await show(sim,"core-without-halo-"+theme,false)
		var reduced_glow:=root.get_texture().get_image()
		# Sample below the diamond, away from its solid face: a non-empty halo
		# proves the shader has usable UVs and fades into the battlefield.
		var difference:=0.0
		for x in range(202,210):
			for y in range(299,303):
				var a:=full_glow.get_pixel(x,y);var b:=reduced_glow.get_pixel(x,y)
				difference+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
		if difference<.2:
			failures+=1;push_error("Core halo did not render in "+theme)
		app.arena.board.set_process(true)
		for item in sim.content.catalog:
			sim=fresh(theme,[item.id]);sim.state.skillRuntime.shots=2;sim.shoot(12,100)
			var arrow:RefCounted=sim.arrows[0]
			sim.active_arrow=arrow;sim.skills.projectile_hit(sim.bricks[0],arrow);sim.active_arrow=null
			for step in range(24):sim.update(1.0/60)
			# Ensure every signature/trail is drawn even for passive/conditional skills.
			sim.fx.signature(item.id,Vector2(390,480),125)
			for phase in [0.0,.35,.7]:
				for effect in sim.fx.signatures:effect.born=sim.time-phase*effect.duration
				await show(sim,"skill-"+item.id+"-"+theme+"-"+str(phase),phase==.35)
		for id in ["eye","forge","serpent","clock"]:
			sim=fresh(theme);sim.state.bossOverride={"level":50,"boss":id};sim.generate();sim.phase="ready"
			for step in range(180):sim.update(1.0/60)
			for phase in range(1,int(sim.bosses.fight.phases)+1):
				var boss:RefCounted=sim.bosses.model
				sim.bosses.fight.phase=phase;sim.bricks.clear();sim.obstacles.clear();sim.layout();boss.setup(false)
				await show(sim,"boss-"+id+"-"+str(phase)+"-"+theme)
				for ability in sim.bosses.fight.abilities[phase-1]:
					boss.begin(ability)
					for step in range(20 if id!="forge" else 90):sim.update(1.0/60)
					await show(sim,"ability-"+id+"-"+str(phase)+"-"+ability+"-"+theme)
					boss.calm()
	app.queue_free();await process_frame
	print("Native CanvasItem rendering: %d fixture frames, %d failures" % [scenes,failures]);quit(1 if failures else 0)
