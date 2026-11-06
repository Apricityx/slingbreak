extends SceneTree
## Cross-batch integration: new gold silhouettes share the bounded event queue
## with the existing GPU effects, without stale instances or gameplay mutation.
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
const GOLD_IDS=["trident","meteor","hunters","rapid","nova","crossfire","jackpot","supernova","swarmqueen","railgun","frostfire","thunderlottery"]
const GPU_IDS=["echo","piercer","seeking","ricochet","storm"]
var checks:=0
var failures:=0

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func _initialize() -> void:call_deferred("run")

func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw

func run() -> void:
	var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/skills.json"))
	var previews:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/effect_previews.json"))
	for id in GOLD_IDS:
		var entries:=catalog.filter(func(item):return item.id==id)
		check(entries.size()==1 and entries[0].tier=="gold","integrated skill retains gold catalog tier: "+id)
		check(previews.has(id),"integrated skill has a GIF fixture: "+id)
	var g:=Sim.new();g.start(9128);g.state.skills={};g.state.draft=null;g.phase="ready"
	g.bricks.clear();g.obstacles.clear();g.core=null;g.board_entrance=null;g.fx.reset()
	for row in range(4):
		for col in range(6):g.make_brick({"x":165+col*85,"y":320+row*75,"hp":100,"max":100,"w":66,"h":32})
	var board:=Board.new();board.simulation=g;root.add_child(board);board.set_process(false)
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(780,1080)
	var rng_state:int=g.rng.state
	var output:=ProjectSettings.globalize_path("res://../agent-tmp/godot/skill-gold-integration")
	if DisplayServer.get_name()!="headless":DirAccess.make_dir_recursive_absolute(output)
	for theme in ["light","dark"]:
		for reduced in [false,true]:
			RenderingServer.set_default_clear_color(Color("#171e17" if theme=="dark" else "#d5d9cc"))
			g.theme=theme;g.state.performanceMode=reduced;g.fx.reset();board._process(0)
			await frame()
			var before:Image
			if DisplayServer.get_name()!="headless":before=root.get_texture().get_image()
			# More than a queue's worth, interleaving all three new batches and
			# existing GPU-backed IDs. Eviction must not strand a GPU instance.
			var ids:Array=GOLD_IDS+GPU_IDS
			for i in range(85):
				var p:=Vector2(175+(i%6)*85,340+(i%4)*75)
				g.fx.skill_event(ids[i%ids.size()],p,Vector2.UP,p+Vector2(64,-36),1,0.72)
			check(g.fx.skill_events.size()==64,"mixed queue stays bounded "+theme+str(reduced))
			check(g.fx.skill_events[0].id==ids[21%ids.size()],"mixed overflow evicts oldest event")
			var snapshot:Array=g.fx.skill_events.duplicate(true)
			g.fx.advance_visual(0.12);board._process(0);await frame()
			check(g.fx.skill_events==snapshot,"mixed render preserves every event snapshot")
			for id in board.skill_batches:
				var expected:=snapshot.filter(func(event):return event.id==id).size()
				check(board.skill_batches[id].multimesh.visible_instance_count==expected,"mixed queue preserves GPU dispatch: "+id)
			if DisplayServer.get_name()!="headless":
				var peak:=root.get_texture().get_image()
				check(peak.get_data()!=before.get_data(),"mixed gold and GPU effects are visible")
				peak.save_png(output+"/mixed-%s-%s.png" % [theme,"reduced" if reduced else "full"])
			g.fx.advance_visual(1);board._process(0);await frame()
			check(g.fx.skill_events.is_empty(),"mixed events fully expire")
			for id in board.skill_batches:check(board.skill_batches[id].multimesh.visible_instance_count==0,"no stale GPU effect after mixed expiry: "+id)
			for id in ids:g.fx.skill_event(id,Vector2(390,440),Vector2.UP,Vector2(450,400))
			board._process(0);g.fx.reset();board._process(0);await frame()
			check(g.fx.skill_events.is_empty() and g.fx.visual_time==0,"active mixed reset clears events and clock")
			if DisplayServer.get_name()!="headless":
				check(root.get_texture().get_image().get_data()==before.get_data(),"active reset restores clean board pixels")
			for id in board.skill_batches:check(board.skill_batches[id].multimesh.visible_instance_count==0,"active reset clears GPU instances: "+id)
			check(g.rng.state==rng_state,"mixed rendering never consumes gameplay RNG")
			check(g.bricks.all(func(b):return b.hp==100),"mixed rendering preserves all brick HP")
	board.queue_free();await process_frame;g.dispose()
	combined_gameplay()
	print("Native gold integration: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func combined_gameplay() -> void:
	var runs:Array=[]
	for reduced in [false,true]:
		var g:=Sim.new();g.start(9128);g.state.skills={};g.state.draft=null
		g.bricks.clear();g.obstacles.clear();g.core=null;g.board_entrance=null;g.fx.reset();g.skills.reset()
		g.phase="ready";g.intro_active=false;g.locked_until=0;g.next_shot_at=0
		g.initial=1000;g.threshold=1000;g.state.skillChosenLevel=g.state.level
		g.state.performanceMode=reduced
		for id in GOLD_IDS:g.state.skills[id]=1
		for row in range(5):
			for col in range(7):g.make_brick({"x":135+col*85,"y":300+row*50,"hp":80,"max":80,"w":70,"h":34})
		runs.append(g)
	var consistent:=true
	var shots:=0
	for tick in range(180):
		for g in runs:
			if tick%30==0:
				var accepted:bool=g.shoot(0,100)
				if g==runs[0] and accepted:shots+=1
			g.tick(1.0/60.0);g.fx.advance_visual(1.0/60.0)
		var a:RefCounted=runs[0];var b:RefCounted=runs[1]
		consistent=consistent and a.rng.state==b.rng.state and a.state.coins==b.state.coins and a.arrows.size()==b.arrows.size() and a.bricks.size()==b.bricks.size()
		if not consistent:break
		for i in range(a.arrows.size()):
			consistent=consistent and a.arrows[i].position==b.arrows[i].position and a.arrows[i].velocity==b.arrows[i].velocity and a.arrows[i].damage==b.arrows[i].damage
		for i in range(a.bricks.size()):consistent=consistent and a.bricks[i].id==b.bricks[i].id and a.bricks[i].hp==b.bricks[i].hp
	check(shots>=4,"all twelve gold skills coexist through fourth-volley trigger")
	check(consistent,"180 live ticks preserve combined trajectories, HP, rewards and RNG across full/reduced")
	for g in runs:
		check(g.fx.skill_events.size()<=64,"real combined skill triggers keep shared event budget")
		g.dispose()
