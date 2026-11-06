extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
const Renderer=preload("res://src/render/skill_batch_seven.gd")
var checks:=0
var failures:=0

class PaintProbe:
	extends Node2D
	var event:Dictionary
	var clock:=0.0
	var reduced:=false
	var dark:=false
	func _draw() -> void:
		Renderer.paint(self,event,clock,reduced,dark)

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func fresh(id:String) -> RefCounted:
	var g:=Sim.new();g.start(9128);g.bricks.clear();g.obstacles.clear();g.fx.reset();g.skills.reset()
	g.state.skills={id:1} if id!="" else {};g.state.skillChosenLevel=g.state.level
	g.phase="ready";g.initial=1000;g.board_entrance=null;g.locked_until=0;g.origin=Vector2(390,600)
	return g

func events(g:RefCounted,id:String) -> Array:
	return g.fx.skill_events.filter(func(e):return e.id==id)

func targets(g:RefCounted) -> void:
	for i in range(8):g.make_brick({"x":220+i*40,"y":300,"hp":100,"max":100,"w":30,"h":20})

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var g:=fresh("trident")
	var rng_state:int=g.rng.state
	check(g.shoot(0,100),"trident real shoot succeeds")
	check(g.arrows.size()==6 and events(g,"trident").size()==5,"trident keeps main plus five accepted extra arrows")
	for i in range(5):
		var arrow:RefCounted=g.arrows[i+1]
		var offset:float=(int(i/2)+1)*0.1*(-1 if i%2 else 1)
		check(is_equal_approx(arrow.velocity.angle(),-PI/2+offset),"trident exact fan lane %d" % i)
		check(events(g,"trident")[i].direction.is_equal_approx(arrow.velocity.normalized()),"trident snapshot tracks accepted direction")
		check(arrow.damage==g.damage() and arrow.pierce==g.penetration(),"trident child damage and pierce preserved")
	check(g.rng.state==rng_state,"trident launch presentation consumes no gameplay RNG")
	g.dispose()
	g=fresh("trident");g.state.skills.echo=1
	check(g.shoot(0,100),"echo combination real shoot succeeds")
	g.time+=0.24;g.skills.update(0.24)
	check(g.arrows.size()==12 and events(g,"trident").size()==10,"echo repeats actual trident fan and launch art at 0.24s")
	g.dispose()
	g=fresh("trident")
	for i in range(62):g.launch(Vector2.ZERO,Vector2.UP)
	check(g.shoot(0,100),"partially capped fan accepts its main")
	check(g.arrows.size()==64 and events(g,"trident").size()==1,"partial cap emits only one accepted extra lane")
	check(not g.shoot(0,100) and events(g,"trident").size()==1,"rejected shot has no phantom trident event")
	g.dispose()
	g=fresh("rapid");rng_state=g.rng.state
	check(g.shoot(0,100),"rapid real shoot succeeds")
	check(is_equal_approx(g.next_shot_at,g.time+0.18) and events(g,"rapid").size()==1,"rapid keeps exact 0.18s cooldown")
	g.time+=0.179
	check(not g.shoot(0,100) and events(g,"rapid").size()==1,"rapid early shot rejected without art")
	g.time+=0.0011
	check(g.shoot(0,100) and events(g,"rapid").size()==2,"rapid becomes shootable at original deadline")
	check(g.rng.state==rng_state,"rapid has no gameplay RNG")
	g.dispose()
	g=fresh("hunters");targets(g);rng_state=g.rng.state
	check(g.shoot(0,100),"hunters real shoot succeeds")
	check(g.arrows.size()==5 and events(g,"hunters").size()==4,"four accepted homing arrows emit four launch snapshots")
	for i in range(4):
		var arrow:RefCounted=g.arrows[i+1]
		check(arrow.flags.homing and arrow.flags.hunterFx,"hunter owns homing and visual attribution")
		check(arrow.position==g.origin+Vector2(36 if i%2 else -36,0),"hunter exact side origin")
		check(arrow.damage==g.damage() and arrow.pierce==g.penetration(),"hunter numerical parameters preserved")
	var hunter:RefCounted=g.arrows[1]
	var old_velocity:Vector2=hunter.velocity
	g.guide(hunter,1.0/60)
	check(not hunter.velocity.is_equal_approx(old_velocity),"hunter still steers through production homing")
	var b:RefCounted=g.bricks[0]
	g.active_arrow=hunter;g.skills.projectile_hit(b,hunter);g.active_arrow=null
	check(events(g,"hunters").size()==5 and events(g,"hunters")[-1].strength==1.2,"actual hunter contact emits distinct sting")
	check(b.hp==100-hunter.damage,"hunter sting preserves damage")
	g.skills.projectile_hit(b,g.arrows[0])
	check(events(g,"hunters").size()==5,"ordinary main arrow cannot emit a hunter sting")
	check(g.rng.state==rng_state,"hunter art leaves gameplay RNG unchanged")
	g.dispose()
	g=fresh("hunters")
	for i in range(63):g.launch(Vector2.ZERO,Vector2.UP)
	g.shoot(0,100)
	check(events(g,"hunters").is_empty(),"fully capped hunters do not emit phantom wings")
	g.dispose()
	g=fresh("meteor");targets(g)
	var control:=fresh("");targets(control)
	var expected:Array=control.shuffle(control.bricks).slice(0,6)
	var expected_velocity:Array=[]
	for i in range(6):expected_velocity.append(Vector2(control.rng.randf_range(-9,9),18))
	check(g.shoot(0,100) and g.skills.jobs.size()==6,"meteor schedules six unchanged delayed launches")
	check(events(g,"meteor").is_empty(),"meteor has no event before delayed callback")
	for i in range(6):
		g.time=i*0.04+0.000001;g.skills.update(0)
		check(events(g,"meteor").size()==i+1,"meteor launch cadence remains 0.04s")
		var arrow:RefCounted=g.arrows[i+1]
		check(arrow.position==Vector2(expected[i].x,142) and arrow.velocity.is_equal_approx(expected_velocity[i]),"meteor seeded target and velocity preserved")
		check(arrow.damage==g.damage()*2 and arrow.pierce==2 and arrow.color==Color("#d38b63"),"meteor damage/pierce/color preserved")
	check(g.rng.state==control.rng.state,"meteor matches exact original shuffle plus six random velocities")
	b=g.bricks[0];var meteor:RefCounted=g.arrows[1]
	g.skills.projectile_hit(b,meteor)
	check(events(g,"meteor").size()==7 and events(g,"meteor")[-1].position==b.position and events(g,"meteor")[-1].strength==1.2,"meteor actual contact emits local impact")
	check(b.hp==100-meteor.damage,"meteor impact art does not add area damage")
	g.dispose();control.dispose()
	g=fresh("meteor");g.shoot(0,100)
	check(g.skills.jobs.is_empty() and events(g,"meteor").is_empty(),"empty board produces no meteor phantom")
	g.dispose()
	g=fresh("meteor");targets(g)
	for i in range(63):g.launch(Vector2.ZERO,Vector2.UP)
	g.shoot(0,100);g.time+=1;g.skills.update(1)
	check(g.arrows.size()==64 and events(g,"meteor").is_empty(),"delayed meteor cap rejects visuals with launch")
	g.dispose()
	for id in Renderer.IDS:
		# Full and reduced presentation must produce the same entire live trajectory.
		g=fresh(id);targets(g)
		var reduced_sim:=fresh(id);targets(reduced_sim);reduced_sim.state.performanceMode=true
		g.shoot(0,100);reduced_sim.shoot(0,100)
		var same:=true
		for frame in range(60):
			g.fx.advance_visual(1.0/60);reduced_sim.fx.advance_visual(1.0/60)
			g.tick(1.0/60);reduced_sim.tick(1.0/60)
			if g.arrows.size()!=reduced_sim.arrows.size():same=false;break
			for i in range(g.arrows.size()):
				if g.arrows[i].position!=reduced_sim.arrows[i].position or g.arrows[i].velocity!=reduced_sim.arrows[i].velocity:same=false
		check(same,"%s full/reduced preserve every 60Hz trajectory sample" % id)
		check(g.rng.state==reduced_sim.rng.state,"%s full/reduced preserve gameplay RNG state" % id)
		check(g.bricks.map(func(b):return b.hp)==reduced_sim.bricks.map(func(b):return b.hp),"%s full/reduced preserve actual collision damage" % id)
		g.dispose();reduced_sim.dispose()
		g=fresh(id);rng_state=g.rng.state
		for i in range(100):g.fx.skill_event(id,Vector2(i,400),Vector2.UP,Vector2.ZERO,1,0.58)
		check(g.fx.skill_events.size()==64 and g.fx.skill_events[0].position.x==36,"%s bounds queue and evicts oldest" % id)
		check(g.rng.state==rng_state,"%s event flood isolates gameplay RNG" % id)
		g.fx.update(10)
		check(g.fx.skill_events.size()==64,"%s ignores gameplay-clock ageing" % id)
		g.fx.advance_visual(0.59)
		check(g.fx.skill_events.is_empty(),"%s expires on visual clock" % id)
		g.fx.skill_event(id,Vector2.ZERO);g.fx.reset()
		check(g.fx.skill_events.is_empty() and g.fx.visual_time==0,"%s reset clears presentation" % id)
		g.dispose()
	if DisplayServer.get_name()!="headless":await graphics()
	print("Native skill batch seven: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func ink_pixels(image:Image) -> int:
	var count:=0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a>0.05:count+=1
	return count

func graphics() -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(224,224);viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var probe:=PaintProbe.new();viewport.add_child(probe)
	for id in Renderer.IDS:
		var g:=fresh(id)
		for reduced in [false,true]:
			for dark in [false,true]:
				for strength in ([0.55,1.2] if id in ["meteor","hunters"] else [1.0]):
					g.fx.skill_event(id,Vector2(112,138),Vector2.UP,Vector2.ZERO,strength,0.58)
					probe.event=g.fx.skill_events[-1];probe.reduced=reduced;probe.dark=dark
					probe.clock=0.08;probe.queue_redraw()
					await process_frame;await RenderingServer.frame_post_draw
					check(ink_pixels(viewport.get_texture().get_image())>35,"GUI %s reduced=%s dark=%s phase=%s has rendered peak" % [id,reduced,dark,strength])
					probe.clock=0.59;probe.queue_redraw()
					await process_frame;await RenderingServer.frame_post_draw
					check(ink_pixels(viewport.get_texture().get_image())==0,"GUI %s has no post-lifetime geometry" % id)
		g.dispose()
	viewport.queue_free();await process_frame
	# Integration regression: a correctly painted release can still be hidden by
	# Board's opaque launcher pad if dispatched into its background pass.
	for dark in [false,true]:
		var g:=fresh("rapid");g.theme="dark" if dark else "light";g.state.performanceMode=dark
		g.origin=Vector2(390,600)
		var board_view:=SubViewport.new();board_view.size=Vector2i(224,224)
		board_view.transparent_bg=true;board_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(board_view)
		var board:=preload("res://src/render/board.gd").new();board.simulation=g;board_view.add_child(board)
		board.set_process(false);board._process(0);board.position=Vector2(-278,-480)
		await process_frame;await RenderingServer.frame_post_draw
		var baseline:Image=board_view.get_texture().get_image()
		g.fx.skill_event("rapid",g.origin,Vector2.UP,Vector2.ZERO,1,0.36);g.fx.advance_visual(0.08)
		board._process(0)
		await process_frame;await RenderingServer.frame_post_draw
		var peak:Image=board_view.get_texture().get_image()
		var changed:=0
		for y in range(94,146):
			for x in range(70,155):
				if baseline.get_pixel(x,y)!=peak.get_pixel(x,y):changed+=1
		check(changed>80,"GUI Board rapid string remains visible ABOVE launcher pad dark=%s" % dark)
		g.dispose();board_view.queue_free();await process_frame
