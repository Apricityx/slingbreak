extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
const Renderer=preload("res://src/render/skill_batch_six.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func fresh(id:String) -> RefCounted:
	var g:=Sim.new();g.start(9128);g.variants.reset();g.bricks.clear();g.obstacles.clear();g.fx.reset();g.skills.reset()
	g.state.skills={id:1};g.state.skillChosenLevel=g.state.level;g.phase="flying";g.initial=1000;g.threshold=1000
	return g

func brick(g:RefCounted,point:Vector2,hp:float=100) -> RefCounted:
	return g.make_brick({"x":point.x,"y":point.y,"hp":hp,"max":hp,"w":30,"h":20})

func hit(g:RefCounted,a:RefCounted,b:RefCounted) -> void:
	g.active_arrow=a;g.skills.projectile_hit(b,a);g.active_arrow=null

func events(g:RefCounted,id:String) -> Array:
	return g.fx.skill_events.filter(func(e):return e.id==id)

func _initialize() -> void:
	var g:=fresh("opportunist")
	var a:RefCounted=g.launch(Vector2(390,600),Vector2.UP*25,2)
	var b:=brick(g,Vector2(390,400))
	hit(g,a,b)
	check(b.hp==98 and events(g,"opportunist").is_empty(),"opportunist ignores full-health target")
	hit(g,a,b)
	check(b.hp==92 and events(g,"opportunist").size()==1,"wounded target retains exact triple damage and one impact")
	check(events(g,"opportunist")[0].direction==Vector2.UP,"pursuit follows actual arrow direction")
	check(g.fx.signatures.is_empty(),"opportunist has no duplicate generic signature")
	g.dispose()
	g=fresh("bounty");a=g.launch(Vector2(390,600),Vector2.UP*25,2)
	for index in range(10):
		b=brick(g,Vector2(300+index*10,400),1)
		var expected:float=g.reward("normal",index+1)
		var paid:float=a.achievement.paid
		var base:float=a.achievement.base
		g.active_arrow=a;g.hit(b,2,1 if index%2 else 0);g.active_arrow=null
		check(is_equal_approx(a.achievement.base-base,expected),"bounty reward preserved for kill %d" % (index+1))
		check(a.achievement.paid>paid,"bounty settlement remains positive")
		check(events(g,"bounty").size()==index,"bounty skips first kill, includes attributed chain kills")
	check(is_equal_approx(a.achievement.bountyMult,3),"bounty multiplier still caps at three")
	check(is_equal_approx(events(g,"bounty")[8].strength,1.2),"bounty visual strength is bounded at cap")
	var second:RefCounted=g.launch(Vector2(390,600),Vector2.UP*25,2)
	b=brick(g,Vector2(500,400),1);hit(g,second,b)
	check(events(g,"bounty").size()==9,"new arrow starts its own bounty chain")
	g.dispose()
	g=fresh("nailburst");a=g.launch(Vector2(390,600),Vector2.UP*25,2);a.flags.main=true
	b=brick(g,Vector2(390,400));hit(g,a,b)
	check(g.arrows.size()==4 and events(g,"nailburst").size()==1,"first main-arrow hit spawns three children and one shell burst")
	for child in g.arrows.slice(1):
		check(child.hit.has(b.id) and child.overlap.has(b.id),"nail child preserves originating-brick immunity")
		check(is_equal_approx(child.damage,g.damage()*0.9) and child.pierce==2,"nail child damage and pierce unchanged")
	hit(g,a,b);hit(g,g.arrows[1],b)
	check(events(g,"nailburst").size()==1 and g.arrows.size()==4,"repeat hits and children cannot retrigger nailburst")
	check(g.fx.explosions.is_empty() and g.fx.signatures.is_empty(),"nailburst replaces generic fireball and signature")
	g.dispose()
	g=fresh("fusepath");a=g.launch(Vector2(390,600),Vector2.UP*25,1)
	var points:Array=[]
	for i in range(5):points.append(brick(g,Vector2(250+i*70,400)))
	hit(g,a,points[0]);hit(g,a,points[0])
	check(g.skills.jobs.is_empty() and events(g,"fusepath").is_empty(),"fuse first point and repeat point cannot create a segment")
	hit(g,a,points[1]);hit(g,a,points[2]);hit(g,a,points[3]);hit(g,a,points[4])
	check(a.flags.fuse.size()==4 and g.skills.jobs.size()==3,"fuse keeps four distinct points and three delayed jobs")
	check(events(g,"fusepath").size()==3,"fuse emits one arming event per accepted segment")
	check(events(g,"fusepath")[0].position==points[0].position and events(g,"fusepath")[0].target==points[1].position,"fuse snapshots exact collision endpoints")
	var middle:=brick(g,Vector2(285,400))
	g.time+=0.249;g.skills.update(0.249)
	check(middle.hp==100,"fuse damage never arrives before 0.25 seconds")
	g.fx.advance_visual(0.25);g.time+=0.0011;g.skills.update(0.0011)
	check(is_equal_approx(middle.hp,100-g.damage()*1.5),"fuse retains swept segment damage at deadline")
	check(events(g,"fusepath").size()==3 and events(g,"fusepath")[0].strength==1.2,"arming expires and real damage emits a fresh burn event")
	check(g.fx.beams.is_empty() and g.fx.signatures.is_empty(),"fuse replaces generic beams only on its own path")
	g.dispose()
	for id in ["opportunist","bounty","nailburst","fusepath"]:
		g=fresh(id)
		var rng_state:int=g.rng.state
		for i in range(100):g.fx.skill_event(id,Vector2(i,400),Vector2.UP,Vector2(500,400),1,0.69)
		check(g.fx.skill_events.size()==64 and g.fx.skill_events[0].position.x==36,"%s evicts oldest at 64 snapshots" % id)
		check(g.rng.state==rng_state,"%s never consumes gameplay RNG" % id)
		g.fx.update(10)
		check(g.fx.skill_events.size()==64,"%s lifetime belongs to visual clock" % id)
		g.fx.advance_visual(0.7)
		check(g.fx.skill_events.is_empty(),"%s expires on visual clock" % id)
		g.fx.skill_event(id,Vector2.ZERO);g.fx.reset()
		check(g.fx.skill_events.is_empty() and g.fx.visual_time==0,"%s reset clears events and clock" % id)
		g.dispose()
	print("Native skill batch six: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
