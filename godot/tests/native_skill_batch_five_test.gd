extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func fresh(id:String) -> RefCounted:
	var g:=Sim.new();g.start(9128);g.bricks.clear();g.obstacles.clear();g.fx.reset();g.skills.reset()
	g.state.skills={id:1};g.phase="flying";g.initial=1000
	g.intro_active=false;g.locked_until=0;g.next_shot_at=0
	return g

func brick(g:RefCounted,hp:float=100) -> RefCounted:
	return g.make_brick({"x":390,"y":440,"hp":hp,"max":hp})

func hit(g:RefCounted,a:RefCounted,b:RefCounted) -> void:
	g.skills.with_source(a,func():g.skills.projectile_hit(b,a))

func _initialize() -> void:
	var g:=fresh("legion")
	check(g.shoot(0,100),"first real shot accepted")
	check(g.fx.skill_events.is_empty() and g.arrows.size()==1,"legion does not fire early")
	g.time=g.next_shot_at;g.shoot(0,100)
	check(g.fx.skill_events.is_empty() and g.arrows.size()==2,"legion second shot remains ordinary")
	g.time=g.next_shot_at;g.shoot(0,100)
	check(g.arrows.size()==9,"third shot retains six additional gameplay arrows")
	check(g.fx.skill_events.size()==1 and g.fx.skill_events[0].id=="legion","third shot creates one bounded launch event")
	check(g.fx.skill_events[0].direction==Vector2.UP,"legion direction follows real shot")
	g.dispose()
	g=fresh("legion");g.state.skillRuntime.shots=2
	for i in range(63):g.launch(Vector2(390,460),Vector2.UP*24)
	g.shoot(0,100)
	check(g.arrows.size()==64 and g.fx.skill_events.is_empty(),"legion does not flash when capacity rejects all bonus arrows")
	g.dispose()
	g=fresh("ambush");var a:RefCounted=g.launch(Vector2(390,460),Vector2.UP*24);var b:=brick(g)
	var damage:float=a.damage
	hit(g,a,b)
	check(is_equal_approx(b.hp,100-damage*3),"ambush preserves full-health triple damage")
	check(g.fx.skill_events.size()==1 and g.fx.skill_events[0].id=="ambush","full health hit creates armour breach")
	hit(g,a,b)
	check(g.fx.skill_events.size()==1 and is_equal_approx(b.hp,100-damage*4),"damaged brick does not retrigger ambush")
	g.dispose()
	g=fresh("poison");a=g.launch(Vector2(390,460),Vector2.UP*24);b=brick(g)
	damage=g.damage();hit(g,a,b)
	check(g.fx.skill_events.is_empty(),"poison waits for real DOT tick")
	check(g.skills.jobs.size()==3,"poison retains three delayed hits")
	for i in range(1,4):
		g.time=i*0.15+0.001;g.fx.advance_visual(0.15);g.skills.update(0)
		check(is_equal_approx(b.hp,100-damage-damage*0.8*i),"poison tick %d preserves damage" % i)
		check(g.fx.skill_events.back().id=="poison" and is_equal_approx(g.fx.skill_events.back().born,g.fx.visual_time),"poison tick %d uses current visual clock" % i)
	check(g.skills.jobs.is_empty(),"poison delayed work completes")
	g.dispose()
	g=fresh("poison");a=g.launch(Vector2(390,460),Vector2.UP*24);b=brick(g,1);hit(g,a,b)
	g.time=0.6;g.skills.update(0)
	check(g.fx.skill_events.is_empty(),"poison dead target cannot produce ghost ticks")
	g.dispose()
	g=fresh("siphon");a=g.launch(Vector2(390,460),Vector2.UP*24)
	var pierce:int=a.pierce;damage=a.damage
	for i in range(9):b=brick(g,1);hit(g,a,b)
	check(g.fx.skill_events.size()==8,"siphon obeys eight rewards per source arrow")
	check(a.pierce==pierce+8 and is_equal_approx(a.damage,damage*3),"siphon preserves penetration and base-damage growth")
	check(g.fx.skill_events[0].target==a.position,"siphon stores source position snapshot")
	var other:RefCounted=g.launch(Vector2(420,460),Vector2.UP*24);b=brick(g,1);hit(g,other,b)
	check(g.fx.skill_events.size()==9,"siphon budget is per arrow")
	b=brick(g);hit(g,other,b)
	check(g.fx.skill_events.size()==9,"siphon surviving target does not reward")
	g.dispose()
	for id in ["legion","poison","ambush","siphon"]:
		g=fresh(id);var rng_state:int=g.rng.state
		for i in range(90):g.fx.skill_event(id,Vector2(i,440),Vector2.UP,Vector2(390,460),1,0.58)
		check(g.fx.skill_events.size()==64 and g.fx.skill_events[0].position.x==26,"%s bounded queue evicts oldest" % id)
		check(g.rng.state==rng_state,"%s visual events do not consume gameplay RNG" % id)
		g.time+=10
		check(g.fx.skill_events.size()==64,"%s events are independent of simulation time" % id)
		g.fx.advance_visual(0.7)
		check(g.fx.skill_events.is_empty(),"%s expires on visual time" % id)
		g.fx.skill_event(id,Vector2.ZERO);g.fx.reset()
		check(g.fx.skill_events.is_empty() and g.fx.visual_time==0,"%s reset clears event and clock" % id)
		g.dispose()
	if DisplayServer.get_name()!="headless":call_deferred("graphics")
	else:finish()

