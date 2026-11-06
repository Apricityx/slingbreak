extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func fresh(id:String) -> RefCounted:
	var g:=Sim.new();g.start(9128);g.bricks.clear();g.obstacles.clear();g.fx.reset()
	g.skills.reset();g.state.skills={id:1};g.phase="flying";g.board_entrance=null;g.initial=1000
	return g

func brick(g:RefCounted,point:Vector2,hp:float=1) -> RefCounted:
	return g.make_brick({"x":point.x,"y":point.y,"hp":hp,"max":hp})

func run() -> void:
	var g:=fresh("shatter")
	var a:RefCounted=g.launch(Vector2(390,600),Vector2.UP*24)
	var b:RefCounted=brick(g,Vector2(390,400));b.frozen=true
	var neighbor:RefCounted=brick(g,Vector2(440,400),100)
	g.active_arrow=a;g.hit(b,10);g.active_arrow=null
	check(g.fx.skill_events.is_empty(),"ice shock waits for its damage delay")
	g.time=0.1;g.skills.update(0.1)
	check(g.fx.skill_events.size()==1 and g.fx.skill_events[0].id=="shatter","frozen destruction triggers ice event")
	check(neighbor.hp==97 and g.fx.explosions.is_empty(),"ice damage occurs once with crystal material")
	for i in range(7):
		b=brick(g,Vector2(150,400));b.frozen=true;g.active_arrow=a;g.hit(b,10)
	g.active_arrow=null;g.time=0.3;g.skills.update(0.2)
	check(g.fx.skill_events.size()==6,"shatter respects six activations per arrow")
	g.dispose()
	g=fresh("aftershock");a=g.launch(Vector2(390,600),Vector2.UP*24)
	b=brick(g,Vector2(390,400));b.type="bomb";neighbor=brick(g,Vector2(440,400),100)
	g.active_arrow=a;g.hit(b,10);g.active_arrow=null
	check(neighbor.hp==96 and g.fx.skill_events.is_empty(),"bomb precedes the secondary fault")
	g.time=0.17;g.skills.update(0.17)
	check(neighbor.hp==92 and g.fx.skill_events.size()==1 and g.fx.explosions.size()==1 and g.fx.bombs.size()==1,"secondary explosion and fault share one damage event")
	g.dispose()
	g=fresh("execute");a=g.launch(Vector2(390,600),Vector2.UP*24)
	b=brick(g,Vector2(390,400),100);b.hp=28
	g.skills.with_source(a,func():g.skills.projectile_hit(b,a))
	check(g.fx.skill_events.is_empty() and b.hp==26,"no execution flash above threshold")
	g.skills.with_source(a,func():g.skills.projectile_hit(b,a))
	check(not b in g.bricks and g.fx.skill_events.size()==1,"successful execution creates one crossed cut")
	g.dispose()
	g=fresh("rage");a=g.launch(Vector2(390,600),Vector2.UP*24)
	for i in range(21):
		b=brick(g,Vector2(390,400));g.active_arrow=a;g.hit(b,10)
		check(g.fx.skill_events.size()==mini(6,(i+1)/3),"rage emits only at capped three-kill milestones %d" % (i+1))
	g.active_arrow=null
	var other:RefCounted=g.launch(Vector2(390,600),Vector2.UP*24)
	b=brick(g,Vector2(390,400));g.active_arrow=other;g.hit(b,10);g.active_arrow=null
	check(g.fx.skill_events.size()==6,"each arrow has an independent rage counter")
	var rng_state:int=g.rng.state
	for i in range(100):g.fx.skill_event("rage",Vector2(i,200))
	check(g.fx.skill_events.size()==64 and g.fx.skill_events[0].position.x==36,"overflow drops oldest presentation events")
	check(g.rng.state==rng_state,"presentation leaves gameplay RNG untouched")
	g.fx.advance_visual(1)
	check(g.fx.skill_events.is_empty(),"all second-batch events expire on visual time")
	g.fx.skill_event("execute",Vector2.ZERO);g.fx.reset()
	check(g.fx.skill_events.is_empty(),"reset clears second-batch events")
	g.dispose()
	if DisplayServer.get_name()!="headless":await render_previews()
	print("Native skill batch two: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func render_previews() -> void:
	root.content_scale_size=Vector2i.ZERO
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(780,1100)
	var bg:=ColorRect.new();bg.size=Vector2(780,1100);root.add_child(bg)
	var board:=Board.new();root.add_child(board)
	var out:="res://../agent-tmp/godot/skill-batch-two/"
	DirAccess.make_dir_recursive_absolute(out)
	for theme in ["light","dark"]:
		for reduced in [false,true]:
			var g:=fresh("rage");g.theme=theme;g.state.performanceMode=reduced
			bg.color=Color("#d5d9cc" if theme=="light" else "#191f1b")
			for row in range(11):
				for col in range(7):brick(g,Vector2(100+col*96,180+row*58),12)
			var ids:=["shatter","execute","rage","aftershock"]
			for i in range(4):
				var p:=Vector2(230+320*(i%2),330+300*(i/2))
				g.fx.skill_event(ids[i],p,Vector2.UP,Vector2.ZERO,1,0.6)
				# Nearby simultaneous bursts exercise overlap without obscuring the centre.
				g.fx.skill_event(ids[i],p+Vector2(-65,58),Vector2.UP,Vector2.ZERO,0.65,0.6)
			board.simulation=g
			for age in [0.0,0.09,0.3,0.58]:
				g.fx.visual_time=age
				for frame in range(2):await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(out+"%s-%s-%.2f.png" % [theme,"reduced" if reduced else "full",age])
				check(true,"rendered %s reduced=%s age=%s" % [theme,reduced,age])
			board.simulation=null;g.dispose()
	board.queue_free();bg.queue_free();await process_frame
