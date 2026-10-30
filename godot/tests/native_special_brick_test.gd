extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
var failures:=0
func check(ok:bool,label:String) -> void:
	if not ok:failures+=1;push_error(label)
func _initialize() -> void:
	var g:=Sim.new();g.start(9128)
	g.fx.special_break(Vector2(100,100),"lightning")
	g.fx.special_break(Vector2(200,100),"gold")
	check(g.fx.specials.size()==2,"special events are queued")
	var lightning:Dictionary=g.fx.specials[0]
	var gold:Dictionary=g.fx.specials[1]
	check(is_equal_approx(lightning.max,0.42),"arc brick uses a snap duration")
	check(is_equal_approx(gold.max,0.58),"coin brick uses a quick burst duration")
	check(lightning.type=="lightning" and gold.type=="gold","event identities remain distinct")
	g.fx.advance_visual(0.44)
	check(g.fx.specials.size()==1 and g.fx.specials[0].type=="gold","arc disappears before coin burst")
	g.fx.advance_visual(0.2)
	check(g.fx.specials.is_empty(),"coin burst fades cleanly")
	for index in range(100):g.fx.special_break(Vector2(index,200),"lightning")
	check(g.fx.specials.size()==48,"special queue remains bounded")
	g.dispose();print("Native special bricks: 6 checks, %d failures" % failures);quit(1 if failures else 0)
