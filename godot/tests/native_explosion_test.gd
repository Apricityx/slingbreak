extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
var failures:=0
func _initialize() -> void:
	var g:=Sim.new();g.start(9128)
	var state:int=g.rng.state
	for index in range(100):g.fx.explosion(Vector2(index,200))
	check(g.fx.explosions.size()==16,"chain budget")
	check(g.rng.state==state,"visual effects must not consume gameplay RNG")
	g.fx.advance_visual(0.5)
	check(g.fx.explosions.size()==16,"smoke survives initial impact")
	g.fx.advance_visual(1.0)
	check(g.fx.explosions.is_empty(),"all volumes expire")
	g.fx.special_break(Vector2.ZERO,"bomb")
	check(g.fx.explosions.size()==1 and g.fx.specials.is_empty(),"bomb uses GPU event instead of legacy glyph")
	g.fx.normal_break(Vector2(100,100),Color("#dce2d0"))
	check(g.fx.normal_breaks.size()==1,"normal brick break queues one bounded presentation event")
	g.fx.advance_visual(0.5)
	check(g.fx.normal_breaks.is_empty(),"normal brick shards expire quickly")
	g.fx.reset()
	check(g.fx.explosions.is_empty(),"new board clears effects")
	var explosive_ids:= ["blast","shatter","aftershock","doubletap","minefield","frostfire","cascade","orbital","stormfront","undertow","starforge","siegebreaker"]
	for index in range(explosive_ids.size()):
		g.fx.reset()
		g.skills.detonate(Vector2(120+index*45,300),70+index*5,1.0,explosive_ids[index])
		if explosive_ids[index]=="shatter":
			check(g.fx.explosions.is_empty() and g.fx.skill_events.size()==1,"shatter uses the upgraded crystal impact")
		else:check(g.fx.explosions.size()==1,"explosive skill queues fire volume: "+explosive_ids[index])
	g.fx.reset();g.skills.global_damage(1.0,"supernova",650)
	check(g.fx.explosions.size()==1 and g.fx.explosions[0].radius==650,"supernova uses the full-arena explosion volume")
	g.dispose()
	print("Native explosion: %d checks, %d failures" % [8+explosive_ids.size()+1,failures])
	quit(1 if failures else 0)
func check(ok:bool,label:String) -> void:
	if not ok:failures+=1;push_error(label)
