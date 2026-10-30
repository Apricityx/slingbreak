extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func fresh(id:String) -> RefCounted:
	var g:=Sim.new();g.start(9128);g.bricks.clear();g.obstacles.clear();g.fx.reset();g.skills.reset()
	g.state.skills={id:1};g.state.skillChosenLevel=g.state.level;g.phase="flying";g.initial=1000
	return g

func brick(g:RefCounted,point:Vector2,hp:float=1,type:String="normal") -> RefCounted:
	return g.make_brick({"x":point.x,"y":point.y,"hp":hp,"max":hp,"type":type})

func hit(g:RefCounted,source:RefCounted,target:RefCounted,amount:float=100) -> void:
	g.active_arrow=source;g.hit(target,amount);g.active_arrow=null

func _initialize() -> void:
	var g:=fresh("storm");var a:RefCounted=g.launch(Vector2(390,600),Vector2.UP*24)
	var lightning:=brick(g,Vector2(390,400),1,"lightning");brick(g,Vector2(440,400),100);brick(g,Vector2(490,400),100)
	hit(g,a,lightning)
	check(g.fx.skill_events.size()==2,"storm emits one hop event per chained target")
	check(g.fx.skill_events[0].id=="storm" and g.fx.skill_events[1].target==Vector2(490,400),"storm events retain hop endpoints")
	g.dispose()
	g=fresh("blizzard");a=g.launch(Vector2(390,600),Vector2.UP*24)
	var frost:=brick(g,Vector2(390,400),1,"frost");brick(g,Vector2(440,400),100)
	hit(g,a,frost)
	check(g.fx.skill_events.size()==1 and g.fx.skill_events[0].id=="blizzard","blizzard emits one expanding frost front")
	check(g.bricks[0].frozen,"blizzard preserves frozen target state")
	g.dispose()
	g=fresh("prism");a=g.launch(Vector2(390,600),Vector2.UP*24)
	var prism:=brick(g,Vector2(390,400),1,"prism")
	hit(g,a,prism)
	check(g.fx.skill_events.size()==1 and g.fx.skill_events[0].id=="prism","prism emits a faceted split event")
	check(g.arrows.size()==7,"prism event does not replace split arrows")
	g.dispose()
	g=fresh("alchemist");a=g.launch(Vector2(390,600),Vector2.UP*24)
	var gold:=brick(g,Vector2(390,400),1,"gold")
	hit(g,a,gold)
	check(g.fx.skill_events.size()==1 and g.fx.skill_events[0].id=="alchemist","alchemist emits a minted reward event")
	check(g.state.coins>0,"alchemist retains gold reward")
	var rng_state:int=g.rng.state
	for i in range(100):g.fx.skill_event("prism",Vector2(i,200))
	check(g.fx.skill_events.size()==64,"third batch shares the bounded skill queue")
	check(g.rng.state==rng_state,"third batch presentation does not consume gameplay RNG")
	g.fx.advance_visual(1)
	check(g.fx.skill_events.is_empty(),"third batch events expire on visual time")
	g.fx.skill_event("storm",Vector2.ZERO,Vector2.RIGHT,Vector2.ONE);g.fx.reset()
	check(g.fx.skill_events.is_empty(),"third batch resets with the board")
	g.dispose()
	print("Native skill batch three: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
