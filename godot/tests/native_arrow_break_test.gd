extends SceneTree
## Geometry/lifecycle regression plus optional real CanvasItem breakup frames.
const Sim=preload("res://src/core/simulation.gd")
var checks:=0
var failures:=0
var out:="res://../agent-tmp/godot/arrow-break/"

func _initialize() -> void:call_deferred("run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func fixture() -> RefCounted:
	var g:=Sim.new();g.start(9128)
	g.state.skills={};g.state.draft=null;g.phase="flying"
	g.bricks.clear();g.obstacles.clear();g.core=null;g.fx.reset()
	return g

func run() -> void:
	var g:=fixture()
	var point:=Vector2(390,650)
	var angle:float=-0.8
	var flight:=Vector2.from_angle(angle)*18
	var rng_state:int=g.rng.state
	g.fx.arrow_break(point,flight,Color.WHITE,Color.GREEN,1024)
	check(g.rng.state==rng_state,"breakup consumes visual randomness only")
	check(g.fx.particles.size()==10 and g.fx.rings.size()==1,"ten physical fragments and a small burst ring")
	var minimum:=INF;var maximum:float=-INF;var area:=0.0
	var forward:=false;var backward:=false;var above:=false;var below:=false
	var full_opacity:=true;var bounded:=true;var initial_pose:=true
	for particle in g.fx.particles:
		var vertices:PackedVector2Array=particle.polygon
		var fragment_area:=0.0
		for index in range(vertices.size()):
			var local:Vector2=(particle.origin-point).rotated(-angle)+vertices[index]
			minimum=minf(minimum,local.x);maximum=maxf(maximum,local.x)
			fragment_area+=vertices[index].cross(vertices[(index+1)%vertices.size()])/2
		area+=absf(fragment_area)
		var local_velocity:Vector2=particle.velocity.rotated(-angle)
		forward=forward or local_velocity.x>30;backward=backward or local_velocity.x < -30
		above=above or local_velocity.y < -80;below=below or local_velocity.y>80
		full_opacity=full_opacity and particle.life>0.32
		bounded=bounded and particle.velocity.length()<400
		initial_pose=initial_pose and is_equal_approx(particle.rotation,angle)
	check(absf(minimum+29+4/sqrt(52))<0.01 and absf(maximum-10)<0.01,"fragments cover the original arrow tail through tip")
	check(absf(absf(area)-(33*2.3+40+sqrt(52)*4))<0.05,"shaft, head and feather polygons preserve the original filled area")
	check(forward and backward and above and below,"explosion throws fragments in all directions rather than forward only")
	check(full_opacity and initial_pose,"fragments start opaque in the original arrow pose")
	check(bounded,"exponential damage scale cannot fling debris offscreen")
	var first:Dictionary=g.fx.particles[0].duplicate(true)
	g.fx.advance_visual(0.1)
	check(g.fx.particles[0].position.distance_to(first.position)>10 and absf(g.fx.particles[0].rotation-first.rotation)>0.4,"burst separates and spins fragments within 100 ms")
	check(g.fx.particles[0].life>0.32,"fragments do not fade during the initial explosion")
	var once:Vector2=g.fx.particles[0].position
	var g2:=fixture();g2.fx.arrow_break(point,flight,Color.WHITE,Color.GREEN,1024)
	for i in range(10):g2.fx.advance_visual(0.01)
	check(g2.fx.particles[0].position.distance_to(once)<0.001,"debris motion is independent of display cadence")
	g2.dispose()
	g.fx.advance_visual(1)
	check(g.fx.particles.is_empty() and g.fx.rings.is_empty(),"explosion debris and ring expire")
	for reason in ["pierce","timeout","bounds"]:
		g.fx.reset()
		var arrow:RefCounted=g.launch(point,flight)
		if reason=="pierce":arrow.pierce=0
		elif reason=="timeout":arrow.life=4.6
		else:arrow.position.y=1090
		g.advance_arrow(arrow,0)
		check(g.arrows.is_empty() and g.fx.particles.size()==10,"actual arrow removal triggers one explosion: "+reason)
	g.state.performanceMode=true;g.fx.reset()
	g.fx.arrow_break(point,Vector2.ZERO,Color.WHITE,Color.GREEN)
	check(g.fx.particles.size()==7,"performance mode still reconstructs shaft, head and both feathers")
	for i in range(64):g.fx.arrow_break(point,flight,Color.WHITE,Color.GREEN)
	check(g.fx.particles.size()==300 and g.fx.rings.size()<=48,"mass explosions preserve bounded particle/ring pools")
	g.fx.reset();check(g.fx.particles.is_empty(),"reset removes all arrow fragments")
	g.dispose()
	trail_checks()
	if DisplayServer.get_name()!="headless":await capture()
	print("Native arrow explosion: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func trail_checks() -> void:
	var g:=fixture()
	var arrow:RefCounted=g.launch(Vector2(390,760),Vector2(18,-4))
	arrow.visual="railgun"
	for i in range(14):arrow.trail.append(Vector2(90+i*22,820-i*5))
	arrow.reset_display()
	var rng_state:int=g.rng.state
	arrow.pierce=0;g.advance_arrow(arrow,0)
	check(g.arrows.is_empty() and g.fx.trail_remnants.size()==1,"removed arrows leave an independently owned trail")
	var remnant:Dictionary=g.fx.trail_remnants[0]
	var ghost:RefCounted=remnant.arrow
	check(ghost.trail==arrow.trail and ghost.visual=="railgun" and ghost.position==arrow.position,"long trail keeps every point, style and endpoint")
	check(ghost.source==null and ghost.achievement.is_empty(),"trail does not retain gameplay attribution objects")
	arrow.trail.clear()
	check(ghost.trail.size()==14,"residual trail is independent of the original arrow buffer")
	g.fx.advance_visual(0.25)
	check(is_equal_approx(remnant.life/remnant.max,0.5) and ghost.trail.size()==14,"full length trail fades smoothly without a sudden length cut")
	check(g.rng.state==rng_state,"residual trails cannot advance gameplay randomness")
	g.fx.advance_visual(0.3)
	check(g.fx.trail_remnants.is_empty(),"residual trails expire after half a second")
	g.fx.linger_trail(arrow)
	check(g.fx.trail_remnants.is_empty(),"empty or teleport-cleared trails do not leave stale ribbons")
	arrow.trail.append(Vector2(200,700))
	for i in range(80):g.fx.linger_trail(arrow)
	check(g.fx.trail_remnants.size()==64,"residual trail workload remains capped")
	g.fx.reset();check(g.fx.trail_remnants.is_empty(),"reset releases residual trails")
	var a:RefCounted=g.launch(Vector2(390,760),Vector2.UP)
	a.trail.append(Vector2(390,790));g.clear()
	check(g.arrows.is_empty() and g.fx.trail_remnants.size()==1,"level clearing also preserves the trailing afterimage")
	g.dispose()

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var app:Node=load("res://scenes/main.tscn").instantiate()
	app.set_meta("test_mode",true);root.add_child(app)
	app.audio.shutdown();app.interface._close_all()
	var g:RefCounted=app.session.runtime
	g.state.skills={};g.state.draft=null;g.phase="ready";g.board_entrance=null
	for theme in ["light","dark"]:
		g.theme=theme;g.theme_mode=theme;g.fx.reset()
		var arrow:RefCounted=g.launch(Vector2(390,820),Vector2(12,-14))
		app.session.command("snapshot")
		await frame(app,theme+"-intact")
		arrow.pierce=0;g.advance_arrow(arrow,0)
		var age:=0.0
		for milliseconds in [0,40,90,160,260,400,600,860]:
			g.fx.advance_visual(milliseconds/1000.0-age);age=milliseconds/1000.0
			await frame(app,theme+"-"+str(milliseconds))
		# Draw every distinct skill trail with the production renderer, then
		# capture a long ribbon before destruction and during the fade.
		var styles:Dictionary={"plain":""}
		for id in g.content.effect_profiles:
			styles[g.content.effect_profiles[id].trail]=id
		for style in styles:
			g.fx.reset()
			arrow=g.launch(Vector2(390,760),Vector2(18,-4));arrow.visual=styles[style]
			for i in range(14):arrow.trail.append(Vector2(90+i*22,820-i*5))
			arrow.reset_display()
			await frame(app,theme+"-trail-"+style+"-intact")
			arrow.pierce=0;g.advance_arrow(arrow,0)
			await frame(app,theme+"-trail-"+style+"-0")
			g.fx.advance_visual(0.25)
			await frame(app,theme+"-trail-"+style+"-250")
			g.fx.advance_visual(0.3)
			check(g.fx.trail_remnants.is_empty(),"rendered trail expires: "+theme+"/"+style)
	app.queue_free();await process_frame

func frame(app:Node,label:String) -> void:
	app.arena.board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	check(image!=null and image.save_png(out+label+".png")==OK,"actual graphics capture: "+label)
