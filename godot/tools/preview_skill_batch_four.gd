extends RefCounted
## Exercise the live entry points, then reframe their immutable visual snapshots
## into the shared close-up. Common clear/spawn fireworks are omitted here.
static func fire(g:RefCounted,id:String) -> void:
	g.state.skills={id:1}
	var saved_bricks:Array=g.bricks.duplicate()
	match id:
		"treasury":
			g.core={"x":390.0,"y":80.0,"born":0.0};g.clear()
		"bargain":
			g.phase="ready";g.state.coins=10000;g.buy("power")
		"resonance":g.spawn_core()
		"corehunter":
			g.core={"x":470.0,"y":385.0,"born":0.0}
			var arrow:RefCounted=g.launch(Vector2(350,465),Vector2.UP*24)
			g.guide(arrow,1.0/60)
	var event:Dictionary=g.fx.skill_events.back()
	if id!="corehunter":event.position=Vector2(390,440)
	g.bricks=saved_bricks;g.phase="flying";g.arrows.clear()
	g.core={"x":event.target.x,"y":event.target.y,"born":-2.0} if id=="corehunter" else {"x":390.0,"y":440.0,"born":-2.0} if id=="resonance" else null
	if g.core!=null:g.presentation_core_previous=Vector2(g.core.x,g.core.y)
	g.fx.particles.clear();g.fx.rings.clear();g.fx.flash=0;g.fx.shake=0
