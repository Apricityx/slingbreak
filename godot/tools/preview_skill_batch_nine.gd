extends RefCounted
## Production shoot/hit/jobs; the fixture only positions targets and advances clocks.
static func step(entry:Dictionary,time:float) -> void:
	if time<0:return
	var g:RefCounted=entry.g
	if not entry.fired:
		g.state.skills={entry.id:1};g.state.skillChosenLevel=g.state.level;g.initial=1000
		var resting_origin:Vector2=g.origin
		g.origin=Vector2(390,505)
		for b in g.bricks:b.hp=80;b.max_hp=80
		if entry.id in ["swarmqueen","railgun"]:
			g.skills.on_shoot(g.launch(g.origin,Vector2.UP*25,-1,-1,false,true),Vector2(0,100))
			if entry.id=="railgun":
				g.active_arrow=g.arrows[0];g.skills.projectile_hit(g.bricks[12],g.arrows[0]);g.active_arrow=null
		else:
			var arrow:RefCounted=g.launch(Vector2(390,510),Vector2.UP*25,2)
			if entry.id=="thunderlottery":
				# A fixed successful seed; the real probability gate still runs once.
				g.rng.seed=1
			g.active_arrow=arrow;g.skills.projectile_hit(g.bricks[12],arrow);g.active_arrow=null
		g.origin=resting_origin
		g.arrows.clear();entry.fired=true;entry.batch_nine_start=g.time
	g.fx.advance_visual(maxf(0,time-g.fx.visual_time))
	g.time=entry.batch_nine_start+time
	g.skills.update(0)
