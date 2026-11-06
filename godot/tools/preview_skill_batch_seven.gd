extends RefCounted
## Actual shoot -> delayed jobs -> homing/ballistics -> swept brick contacts.
## Fixed 60 Hz gameplay, sampled by the common real-GPU GIF collector.
static func setup(g:RefCounted,id:String) -> Vector2:
	g.origin=Vector2(390,550);g.initial=1000;g.state.skills={id:1}
	g.phase="ready";g.locked_until=0;g.next_shot_at=0;g.intro_active=false
	if id=="meteor":
		for i in range(g.bricks.size()):g.bricks[i].y=210+int(i/5)*42
		return Vector2(-218,-115)
	# Leave a visible release throat under the dense target field.
	for brick in g.bricks:brick.y-=55
	return Vector2(-218,-320)

static func step(entry:Dictionary,time:float) -> void:
	if time<0:return
	var g:RefCounted=entry.g
	if not entry.fired:
		g.shoot(0,100)
		entry.fired=true;entry.seven_elapsed=0.0
	while entry.seven_elapsed+1.0/60<=time+0.000001:
		entry.seven_elapsed+=1.0/60
		g.fx.advance_visual(maxf(0,entry.seven_elapsed-g.fx.visual_time))
		g.tick(1.0/60)
	g.presentation_fraction=1.0;g.presentation_time=g.time
