extends RefCounted
## Real shoot/hit/wall hooks and delayed jobs, sampled on the visual clock.
## Shared by the GIF collector and the explosive-skill integration regression.
static func step(entry:Dictionary,time:float) -> void:
	if time<0:return
	var g:RefCounted=entry.g
	if not entry.fired:
		g.state.skills={entry.id:1};g.state.skillChosenLevel=g.state.level
		g.initial=1000;g.threshold=1000;g.intro_active=false
		g.locked_until=0;g.next_shot_at=0
		for brick in g.bricks:brick.hp=100;brick.max_hp=100
		var target:RefCounted=g.bricks[12]
		var point:Vector2=target.position
		entry.target=target;entry.start=g.time;entry.elapsed=0.0
		if entry.id in ["orbital","stormfront","supernova","starforge"]:
			if entry.id=="supernova":g.state.skillRuntime.shots=3
			g.shoot(0,100)
		else:
			var arrow:RefCounted=g.launch(point+Vector2(0,70),Vector2.UP*25,2)
			g.skills.with_source(arrow,func():
				match entry.id:
					"aftershock":target.type="bomb";target.hp=1;g.hit(target,2)
					"cascade":target.hp=1;g.hit(target,2)
					"siegebreaker":
						var wall:RefCounted=g.make_obstacle({"x":point.x,"y":point.y})
						g.skills.wall(arrow,wall)
					_:
						if entry.id=="blast":target.hp=1
						g.skills.projectile_hit(target,arrow)
			)
		# Accepted arrows are real; hide them rather than freezing unstepped
		# flight paths over the standalone blast showcase.
		g.arrows.clear();entry.fired=true
	# A fixed 60 Hz schedule keeps delayed chains identical at every capture fps.
	while entry.elapsed+1.0/60<=time+0.000001:
		entry.elapsed+=1.0/60
		g.fx.advance_visual(maxf(0,entry.elapsed-g.fx.visual_time))
		g.time=entry.start+entry.elapsed;g.skills.update(0)
