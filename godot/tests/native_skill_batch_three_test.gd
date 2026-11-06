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
	check(g.fx.specials.is_empty() and g.fx.bolts.is_empty(),"Storm upgrade does not double-draw the brick or hops")
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
	for fragment in g.arrows.slice(1):
		check(is_equal_approx(fragment.damage,a.damage*0.5) and is_equal_approx(fragment.base_damage,fragment.damage),"prism halves damage without multiplying launch bonuses twice")
		check(is_equal_approx(fragment.velocity.length(),a.velocity.length()*0.5),"prism halves source speed")
		check(fragment.pierce==maxi(1,floori(a.pierce*0.5)) and fragment.flags.get("noSkills",false),"prism halves penetration and disables skills")
	var fragment:RefCounted=g.arrows[1]
	g.state.skills={"blast":1,"cascade":1,"nova":1,"poison":1,"ice":1,"ambush":1,"rhythm":1,"ricochet":1,"bankshot":1,"spectral":1,"siegebreaker":1,"boomerang":1,"seeking":1,"corehunter":1,"jackpot":1,"bounty":1}
	g.fx.reset()
	var target:=brick(g,Vector2(440,400),10000)
	g.active_arrow=fragment;g.skills.projectile_hit(target,fragment);g.active_arrow=null
	check(is_equal_approx(target.hp,10000-fragment.damage) and not target.frozen,"fragment hits only for its own damage without hit skills")
	check(g.skills.jobs.is_empty() and g.skills.fields.is_empty(),"fragment hit schedules no skill work")
	var before_velocity:Vector2=fragment.velocity
	var before_pierce:int=fragment.pierce
	fragment.life=1;g.core={"x":390.0,"y":80.0,"born":g.time};g.guide(fragment,0.1)
	g.skills.bounce(fragment)
	var wall:RefCounted=g.make_obstacle({"x":300,"y":300})
	check(not g.skills.wall(fragment,wall) and wall in g.obstacles,"fragment cannot phase through or destroy obstacles")
	check(fragment.velocity==before_velocity and fragment.pierce==before_pierce,"fragment cannot guide, return, gain penetration or spawn bounce arrows")
	var victim:=brick(g,Vector2(600,600))
	hit(g,fragment,victim)
	check(g.skills.jobs.is_empty() and g.arrows.size()==7 and g.fx.skill_events.is_empty(),"fragment kill triggers no skills, including jackpot and rebirth")
	g.state.skills={"prism":1,"spectral":1,"timeslip":1}
	var chained:=brick(g,Vector2(600,200),1,"prism")
	hit(g,fragment,chained)
	check(g.arrows.size()==10,"fragment can activate another prism brick but not its skill upgrade")
	check(is_equal_approx(g.arrows.back().damage,a.damage*0.5),"chained prism inherits the original arrow rather than halving fragments again")
	check(g.arrows.back().pierce==maxi(1,floori(a.pierce*0.5)),"chained prism does not reapply passive penetration bonuses")
	g.dispose()
	g=fresh("prism");g.state.skills={}
	a=g.launch(Vector2(390,600),Vector2.UP*30,20,5)
	prism=brick(g,Vector2(390,400),1,"prism");hit(g,a,prism)
	check(g.arrows.size()==4 and g.arrows[1].damage==10 and g.arrows[1].pierce==2,"ordinary prism emits three half-stat arrows and rounds penetration down")
	a.pierce=1
	g.active_arrow=a;fragment=g.launch_prism(Vector2(390,300),Vector2.UP);g.active_arrow=null
	check(fragment.pierce==1,"fragment penetration has a minimum of one")
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
