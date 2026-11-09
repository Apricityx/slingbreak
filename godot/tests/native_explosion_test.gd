extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
const Blast=preload("res://src/render/bomb_batch.gd")
const Fixture=preload("res://tools/preview_explosive_skills.gd")
const LIVE_SKILLS={"blast":[1,125.0],"aftershock":[2,112.0],"doubletap":[1,115.0],"minefield":[3,135.0],"frostfire":[1,100.0],"cascade":[1,145.0],"orbital":[3,160.0],"stormfront":[3,360.0],"undertow":[1,110.0],"starforge":[1,170.0],"siegebreaker":[1,155.0],"supernova":[1,180.0]}
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")

func run() -> void:
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
	check(g.fx.bombs.size()==1 and g.fx.explosions.is_empty() and g.fx.specials.is_empty(),"bomb uses the upgraded blast event without a legacy fire volume")
	for index in range(60):g.fx.bomb_blast(Vector2(index,100))
	check(g.fx.bombs.size()==16,"bomb chains stay within the blast batch capacity")
	g.fx.advance_visual(1.11)
	check(g.fx.bombs.is_empty(),"bomb blasts expire")
	g.fx.reset();g.bricks.clear();g.sounds.clear();g.last_sounds.clear();g.state.sound=true;g.paused=false
	var bomb:RefCounted=g.make_brick({"x":300,"y":500,"hp":1,"type":"bomb"})
	var second:RefCounted=g.make_brick({"x":380,"y":500,"hp":1,"type":"bomb"})
	var outside:RefCounted=g.make_brick({"x":300,"y":800,"hp":1,"type":"normal"})
	g.hit(bomb,2)
	check(g.fx.bombs.size()==2 and g.fx.rings.is_empty() and g.fx.particles.is_empty(),"bomb chain is GPU blasts only: no ring or CPU burst")
	check(not g.bricks.has(second) and g.bricks.has(outside),"blast damages within its 132 px radius only")
	var bomb_cues:Array=g.sounds.filter(func(v):return v.type=="bomb")
	check(bomb_cues.size()==2 and bomb_cues[1].n==2 and not g.sounds.any(func(v):return v.type=="boom"),"chain bombs carry depth and skip the synthetic boom")
	check(is_equal_approx(g.fx.bombs[1].intensity,0.82),"chained bombs are slightly smaller")
	g.fx.normal_break(Vector2(100,100),Color("#dce2d0"))
	check(g.fx.normal_breaks.size()==1,"normal brick break queues one bounded presentation event")
	g.fx.advance_visual(0.5)
	check(g.fx.normal_breaks.is_empty(),"normal brick shards expire quickly")
	g.fx.reset()
	var brick:RefCounted=g.make_brick({"x":300,"y":300,"hp":1,"type":"normal"})
	g.hit(brick,2)
	check(g.fx.normal_breaks.size()==1 and g.fx.particles.is_empty() and g.fx.rings.is_empty(),"normal kill is one GPU shatter, no CPU particles or ring")
	check(g.fx.normal_breaks[0].size==Vector2(brick.w,brick.h) and is_equal_approx(g.fx.normal_breaks[0].heading.length(),1.0),"shatter carries the real brick size and a unit heading")
	for index in range(200):g.fx.normal_break(Vector2(index,100),Color.WHITE,1.0,Vector2(76,36),Vector2(index-100,1))
	check(g.fx.normal_breaks.size()==72,"dense chains stay within the shatter batch capacity")
	g.fx.reset()
	check(g.fx.explosions.is_empty() and g.fx.bombs.is_empty(),"new board clears effects")
	var explosive_ids:= ["blast","shatter","aftershock","doubletap","minefield","frostfire","cascade","orbital","stormfront","undertow","starforge","siegebreaker"]
	for index in range(explosive_ids.size()):
		g.fx.reset()
		var point:=Vector2(120+index*45,300)
		var radius:float=70+index*5
		g.skills.detonate(point,radius,1.0,explosive_ids[index],0.86)
		if explosive_ids[index]=="shatter":
			check(g.fx.explosions.is_empty() and g.fx.bombs.is_empty() and g.fx.skill_events.size()==1,"shatter keeps its upgraded crystal impact instead of a fire blast")
		else:
			check(g.fx.bombs.size()==1 and g.fx.explosions.is_empty(),"explosive skill uses the upgraded batch only: "+explosive_ids[index])
			check(g.fx.bombs[0].position==point and g.fx.bombs[0].radius==radius and is_equal_approx(g.fx.bombs[0].intensity,0.86),"skill blast preserves point, radius and intensity: "+explosive_ids[index])
			check(g.fx.rings.is_empty(),"blast has no duplicate legacy ring: "+explosive_ids[index])
	g.fx.reset();g.skills.global_damage(1.0,"supernova",650)
	check(g.fx.bombs.size()==1 and g.fx.explosions.is_empty() and g.fx.bombs[0].radius==180 and g.fx.skill_events.size()==1 and g.fx.skill_events[0].id=="supernova","supernova shares the upgraded local blast and keeps its global target response")
	g.fx.reset();state=g.rng.state
	for index in range(100):
		g.fx.special_break(Vector2(index,100),"bomb")
		g.skills.detonate(Vector2(index,200),125,1,"blast")
	check(g.fx.bombs.size()==Blast.CAPACITY and g.fx.explosions.is_empty(),"bricks and skills share one bounded blast queue")
	check(g.rng.state==state,"mixed blast presentation preserves gameplay RNG")
	g.time+=10
	check(g.fx.bombs.size()==16,"blast lifetime belongs to visual time")
	g.fx.advance_visual(1.09)
	check(g.fx.bombs.size()==16,"full smoke tail survives until 1.1 seconds")
	g.fx.advance_visual(0.011)
	check(g.fx.bombs.is_empty(),"skill blasts expire at the upgraded 1.1-second lifetime")
	g.skills.detonate(Vector2.ZERO,100,1,"blast");g.fx.reset()
	check(g.fx.bombs.is_empty() and g.fx.explosions.is_empty(),"reset clears active skill blasts")
	g.dispose()
	for id in LIVE_SKILLS:
		var full:=live_skill(id,false)
		var reduced:=live_skill(id,true)
		check(full==reduced,"full/reduced preserve damage, rewards, RNG and jobs: "+id)
		g=fresh(id);g.bricks.clear()
		var radius:float=LIVE_SKILLS[id][1]
		var inside:RefCounted=g.make_brick({"x":390+radius-0.5,"y":440,"hp":100,"max":100})
		var outside_radius:RefCounted=g.make_brick({"x":390+radius+0.5,"y":440,"hp":100,"max":100})
		g.skills.detonate(Vector2(390,440),radius,7,id)
		check(inside.hp==93 and outside_radius.hp==100,"upgraded detonation preserves exact damage and radius boundary: "+id)
		g.dispose()
	if DisplayServer.get_name()!="headless":await graphics()
	print("Native explosion: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func fresh(id:String,reduced:bool=false) -> RefCounted:
	var g:=Sim.new();g.start(9128);g.variants.reset();g.skills.reset();g.fx.reset()
	g.bricks.clear();g.obstacles.clear();g.state.skills={id:1}
	g.phase="flying";g.board_entrance=null;g.state.draft=null;g.state.performanceMode=reduced
	for row in range(5):
		for col in range(5):g.make_brick({"x":220+col*85,"y":340+row*50,"hp":100,"max":100,"w":76,"h":36})
	return g

func live_skill(id:String,reduced:bool) -> Dictionary:
	var g:=fresh(id,reduced)
	var entry:Dictionary={"g":g,"id":id,"fired":false}
	var seen:Dictionary={}
	var legacy:=false
	var duplicate_ring:=false
	for frame in range(91):
		Fixture.step(entry,frame/60.0)
		legacy=legacy or not g.fx.explosions.is_empty()
		if id!="undertow":duplicate_ring=duplicate_ring or not g.fx.rings.is_empty()
		for event in g.fx.bombs:seen[event.seed]=event.duplicate()
	check(seen.size()==LIVE_SKILLS[id][0],"real hook creates the exact number of upgraded blasts: "+id)
	var skill_blasts:Array=seen.values()
	if id=="aftershock":skill_blasts=skill_blasts.filter(func(e):return e.radius!=132)
	check(not skill_blasts.is_empty() and skill_blasts.all(func(e):return e.radius==LIVE_SKILLS[id][1]),"real hook keeps the original blast radius: "+id)
	check(not legacy and not duplicate_ring,"real hook never renders legacy fire or duplicate ring: "+id)
	var targets:Array=[]
	for brick in g.bricks:targets.append([brick.position,brick.hp,brick.frozen])
	var snapshot:Dictionary={"bricks":targets,"rng":g.rng.state,"coins":g.state.coins,"killed":g.killed,"jobs":g.skills.jobs.size(),"fields":g.skills.fields.size(),"blasts":seen.values()}
	g.fx.advance_visual(1.2)
	check(g.fx.bombs.is_empty(),"real skill blast tail expires: "+id)
	g.dispose()
	return snapshot

func graphics() -> void:
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(560,470)
	for theme in ["light","dark"]:
		RenderingServer.set_default_clear_color(Color("#d5d9cc" if theme=="light" else "#191f1b"))
		for reduced in [false,true]:
			var g:=fresh("frostfire",reduced);g.theme=theme
			var board:=Board.new();board.simulation=g;root.add_child(board);board.set_process(false)
			var entry:Dictionary={"g":g,"id":"frostfire","fired":false}
			Fixture.step(entry,0);Fixture.step(entry,0.15);board._process(0);board.position=Vector2(-120,-225)
			check(board.bomb_batch.multimesh.visible_instance_count==1 and board.explosions.volumes.multimesh.visible_instance_count==0,"real skill fills only the upgraded GPU batch")
			check(board.foreground.get_index()<board.bomb_batch.get_index() and board.bomb_batch.get_index()<board.frost.get_index(),"blast overlay remains below persistent frost")
			check(board.bomb_batch.multimesh.get_instance_custom_data(0).b==100,"GPU payload keeps the actual skill radius")
			var mesh:Mesh=board.bomb_batch.multimesh.mesh
			var rng_state:int=g.rng.state;var hp:float=entry.target.hp
			board.bomb_batch.visible=false
			await process_frame;await RenderingServer.frame_post_draw
			var before:=root.get_texture().get_image()
			board.bomb_batch.visible=true
			await process_frame;await RenderingServer.frame_post_draw
			check(before.get_data()!=root.get_texture().get_image().get_data(),"upgraded skill blast contributes visible GPU pixels: %s reduced=%s" % [theme,reduced])
			check(g.rng.state==rng_state and entry.target.hp==hp,"blast rendering preserves gameplay")
			Fixture.step(entry,1.6);board._process(0)
			check(board.bomb_batch.multimesh.visible_instance_count==0 and g.fx.bombs.is_empty() and entry.target.frozen,"blast ends while the frost state survives")
			for index in range(100):g.skills.detonate(Vector2(390,440),100,0,"blast")
			board._process(0)
			check(board.bomb_batch.multimesh.visible_instance_count==Blast.CAPACITY and board.bomb_batch.multimesh.mesh==mesh,"saturated skills keep one fixed-capacity shared GPU mesh")
			g.fx.reset();board._process(0)
			check(board.bomb_batch.multimesh.visible_instance_count==0,"active reset clears the upgraded GPU batch")
			board.queue_free();await process_frame;g.dispose()

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
