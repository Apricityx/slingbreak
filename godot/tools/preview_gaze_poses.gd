extends SceneTree
## Native keyframe evidence, sampled from the same real-input slice as the GIF.
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
const Preview=preload("res://tools/preview_abyss.gd")
const Rig=preload("res://src/render/abyss_rig.gd")
var out:="res://../agent-tmp/godot/eye-nebula/poses/"
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(390,530);root.content_scale_size=Vector2i.ZERO
	var background:=ColorRect.new();background.size=root.size;background.color=Color("#191f1b");root.add_child(background)
	var g:=Sim.new();g.start(9128);g.theme="dark";Preview.setup(g,"eye_gaze_counter")
	var board:=Board.new();board.simulation=g;root.add_child(board);board.scale=Vector2.ONE*0.5;board.set_process(false)
	var entry:Dictionary={"g":g,"id":"eye_gaze_counter","fired":false}
	var records:Array=[]
	for item in [["01-observe",0.2],["02-lock",1.0],["03-red",2.6],["04-laser",2.92],["gaze-active",3.1],["05-broken",3.48],["break-separate",3.65],["06-exposed",4.0]]:
		while g.time+0.001<item[1]:Preview.step_gaze(entry,float(entry.get("elapsed",0))+1.0/60)
		board._process(0);board.position=Vector2(0,15)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+item[0]+".png")
		records.append({"name":item[0],"time":g.time,"pose":Rig.pose(g).pose,"brokenAt":entry.get("broken_at",-1)})
	FileAccess.open(out+"timing.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	g.dispose();board.queue_free();await process_frame;quit()
