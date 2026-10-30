extends RefCounted
## Production gameplay hooks, with delayed fuse jobs advanced on the capture clock.
static func step(entry:Dictionary,time:float) -> void:
	if time<0:return
	var g:RefCounted=entry.g
	if not entry.fired:
		g.state.skills={entry.id:1};g.initial=1000;g.threshold=1000
		var arrow:RefCounted=g.launch(Vector2(390,510),Vector2.UP*25,2)
		arrow.flags.main=true
		var target:RefCounted=g.bricks[12]
		g.active_arrow=arrow
		match entry.id:
			"opportunist":
				target.hp=10;g.skills.projectile_hit(target,arrow)
			"bounty":
				g.hit(g.bricks[0],100);g.fx.reset();g.hit(target,100)
			"nailburst":g.skills.projectile_hit(target,arrow)
			"fusepath":
				g.skills.projectile_hit(g.bricks[11],arrow)
				g.skills.projectile_hit(g.bricks[13],arrow)
		g.active_arrow=null
		# Real children were generated; launch lanes show their directions without
		# leaving non-simulated arrows frozen across the standalone showcase.
		g.arrows.clear();entry.fired=true;entry.batch_six_start=g.time
	g.fx.advance_visual(maxf(0,time-g.fx.visual_time))
	g.time=entry.batch_six_start+time
	g.skills.update(0)
