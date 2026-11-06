extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
const Batch=preload("res://src/render/skill_batch_nine.gd")
const Board=preload("res://src/render/board.gd")
const Fixture=preload("res://tools/preview_skill_batch_nine.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func fresh(id:String) -> RefCounted:
	var g:=Sim.new();g.start(9128);g.bricks.clear();g.obstacles.clear();g.fx.reset();g.skills.reset()
	g.state.skills={id:1};g.state.skillChosenLevel=g.state.level;g.phase="flying";g.initial=1000
	g.board_entrance=null;g.state.draft=null
	return g

func brick(g:RefCounted,point:Vector2,hp:float=100) -> RefCounted:
	return g.make_brick({"x":point.x,"y":point.y,"hp":hp,"max":hp,"w":30,"h":20})

func hit(g:RefCounted,a:RefCounted,b:RefCounted) -> void:
	g.active_arrow=a;g.skills.projectile_hit(b,a);g.active_arrow=null

func events(g:RefCounted,id:String) -> Array:
	return g.fx.skill_events.filter(func(e):return e.id==id)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var g:=fresh("swarmqueen")
	var a:RefCounted=g.launch(g.origin,Vector2.UP*25)
	var rng:int=g.rng.state
	g.skills.on_shoot(a,Vector2(0,100))
	check(g.arrows.size()==9 and events(g,"swarmqueen").size()==8,"queen emits exactly eight accepted child snapshots")
	for i in range(8):
		var child:RefCounted=g.arrows[i+1]
		check(child.flags.homing and child.pierce==3 and is_equal_approx(child.damage,g.damage()*1.5),"queen child retains homing, damage, pierce")
		check(child.velocity.is_equal_approx(Vector2.from_angle(-PI/2+(i-3.5)*0.12)*25),"queen angular spread and speed unchanged")
		check(events(g,"swarmqueen")[i].direction.is_equal_approx(child.velocity.normalized()),"queen visual matches exact child lane")
	check(g.rng.state==rng,"queen does not consume RNG")
	g.dispose();g=fresh("swarmqueen")
	for i in range(62):a=g.launch(g.origin,Vector2.UP*25)
	g.skills.on_shoot(a,Vector2(0,100))
	check(g.arrows.size()==64 and events(g,"swarmqueen").size()==2,"queen capacity emits only the two accepted lanes")
	g.dispose();g=fresh("railgun")
	a=g.launch(g.origin,Vector2(3,-25))
	var amount:float=a.damage;var pierce:int=a.pierce
	check(is_equal_approx(amount,g.base_damage()*4),"railgun keeps fourfold base damage")
	g.skills.on_shoot(a,Vector2(0,100))
	var b:=brick(g,Vector2(390,440));hit(g,a,b)
	check(is_equal_approx(b.hp,100-amount) and a.pierce==pierce,"rail impact changes neither damage nor pierce bookkeeping")
	check(events(g,"railgun").size()==2 and events(g,"railgun")[0].strength<0.8 and events(g,"railgun")[1].strength==1,"rail separates muzzle from real hit")
	check(events(g,"railgun")[1].direction.is_equal_approx(a.velocity.normalized()),"rail strike follows collision direction")
	check(g.fx.signatures.is_empty() and g.fx.beams.is_empty(),"rail has no generic signature or invented board beam")
	g.dispose();g=fresh("frostfire")
	a=g.launch(Vector2(390,600),Vector2.UP*25,2)
	b=brick(g,Vector2(390,440));var near:=brick(g,Vector2(460,440));var far:=brick(g,Vector2(500,440))
	rng=g.rng.state;hit(g,a,b)
	check(b.frozen and near.frozen and not far.frozen,"frostfire keeps the 100px freeze radius")
	check(b.hp==98 and near.hp==100 and g.skills.jobs.size()==1,"frostfire starts with original direct hit and one delayed blast")
	check(events(g,"frostfire").size()==1 and near.frost_born==g.fx.visual_time,"frostfire ice impact and persistent shell have independent lifetimes")
	g.time+=0.089;g.skills.update(0)
	check(near.hp==100 and g.fx.explosions.is_empty(),"frostfire never detonates early")
	g.fx.advance_visual(0.09);g.time+=0.0011;g.skills.update(0)
	check(is_equal_approx(near.hp,100-g.damage()*3) and far.hp==100,"frostfire retains 1.5x damage with frozen double damage at deadline")
	check(events(g,"frostfire").size()==2 and g.fx.explosions.size()==1,"frostfire actual detonation emits hot shards and GPU fire volume")
	check(g.fx.explosions[0].radius==100 and g.fx.rings.is_empty(),"frostfire fire radius exact and no legacy closed ring")
	check(g.rng.state==rng,"frostfire leaves gameplay RNG unchanged")
	g.fx.advance_visual(2)
	check(g.fx.skill_events.is_empty() and near.frozen,"frostfire transient ends while frozen state survives")
	g.dispose()
	# Every seeded hit is checked against exactly one draw of the original 35% gate.
	var successes:=0;var misses:=0
	for seed_value in range(1,21):
		g=fresh("thunderlottery");g.rng.seed=seed_value
		var probe:=RandomNumberGenerator.new();probe.state=g.rng.state
		var success:bool=probe.randf()<0.35
		a=g.launch(Vector2(390,600),Vector2.UP*25,2)
		var targets:Array=[]
		for i in range(7):targets.append(brick(g,Vector2(320+i*30,440)))
		b=targets[0];hit(g,a,b)
		check(g.rng.state==probe.state,"lottery gate consumes exactly one original gameplay draw")
		check(g.skills.jobs.size()==int(success) and events(g,"thunderlottery").is_empty(),"lottery success is delayed and failed rolls have no false celebration")
		g.time+=0.069;g.skills.update(0)
		check(events(g,"thunderlottery").is_empty(),"lottery cannot hit before .07s")
		g.fx.advance_visual(0.07);g.time+=0.0011;g.skills.update(0)
		if success:
			successes+=1
			var shots:=events(g,"thunderlottery")
			check(shots.size()==7,"lottery creates one six-pip die and six actual hop events")
			var previous:Vector2=b.position
			for i in range(6):
				check(shots[i+1].position==previous and shots[i+1].target==targets[i].position,"lottery keeps nearest ordering and exact endpoints")
				check(is_equal_approx(targets[i].hp,100-(2 if i==0 else 0)-g.damage()*3),"lottery retains 3x hop damage")
				previous=targets[i].position
			check(targets[6].hp==100,"lottery never hits a seventh target")
		else:
			misses+=1;check(events(g,"thunderlottery").is_empty(),"failed lottery remains visually silent")
		check(g.fx.signatures.is_empty() and g.fx.bolts.is_empty(),"lottery replaces old signatures and bolts")
		g.dispose()
	check(successes>0 and misses>0,"seed fixtures cover both lottery outcomes")
	g=fresh("thunderlottery")
	b=brick(g,Vector2(350,440),1);b.type="lightning"
	brick(g,Vector2(400,440),1)
	g.skills.arc(Vector2(340,440),6,g.damage()*3,"thunderlottery")
	check(g.bricks.is_empty() and events(g,"thunderlottery").size()==2,"lottery omits stale targets already destroyed by an earlier special-brick chain")
	g.dispose()
	for id in ["frostfire","thunderlottery"]:
		g=fresh(id);g.rng.seed=1;g.skills.budget=0
		a=g.launch(Vector2(390,600),Vector2.UP*25,2);b=brick(g,Vector2(390,440));hit(g,a,b)
		g.time+=0.2;g.skills.update(0)
		check(g.skills.jobs.is_empty() and g.fx.explosions.is_empty(),"limited jobs keep original exhausted-budget behavior: "+id)
		check(events(g,id).size()==(1 if id=="frostfire" else 0),"no invented delayed impact when budget rejects job: "+id)
		g.dispose()
	for id in Batch.IDS:
		g=fresh(id);rng=g.rng.state
		for i in range(100):g.fx.skill_event(id,Vector2(i,440),Vector2.RIGHT,Vector2(500,440),1,0.62)
		check(g.fx.skill_events.size()==64 and g.fx.skill_events[0].position.x==36,"64 newest snapshots: "+id)
		var batch:=Batch.new();batch.setup(id);batch.present(g)
		check(batch.multimesh.visible_instance_count==64,"fixed GPU capacity: "+id)
		var mesh:=batch.multimesh.mesh
		check(mesh.surface_get_array_len(0)<=40,"at most forty vertices per event: "+id)
		var twin:=Batch.new();twin.setup(id)
		check(twin.multimesh.mesh==mesh,"shared immutable template: "+id);twin.free()
		g.state.performanceMode=true;batch.present(g)
		check(batch.multimesh.mesh.surface_get_array_len(0)<mesh.surface_get_array_len(0),"reduced mode decreases geometry: "+id)
		g.fx.update(10);check(g.fx.skill_events.size()==64,"visual clock independent of gameplay: "+id)
		g.fx.advance_visual(0.63);batch.present(g)
		check(g.fx.skill_events.is_empty() and batch.multimesh.visible_instance_count==0,"expired queue and GPU count: "+id)
		g.fx.skill_event(id,Vector2.ZERO);g.fx.reset();batch.present(g)
		check(g.fx.skill_events.is_empty() and batch.multimesh.visible_instance_count==0,"reset while active clears GPU: "+id)
		check(g.rng.state==rng,"GPU and event queue never consume gameplay RNG: "+id)
		batch.free();g.dispose()
	if DisplayServer.get_name()!="headless":
		await graphics_checks()
		var warmup:Dictionary=await preload("res://src/render/effect_warmup.gd").prepare(root)
		check(warmup.get("frames",0)==16,"production warmup renders both GPU mesh variants before play")
	print("Native skill batch nine: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func graphics_checks() -> void:
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(412,600)
	for reduced in [false,true]:
		for id in Batch.IDS:
			var g:=fresh(id);g.theme="dark" if reduced else "light";g.state.performanceMode=reduced
			for row in range(5):
				for col in range(5):brick(g,Vector2(220+col*85,340+row*50),80)
			var board:=Board.new();board.simulation=g;root.add_child(board);board.set_process(false);board.scale=Vector2.ONE*0.7
			var entry:Dictionary={"g":g,"id":id,"fired":false}
			Fixture.step(entry,0);Fixture.step(entry,0.12);board._process(0)
			var batch:MultiMeshInstance2D=board.skill_batches[id]
			check(batch.multimesh.visible_instance_count>0,"real hook fixture emits GPU instances: "+id)
			batch.visible=false;await frame();var before:=root.get_texture().get_image()
			batch.visible=true;await frame();var after:=root.get_texture().get_image()
			var changed:=0
			for y in range(200,430):
				for x in range(90,410):
					if before.get_pixel(x,y)!=after.get_pixel(x,y):changed+=1
			check(changed>30,"GPU family visibly contributes to real live fixture: %s / reduced=%s (%dpx)" % [id,reduced,changed])
			print("Batch nine GPU: %s reduced=%s changed=%dpx" % [id,reduced,changed])
			Fixture.step(entry,1.8);board._process(0);await frame()
			check(batch.multimesh.visible_instance_count==0,"real fixture has clean final tail: "+id)
			board.queue_free();await process_frame;g.dispose()
