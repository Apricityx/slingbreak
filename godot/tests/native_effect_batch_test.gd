extends SceneTree
## Shared mesh lifecycle, float payload, draw ordering and real GPU visibility.
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
const Special=preload("res://src/render/special_batch.gd")
const Debris=preload("res://src/render/debris_batch.gd")
const Geometry=preload("res://src/render/effect_mesh.gd")
var checks:=0
var failures:=0

class OverlayBoard extends "res://src/render/board.gd":
	var sentinel:=false
	func _draw_foreground() -> void:
		super._draw_foreground()
		if sentinel:draw_on.draw_rect(Rect2(360,410,60,60),Color.RED)

func _initialize() -> void:call_deferred("run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw

func run() -> void:
	var g:=Sim.new();g.start(9128);g.state.draft=null;g.phase="ready"
	g.state.skills={};g.bricks.clear();g.obstacles.clear();g.core=null;g.board_entrance=null;g.fx.reset()
	var board:=OverlayBoard.new();board.simulation=g;root.add_child(board)
	board.set_process(false)
	var rng_state:int=g.rng.state
	for type in ["lightning","gold","ice_shards","bomb"]:
		g.fx.reset()
		for i in range(100):
			if type=="bomb":g.fx.explosion(Vector2(200+i,300),232)
			elif type=="ice_shards":g.fx.frozen_target(Vector2(200+i,300))
			else:g.fx.special_break(Vector2(200+i,300),type)
		g.fx.advance_visual(0.06)
		board._process(0)
		var batch:MultiMeshInstance2D
		match type:
			"lightning":batch=board.arc_batch
			"gold":batch=board.coin_batch
			"ice_shards":batch=board.frost.debris
			_:batch=board.explosions.debris
		var capacity:=16 if type=="bomb" else 48
		check(batch.multimesh.instance_count==capacity and batch.multimesh.visible_instance_count==capacity,"bounded full batch: "+type)
		if DisplayServer.get_name()!="headless":
			# Dummy RenderingServer has no backing instance buffer/getters.
			var payload:=batch.multimesh.get_instance_custom_data(0)
			var event:Dictionary=g.fx.explosions[0] if type=="bomb" else g.fx.specials[0]
			check(absf(payload.g+payload.a-fposmod(event.seed,TAU))<0.000004,"split seed preserves subpixel phase: "+type)
			if type=="bomb":check(is_equal_approx(payload.b,232),"radius > 1 survives custom data")
			check(batch.multimesh.get_instance_transform_2d(0).origin==event.position,"instance preserves event position: "+type)
		var mesh:=batch.multimesh.mesh
		var twin:MultiMeshInstance2D=Debris.new() if type in ["bomb","ice_shards"] else Special.new()
		if twin is Debris:twin.setup(type=="ice_shards",capacity)
		else:twin.setup(type)
		check(twin.multimesh.mesh==mesh,"immutable template shared across boards: "+type);twin.free()
		g.state.performanceMode=true;board._process(0)
		if type in ["bomb","ice_shards"]:check(batch.material.get_shader_parameter("reduced"),"existing reduced mode forwarded: "+type)
		g.state.performanceMode=false
		g.phase="draft";board._process(0);await frame()
		check(not batch.is_visible_in_tree(),"draft hides batch: "+type)
		g.phase="ready";board._process(0);await frame()
		check(batch.is_visible_in_tree(),"resume shows batch: "+type)
		if type=="gold":check(board.coin_batch.glyphs.items.size()==48,"real currency glyph retained for every coin")
		if type in ["lightning","gold"]:
			var limit:=0.42 if type=="lightning" else 0.58
			for item in g.fx.specials:item.life=item.max*(1.0-limit+0.001)
			board._process(0)
			check(batch.multimesh.visible_instance_count==capacity,"preserve last nontransparent beat: "+type)
			for item in g.fx.specials:item.life=item.max*(1.0-limit-0.001)
			board._process(0)
			check(batch.multimesh.visible_instance_count==0,"skip exactly transparent tail: "+type)
		g.fx.advance_visual(2);board._process(0)
		check(batch.multimesh.visible_instance_count==0,"expired instances removed: "+type)
		check(batch.multimesh.mesh==mesh,"animation never rebuilds the mesh: "+type)
		g.fx.reset();board._process(0)
		check(batch.multimesh.visible_instance_count==0,"reset clears live batch: "+type)
		if type=="gold":check(board.coin_batch.glyphs.items.is_empty(),"reset clears currency glyphs")
		if type=="bomb":g.fx.explosion(Vector2(390,440))
		elif type=="ice_shards":g.fx.frozen_target(Vector2(390,440))
		else:g.fx.special_break(Vector2(390,440),type)
		board._process(0)
		check(batch.multimesh.visible_instance_count==1,"restart repopulates previously empty batch: "+type)
		g.fx.reset();board._process(0)
		check(batch.multimesh.visible_instance_count==0,"reset while active cannot leave a stale instance: "+type)
	check(g.rng.state==rng_state,"batch playback never consumes gameplay RNG")
	var large_seed:=Geometry.event_data(0.1,16180000.0,132)
	check(absf(large_seed.g+large_seed.a-fposmod(16180000.0,TAU))<0.000004,"large serial wraps without phase loss")
	check(board.arc_batch.get_index()<board.foreground.get_index() and board.coin_batch.get_index()<board.foreground.get_index(),"arrows and text remain above special hits")
	check(board.foreground.get_index()<board.explosions.get_index() and board.explosions.get_index()<board.frost.get_index(),"original fire/frost overlay order preserved")
	if DisplayServer.get_name()!="headless":await graphics_checks(g,board)
	board.queue_free();await process_frame;g.dispose()
	print("Native effect batches: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func graphics_checks(g:RefCounted,board:Node2D) -> void:
	root.size=Vector2i(412,915)
	board.scale=Vector2.ONE*0.52
	var out:="res://../agent-tmp/godot/effect-batches/"
	DirAccess.make_dir_recursive_absolute(out)
	for theme in ["light","dark"]:
		g.theme=theme
		for type in ["lightning","gold","ice_shards","bomb"]:
			g.fx.reset();board._process(0);await frame()
			var before:=root.get_texture().get_image()
			var point:=Vector2(390,440)
			if type=="bomb":g.fx.explosion(point,132)
			elif type=="ice_shards":g.fx.frozen_target(point)
			else:g.fx.special_break(point,type)
			g.fx.advance_visual(0.08);board._process(0);await frame()
			var image:=root.get_texture().get_image()
			var changed:=0
			for y in range(180,285):
				for x in range(145,265):
					if image.get_pixel(x,y)!=before.get_pixel(x,y):changed+=1
			check(changed>20,"actual GPU effect remains visible: "+theme+"/"+type)
			check(image.save_png(out+theme+"-"+type+".png")==OK,"save graphics evidence: "+theme+"/"+type)
	# A shader-expanded bolt can enter the screen while the unit template and
	# emitter are completely outside. Its AABB must include that reach.
	g.fx.reset();board._process(0);await frame()
	var before:=root.get_texture().get_image()
	g.fx.special_break(Vector2(-80,440),"lightning");g.fx.specials[0].seed=0.0
	g.fx.advance_visual(0.06);board._process(0);await frame()
	var image:=root.get_texture().get_image();var changed:=0
	for y in range(190,270):
		for x in range(0,60):
			if image.get_pixel(x,y)!=before.get_pixel(x,y):changed+=1
	check(changed>20,"offscreen emitter retains visible shader-expanded bolt")
	for type in ["lightning","gold"]:
		g.fx.reset();g.fx.special_break(Vector2(390,440),type);g.fx.advance_visual(0.04)
		board.sentinel=true;board._process(0);await frame()
		image=root.get_texture().get_image()
		check(image.get_pixel(206,229).is_equal_approx(Color.RED),"foreground really renders above special hit: "+type)
	board.sentinel=false
