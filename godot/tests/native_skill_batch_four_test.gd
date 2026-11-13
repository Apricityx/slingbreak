extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
const Renderer=preload("res://src/render/skill_batch_four.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func fresh(id:String,reduced:bool=false) -> RefCounted:
	var g:=Sim.new();g.start(9128);g.bricks.clear();g.obstacles.clear();g.fx.reset();g.skills.reset()
	g.state.skills={id:1};g.state.skillChosenLevel=g.state.level;g.state.performanceMode=reduced;g.phase="flying";g.initial=1000
	return g

func count(g:RefCounted,id:String) -> int:
	return g.fx.skill_events.filter(func(e):return e.id==id).size()

func _initialize() -> void:
	for reduced in [false,true]:
		var g:=fresh("treasury",reduced)
		g.core={"x":390.0,"y":80.0,"born":-2.0}
		var expected:float=g.bonus();var coins:float=g.state.coins
		var arrow:RefCounted=g.launch(Vector2(390,125),Vector2.UP*24)
		g.advance_arrow(arrow,1.0/60)
		check(g.phase=="clearing" and count(g,"treasury")==1,"treasury emits at actual core contact")
		check(g.settled_bonus==expected and g.state.coins==coins+expected and expected==720,"treasury preserves triple payout")
		check(g.core==null and g.fx.skill_events[0].position==Vector2(390,80),"payout snapshot survives destroyed core")
		g.clear();check(count(g,"treasury")==1,"clear guard prevents duplicate payout FX")
		g.dispose()
		g=fresh("bargain",reduced);g.phase="ready";g.state.coins=0
		check(not g.buy("power") and g.fx.skill_events.is_empty(),"unaffordable bargain emits nothing")
		g.state.coins=1000
		check(g.buy("power") and count(g,"bargain")==1,"successful bargain emits forging seam")
		check(g.state.coins==940 and g.state.up.power==1,"bargain keeps 80 percent price and one upgrade")
		g.paused=true;check(not g.buy("power") and count(g,"bargain")==1,"paused purchase emits nothing")
		g.dispose()
		g=fresh("resonance",reduced);g.initial=20;g.killed=8
		var brick:RefCounted=g.make_brick({"x":390,"y":400,"hp":1,"max":1})
		g.hit(brick,10)
		check(g.threshold==9 and g.core!=null and count(g,"resonance")==1,"resonance fires on actual reduced kill threshold")
		g.spawn_core();check(count(g,"resonance")==1,"already present core does not repeat resonance")
		g.core=null;g.fx.reset();g.spawn_core(true)
		check(g.fx.skill_events.is_empty(),"quiet save restoration has no resonance burst")
		g.dispose()
		g=fresh("corehunter",reduced);g.core={"x":390.0,"y":80.0,"born":-2.0}
		arrow=g.launch(Vector2(290,250),Vector2.UP*24)
		var pierce:int=arrow.pierce;var rng_state:int=g.rng.state
		g.skills.guide_prediction(arrow,1.0/60)
		check(g.fx.skill_events.is_empty() and arrow.pierce==pierce,"prediction never emits attraction or awards pierce")
		arrow.velocity=Vector2.UP*24;g.guide(arrow,1.0/60)
		check(count(g,"corehunter")==1 and arrow.pierce==pierce+4,"live core correction emits and preserves one-time pierce boost")
		check(g.fx.skill_events[0].target==Vector2(390,80) and arrow.velocity.x>0,"attraction stores true core endpoint and preserves turn")
		g.guide(arrow,1.0/60)
		check(count(g,"corehunter")==1 and arrow.pierce==pierce+4,"per-arrow visual cooldown suppresses repeated frame events")
		g.fx.advance_visual(0.19);g.guide(arrow,1.0/60)
		check(count(g,"corehunter")==2 and g.rng.state==rng_state,"continued live guidance retriggers on visual time without gameplay RNG")
		g.fx.reset();arrow.position=Vector2(390,900);g.guide(arrow,1.0/60)
		check(g.fx.skill_events.is_empty(),"outside attraction reach produces no fake guidance")
		arrow.position=Vector2(390,250);arrow.velocity=Vector2.UP*24;g.guide(arrow,1.0/60)
		check(g.fx.skill_events.is_empty(),"already aligned arrows do not flash")
		g.dispose()
	for id in ["treasury","bargain","resonance","corehunter"]:
		var g:=fresh(id);var rng_state:int=g.rng.state
		for i in range(100):g.fx.skill_event(id,Vector2(i,400),Vector2.UP,Vector2(390,80),1,0.72)
		check(g.fx.skill_events.size()==64 and g.fx.skill_events[0].position.x==36,"bounded oldest-first queue: "+id)
		check(g.rng.state==rng_state,"isolated visual RNG: "+id)
		g.time+=10;check(g.fx.skill_events.size()==64,"gameplay clock does not expire visual snapshots: "+id)
		g.fx.advance_visual(0.8);check(g.fx.skill_events.is_empty(),"visual expiry: "+id)
		g.fx.skill_event(id,Vector2.ZERO);g.fx.reset();check(g.fx.skill_events.is_empty() and g.fx.visual_time==0,"reset: "+id)
		g.dispose()
	var g:=fresh("");g.state.skills={};g.phase="ready";g.state.coins=1000;g.buy("power");g.spawn_core();g.clear()
	check(g.fx.skill_events.is_empty(),"unowned economy/core skills produce no specialized FX")
	g.dispose()
	if DisplayServer.get_name()!="headless":call_deferred("shop_foreground")
	else:finish()

func finish() -> void:
	print("Native skill batch four: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func shop_foreground() -> void:
	var app:Node=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);root.add_child(app)
	app.audio.shutdown();app.interface._close_all()
	var g:RefCounted=app.session.runtime
	g.state.skills={"bargain":1};g.state.draft=null;g.state.skillChosenLevel=g.state.level;g.phase="ready";g.state.coins=10000000
	app.session.command("snapshot");app.interface._shop()
	await create_timer(0.6).timeout
	# The shop is a tree now: a node stops selling at its own cap and later
	# nodes need full prerequisites, so purchases must walk the real order.
	var tree:Script=preload("res://src/core/upgrade_tree.gd")
	var page:Control=app.interface.modal_content.find_child("UpgradeTree",true,false)
	check(page!=null,"shop opens the upgrade tree page")
	var buys:=0
	for scan in range(8):
		for node in tree.NODES:
			if buys>=10:break
			var before:int=g.state.coins
			# Select the node first: the shared buy button is named for the
			# current selection, as it is for a real tap.
			page._select(node.id,false)
			app._action("buy",{"key":node.key,"node":node.id})
			if g.state.coins<before:buys+=1
		if buys>=10:break
	check(buys==10,"ten rapid tree purchases succeed through real prerequisites")
	var overlays:Array=app.interface.motion_layer.get_children().filter(func(node):return node.has_meta("bargain_feedback"))
	check(overlays.size()==8,"shop foreground nodes are capped at eight under rapid purchases")
	check(overlays.back().event.id=="bargain" and overlays.back().event.born==g.fx.skill_events.back().born,"shop foreground reuses successful purchase visual timestamp")
	g.fx.advance_visual(0.12)
	await process_frame;await RenderingServer.frame_post_draw
	var out:="res://../agent-tmp/godot/skill-batch-four/"
	DirAccess.make_dir_recursive_absolute(out)
	root.get_texture().get_image().save_png(out+"bargain-shop-peak.png")
	g.fx.advance_visual(0.6)
	await process_frame;await process_frame
	check(app.interface.motion_layer.get_children().filter(func(node):return node.has_meta("bargain_feedback")).is_empty(),"shop foreground expires on the shared visual clock")
	for node in tree.NODES:
		var before:int=g.state.coins
		app._action("buy",{"key":node.key,"node":node.id})
		if g.state.coins<before:break
	g.fx.reset()
	await process_frame;await process_frame
	check(app.interface.motion_layer.get_children().filter(func(node):return node.has_meta("bargain_feedback")).is_empty(),"shop foreground drops stale snapshots on reset")
	app.queue_free();await process_frame
	finish()
