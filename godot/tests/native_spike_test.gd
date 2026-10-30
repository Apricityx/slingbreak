extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
const Session=preload("res://src/core/session.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var g:=Sim.new();g.start(9128)
	var odds:=g.draft_chances().duplicate(true);var key:=g.chance_key
	check(odds.size()==81 and not odds.is_empty(),"draft retains full inclusion probabilities")
	var chosen:String=g.state.draft.options[0];g.choose(chosen)
	check(g.snapshot().chances.is_empty() and g.chance_key==key,"flight snapshots skip cold draft probability calculation")
	g.state.swapOffer={"options":["titan","rapid","pulse"],"target":chosen,"level":g.state.level}
	check(g.snapshot().chances.size()==81 and g.chance_key!=key,"replacement offer computes new odds for the equipped queue")
	g.state.swapOffer=null;g.fx.reset()
	var reference:Array=[];var rng:=RandomNumberGenerator.new();rng.state=g.visual_rng.state
	for i in range(50):
		for index in range(9):
			var angle:=rng.randf()*TAU;var velocity:=Vector2.from_angle(angle)*(1+rng.randf()*5)
			var life:=rng.randf_range(.5,.9);var rotation:=rng.randf()*TAU;var size_value:=rng.randf_range(2,7)
			reference.append({"origin":Vector2(i,0),"velocity":velocity*60-Vector2(0,60),"max":life,"initial_rotation":rotation,"size":size_value})
		g.fx.burst(Vector2(i,0),Color.GREEN,16)
	reference=reference.slice(reference.size()-300);g.fx.advance_visual(0)
	check(g.fx.particles.size()==300 and g.visual_rng.state==rng.state,"mass bursts retain particle cap and exact visual RNG sequence")
	var same:=true
	for i in range(300):
		for field in reference[i]:same=same and g.fx.particles[i][field]==reference[i][field]
	check(same,"ring reuse preserves newest particles and oldest-first draw order")
	g.fx.advance_visual(1);check(g.fx.particles.is_empty(),"reused particles expire normally")
	g.fx.arrow_break(Vector2.ZERO,Vector2.RIGHT,Color.WHITE,Color.GREEN)
	check(g.fx.particles.size()==10 and g.fx.particles[0].has("polygon") and g.fx.particles[0].position.distance_to(g.fx.particles[6].position)>20,"arrow destruction reconstructs shaft, arrowhead and fletching as shards")
	g.fx.advance_visual(1);check(g.fx.particles.is_empty(),"arrow shard particles expire normally")
	g.dispose()
	var session:=Session.new();session.save_path="user://spike-test-progress.json";session.start(9128)
	for i in range(8):session.runtime.state.coins=i;session.request_save()
	session.finish_save()
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(session.save_path))
	check(saved.state.coins==7 and session.save_thread==null and session.queued_save=="","async save coalesces to latest payload and joins at lifecycle boundary")
	check(not FileAccess.file_exists(session.save_path+".pending"),"async save preserves atomic pending-file rename")
	session.runtime.state.coins=13;session.request_save()
	check(session.load_progress().state.coins==13,"reload joins the pending writer before reading the save")
	var replacement:Dictionary=session.runtime.export_progress();replacement.state.coins=99
	session.runtime.state.coins=17;session.request_save()
	check(session.import_progress(replacement) and session.load_progress().state.coins==99,"import drains old save jobs before replacing progress")
	session.runtime.state.coins=23;session.request_save()
	check(session.save() and session.load_progress().state.coins==23,"pause/exit synchronous save waits for queued work")
	DirAccess.remove_absolute(session.save_path);session.runtime.dispose()
	print("Native spike regression: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
