extends SceneTree
## Sequential V2 effect coverage and graphics-driver stress test.
## Run with --gui; headless rendering cannot measure CanvasItem frame cost.
const Main:=preload("res://src/main.gd")
const EffectIds:= ["echo","piercer","seeking","ricochet"]
const SpecialIds:= ["bomb","lightning","frost","prism","gold"]
const FRAME_BUDGET_MS:=1000.0/60.0
const STRESS_FRAMES:=240

class TimedBoard extends "res://src/render/board.gd":
	var draw_samples:Array=[]

	func _draw() -> void:
		var started:=Time.get_ticks_usec()
		super._draw()
		draw_samples.append(float(Time.get_ticks_usec()-started)/1000.0)

	func _draw_foreground() -> void:
		var started:=Time.get_ticks_usec()
		super._draw_foreground()
		if not draw_samples.is_empty():draw_samples[-1]+=float(Time.get_ticks_usec()-started)/1000.0

var app:Node
var checks:=0
var failures:=0

func _initialize() -> void:
	call_deferred("run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func stats(values:Array) -> Dictionary:
	if values.is_empty():return {"count":0,"p50":0.0,"p95":0.0,"p99":0.0,"max":0.0}
	var sorted:=values.duplicate()
	sorted.sort()
	return {"count":sorted.size(),"p50":sorted[int(sorted.size()*.50)],"p95":sorted[int(sorted.size()*.95)],"p99":sorted[int(sorted.size()*.99)],"max":sorted.back()}

func wait_frame() -> float:
	var started:=Time.get_ticks_usec()
	await process_frame
	await RenderingServer.frame_post_draw
	return float(Time.get_ticks_usec()-started)/1000.0

func trigger(g:RefCounted,id:String,index:int) -> void:
	# Wrap emitters into the visible arena rather than letting the late stress
	# frames scroll offscreen and accidentally benchmark culled effects.
	var point:=Vector2(100+(index%6)*110,180+((index/6)%7)*85)
	var direction:=Vector2.RIGHT.rotated(index*.31)
	var target:=point+direction*90.0 if id=="seeking" else Vector2.ZERO
	g.fx.skill_event(id,point,direction,target,1.0,0.42 if id=="seeking" else 0.5)

func trigger_special(g:RefCounted,id:String,index:int) -> void:
	var point:=Vector2(90+(index%6)*110,220+((index/6)%7)*80)
	if id=="bomb":
		g.fx.special_break(point,"bomb")
	elif id=="frost":
		g.fx.special_break(point,"frost")
		g.fx.frozen_target(point+Vector2(48,0),42)
	else:
		g.fx.special_break(point,id)

func special_sequential(g:RefCounted,board:TimedBoard) -> Dictionary:
	var frame_times:Array=[]
	var effects_seen:Array=[]
	for index in range(SpecialIds.size()):
		var id:String=SpecialIds[index]
		g.fx.reset()
		trigger_special(g,id,index)
		if id=="bomb":
			check(g.fx.explosions.size()==1,"special brick queues explosion: "+id)
		elif id=="frost":
			check(g.fx.specials.size()==2,"special brick queues frost wave and shards")
		else:
			check(g.fx.specials.size()==1,"special brick queues presentation event: "+id)
		effects_seen.append(id)
		for frame in range(90):
			g.fx.advance_visual(1.0/60.0)
			frame_times.append(await wait_frame())
		check(g.fx.specials.is_empty() and g.fx.explosions.is_empty(),"special brick effect expires: "+id)
	return {"effects":effects_seen,"frames":stats(frame_times),"over_60fps":frame_times.filter(func(v):return v>FRAME_BUDGET_MS).size()}

func sequential(g:RefCounted,board:TimedBoard) -> Dictionary:
	var frame_times:Array=[]
	var effects_seen:Array=[]
	for index in range(EffectIds.size()):
		var id:String=EffectIds[index]
		g.fx.reset()
		trigger(g,id,index)
		check(g.fx.skill_events.size()==1,"V2 event queued: "+id)
		check(g.fx.skill_events[0].id==id,"V2 event id preserved: "+id)
		effects_seen.append(g.fx.skill_events[0].id)
		for frame in range(42):
			g.fx.advance_visual(1.0/60.0)
			frame_times.append(await wait_frame())
		check(g.fx.skill_events.is_empty(),"V2 event expires: "+id)
	return {"effects":effects_seen,"frames":stats(frame_times),"over_60fps":frame_times.filter(func(v):return v>FRAME_BUDGET_MS).size()}

func stress(g:RefCounted,board:TimedBoard) -> Dictionary:
	g.fx.reset()
	board.draw_samples.clear()
	var frame_times:Array=[]
	var peak_queue:=0
	for frame in range(STRESS_FRAMES):
		# Four effects overlap continuously. This intentionally reaches the
		# presentation queue limit without changing gameplay state.
		for lane in range(4):trigger(g,EffectIds[(frame+lane)%EffectIds.size()],frame+lane)
		trigger_special(g,SpecialIds[frame%SpecialIds.size()],frame)
		if frame%3==0:g.fx.explosion(Vector2(250,320),132,1.0)
		g.fx.advance_visual(1.0/60.0)
		peak_queue=maxi(peak_queue,g.fx.skill_events.size())
		frame_times.append(await wait_frame())
	check(peak_queue<=64,"V2 stress queue stays within 64-event budget")
	check(g.fx.skill_events.size()<=64,"V2 stress queue is bounded after playback")
	return {"frames":stats(frame_times),"draw_ms":stats(board.draw_samples),"peak_events":peak_queue,
		"over_60fps":frame_times.filter(func(v):return v>FRAME_BUDGET_MS).size(),
		"over_30fps":frame_times.filter(func(v):return v>1000.0/30.0).size(),
		"draw_over_60fps":board.draw_samples.filter(func(v):return v>FRAME_BUDGET_MS).size()}

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("V2 effects graphics test requires --gui and a graphics driver")
		quit(1)
		return
	app=Main.new()
	app.set_meta("test_mode",true)
	root.add_child(app)
	await process_frame
	app.audio.shutdown()
	var g:RefCounted=app.session.runtime
	app.interface._close_all()
	app.interface.visible=false
	g.state.draft=null
	g.state.performanceMode=false
	g.phase="ready"
	g.paused=false
	g.board_entrance=null
	var old:Node=app.arena.board
	app.arena.remove_child(old)
	old.free()
	var board:=TimedBoard.new()
	board.position=app.arena.VIEW_OFFSET
	board.scale=Vector2.ONE*app.arena.VIEW_SCALE
	board.simulation=g
	app.arena.board=board
	app.arena.add_child(board)
	await process_frame
	var report:={"version":Engine.get_version_info(),"v2_effects":EffectIds,
		"special_bricks":SpecialIds,"sequential":await sequential(g,board),
		"special_sequential":await special_sequential(g,board),"stress":await stress(g,board),
		"environment":{"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),
			"scope":"CanvasItem board draw and host frame intervals; excludes GPU completion, audio and device scheduling"}}
	app.queue_free()
	await process_frame
	print("Native V2 effects: "+JSON.stringify(report))
	print("Native V2 effects checks: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
