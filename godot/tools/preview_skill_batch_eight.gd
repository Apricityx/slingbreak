extends RefCounted
## Fixed-clock real hooks; source arrows are hidden after their launch is recorded.
static func setup(g:RefCounted) -> void:
	for brick in g.bricks:brick.hp=100;brick.max_hp=100

static func seed_reward(g:RefCounted,win:bool) -> void:
	var probe:=RandomNumberGenerator.new()
	for value in range(1,100):
		probe.seed=value
		if (probe.randf()<0.25)==win:g.rng.seed=value;return

static func step(entry:Dictionary,time:float) -> void:
	if time<0:return
	var g:RefCounted=entry.g
	if not entry.fired:
		g.state.skills={entry.id:1};g.initial=1000;g.threshold=1000
		g.intro_active=false;g.locked_until=0;g.next_shot_at=0
		setup(g)
		var target:RefCounted=g.bricks[12]
		match entry.id:
			"nova":g.hit(target,1000)
			"crossfire":
				var arrow:RefCounted=g.launch(Vector2(390,490),Vector2.UP*24)
				g.skills.with_source(arrow,func():g.skills.projectile_hit(target,arrow))
			"jackpot":seed_reward(g,true);g.hit(target,1000)
			"supernova":g.state.skillRuntime.shots=3;g.shoot(0,100)
		entry.fired=true;entry.batch_eight_start=g.time
	g.fx.advance_visual(maxf(0,time-g.fx.visual_time))
	g.time=entry.batch_eight_start+time;g.skills.update(0)
	if entry.id=="jackpot" and time>=0.88 and not entry.get("second_reward",false):
		seed_reward(g,false)
		for brick in g.bricks:
			if brick.position==Vector2(475,440):g.hit(brick,1000);break
		entry.second_reward=true
	g.arrows.clear()
