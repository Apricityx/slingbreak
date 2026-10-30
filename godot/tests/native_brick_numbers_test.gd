extends SceneTree
## Compare actual font pixels, not just calls to the text drawing helper.
const Sim=preload("res://src/core/simulation.gd")
class NumberBoard extends "res://src/render/board.gd":
	var show_numbers:=true
	func _text(value:String,point:Vector2,size:int,color_value:Color) -> void:
		if show_numbers:super._text(value,point,size,color_value)

var failures:=0
func _initialize() -> void:call_deferred("run")
func capture(view:SubViewport,board:Node2D) -> Image:
	for node in board.retained.values():node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Font pixel regression requires --gui");quit(1);return
	var sim:=Sim.new();sim.start(9128)
	sim.bricks.clear();sim.obstacles.clear();sim.phase="ready";sim.board_entrance=null;sim.paused=true
	for data in [{"x":150,"y":200,"hp":1,"max":1},{"x":300,"y":200,"hp":13,"max":14},{"x":450,"y":200,"hp":12,"max":12,"type":"bomb"}]:sim.make_brick(data)
	var view:=SubViewport.new();view.size=Vector2i(780,1100);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var board:=NumberBoard.new();board.simulation=sim;view.add_child(board)
	for theme in ["light","dark"]:
		sim.theme=theme
		await process_frame;await process_frame
		if "--broken-material" in OS.get_cmdline_user_args():
			for node in board.retained.values():node.material=board.material
		board.show_numbers=true
		var visible:=await capture(view,board)
		board.show_numbers=false
		var hidden:=await capture(view,board)
		for brick in sim.bricks:
			var changed:=0
			for y in range(184,216):
				for x in range(int(brick.x-35),int(brick.x+39)):
					if visible.get_pixel(x,y)!=hidden.get_pixel(x,y):changed+=1
			if changed<15:
				failures+=1;push_error("Missing brick number pixels: %s %s HP %s" % [theme,brick.type,brick.hp])
		board.show_numbers=true
	view.queue_free();await process_frame;sim.dispose()
	print("Native brick numbers: 6 pixel comparisons, %d failures" % failures)
	quit(1 if failures else 0)
