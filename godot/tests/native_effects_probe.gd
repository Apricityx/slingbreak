extends SceneTree
## Isolated, visible, fixed-count FX attribution. Run alone with a graphics
## driver. Diagnostic ablations never change production shaders or simulation.
const Sim=preload("res://src/core/simulation.gd")
const SKILLS=["echo","piercer","seeking","ricochet"]
const SPECIALS=["lightning","frost","prism","gold"]
const FLAT_SHADER="shader_type canvas_item; render_mode unshaded; void fragment() { COLOR=vec4(1.0,0.5,0.1,0.4); }"

class TimedExplosions extends "res://src/render/explosions.gd":
	var draw_ms:=0.0
	var draw_debris:=true
	func _draw() -> void:
		var started:=Time.get_ticks_usec()
		if draw_debris:super._draw()
		debris.visible=draw_debris and simulation!=null and simulation.phase!="draft"
		draw_ms=float(Time.get_ticks_usec()-started)/1000.0

class TimedFrost extends "res://src/render/frost.gd":
	var draw_ms:=0.0
	var quad_shards:=false
	func _draw() -> void:
		var started:=Time.get_ticks_usec()
		if quad_shards:_draw_quad_shards()
		else:super._draw()
		debris.visible=not quad_shards and g!=null and g.phase!="draft"
		draw_ms=float(Time.get_ticks_usec()-started)/1000.0
	func _draw_quad_shards() -> void:
		# Diagnostic copy of the original filled quad geometry, before the
		# earlier (unproven) ice-shard triangulation workaround.
		if g==null or g.phase=="draft":return
		for event in g.fx.specials:
			if event.type!="ice_shards":continue
			var t:float=g.fx.visual_time-event.born
			var fade:float=clampf(event.life/event.max,0,1)
			for index in range(10):
				var angle:float=event.seed+index*2.39996
				var travel:float=(7+index%4*3)*(1-exp(-t*9.0))
				var p:Vector2=event.position+Vector2.from_angle(angle)*travel+Vector2(0,18*t*t)
				var axis:=Vector2.from_angle(angle+t*5.0)*(2.0+index%3)
				var side:=axis.orthogonal()*0.32
				var alpha_value:float=fade*minf(1.0,t*18.0)
				var outline:=Color("#245766") if g.theme=="light" else Color("#d7f5ff")
				draw_colored_polygon(PackedVector2Array([p-axis*1.28,p+side*1.28,p+axis*1.28,p-side*1.28]),Color(outline,alpha_value*0.78))
				draw_colored_polygon(PackedVector2Array([p-axis,p+side,p+axis,p-side]),Color(0.58,0.9,1.0,alpha_value*0.9))
				draw_line(p-axis,p+axis,Color(0.94,1,1,alpha_value),1.2,true)

class ProbeBoard extends "res://src/render/board.gd":
	var process_ms:=0.0
	var draw_ms:=0.0
	var foreground_ms:=0.0
	var retained_ms:=0.0
	var special_ms:=0.0
	var skill_ms:=0.0
	var mode:="full"
	var flat:Shader

	func _process(delta:float) -> void:
		var started:=Time.get_ticks_usec()
		super._process(delta)
		explosions.visible=mode!="hide_explosions"
		frost.visible=mode!="hide_frost"
		frost.quad_shards=mode=="original_quads"
		frost.debris.visible=mode!="original_quads" and g_visible()
		explosions.draw_debris=mode!="hide_debris"
		explosions.debris.visible=mode!="hide_debris" and g_visible()
		arc_batch.visible=mode!="hide_specials" and g_visible()
		coin_batch.visible=mode!="hide_specials" and g_visible()
		get_parent().position=Vector2(0,5000) if mode=="offscreen" else Vector2(0,238)
		for quad in explosions.pool:
			if mode=="hide_volumes":quad.visible=false
			quad.material.shader=flat if mode=="flat_volumes" else explosions.SHADER
		process_ms=float(Time.get_ticks_usec()-started)/1000.0

	func g_visible() -> bool:return simulation!=null and simulation.phase!="draft"

	func _draw() -> void:
		var started:=Time.get_ticks_usec()
		super._draw()
		draw_ms=float(Time.get_ticks_usec()-started)/1000.0

	func _draw_foreground() -> void:
		var started:=Time.get_ticks_usec()
		super._draw_foreground()
		foreground_ms=float(Time.get_ticks_usec()-started)/1000.0

	func _sync_retained() -> void:
		var started:=Time.get_ticks_usec()
		super._sync_retained()
		retained_ms=float(Time.get_ticks_usec()-started)/1000.0

	func _draw_special_breaks(g:RefCounted) -> void:
		var started:=Time.get_ticks_usec()
		if mode!="hide_specials":super._draw_special_breaks(g)
		special_ms=float(Time.get_ticks_usec()-started)/1000.0

	func _draw_skill_events(g:RefCounted) -> void:
		var started:=Time.get_ticks_usec()
		if mode!="hide_skills":super._draw_skill_events(g)
		skill_ms=float(Time.get_ticks_usec()-started)/1000.0

