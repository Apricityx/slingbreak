extends SceneTree
## Per-frame continuous-load attribution with fixed populations, actual graphics,
## cold/warm passes and renderer-only ablations. Not a device FPS benchmark.
const Sim=preload("res://src/core/simulation.gd")
const Fixture=preload("res://tests/effects_stress_fixture.gd")
const FLAT="shader_type canvas_item; render_mode unshaded; void fragment(){COLOR=vec4(1.0,0.5,0.1,0.4);}"

class Fire extends "res://src/render/explosions.gd":
	var present_ms:=0.0
	func present(g:RefCounted) -> void:
		var at:=Time.get_ticks_usec();super.present(g)
		present_ms=(Time.get_ticks_usec()-at)/1000.0

class Ice extends "res://src/render/frost.gd":
	var present_ms:=0.0
	func present(g:RefCounted) -> void:
		var at:=Time.get_ticks_usec();super.present(g)
		present_ms=(Time.get_ticks_usec()-at)/1000.0

class TailBoard extends "res://src/render/board.gd":
	var process_ms:=0.0
	var draw_ms:=0.0
	var foreground_ms:=0.0
	var skills_ms:=0.0
	var retained_ms:=0.0
	var mode:="full"
	var flat:Shader
	func _process(delta:float) -> void:
		var at:=Time.get_ticks_usec();super._process(delta)
		masonry.visible=mode!="no_masonry"
		explosions.visible=mode!="no_fire"
		frost.visible=mode!="no_ice"
		for id in skill_batches:
			skill_batches[id].visible=not ((mode=="no_storm" and id=="storm") or (mode=="no_skills" and id!="storm"))
		get_parent().position=Vector2(0,5000) if mode=="offscreen" else Vector2(0,238)
		explosions.volumes.visible=mode!="no_volumes"
		var shader:Shader=flat if mode=="flat_fire" else explosions.SHADER
		if explosions.volumes.material.shader!=shader:explosions.volumes.material.shader=shader
		process_ms=(Time.get_ticks_usec()-at)/1000.0
	func _sync_retained() -> void:
		var at:=Time.get_ticks_usec();super._sync_retained()
		retained_ms=(Time.get_ticks_usec()-at)/1000.0
	func _draw() -> void:
		var at:=Time.get_ticks_usec();super._draw()
		draw_ms=(Time.get_ticks_usec()-at)/1000.0
	func _draw_foreground() -> void:
		var at:=Time.get_ticks_usec();super._draw_foreground()
		foreground_ms=(Time.get_ticks_usec()-at)/1000.0
	func _draw_skill_events(g:RefCounted) -> void:
		var at:=Time.get_ticks_usec()
		var events:Array=g.fx.skill_events
		if mode in ["no_skills","no_storm"]:
			g.fx.skill_events=events.filter(func(e):return (e.id=="storm") if mode=="no_skills" else (e.id!="storm"))
		super._draw_skill_events(g)
		g.fx.skill_events=events
		skills_ms=(Time.get_ticks_usec()-at)/1000.0

var g:RefCounted
var board:TailBoard
var frames:=240
var passes:=2
var resolution:=1.0
var selection:="full,no_storm,no_skills,no_fire,no_volumes,flat_fire,no_ice,no_masonry,offscreen"
var output:="res://../agent-tmp/godot/fx-tail/attribution.json"
var rows:Array=[]
var warmup_report:Dictionary={}
var prewarm:=false

func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func stats(values:Array) -> Dictionary:
	values=values.duplicate();values.sort()
	return {"p50":values[int(values.size()*.5)],"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)],"max":values.back()}

func measure(mode:String,pass_index:int) -> Dictionary:
	g.fx.reset();board.mode=mode
	await frame()
	var samples:Array=[]
	for i in range(frames):
		var at:=Time.get_ticks_usec()
		Fixture.step(g,i)
		var trigger_ms:=(Time.get_ticks_usec()-at)/1000.0
		await frame()
		var wall_ms:=(Time.get_ticks_usec()-at)/1000.0
		var row:={"frame":i,"wall_ms":wall_ms,"trigger_ms":trigger_ms,"process_ms":board.process_ms,
			"draw_ms":board.draw_ms+board.foreground_ms,"skills_ms":board.skills_ms,"retained_ms":board.retained_ms,
			"fire_ms":board.explosions.present_ms,"ice_ms":board.frost.present_ms,
			"calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"render_setup_ms":RenderingServer.get_frame_setup_time_cpu(),
			"skills":g.fx.skill_events.size(),"specials":g.fx.specials.size(),"explosions":g.fx.explosions.size(),
			"fire_pool":16,"ice_pool":board.frost.pool.size()}
		samples.append(row)
	var result:={"mode":mode,"pass":pass_index,"samples":samples,"stats":{}}
	for key in ["wall_ms","trigger_ms","process_ms","draw_ms","skills_ms","retained_ms","fire_ms","ice_ms","calls","render_setup_ms"]:
		result.stats[key]=stats(samples.map(func(r):return r[key]))
	print("Tail case: "+mode+" pass="+str(pass_index)+" "+JSON.stringify(result.stats))
	return result

func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Tail probe requires graphics");quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):frames=maxi(60,int(arg.get_slice("=",1)))
		elif arg.begins_with("--passes="):passes=maxi(1,int(arg.get_slice("=",1)))
		elif arg.begins_with("--case="):selection=arg.get_slice("=",1)
		elif arg.begins_with("--resolution="):resolution=clampf(float(arg.get_slice("=",1)),0.25,2.0)
		elif arg.begins_with("--output="):output=arg.get_slice("=",1)
		elif arg=="--prewarm":prewarm=true
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(Vector2(412,915)*resolution)
	root.content_scale_size=Vector2i(412,915);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if prewarm:warmup_report=await preload("res://src/render/effect_warmup.gd").prepare(root)
	g=Sim.new();g.start(9128);g.state.draft=null;g.state.skills={};g.state.performanceMode=false
	g.phase="ready";g.board_entrance=null;g.bricks.clear();g.obstacles.clear();g.core=null
	for row in range(10):
		for col in range(6):g.make_brick({"x":150+col*96,"y":170+row*60,"hp":1000,"max":1000})
	board=TailBoard.new();board.simulation=g;board.scale=Vector2.ONE*.52
	board.explosions.free();board.explosions=Fire.new();board.frost.free();board.frost=Ice.new()
	board.flat=Shader.new();board.flat.code=FLAT
	var arena:=Node2D.new();arena.position=Vector2(0,238);root.add_child(arena);arena.add_child(board)
	await frame()
	var report:={"warmup":warmup_report,"version":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"viewport":root.size,
		"frames":frames,"passes":passes,"scope":"Same visible trigger schedule, visual time 1/60 per frame; post-draw wall includes driver and scheduling, not explicit GPU completion. Pass 0 cold pools, pass 1+ warm pools.","sources":{},"cases":rows}
	report.sources=preload("res://tests/effects_source_manifest.gd").hashes()
	report.sources["res://tests/native_effects_tail_probe.gd"]=FileAccess.get_sha256("res://tests/native_effects_tail_probe.gd")
	for pass_index in range(passes):
		for mode in selection.split(","):
			rows.append(await measure(mode,pass_index))
			var file:=FileAccess.open(output,FileAccess.WRITE)
			if file==null:push_error("Cannot write "+output);quit(1);return
			file.store_string(JSON.stringify(report,"  "));file.close()
	arena.queue_free();await process_frame;g.dispose();print("Tail report: "+output);quit()
