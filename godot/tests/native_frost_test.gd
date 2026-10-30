extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
var failures:=0
func check(ok:bool,label:String) -> void:
	if not ok:failures+=1;push_error(label)
func _initialize() -> void:
	var g:=Sim.new();g.start(9128);g.choose(g.state.draft.options[0])
	g.bricks.clear();g.phase="ready";g.threshold=999
	var source=g.make_brick({"x":300,"y":400,"hp":1,"type":"frost"})
	var target=g.make_brick({"x":396,"y":400,"hp":20,"max":20})
	var outside=g.make_brick({"x":600,"y":400,"hp":20})
	g.hit(source,100)
	check(target.frozen and target.hp<20,"freeze and damage remain immediate")
	check(not outside.frozen,"wave does not extend gameplay range")
	check(target.frost_born>g.fx.visual_time and target.frost_direction==Vector2.RIGHT,"shell grows from the source-facing side on wave arrival")
	check(not target.serialize().has("frost_born"),"animation clock is not saved")
	check(g.fx.specials.any(func(e):return e.type=="frost" and e.radius==140),"wave uses actual frost range")
	g.hit(target,100)
	check(g.fx.specials.any(func(e):return e.type=="ice_shards" and e.position==target.position),"frozen targets shed shards on destruction")
	g.fx.advance_visual(2)
	check(g.fx.specials.is_empty(),"all frost events expire")
	for index in range(100):g.fx.special_break(Vector2.ZERO,"frost")
	check(g.fx.specials.size()==48,"chain reactions retain bounded events")
	g.fx.reset();check(g.fx.specials.is_empty(),"new board resets frost events")
	g.dispose();print("Native frost: 9 checks, %d failures" % failures);quit(1 if failures else 0)
