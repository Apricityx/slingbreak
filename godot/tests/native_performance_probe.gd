extends SceneTree
## Reproducible CPU samples, not a device FPS acceptance gate. Run separately
## from other checks/builds, with a graphics driver and --disable-vsync. Samples
## cover board _process/_draw and retained brick/wall submission; the separate
## guide/Boss-background and halo _draw callbacks are not instrumented.
const Main=preload("res://src/main.gd")
const Motion=preload("res://src/ui/motion.gd")

class ProfileBoard extends "res://src/render/board.gd":
	var draw_us:=0
	var process_us:=0
	var retained_us:=0
	var in_board_draw:=false
	func _process(delta:float) -> void:
		var start:=Time.get_ticks_usec();super._process(delta);process_us=Time.get_ticks_usec()-start
	func _draw() -> void:
		var start:=Time.get_ticks_usec();in_board_draw=true;super._draw();in_board_draw=false;draw_us+=Time.get_ticks_usec()-start
	func _brick(brick:RefCounted) -> void:
		var start:=Time.get_ticks_usec();super._brick(brick)
		if not in_board_draw:retained_us+=Time.get_ticks_usec()-start
	func _wall(wall:RefCounted) -> void:
		var start:=Time.get_ticks_usec();super._wall(wall)
		if not in_board_draw:retained_us+=Time.get_ticks_usec()-start
	func reset_times() -> void:draw_us=0;retained_us=0;process_us=0

var app:Node
var report:Dictionary={}
var simulation_us:=0

func _initialize() -> void:call_deferred("run")
func stats(values:PackedFloat64Array) -> Dictionary:
	values.sort()
	return {"count":values.size(),"p50":values[int(values.size()*.5)],"p95":values[int(values.size()*.95)],"max":values[values.size()-1]}

func sample_copy(label:String,node:Control,count:int=30) -> void:
	var values:=PackedFloat64Array()
	for i in range(count):
		var start:=Time.get_ticks_usec();var face:=Motion.copy(node);face.free();values.append(float(Time.get_ticks_usec()-start)/1000.0)
	report[label]=stats(values)

func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Performance probe requires a graphics driver");quit(1);return
	app=Main.new();app.set_meta("test_mode",true);root.add_child(app);app.audio.shutdown()
	await create_timer(1.6).timeout
	sample_copy("copy_draft",app.interface.panel)
	var cards:Array=Motion.cards(app.interface.modal_content.find_child("DraftOptions",true,false))
	for i in range(cards.size()):sample_copy("copy_card_"+str(i),cards[i])
	app.interface._close_all()
	var old:Node=app.arena.board;app.arena.remove_child(old);old.free()
	var board:=ProfileBoard.new();app.arena.board=board;board.position=app.arena.VIEW_OFFSET;board.scale=Vector2.ONE*app.arena.VIEW_SCALE;board.oversampling_with_scale=CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	board.simulation=app.session.runtime;app.arena.add_child(board)
	for busy in [false,true]:
		var g=app.session.runtime
		g.rng.seed=9128;g.visual_rng.seed=9128^0x4f7314;g.state.level=50;g.state.skillChosenLevel=50;g.state.draft=null;g.state.bossOverride=null;g.state.board=null
		g.state.skills={"prism":1,"lightning":1,"supernova":1,"timeslip":1} if busy else {}
		g.state.up.slots=3;g.generate();g.phase="ready";g.board_entrance=null;g.paused=false
		# Keep the workload in flight/impact instead of drifting into a draft
		# after it clears the board. Targets retain enough HP for all samples.
		if busy:
			for brick in g.bricks:brick.hp=1000;brick.max_hp=1000
			g.threshold=100000
		app.session.command("snapshot")
		var costs:=PackedFloat64Array();var draws:=PackedFloat64Array();var syncs:=PackedFloat64Array();var logic:=PackedFloat64Array();var intervals:=PackedFloat64Array()
		var peak_arrows:=0;var peak_particles:=0;var peak_signatures:=0
		for i in range(300):
			board.reset_times()
			if busy:
				if i%35==0 and g.phase in ["ready","flying"]:app.session.command("shoot",{"dx":sin(i*.13)*75,"dy":100})
				var start:=Time.get_ticks_usec();app.session.update(1.0/60);simulation_us=Time.get_ticks_usec()-start
			else:simulation_us=0
			peak_arrows=maxi(peak_arrows,g.arrows.size());peak_particles=maxi(peak_particles,g.fx.particles.size());peak_signatures=maxi(peak_signatures,g.fx.signatures.size())
			var start:=Time.get_ticks_usec()
			await process_frame
			if i>=30:
				var draw_time:=float(board.draw_us+board.retained_us)/1000.0
				var process_time:=float(board.process_us)/1000.0
				draws.append(draw_time);syncs.append(process_time);costs.append(draw_time+process_time);logic.append(float(simulation_us)/1000.0);intervals.append(float(Time.get_ticks_usec()-start)/1000.0)
		report["busy" if busy else "ordinary"]={"board_cpu_ms":stats(costs),"draw_cpu_ms":stats(draws),"process_cpu_ms":stats(syncs),"simulation_cpu_ms":stats(logic),"frame_interval_ms":stats(intervals),"peakArrows":peak_arrows,"peakParticles":peak_particles,"peakSignatures":peak_signatures}
	report["environment"]={"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"includes":"CPU board updates, dynamic/brick/wall vector submission and fixed-step simulation; excludes separate background/halo draw callbacks, audio and device GPU; host frame intervals include driver/scheduler"}
	app.queue_free();await process_frame
	print("Native performance: "+JSON.stringify(report));quit()
