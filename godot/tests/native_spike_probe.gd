extends SceneTree
## Fixed peak-effects/selection workload. Run alone with a graphics driver.
## Supports both the preceding APK staging and current checkout for paired data.
const Main=preload("res://src/main.gd")
const Sim=preload("res://src/core/simulation.gd")
class Board extends "res://src/render/board.gd":
	var cpu:=0
	func _draw() -> void:
		var start:=Time.get_ticks_usec();super._draw();cpu=Time.get_ticks_usec()-start
var app:Node
var report:Dictionary={}
var choose_us:=0
func _initialize() -> void:call_deferred("run")
func stats(values:Array) -> Dictionary:
	values.sort();return {"count":values.size(),"p50":values[int(values.size()*.5)],"p95":values[int(values.size()*.95)],"max":values.back()}
func measure(label:String,callback:Callable,count:int=20) -> void:
	var samples:Array=[]
	for i in range(count):
		var start:=Time.get_ticks_usec();callback.call();samples.append((Time.get_ticks_usec()-start)/1000.0)
	report[label]=stats(samples)
func command(method:String,input:Dictionary) -> void:
	var start:=Time.get_ticks_usec();app._action(method,input)
	if method=="choose":choose_us=Time.get_ticks_usec()-start
func selection() -> void:
	var cpu:Array=[];var intervals:Array=[]
	app.interface.action.disconnect(app._action);app.interface.action.connect(command)
	for trial in range(12):
		app.session.runtime.state.skills={"titan":1,"rapid":1,"ice":1,"pulse":1}
		app.session.runtime.state.up.slots=3
		app.session.runtime.state.level=50;app.session.runtime.state.skillChosenLevel=49;app.session.runtime.state.board=null;app.session.runtime.generate()
		app.session.runtime.state.draft.options=["mint","treasury","supernova"]
		app.session.command("snapshot");await create_timer(1.7).timeout
		choose_us=0;app.interface._select("mint")
		while app.interface.choosing:
			var start:=Time.get_ticks_usec();await process_frame;await RenderingServer.frame_post_draw
			intervals.append((Time.get_ticks_usec()-start)/1000.0)
		cpu.append(choose_us/1000.0)
		await create_timer(.5).timeout
	report["selection"]={"choose_command_cpu_ms":stats(cpu),"host_interval_ms":stats(intervals),"trials":12,"includes":"snapshot, equipped-slot rebuild and choose command; test mode excludes disk save and audio"}
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Spike probe requires a graphics driver");quit(1);return
	app=Main.new();app.set_meta("test_mode",true);root.add_child(app);app.audio.shutdown()
	await create_timer(1.7).timeout
	var g=app.session.runtime
	measure("chances_cold",func():g.chance_key="";g.draft_chances())
	g.state.skills={"pulse":1};g.phase="entering";g.state.draft=null
	measure("choose_snapshot",func():g.chance_key="";g.snapshot())
	await selection()
	app.interface._close_all();app.interface.visible=false
	var old:Node=app.arena.board;app.arena.remove_child(old);old.free()
	var board:=Board.new();board.simulation=g;board.scale=Vector2.ONE*.52;app.arena.board=board;app.arena.add_child(board)
	g.phase="ready";g.board_entrance=null;g.state.skillChosenLevel=g.state.level
	for fixture in ["empty","particles","signatures","combined"]:
		g.fx.reset()
		if fixture in ["particles","combined"]:
			for i in range(90):g.fx.burst(Vector2(90+i%7*96,170+i/7*50),Color("#8a9f6a"),16)
		if fixture in ["signatures","combined"]:
			if board.signatures.has_method("prepare"):
				board.signatures.prepare(["mint","treasury","supernova","pulse"])
				while not board.signatures.pending.is_empty():await process_frame;board.signatures.collect()
			for i in range(80):
				var id:String=["mint","treasury","supernova","pulse"][i%4];g.fx.cooldowns.erase(id)
				g.fx.signature(id,Vector2(95+i%7*96,190+i/7*50),125)
		var draws:Array=[];var intervals:Array=[]
		for i in range(150):
			g.time+=1.0/600;g.presentation_time=g.time
			for effect in g.fx.signatures:effect.born=g.time-.35*effect.duration
			var start:=Time.get_ticks_usec()
			await process_frame;await RenderingServer.frame_post_draw
			if i>=15:draws.append(board.cpu/1000.0);intervals.append((Time.get_ticks_usec()-start)/1000.0)
		report[fixture]={"board_draw_ms":stats(draws),"host_interval_ms":stats(intervals),"particles":g.fx.particles.size(),"signatures":g.fx.signatures.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	measure("shatter_board",func():
		g.state.level=50;g.state.skillChosenLevel=50;g.state.skills={"aftershock":1,"shatter":1,"nailburst":1,"supernova":1};g.generate();g.phase="flying"
		g.skills.global_damage(10000,"supernova")
	)
	report["environment"]={"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"scope":"CPU dynamic board submission and forced chain reaction; no background/retained/halo draw CPU, real audio or phone GPU. Host intervals include desktop driver/scheduler, not phone FPS."}
	app.queue_free();await process_frame;print("Native spike performance: "+JSON.stringify(report));quit()