var g:RefCounted
var board:ProbeBoard
var samples:=90
var warmup:=20
var repeats:=1
var selection:=""
var output:="res://../agent-tmp/godot/effects-probe.json"
var resolution:=1.0
var capture_path:=""
var age_start:=0.06
var age_end:=0.36

func _initialize() -> void:call_deferred("run")

func stats(values:Array) -> Dictionary:
	var ordered:=values.duplicate();ordered.sort()
	return {"count":ordered.size(),"p50":ordered[int(ordered.size()*.50)],"p95":ordered[int(ordered.size()*.95)],"p99":ordered[int(ordered.size()*.99)],"max":ordered.back()}

func point(index:int) -> Vector2:
	# Every emitter stays on the actual board, including late stress samples.
	return Vector2(150+(index%6)*96,230+((index/6)%6)*85)

func reset_fixture() -> void:
	g.fx.reset();g.arrows.clear()
	for brick in g.bricks:brick.frozen=false;brick.frost_born=-1.0
	board.mode="full"

func populate(kind:String,count:int) -> void:
	if kind=="shells":
		for i in range(mini(count,g.bricks.size())):
			g.bricks[i].frozen=true;g.bricks[i].frost_born=0.0
		return
	for i in range(count):
		var p:=point(i)
		if kind=="bomb":g.fx.explosion(p)
		elif kind=="normal":g.fx.normal_break(p,g.fx.brick_color("normal"))
		elif kind=="mixed":
			var id:String=SKILLS[i%4]
			g.fx.skill_event(id,p,Vector2.UP,p+Vector2(40,-60),1.0,0.5)
		elif kind in SKILLS:g.fx.skill_event(kind,p,Vector2.UP,p+Vector2(40,-60),1.0,0.5)
		elif kind=="ice_shards":g.fx.frozen_target(p)
		else:g.fx.special_break(p,kind)
	if kind=="mixed":
		for i in range(16):g.fx.explosion(point(i))
		for i in range(48):g.fx.special_break(point(i),SPECIALS[i%4])
		for i in range(32):g.bricks[i].frozen=true;g.bricks[i].frost_born=0.0

func pose(frame:int) -> void:
	# A repeated 0.06..0.36 s impact sweep keeps population fixed, yet exercises
	# animation instead of making everything invisible during its long tail.
	var age:=age_start+(frame%30)/30.0*(age_end-age_start)
	g.fx.visual_time=age
	for event in g.fx.specials:event.life=event.max-age
	# Other event families evaluate born/visual_time directly.

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func measure(fixture:Dictionary,trial:int) -> Dictionary:
	reset_fixture();populate(fixture.kind,fixture.count)
	board.mode=fixture.get("mode","full")
	for i in range(warmup):pose(i);await frame()
	var intervals:Array=[];var process_cost:Array=[];var draw_cost:Array=[]
	var retained_cost:Array=[];var special_cost:Array=[];var skill_cost:Array=[]
	var update_cost:Array=[];var calls:Array=[]
	var lifecycle_cost:Array=[]
	var explosion_cost:Array=[];var frost_cost:Array=[]
	for i in range(samples):
		var started:=Time.get_ticks_usec()
		pose(i)
		update_cost.append(float(Time.get_ticks_usec()-started)/1000.0)
		var lifecycle_started:=Time.get_ticks_usec()
		g.fx.advance_visual(1.0/60.0)
		lifecycle_cost.append(float(Time.get_ticks_usec()-lifecycle_started)/1000.0)
		await frame()
		intervals.append(float(Time.get_ticks_usec()-started)/1000.0)
		process_cost.append(board.process_ms);draw_cost.append(board.draw_ms+board.foreground_ms)
		retained_cost.append(board.retained_ms);special_cost.append(board.special_ms);skill_cost.append(board.skill_ms)
		explosion_cost.append(board.explosions.draw_ms if board.explosions.visible else 0.0)
		frost_cost.append(board.frost.draw_ms if board.frost.visible else 0.0)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var result:={"case":fixture.label,"trial":trial,"kind":fixture.kind,"requested":fixture.count,"mode":board.mode,
		"wall_ms":stats(intervals),"board_process_ms":stats(process_cost),"board_draw_ms":stats(draw_cost),
		"retained_ms":stats(retained_cost),"special_draw_ms":stats(special_cost),"skill_draw_ms":stats(skill_cost),
		"explosion_draw_ms":stats(explosion_cost),"frost_draw_ms":stats(frost_cost),
		"fixture_update_ms":stats(update_cost),"draw_calls":stats(calls),
		"lifecycle_ms":stats(lifecycle_cost),
		"queues":{"skills":g.fx.skill_events.size(),"specials":g.fx.specials.size(),"explosions":g.fx.explosions.size(),"normal":g.fx.normal_breaks.size()},
		"emitters_in_board":fixture.get("mode","full")!="offscreen",
		"over_33ms":intervals.filter(func(v):return v>1000.0/30.0).size()}
	print("Native FX case: "+JSON.stringify(result))
	if not capture_path.is_empty() and trial==0 and fixture.label=="mixed_full":
		root.get_texture().get_image().save_png(capture_path)
	return result

