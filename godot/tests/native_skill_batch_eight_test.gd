extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
const Batch=preload("res://src/render/skill_batch_eight.gd")
const Fixture=preload("res://tools/preview_skill_batch_eight.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func fresh(id:String) -> RefCounted:
	var g:=Sim.new();g.start(9128);g.bricks.clear();g.obstacles.clear();g.fx.reset();g.skills.reset()
	g.state.skills={id:1};g.phase="flying";g.initial=1000;g.threshold=1000
	g.intro_active=false;g.locked_until=0;g.next_shot_at=0;g.board_entrance=null
	return g

func brick(g:RefCounted,point:Vector2=Vector2(390,440),hp:float=100) -> RefCounted:
	return g.make_brick({"x":point.x,"y":point.y,"hp":hp,"max":hp})

func _initialize() -> void:
	var g:=fresh("nova");var b:=brick(g);var a:RefCounted=g.launch(Vector2(390,470),Vector2.UP*24)
	g.skills.with_source(a,func():g.skills.projectile_hit(b,a))
	check(g.fx.skill_events.is_empty(),"nova surviving target never emits rebirth")
	g.skills.with_source(a,func():g.hit(b,1000))
	check(g.fx.skill_events.is_empty() and g.skills.jobs.size()==1,"nova waits for delayed launch")
	g.time=0.081;g.skills.update(0)
	check(g.arrows.size()==4 and g.fx.skill_events.size()==1,"nova creates three real arrows and one birth event")
	check(g.fx.skill_events[0].targets.size()==3,"nova snapshot records three actual lanes")
	check(g.arrows[1].damage==g.damage()*1.5 and g.arrows[1].pierce==3,"nova preserves child damage and penetration")
	check(g.arrows[1].source==a,"nova delayed children preserve source attribution")
	for i in range(10):g.hit(brick(g,Vector2(200+i*20,440)),1000)
	check(g.round_uses.nova==8 and g.skills.jobs.size()==7,"nova keeps eight births per round")
	g.dispose()
	g=fresh("nova")
	for i in range(64):g.launch(Vector2(390,470),Vector2.UP*24)
	g.hit(brick(g),1000);g.time=0.081;g.skills.update(0)
	check(g.fx.skill_events.is_empty(),"nova capped arrows cannot emit phantom birth")
	g.dispose()
	g=fresh("nova")
	for i in range(63):g.launch(Vector2(390,470),Vector2.UP*24)
	g.hit(brick(g),1000);g.time=0.081;g.skills.update(0)
	check(g.fx.skill_events[0].targets.size()==1,"nova partial capacity records just the successful lane")
	g.dispose()
	g=fresh("crossfire");a=g.launch(Vector2(390,470),Vector2.UP*24);b=brick(g)
	var row:=brick(g,Vector2(560,440));var column:=brick(g,Vector2(390,290));var off:=brick(g,Vector2(475,390))
	var damage:float=g.damage()
	g.skills.with_source(a,func():g.skills.projectile_hit(b,a))
	check(g.fx.skill_events.is_empty(),"crossfire waits for actual delayed row and column hit")
	g.time=0.081;g.skills.update(0)
	check(b.hp==100-damage*4 and row.hp==100-damage*3 and column.hp==100-damage*3 and off.hp==100,"crossfire preserves exactly row/column triple damage")
	check(g.fx.skill_events.size()==1 and g.fx.skill_events[0].targets.size()==3,"crossfire snapshots exactly affected targets")
	g.skills.with_source(a,func():g.skills.projectile_hit(off,a))
	check(g.skills.jobs.is_empty(),"crossfire is once per source arrow")
	check(g.fx.beams.is_empty() and g.fx.signatures.is_empty(),"crossfire has no duplicate legacy beam")
	g.dispose()
	g=fresh("supernova");b=brick(g);damage=g.damage()
	for i in range(3):g.time=g.next_shot_at;g.shoot(0,100)
	check(g.skills.jobs.is_empty(),"supernova first three shots remain ordinary")
	g.time=g.next_shot_at;g.shoot(0,100)
	check(g.skills.jobs.size()==1 and g.fx.skill_events.is_empty(),"fourth shot schedules delayed supernova")
	g.time+=0.181;g.skills.update(0)
	check(b.hp==100-damage*5,"supernova retains five-times global damage")
	check(g.fx.skill_events.size()==1 and g.fx.skill_events[0].targets[0]==b.position,"supernova records global targets")
	check(g.fx.bombs.size()==1 and g.fx.explosions.is_empty() and g.fx.rings.is_empty(),"supernova uses the upgraded blast without a legacy fire volume or large ring")
	g.dispose()
	for win in [false,true]:
		g=fresh("jackpot");Fixture.seed_reward(g,win)
		var control:=fresh("jackpot");control.rng.state=g.rng.state
		var expected:float=control.reward("gold",4)
		var actual:float=g.reward("gold",4,Vector2(390,440))
		check(actual==expected and g.rng.state==control.rng.state,"jackpot outcome and RNG unchanged win=%s" % win)
		check(g.fx.skill_events[0].outcome==(10.0 if win else 1.5),"jackpot event carries exact sampled multiplier")
		check(control.fx.skill_events.is_empty(),"reward calculation without payment point does not produce art")
		g.dispose();control.dispose()
	g=fresh("jackpot");g.hit(brick(g),1000)
	check(g.fx.skill_events.size()==1 and g.fx.skill_events[0].id=="jackpot","brick reward emits jackpot even without active arrow")
	a=g.launch(Vector2(390,470),Vector2.UP*24)
	g.skills.with_source(a,func():g.hit(brick(g),1000))
	check(g.fx.skill_events.size()==2,"attributed brick reward emits jackpot")
	g.bosses.fight={"paid":0.0};g.bosses.boss_id="eye";g.bosses.pay(a,Vector2(350,220))
	check(g.fx.skill_events.size()==3 and g.fx.skill_events.back().position==Vector2(350,220),"boss reward emits jackpot at real payment point")
	g.dispose()
	for id in Batch.IDS:
		g=fresh(id);var rng_state:int=g.rng.state
		var targets:=PackedVector2Array()
		for i in range(100):targets.append(Vector2(i,440))
		for i in range(90):g.fx.skill_batch_eight(id,Vector2(i,440),targets)
		check(g.fx.skill_events.size()==64 and g.fx.skill_events[0].position.x==26,"%s queue evicts oldest" % id)
		check(g.fx.skill_events[0].targets.size()==48,"%s target snapshots bounded to 48" % id)
		check(g.rng.state==rng_state,"%s visual events preserve gameplay RNG" % id)
		targets[0]=Vector2.ZERO
		check(g.fx.skill_events[0].targets[0]!=Vector2.ZERO,"%s copies snapshot independently" % id)
		g.time+=10;check(g.fx.skill_events.size()==64,"%s uses independent visual time" % id)
		g.fx.advance_visual(1.5);check(g.fx.skill_events.is_empty(),"%s visual expiry" % id)
		g.fx.skill_batch_eight(id,Vector2.ZERO);g.fx.reset()
		check(g.fx.skill_events.is_empty() and g.fx.visual_time==0,"%s reset" % id)
		g.dispose()
	if DisplayServer.get_name()!="headless":call_deferred("graphics")
	else:finish()

func graphics() -> void:
	var output:=ProjectSettings.globalize_path("res://../agent-tmp/godot/skill-batch-eight")
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(780,1080)
	await process_frame
	for dark in [false,true]:
		for reduced in [false,true]:
			for id in Batch.IDS:
				var g:=fresh(id);g.theme="dark" if dark else "light";g.state.performanceMode=reduced
				RenderingServer.set_default_clear_color(Color("#191f1b" if dark else "#d5d9cc"))
				for row in range(5):
					for col in range(5):brick(g,Vector2(220+col*85,340+row*50))
				var entry:Dictionary={"g":g,"id":id,"fired":false}
				Fixture.step(entry,0);Fixture.step(entry,0.2);g.fx.advance_visual(0.06)
				var rng_state:int=g.rng.state;var hp:float=g.bricks[0].hp
				var board:=preload("res://src/render/board.gd").new();board.simulation=g;root.add_child(board);board.set_process(false);board._process(0)
				var batch:MultiMeshInstance2D=board.skill_batches[id]
				check(batch.multimesh.visible_instance_count>0,"%s GPU has live production instances" % id)
				await process_frame;await RenderingServer.frame_post_draw
				var peak:=root.get_texture().get_image()
				peak.save_png(output+"/%s-%s-%s-peak.png" % [id,g.theme,"reduced" if reduced else "full"])
				batch.visible=false
				await process_frame;await RenderingServer.frame_post_draw
				check(peak.get_data()!=root.get_texture().get_image().get_data(),"%s GPU contributes visible pixels theme=%s reduced=%s" % [id,g.theme,reduced])
				g.fx.advance_visual(2);board._process(0)
				await process_frame;await RenderingServer.frame_post_draw
				check(batch.multimesh.visible_instance_count==0 and g.fx.skill_events.is_empty(),"%s clean GPU/event tail" % id)
				check(g.rng.state==rng_state and g.bricks[0].hp==hp,"%s rendering preserves physics and RNG" % id)
				for i in range(64):g.fx.skill_batch_eight(id,Vector2(390,440),PackedVector2Array([Vector2(200,300),Vector2(300,300)]),10)
				board._process(0)
				check(batch.multimesh.visible_instance_count<=Batch.CAPACITY and batch.multimesh.instance_count==Batch.CAPACITY,"%s GPU budget stays fixed under saturation" % id)
				board.queue_free();g.dispose();await process_frame
			await overlap(dark,reduced,output)
	finish()

func overlap(dark:bool,reduced:bool,output:String) -> void:
	var g:=fresh("nova");g.theme="dark" if dark else "light";g.state.performanceMode=reduced
	g.state.skills={"nova":1,"crossfire":1,"jackpot":1,"supernova":1}
	for row in range(5):
		for col in range(7):brick(g,Vector2(135+col*85,340+row*50))
	g.state.skillRuntime.shots=3;g.shoot(0,100)
	var arrow:RefCounted=g.arrows[0];var target:RefCounted=g.bricks[17];target.hp=1
	g.skills.with_source(arrow,func():g.skills.projectile_hit(target,arrow))
	g.time=0.2;g.fx.advance_visual(0.2);g.skills.update(0);g.fx.advance_visual(0.06)
	var kinds:Array=[]
	for event in g.fx.skill_events:
		if not event.id in kinds:kinds.append(event.id)
	check(kinds.size()==4,"combined fourth shot and kill fire all four real skills")
	var hp:float=g.bricks[0].hp;var rng_state:int=g.rng.state
	var board:=preload("res://src/render/board.gd").new();board.simulation=g;root.add_child(board);board.set_process(false);board._process(0)
	await process_frame;await RenderingServer.frame_post_draw
	var peak:=root.get_texture().get_image()
	peak.save_png(output+"/overlap-%s-%s.png" % [g.theme,"reduced" if reduced else "full"])
	g.fx.advance_visual(2);board._process(0)
	await process_frame;await RenderingServer.frame_post_draw
	check(peak.get_data()!=root.get_texture().get_image().get_data(),"combined production effects visibly expire")
	check(g.fx.skill_events.is_empty() and g.fx.explosions.is_empty() and g.fx.bombs.is_empty(),"combined event and blast tails empty")
	check(g.bricks[0].hp==hp and g.rng.state==rng_state,"combined rendering leaves physics and RNG unchanged")
	board.queue_free();g.dispose();await process_frame

func finish() -> void:
	print("Native skill batch eight: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
