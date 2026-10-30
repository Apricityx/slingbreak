extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
var failures:=0
var checks:=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func fresh(storm:bool=false) -> RefCounted:
	var g:=Sim.new();g.start(9128);g.state.skills={"storm":1} if storm else {}
	g.bricks.clear();g.obstacles.clear();g.fx.reset();g.skills.reset()
	g.phase="flying";g.initial=1000;g.board_entrance=null
	return g

func brick(g:RefCounted,point:Vector2,hp:float,type:String="normal") -> RefCounted:
	return g.make_brick({"x":point.x,"y":point.y,"hp":hp,"max":hp,"type":type})

func _initialize() -> void:
	var g:=fresh()
	g.fx.special_break(Vector2(100,100),"lightning")
	check(g.fx.specials.is_empty() and g.fx.skill_events.is_empty(),"no endpoint-free radial electric impact remains")
	g.fx.special_break(Vector2(200,100),"gold")
	var gold:Dictionary=g.fx.specials[0]
	check(is_equal_approx(gold.max,0.58),"coin brick uses a quick burst duration")
	g.fx.advance_visual(0.6)
	check(g.fx.specials.is_empty(),"coin burst fades cleanly")
	for index in range(100):g.fx.special_break(Vector2(index,200),"gold")
	check(g.fx.specials.size()==48,"special queue remains bounded")
	g.dispose()
	for storm in [false,true]:
		for reduced in [false,true]:
			g=fresh(storm);g.state.performanceMode=reduced
			var source:RefCounted=g.launch(Vector2(390,600),Vector2.UP*24)
			var origin:=Vector2(140,400)
			var lightning:=brick(g,origin,1,"lightning")
			var targets:Array=[]
			for i in range(8):targets.append(brick(g,origin+Vector2((i+1)*60,0),100))
			g.active_arrow=source;g.hit(lightning,100);g.active_arrow=null
			var count:=7 if storm else 5
			check(g.fx.skill_events.size()==count,"exactly one Storm event per hop, skill=%s reduced=%s" % [storm,reduced])
			check(g.fx.specials.is_empty() and g.fx.bolts.is_empty(),"no old radial or duplicate legacy bolt")
			var previous:=origin
			for i in range(8):
				check(is_equal_approx(targets[i].hp,100-g.damage()*(2 if storm else 1.6) if i<count else 100),"unchanged target selection and damage %d" % i)
				if i>=count:continue
				var event:Dictionary=g.fx.skill_events[i]
				check(event.id=="storm" and event.position==previous and event.target==targets[i].position,"hop uses actual gameplay endpoints %d" % i)
				check(is_equal_approx(event.max,0.5),"shared Storm lifetime %d" % i)
				previous=targets[i].position
			check(source.kills==1 and g.active_arrow==null,"source attribution unchanged")
			var rng_state:int=g.rng.state
			for i in range(100):g.fx.skill_event("storm",origin,Vector2.RIGHT,origin+Vector2(60+i,0))
			check(g.fx.skill_events.size()==64 and g.fx.specials.is_empty(),"Storm uses existing 64-event budget only")
			check(g.rng.state==rng_state,"Storm presentation consumes no gameplay RNG")
			g.fx.advance_visual(0.51)
			check(g.fx.skill_events.is_empty(),"all hops expire on visual time")
			g.fx.skill_event("storm",origin,Vector2.RIGHT,previous);g.fx.reset()
			check(g.fx.skill_events.is_empty() and g.fx.skill_event_serial==0,"active reset removes hops and serial")
			g.dispose()
	# Recursive electric bricks preserve nested hop ordering and kill ownership.
	g=fresh();var source:RefCounted=g.launch(Vector2(390,600),Vector2.UP*24)
	var first:=brick(g,Vector2(200,400),1,"lightning")
	brick(g,Vector2(260,400),1,"lightning");brick(g,Vector2(320,400),1)
	g.active_arrow=source;g.hit(first,100);g.active_arrow=null
	check(g.bricks.is_empty() and source.kills==3,"nested chain kills remain attributed to original arrow")
	check(g.fx.skill_events.size()==3 and g.fx.bolts.is_empty(),"nested chain emits original hop count without duplicates")
	g.dispose()
	g=fresh();g.hit(brick(g,Vector2(390,400),1,"lightning"),100)
	check(g.fx.skill_events.is_empty() and g.fx.specials.is_empty(),"no fake targets when electric brick has no neighbours")
	g.dispose();print("Native special bricks: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