func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("FX probe requires a graphics driver");quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--samples="):samples=maxi(5,int(arg.get_slice("=",1)))
		elif arg.begins_with("--warmup="):warmup=maxi(1,int(arg.get_slice("=",1)))
		elif arg.begins_with("--repeats="):repeats=maxi(1,int(arg.get_slice("=",1)))
		elif arg.begins_with("--case="):selection=arg.get_slice("=",1)
		elif arg.begins_with("--output="):output=arg.get_slice("=",1)
		elif arg.begins_with("--resolution="):resolution=clampf(float(arg.get_slice("=",1)),0.25,2.0)
		elif arg.begins_with("--capture="):capture_path=arg.get_slice("=",1)
		elif arg.begins_with("--age-start="):age_start=maxf(0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--age-end="):age_end=maxf(age_start,float(arg.get_slice("=",1)))
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Render at the production viewport size; a half-size A/B changes pixels,
	# not effect coordinates, queue sizes, or CPU draw-command counts.
	root.size=Vector2i(Vector2(412,915)*resolution)
	root.content_scale_size=Vector2i(412,915)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	g=Sim.new();g.start(9128);g.state.draft=null;g.state.skills={};g.state.performanceMode=false
	g.phase="ready";g.board_entrance=null;g.bricks.clear();g.obstacles.clear();g.core=null
	for row in range(10):
		for column in range(6):g.make_brick({"x":150+column*96,"y":170+row*60,"hp":1000,"max":1000})
	board=ProbeBoard.new();board.simulation=g;board.position=Vector2(3,238);board.scale=Vector2.ONE*.52
	board.explosions.free();board.explosions=TimedExplosions.new()
	board.frost.free();board.frost=TimedFrost.new()
	board.flat=Shader.new();board.flat.code=FLAT_SHADER
	# Board's process sets its local origin; a parent supplies arena position.
	var arena:=Node2D.new();arena.position=Vector2(0,238);root.add_child(arena);arena.add_child(board)
	await frame()
	var fixtures:Array=[{"label":"baseline","kind":"none","count":0}]
	for id in SKILLS:
		for count in [1,64]:fixtures.append({"label":id+"_"+str(count),"kind":id,"count":count})
	for id in SPECIALS+["ice_shards","normal"]:
		for count in [1,48]:fixtures.append({"label":id+"_"+str(count),"kind":id,"count":count})
	for id in ["lightning","gold"]:
		for count in [8,16]:fixtures.append({"label":id+"_"+str(count),"kind":id,"count":count})
	for id in ["lightning","gold","ice_shards"]:
		fixtures.append({"label":id+"_48_offscreen","kind":id,"count":48,"mode":"offscreen"})
	fixtures.append({"label":"ice_shards_48_original_quads","kind":"ice_shards","count":48,"mode":"original_quads"})
	for count in [1,8,16]:fixtures.append({"label":"bomb_"+str(count),"kind":"bomb","count":count})
	for count in [1,60]:fixtures.append({"label":"shells_"+str(count),"kind":"shells","count":count})
	for mode in ["full","hide_volumes","flat_volumes","hide_explosions","hide_debris","offscreen"]:
		fixtures.append({"label":"bomb_16_"+mode,"kind":"bomb","count":16,"mode":mode})
	for mode in ["full","hide_explosions","flat_volumes","hide_frost","hide_specials","hide_skills","offscreen"]:
		fixtures.append({"label":"mixed_"+mode,"kind":"mixed","count":64,"mode":mode})
	fixtures.append({"label":"baseline_end","kind":"none","count":0})
	var report:={"environment":{"version":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),
		"display":DisplayServer.get_name(),"viewport":root.size,"resolution":resolution,"samples":samples,"warmup":warmup,
		"age_start":age_start,"age_end":age_end,
		"scope":"Post-draw wall intervals and CPU board callbacks; includes actual renderer but not explicit GPU completion, real audio or physics. Fixed in-view queues; test-only ablations."},"cases":[]}
	report["sources"]={}
	for path in ["res://src/render/board.gd","res://src/render/effect_foreground.gd","res://src/render/explosions.gd","res://src/render/frost.gd","res://src/render/explosion.gdshader","res://src/render/frost.gdshader","res://src/render/effect_mesh.gd","res://src/render/debris_batch.gd","res://src/render/debris.gdshader","res://src/render/special_batch.gd","res://src/render/arc_batch.gdshader","res://src/render/coin_batch.gdshader"]:
		report.sources[path]=FileAccess.get_sha256(path)
	for trial in range(repeats):
		for fixture in fixtures:
			if not selection.is_empty():
				var selected:=false
				for prefix in selection.split(","):
					if fixture.label.begins_with(prefix):selected=true
				if not selected:continue
			report.cases.append(await measure(fixture,trial))
			var file:=FileAccess.open(output,FileAccess.WRITE)
			if file==null:push_error("Cannot write FX report: "+output);quit(1);return
			file.store_string(JSON.stringify(report,"  "));file.close()
	arena.queue_free();await process_frame;g.dispose();g=null
	print("Native FX probe report: "+output);quit()
