extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Income render test requires --gui");quit(1);return
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(780,1100)
	var g:=Sim.new();g.start(123);g.bricks.clear();g.fx.reset();g.phase="flying";g.board_entrance=null
	var board:=Board.new();board.simulation=g;root.add_child(board)
	for theme in ["light","dark"]:
		g.theme=theme
		for i in range(3):await process_frame
		await RenderingServer.frame_post_draw
		var empty:=root.get_texture().get_image()
		g.fx.income.record(Vector2(390,440),100,1,8,9)
		g.fx.income.record(Vector2(390,440),200,1,9,9)
		g.fx.income.advance(0.04)
		for i in range(3):await process_frame
		await RenderingServer.frame_post_draw
		var visible:=root.get_texture().get_image()
		var changed:=0;var subtitle:=0
		for y in range(360,445):
			for x in range(300,480):
				if empty.get_pixel(x,y)!=visible.get_pixel(x,y):
					changed+=1
					if y>=422:subtitle+=1
		if changed<250 or subtitle<20:
			push_error("Income amount/count not visible in %s: %d/%d pixels" % [theme,changed,subtitle]);g.dispose();quit(1);return
		g.fx.income.items.clear()
	g.dispose();board.queue_free();await process_frame
	print("Native income rendering: light/dark amount and count pixels visible; 0 failures");quit()
