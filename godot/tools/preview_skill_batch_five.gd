extends RefCounted
## Real hooks with a deterministic showcase clock; no full-flight simulation.
static func step(entry:Dictionary,time:float) -> void:
	var g:RefCounted=entry.g
	g.fx.advance_visual(maxf(0,time)-g.fx.visual_time)
	if time<0:return
	g.time=time
	if not entry.fired:
		g.state.skills={entry.id:1};g.initial=1000
		if entry.id=="legion":
			g.origin=Vector2(390,485);g.state.skillRuntime.shots=2
			g.intro_active=false;g.locked_until=0;g.next_shot_at=0
			g.shoot(0,100)
		else:
			var target:RefCounted=g.bricks[12]
			target.hp=100;target.max_hp=100
			if entry.id=="siphon":target.hp=1;target.max_hp=1
			var arrow:RefCounted=g.launch(target.position+Vector2(0,17),Vector2.UP*24)
			g.skills.with_source(arrow,func():g.skills.projectile_hit(target,arrow))
		# Isolate the material burst; arrows are tested separately by native tests.
		g.arrows.clear();entry.fired=true
	g.skills.update(0)
