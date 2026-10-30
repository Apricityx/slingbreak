extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
var failures:=0
var checks:=0

func _initialize() -> void:
	var g:=Sim.new();g.start(9128)
	var ids:= ["echo","piercer","seeking","ricochet"]
	for index in range(ids.size()):
		g.fx.skill_event(ids[index],Vector2(120+index*120,300),Vector2.RIGHT,Vector2(300+index*20,300),1.0,0.42)
		check(g.fx.skill_events[index].id==ids[index],"skill event stores id: "+ids[index])
		check(g.fx.skill_events[index].position==Vector2(120+index*120,300),"skill event stores point: "+ids[index])
	check(g.fx.skill_events.size()==4,"four ordinary skill events are queued")
	for index in range(80):g.fx.skill_event("echo",Vector2(index,200))
	check(g.fx.skill_events.size()==64,"skill event queue is bounded")
	g.fx.advance_visual(0.5)
	check(g.fx.skill_events.is_empty(),"skill events expire on the visual clock")
	g.fx.skill_event("ricochet",Vector2(200,200))
	g.fx.reset()
	check(g.fx.skill_events.is_empty(),"skill event queue resets with the board")
	g.dispose()
	print("Native skill effects: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
