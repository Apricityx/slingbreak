extends SceneTree
## Independent native regression fixtures: rules, attribution and lifecycle.
const Sim=preload("res://src/core/simulation.gd")
const Progress=preload("res://src/core/progress.gd")
const Geometry=preload("res://src/core/geometry.gd")
var failures:=0
var checks:=0
var current_sim:RefCounted

func _initialize() -> void:call_deferred("_run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func fresh(ids:Array=[],seed_value:int=7281) -> RefCounted:
	if current_sim!=null:current_sim.dispose()
	var sim:=Sim.new();sim.start(seed_value)
	current_sim=sim
	sim.state.level=50;sim.state.skills={};sim.state.up.slots=3
	for id in ids:sim.state.skills[id]=1
	sim.state.skillChosenLevel=50;sim.generate();sim.phase="ready"
	return sim

func _run() -> void:
	check(not ClassDB.class_exists("SlingRuntime"),"project starts with no JavaScript extension")
	var sim:=fresh()
	check(sim.content.catalog.size()==81,"all 81 skills owned by standalone content")
	check(sim.bricks.size()+sim.obstacles.size()>=66,"native board density")
	check(sim.obstacles.size()<=8,"native obstacle quota")
	for wall in sim.obstacles:check(absf(wall.x-390)>=192,"open central route")
	var contact:=Geometry.sweep(Rect2(100,100,84,44),Vector2(40,120),Vector2(220,120))
	check(not contact.is_empty() and contact.normal==Vector2.LEFT and contact.t<1,"swept collision prevents tunnelling")
	check(Geometry.sweep(Rect2(100,100,84,44),Vector2(40,20),Vector2(220,20)).is_empty(),"swept miss")
	var expected_position:=Vector2(390,970)+Vector2(0,-24*0.9995+0.1333333333)
	var a:RefCounted=sim.launch(sim.origin,Vector2(0,-24));sim.integrate(a,1.0/60)
	check(a.position.distance_to(expected_position)<0.00001,"native integrator retains calibrated velocity units")
	a.position=Vector2(12,18);a.velocity=Vector2(-24,-16)
	sim.reflect_walls(a,false)
	check(a.px==20 and a.py==22 and a.vx>0 and a.vy>0,"both wall contacts update authoritative motion")
	check(a.position==Vector2(20,22) and a.velocity.x>0 and a.velocity.y>0,"collision view follows wall reflection")
	a.velocity=Vector2(-11,9);a.position=Vector2(500,600)
	sim.integrate(a,1.0/60)
	check(a.px<500 and a.py>600 and a.vx<0,"external collision/steering writes feed the next integration")
	sim= fresh(["spectral"])
	sim.fx.signature("spectral",Vector2(390,300),80)
	sim.fx.beam("spectral",Vector2(100,200),Vector2(200,300))
	sim.fx.skill_bolt(Vector2(100,200),Vector2(200,300))
	check(sim.fx.signatures.is_empty() and sim.fx.beams.is_empty() and sim.fx.bolts.is_empty(),"v1 skill effects stay hidden")
	check(sim.predict(sim.origin,Vector2(0,-24)).size()>12,"native aim prediction")
	var before_rng:int=sim.rng.state
	for i in range(20):sim.fx.burst(Vector2(10,10),Color.GREEN,20)
	check(sim.rng.state==before_rng,"visual random state does not change gameplay")
	var original:Dictionary=sim.export_progress()
	check(Progress.valid(original),"native progress envelope validates")
	var restored:=Sim.new();restored.start(3,JSON.parse_string(JSON.stringify(original)))
	check(restored.state.skills==sim.state.skills and restored.bricks.size()==sim.bricks.size(),"progress survives JSON roundtrip")
	var invalid:Dictionary=original.duplicate(true);invalid.state.up.draw=11
	check(not Progress.valid(invalid),"invalid draw upgrade rejected")
	invalid=original.duplicate(true);invalid.state.board.bricks[0].hp=-1
	check(not Progress.valid(invalid),"invalid board rejected")
	invalid=original.duplicate(true);invalid.state.skillRuntime={"level":50,"shots":"bad"}
	check(not Progress.valid(invalid),"invalid skill counters rejected before import")
	invalid=original.duplicate(true);invalid.state.board.bricks[0].nativeFlags={"markUntil":[]}
	check(not Progress.valid(invalid),"invalid renderer flags rejected before import")
	invalid=original.duplicate(true);invalid.state.board.levelMoney=[]
	check(not Progress.valid(invalid),"invalid restored board income rejected")
	invalid=original.duplicate(true);invalid.state.skillRuntime.contract={"rounds":0,"size":3,"targets":[{"x":[],"y":100}]}
	check(not Progress.valid(invalid),"malformed contract targets rejected")
	invalid=original.duplicate(true);invalid.state.draft={"level":50,"options":["spectral","spectral","unknown"]}
	check(not Progress.valid(invalid),"unknown and duplicate draft candidates rejected")
	sim=fresh();sim.state.coins=100000;sim.state.up.draw=9
	check(sim.buy("draw") and is_equal_approx(sim.draw_interval(),0.1),"last draw upgrade reaches tenfold frequency")
	check(not sim.buy("draw"),"draw cap enforced")
	sim=fresh(["titan","blast","lightning","ice"]);sim.state.level=51;sim.generate()
	var picked:String=sim.state.draft.options[0];check(sim.choose(picked),"draft commit")
	check(sim.state.skills.keys()==["blast","lightning","ice",picked],"full queue evicts oldest slot")
	check(not sim.choose(picked),"draft cannot commit twice")
	sim=fresh();sim.bricks.clear();sim.obstacles.clear();sim.phase="flying";sim.initial=20
	a=sim.launch(sim.origin,Vector2(0,-24));sim.active_arrow=a
	for index in range(4):
		var b:RefCounted=sim.make_brick({"x":100+index*96,"y":200,"hp":1,"max":1});sim.hit(b,10)
	check(a.kills==4 and sim.state.achievements.get("double",0)==1,"single arrow achievement threshold")
	var paid:float=a.achievement.paid
	check(sim.evaluate_achievements(a)==0 and paid>0,"achievement payout cannot repeat")
	sim.active_arrow=null
	for item in sim.content.catalog:
		sim=fresh([item.id]);sim.state.skillRuntime.shots=2
		check(sim.shoot(12,100),"shoot "+item.id)
		a=sim.arrows[0]
		if not sim.bricks.is_empty():
			sim.active_arrow=a;sim.skills.projectile_hit(sim.bricks[0],a);sim.active_arrow=null
		for step in range(200):sim.update(1.0/60)
		check(sim.skills.jobs.size()<=512 and sim.arrows.size()<=64 and sim.fx.particles.size()<=300,"bounded work "+item.id)
		for arrow in sim.arrows:check(arrow.position.is_finite() and arrow.velocity.is_finite(),"finite projectile "+item.id)
	# Bounty rounds draw three live bricks at random, never twice, and pay out.
	var contract_sets:Array=[]
	for contract_seed in [11,29,47,73]:
		sim=fresh(["contract"],contract_seed);sim.phase="flying"
		sim.state.skillRuntime.contract={"rounds":0,"targets":[],"size":0}
		sim.skills.ensure_contract()
		var contract_targets:Array=sim.state.skillRuntime.contract.targets
		check(contract_targets.size()==3 and int(sim.state.skillRuntime.contract.size)==3,"contract marks three bounty targets")
		var contract_points:Dictionary={}
		var contract_live:=true
		for contract_point in contract_targets:
			contract_points["%s:%s" % [contract_point.x,contract_point.y]]=true
			var contract_found:=false
			for contract_brick in sim.bricks:
				if contract_brick.x==contract_point.x and contract_brick.y==contract_point.y:contract_found=true;break
			contract_live=contract_live and contract_found
		check(contract_points.size()==3 and contract_live,"bounty targets are distinct live bricks")
		contract_sets.append(contract_points.keys())
		var contract_coins:int=sim.state.coins
		sim.fx.rings.clear()
		var contract_target:Dictionary=contract_targets[0]
		for contract_brick in sim.bricks.duplicate():
			if contract_brick.x!=contract_target.x or contract_brick.y!=contract_target.y:continue
			sim.hit(contract_brick,1000000)
			check(sim.fx.rings.any(func(ring):return is_equal_approx(ring.radius,74)),"bounty hit emits its target ring")
			break
		for contract_brick in sim.bricks.duplicate():
			if sim.skills.contracted(contract_brick):sim.hit(contract_brick,1000000)
		check(sim.state.coins>contract_coins and int(sim.state.skillRuntime.contract.rounds)==1,"bounty completion pays and advances the round")
		check(sim.fx.rings.any(func(ring):return is_equal_approx(ring.radius,190)),"bounty completion pulses the core with a wide ring")
	check(contract_sets[0]!=contract_sets[1] or contract_sets[2]!=contract_sets[3],"bounty targets vary with the board seed")
	sim=fresh(["lightning"]);sim.phase="flying";sim.bricks.clear();sim.obstacles.clear();sim.initial=100
	var target:RefCounted=sim.make_brick({"x":100,"y":200,"hp":1,"max":1})
	var neighbour:RefCounted=sim.make_brick({"x":196,"y":200,"hp":1,"max":1})
	a=sim.launch(sim.origin,Vector2(0,-24));sim.active_arrow=a;sim.skills.projectile_hit(target,a);sim.active_arrow=null
	var other:RefCounted=sim.launch(sim.origin,Vector2(0,-24));sim.arrows.erase(a)
	for step in range(10):sim.update(1.0/60)
	check(a.kills==2 and other.kills==0,"delayed lightning keeps retired source arrow")
	for id in ["eye","forge","serpent","clock"]:
		sim=fresh();sim.state.level=100;sim.state.skillChosenLevel=100;sim.state.bossOverride={"level":100,"boss":id};sim.generate();sim.phase="ready"
		check(sim.bosses.boss_id==id and sim.bosses.model!=null,"native boss starts "+id)
		for step in range(210):sim.update(1.0/60)
		a=sim.launch(Vector2(390,900),Vector2(0,-24));sim.phase="flying"
		for step in range(700):sim.update(1.0/60)
		check(sim.bosses.fight.hp>0 and sim.core==null,"boss owns its completion "+id)
		var progress:Dictionary=sim.export_progress()
		check(Progress.valid(progress),"boss progress validates "+id)
		invalid=progress.duplicate(true);invalid.state.nativeBoss.data={}
		check(not Progress.valid(invalid),"missing boss state rejected "+id)
		invalid=progress.duplicate(true);invalid.state.nativeBoss.abilities[0]=["unknown"]
		check(not Progress.valid(invalid),"invalid boss ability rejected "+id)
		restored=Sim.new();restored.start(81,JSON.parse_string(JSON.stringify(progress)))
		check(restored.bosses.boss_id==id and is_equal_approx(restored.bosses.fight.hp,sim.bosses.fight.hp),"boss reload "+id)
		while sim.bosses.fight.phase<sim.bosses.fight.phases:
			sim.bosses.fight.hp=0;sim.update(1.0/60)
			for step in range(100):sim.update(1.0/60)
		sim.bosses.fight.hp=0;sim.update(1.0/60)
		for step in range(230):sim.update(1.0/60)
		check(sim.phase=="clearing" and sim.state.level==101,"all phases finish "+id)
	sim=fresh();sim.state.level=5;sim.state.skillChosenLevel=5;sim.generate()
	var coins:float=sim.state.coins;sim.clear()
	check(sim.state.level==6 and sim.state.coins>coins and sim.state.rerolls==1,"clear reward and fifth-level charge paid once")
	sim.clear();check(sim.state.rerolls==1,"clear is idempotent")
	var stopped:float=sim.time
	for step in range(5):sim.update(1.0/60)
	check(sim.time==stopped,"clear holds 130 ms")
	sim.clear_at=sim.time+0.01
	for step in range(10):sim.update(1.0/60)
	check(sim.phase=="draft" and sim.wipe!=null,"next draft waits for curtain")
	for step in range(75):sim.update(1.0/60)
	check(sim.wipe==null,"curtain lifetime ends")
	sim=fresh();sim.state.level=100;sim.state.skillChosenLevel=100;sim.state.bossDeck=["eye","clock"];sim.generate()
	var natural:Dictionary=sim.export_progress();restored=Sim.new();restored.start(10,JSON.parse_string(JSON.stringify(natural)))
	check(restored.bosses.boss_id==sim.bosses.boss_id and restored.state.bossDeck==sim.state.bossDeck,"natural boss restore does not consume next deck entry")
	sim.dispose();restored.dispose()
	print("Native regression: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
