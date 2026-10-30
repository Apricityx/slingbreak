extends SceneTree
## Frequent skill GPU batches: bounded/shared geometry, unchanged live event data,
## graphics visibility, endpoints, lifecycle, and reset without stale instances.
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
const Batch=preload("res://src/render/skill_batch.gd")
const Warmup=preload("res://src/render/effect_warmup.gd")
const Geometry=preload("res://src/render/effect_mesh.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func run() -> void:
	var g:=Sim.new();g.start(9128);g.state.draft=null;g.state.skills={};g.phase="ready"
	g.bricks.clear();g.obstacles.clear();g.core=null;g.board_entrance=null;g.fx.reset()
	var board:=Board.new();board.simulation=g;root.add_child(board);board.set_process(false)
	root.size=Vector2i(412,915);board.scale=Vector2.ONE*.52
	var rng_state:int=g.rng.state
	for id in Batch.IDS:
		var batch:MultiMeshInstance2D=board.skill_batches[id]
		for reduced in [false,true]:
			g.fx.reset();g.state.performanceMode=reduced
			for i in range(100):g.fx.skill_event(id,Vector2(390,440),Vector2.RIGHT,Vector2(480,440),1.0,0.5)
			var events:Array=g.fx.skill_events.duplicate(true)
			g.fx.advance_visual(0.08);board._process(0)
			check(batch.multimesh.instance_count==64 and batch.multimesh.visible_instance_count==64,"full bounded batch "+id+str(reduced))
			check(g.fx.skill_events==events,"renderer does not mutate event snapshots "+id)
			check(batch.multimesh.mesh.surface_get_array_len(0)<=128,"bounded carrier vertices "+id)
			check(batch.multimesh.mesh==Batch.template(id,reduced),"shared immutable mesh "+id)
			var mesh:Mesh=batch.multimesh.mesh
			g.fx.advance_visual(0.05);board._process(0)
			check(batch.multimesh.mesh==mesh,"no per-frame mesh construction "+id)
			g.phase="draft";board._process(0)
			check(not batch.visible,"draft hides batch "+id)
			g.phase="ready";board._process(0)
			check(batch.visible,"resume restores batch "+id)
			if DisplayServer.get_name()!="headless":
				var transform:=batch.multimesh.get_instance_transform_2d(0)
				check(transform.origin==Vector2(390,440) and transform.x.is_equal_approx(Vector2.RIGHT),"real instance endpoints "+id)
			g.fx.reset();board._process(0)
			check(batch.multimesh.visible_instance_count==0,"reset clears GPU instances "+id)
			g.fx.skill_event(id,Vector2(390,440),Vector2.RIGHT,Vector2(480,440))
			g.fx.advance_visual(1);board._process(0)
			check(batch.multimesh.visible_instance_count==0,"expiry clears GPU instances "+id)
		check(batch.get_index()<board.foreground.get_index(),"arrows/text cover skill batch "+id)
	check(g.rng.state==rng_state,"rendering consumes no gameplay RNG")
	g.fx.reset();g.fx.skill_event("echo",Vector2(390,440),Vector2.UP)
	board._process(0)
	var echo:MultiMeshInstance2D=board.skill_batches.echo
	if DisplayServer.get_name()!="headless":
		var phase:float=echo.multimesh.get_instance_custom_data(0).g
		var expected:float=fposmod(Vector2.UP.angle()-g.fx.skill_events[0].seed*.12,TAU)
		check(absf(phase-expected)<.005,"echo world-space arc direction independent of arrow rotation")
	for seed in [1.618,159.125,4095.618,100001.618]:
		var data:=Geometry.noise_data(.1,seed,1)
		check(absf(data.g+data.a-fposmod(seed,4096))<.001,"nonperiodic fire noise seed preserved and bounded")
	g.state.performanceMode=false
	for theme in ["light","dark"]:
		g.theme=theme
		for id in Batch.IDS:
			g.fx.reset();board._process(0);await frame()
			if DisplayServer.get_name()=="headless":continue
			var before:=root.get_texture().get_image()
			g.fx.skill_event(id,Vector2(390,440),Vector2.RIGHT,Vector2(480,440),1,0.5)
			g.fx.advance_visual(0.08);board._process(0);await frame()
			var after:=root.get_texture().get_image();var changed:=0
			for y in range(175,280):
				for x in range(140,280):
					if after.get_pixel(x,y)!=before.get_pixel(x,y):changed+=1
			check(changed>20,"actual visible pixels "+id+theme)
	g.fx.reset();g.fx.explosion(Vector2(390,440),232);board._process(0)
	var fire:=board.explosions.volumes
	check(fire.multimesh.instance_count==16 and fire.multimesh.visible_instance_count==1,"fire capacity fixed before first impact")
	check(fire.multimesh.mesh.surface_get_array_len(0)==13,"fire shares compact immutable mesh")
	g.fx.reset();board._process(0)
	check(fire.multimesh.visible_instance_count==0,"fire reset removes volume")
	var child_count:=root.get_child_count()
	var snapshot:Array=g.fx.skill_events.duplicate(true)
	var report:=await Warmup.prepare(root)
	check(g.rng.state==rng_state and g.fx.skill_events==snapshot,"warmup never touches live RNG or events")
	check(root.get_child_count()==child_count,"warmup viewport released after use")
	check(report.has("skipped") if DisplayServer.get_name()=="headless" else report.frames==16,"bounded real-render warmup, skipped headlessly")
	check((await Warmup.prepare(root)).has("skipped"),"warmup runs at most once per graphics process")
	board.queue_free();await process_frame;g.dispose()
	print("Native skill batches: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
