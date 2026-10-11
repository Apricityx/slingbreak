extends SceneTree
## Compare the optimized preview to the previous exhaustive collision/target
## queries, then verify that 60/120 Hz input is visible on the next frame.
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
const Arrow=preload("res://src/core/projectile.gd")
const Geometry=preload("res://src/core/geometry.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("_run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func old_sweep(rect:Rect2,start:Vector2,finish:Vector2) -> Dictionary:
	var bounds:=rect.grow(2.5)
	var delta:=finish-start
	var enter:=0.0
	var leave:=1.0
	var normal:=Vector2.ZERO
	for axis in range(2):
		if absf(delta[axis])<0.00000001:
			if start[axis]<bounds.position[axis] or start[axis]>bounds.end[axis]:return {}
			continue
		var first:float=(bounds.position[axis]-start[axis])/delta[axis]
		var last:float=(bounds.end[axis]-start[axis])/delta[axis]
		var near:=minf(first,last)
		if near>enter:enter=near;normal=Vector2.ZERO;normal[axis]=-1 if delta[axis]>0 else 1
		leave=minf(leave,maxf(first,last))
		if enter>leave:return {}
	if leave<0 or enter>1:return {}
	return {"t":enter,"normal":normal}

func old_guide(sim:RefCounted,arrow:RefCounted) -> void:
	if not sim.rank("seeking") and not sim.rank("corehunter"):return
	var target=null
	if sim.core!=null and arrow.position.distance_to(Vector2(sim.core.x,sim.core.y))<(320 if sim.rank("corehunter") else 250):
		target=Vector2(sim.core.x,sim.core.y)
	elif sim.rank("seeking"):
		var selected=sim.nearest(arrow.position,1,func(b):return not arrow.hit.has(b.id) and (b.position-arrow.position).dot(arrow.velocity)>0 and b.position.distance_to(arrow.position)<250)
		if not selected.is_empty():target=selected[0].position
	if target!=null:arrow.velocity=arrow.velocity.rotated(clampf(arrow.velocity.angle_to(target-arrow.position),-4.0/60,4.0/60))

func old_predict(sim:RefCounted,velocity:Vector2) -> PackedVector2Array:
	var arrow:=Arrow.new();arrow.position=sim.origin;arrow.velocity=velocity
	var path:=PackedVector2Array([sim.origin])
	var traveled:=0.0
	for step in range(270):
		var from:Vector2=arrow.position;arrow.previous=from
		old_guide(sim,arrow);sim.bosses.contact(arrow,false);sim.integrate(arrow,1.0/60)
		if not sim.rank("spectral"):
			var contacts:Array=[]
			for wall in sim.obstacles:
				var contact:=old_sweep(wall.bounds,from,arrow.position)
				if not contact.is_empty():contacts.append(contact)
			contacts.sort_custom(func(a,b):return a.t<b.t)
			for contact in contacts:
				if sim.reflect(arrow,contact):break
		sim.reflect_walls(arrow,false)
		for brick in sim.bricks:
			if not old_sweep(brick.bounds,from,arrow.position).is_empty():arrow.hit[brick.id]=true
		traveled+=from.distance_to(arrow.position);path.append(arrow.position)
		if traveled>=720 or arrow.position.y>1380:break
	return path

func compare(sim:RefCounted,label:String) -> void:
	for pull in [Vector2(0,6),Vector2(0,95),Vector2(64,70),Vector2(-83,47),Vector2(100,6)]:
		var velocity:Vector2=-pull.normalized()*sim.speed()*(0.56+0.44*minf(1,pull.length()/100))
		var before:Dictionary=sim.export_progress()
		var seed_before:int=sim.rng.state
		var expected:=old_predict(sim,velocity)
		var actual:PackedVector2Array=sim.predict(sim.origin,velocity)
		check(actual==expected,label+" exact samples "+str(pull))
		var after:Dictionary=sim.export_progress();before.erase("exportedAt");after.erase("exportedAt")
		check(before==after and seed_before==sim.rng.state,label+" preview has no gameplay side effects")

func _run() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=9128
	for i in range(500):
		var rect:=Rect2(rng.randf_range(20,700),rng.randf_range(20,1000),84,44)
		var start:=Vector2(rng.randf_range(0,780),rng.randf_range(0,1100))
		var finish:=Vector2(rng.randf_range(0,780),rng.randf_range(0,1100))
		check(Geometry.sweep(rect,start,finish)==old_sweep(rect,start,finish),"broad phase preserves sweep "+str(i))
	for pair in [[Vector2(97.5,97.5),Vector2(97.5,146.5)],[Vector2(50,97.5),Vector2(200,97.5)],[Vector2(120,120),Vector2(120,120)]]:
		check(Geometry.sweep(Rect2(100,100,84,44),pair[0],pair[1])==old_sweep(Rect2(100,100,84,44),pair[0],pair[1]),"inclusive edge/zero-length sweep")
	var sim:=Sim.new();sim.start(9128);sim.phase="ready"
	for ids in [[],["seeking"],["corehunter"],["seeking","spectral"],["seeking","corehunter"]]:
		sim.state.skills={}
		for id in ids:sim.state.skills[id]=1
		compare(sim,str(ids))
	sim.spawn_core(true);compare(sim,"exposed core")
	for id in ["eye","forge","serpent","clock"]:
		sim.state.bossOverride={"level":sim.state.level,"boss":id};sim.generate();sim.phase="ready"
		for i in range(180):sim.update(1.0/60)
		compare(sim,id+" moving boss")
	sim.dispose()
	sim=Sim.new();sim.start(9128);sim.phase="ready"
	var board:=Board.new();root.add_child(board);board.set_process(false);board.simulation=sim
	for fps in [60,120]:
		for frame in range(12):
			var pull:=Vector2(-50+frame*8,85)
			sim.drag={"dx":pull.x,"dy":pull.y}
			board._process(1.0/fps)
			var expected:PackedVector2Array=sim.predict(sim.origin,-pull.normalized()*sim.speed()*(0.56+0.44*minf(1,pull.length()/100)))
			check(board.prediction==expected,"latest pull presented at "+str(fps)+" Hz frame "+str(frame))
	sim.drag=null;board._process(1.0/120)
	check(board.prediction.is_empty(),"release clears previous path")
	sim.drag={"dx":0,"dy":95};board._process(1.0/120)
	check(not board.prediction.is_empty(),"new drag has immediate first-frame preview")
	sim.paused=true;board._process(1.0/120)
	check(board.prediction.is_empty(),"pause clears preview")
	board.queue_free();await process_frame;sim.dispose()
	print("Native prediction: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