func finish() -> void:
	print("Native skill batch five: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func graphics() -> void:
	var output:=ProjectSettings.globalize_path("res://../agent-tmp/godot/skill-batch-five")
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(780,1080)
	await process_frame
	for dark in [false,true]:
		for reduced in [false,true]:
			var g:=fresh("legion");g.theme="dark" if dark else "light";g.state.performanceMode=reduced
			RenderingServer.set_default_clear_color(Color("#191f1b" if dark else "#d5d9cc"))
			g.state.skills={"legion":1,"poison":1,"ambush":1,"siphon":1}
			for row in range(5):
				for col in range(7):g.make_brick({"x":135+col*85,"y":340+row*50,"hp":100,"max":100,"w":76,"h":36})
			g.origin=Vector2(390,630);g.state.skillRuntime.shots=2;g.shoot(0,100)
			var a:RefCounted=g.arrows[0];a.position=Vector2(390,460)
			hit(g,a,g.bricks[17]);g.bricks[18].hp=1;hit(g,a,g.bricks[18])
			g.time=0.151;g.fx.advance_visual(0.151);g.skills.update(0)
			var kinds:Array=[]
			for event in g.fx.skill_events:
				if event.id not in kinds:kinds.append(event.id)
			check(kinds.size()==4,"combined real hooks produce all four overlapping batch-five effects")
			var hp:float=g.bricks[17].hp;var damage:float=a.damage;var rng_state:int=g.rng.state
			var board:=preload("res://src/render/board.gd").new();board.simulation=g;root.add_child(board);board.set_process(false)
			board._process(0)
			await process_frame
			await RenderingServer.frame_post_draw
			var peak:=root.get_texture().get_image()
			peak.save_png(output+"/overlap-%s-%s.png" % [g.theme,"reduced" if reduced else "full"])
			g.fx.advance_visual(2);board._process(0)
			await process_frame
			await RenderingServer.frame_post_draw
			var tail:=root.get_texture().get_image()
			check(peak.get_data()!=tail.get_data(),"combined geometry is visible and fades in %s reduced=%s" % [g.theme,reduced])
			check(g.fx.skill_events.is_empty(),"GUI tail contains no batch-five events")
			check(g.bricks[17].hp==hp and a.damage==damage and g.rng.state==rng_state,"rendering does not mutate damage or gameplay RNG")
			board.queue_free();g.dispose();await process_frame
	finish()
