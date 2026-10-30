extends RefCounted
## Shared, deterministic trigger schedule. Diagnostics may hide a renderer, never
## change the live event populations or omit trigger/lifecycle work.
const SKILLS=["echo","piercer","seeking","ricochet"]
const SPECIALS=["bomb","lightning","frost","prism","gold"]

static func skill(g:RefCounted,id:String,index:int) -> void:
	var point:=Vector2(100+(index%6)*110,180+((index/6)%7)*85)
	var direction:=Vector2.RIGHT.rotated(index*.31)
	var target:=point+direction*90.0 if id=="seeking" else Vector2.ZERO
	g.fx.skill_event(id,point,direction,target,1.0,0.42 if id=="seeking" else 0.5)

static func special(g:RefCounted,id:String,index:int) -> void:
	var point:=Vector2(90+(index%6)*110,220+((index/6)%7)*80)
	if id=="frost":
		g.fx.special_break(point,"frost");g.fx.frozen_target(point+Vector2(48,0),42)
	elif id=="lightning":
		var previous:=point
		for offset in [Vector2(80,0),Vector2(80,-50),Vector2(0,-50),Vector2(-80,-50),Vector2(-80,0)]:
			var target:Vector2=point+offset
			g.fx.skill_event("storm",previous,previous.direction_to(target),target)
			previous=target
	else:g.fx.special_break(point,id)

static func step(g:RefCounted,frame:int) -> void:
	for lane in range(4):skill(g,SKILLS[(frame+lane)%SKILLS.size()],frame+lane)
	special(g,SPECIALS[frame%SPECIALS.size()],frame)
	if frame%3==0:g.fx.explosion(Vector2(250,320),132,1.0)
	g.fx.advance_visual(1.0/60.0)
