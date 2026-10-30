extends RefCounted
## Compile high-frequency GL paths before the first volley, without touching the
## live simulation. Hidden nodes / offscreen geometry would be culled, so render
## a small independent opaque viewport and then disable and release it.
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
static var complete:=false

static func prepare(host:Node) -> Dictionary:
	if complete or DisplayServer.get_name()=="headless":return {"skipped":true}
	var started:=Time.get_ticks_usec()
	var viewport:=SubViewport.new();viewport.size=Vector2i(128,128)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var g:=Sim.new();g.start(9128);g.state.draft=null;g.state.skills={};g.phase="ready"
	g.bricks.clear();g.obstacles.clear();g.core=null;g.board_entrance=null;g.fx.reset()
	var board:=Board.new();board.simulation=g;viewport.add_child(board);board.set_process(false)
	var frames:=0
	for reduced in [false,true]:
		g.state.performanceMode=reduced
		for i in range(8):
			for id in ["echo","piercer","seeking","ricochet","storm"]:
				g.fx.skill_event(id,Vector2(80,80),Vector2.RIGHT,Vector2(160,100),1,0.5)
			if i%5==0:g.fx.special_break(Vector2(100,100),"bomb")
			elif i%5==1:g.fx.special_break(Vector2(100,100),"gold")
			elif i%5==2:g.fx.special_break(Vector2(100,100),"frost");g.fx.frozen_target(Vector2(100,100))
			elif i%5==3:g.fx.special_break(Vector2(100,100),"prism")
			g.fx.advance_visual(0.04);board._process(0)
			board.position=Vector2.ZERO;board.scale=Vector2.ONE*.52
			await host.get_tree().process_frame
			await RenderingServer.frame_post_draw
			frames+=1
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	g.dispose();host.remove_child(viewport);viewport.queue_free();await host.get_tree().process_frame
	complete=true
	return {"frames":frames,"ms":(Time.get_ticks_usec()-started)/1000.0}
