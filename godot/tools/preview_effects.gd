extends SceneTree
## Deterministic visual fixture: production Board renderer, real GPU frames.
## No wall-clock simulation; this is an effect showcase, not gameplay footage.
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
var config:Dictionary
var entries:Array=[]

func _initialize() -> void:
	config=JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	call_deferred("capture")

func label_at(text:String,point:Vector2,font:Font,size:int,ink:Color) -> void:
	var label:=Label.new();label.text=text;label.position=point
	label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",ink);root.add_child(label)

func capture() -> void:
	if DisplayServer.get_name()=="headless":push_error("GIF capture requires graphics");quit(1);return
	var fixtures:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/effect_previews.json"))
	var columns:int=mini(2,config.skills.size())
	var rows:int=ceili(config.skills.size()/float(columns))
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(columns*360,rows*300+42)
	var dark:bool=config.theme=="dark"
	var bg:=Color("#191f1b" if dark else "#d5d9cc")
	var ink:=Color("#edf2e5" if dark else "#34412f")
	var background:=ColorRect.new();background.color=bg;background.size=root.size;root.add_child(background)
	var font:Font=preload("res://src/ui/presentation.gd").load_font("cjk")
	label_at("技能特效独立预览 · %s× · %s" % [config.speed,"简化" if config.reduced else "完整"],Vector2(12,8),font,16,ink)
	for i in range(config.skills.size()):
		var id:String=config.skills[i]
		var g:=Sim.new();g.start(9128);g.bricks.clear();g.obstacles.clear();g.skills.reset();g.fx.reset()
		g.phase="flying";g.state.skills={};g.board_entrance=null;g.theme=config.theme;g.state.performanceMode=config.reduced
		for row in range(5):
			for col in range(5):g.make_brick({"x":220+col*85,"y":340+row*50,"hp":12,"max":12,"w":76,"h":36})
		var origin:=Vector2((i%columns)*360,42+(i/columns)*300)
		var title:String=fixtures[id].get("label",g.content.by_id[id].name if g.content.by_id.has(id) else id)
		label_at(title+" · "+id,origin+Vector2(12,6),font,17,ink)
		var container:=SubViewportContainer.new();container.position=origin+Vector2(8,32);root.add_child(container)
		var viewport:=SubViewport.new();viewport.size=Vector2i(344,260);viewport.transparent_bg=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport)
		var board:=Board.new();board.simulation=g;viewport.add_child(board);board.set_process(false)
		entries.append({"g":g,"board":board,"id":id,"fixture":fixtures[id],"fired":false})
	for frame in range(config.frames):
		var time:float=(frame/float(config.fps)-0.2)*config.speed
		for entry in entries:
			var g:RefCounted=entry.g
			if entry.fixture.kind=="skill_batch_six":
				preload("res://tools/preview_skill_batch_six.gd").step(entry,time)
			elif entry.fixture.kind=="skill_batch_five":
				preload("res://tools/preview_skill_batch_five.gd").step(entry,time)
			elif time>=0 and not entry.fired:
				if entry.fixture.kind=="batch_four_live":
					preload("res://tools/preview_skill_batch_four.gd").fire(g,entry.id)
				elif entry.fixture.kind=="storm_chain":
					var previous:=Vector2(390,440)
					for offset in [Vector2(-85,0),Vector2(-85,-50),Vector2(0,-50),Vector2(85,-50),Vector2(85,0),Vector2(85,50),Vector2(0,50)]:
						var target:Vector2=Vector2(390,440)+offset
						g.fx.skill_event("storm",previous,previous.direction_to(target),target,1,entry.fixture.duration)
						previous=target
				elif entry.fixture.kind=="special_brick":
					g.fx.special_break(Vector2(390,440),entry.fixture.type)
					if entry.fixture.type=="frost":
						g.fx.frozen_target(Vector2(390,440))
						for brick in g.bricks:
							if brick.position.distance_to(Vector2(390,440))<140:
								brick.frozen=true;brick.frost_born=brick.position.distance_to(Vector2(390,440))/410.0
								brick.frost_direction=(brick.position-Vector2(390,440)).normalized()
				else:
					g.fx.skill_event(entry.id,Vector2(390,440),Vector2.UP,Vector2(470,385),1,entry.fixture.duration)
					if entry.fixture.kind=="explosion_and_skill":g.fx.explosion(Vector2(390,440),112,0.86)
				entry.fired=true
			g.fx.advance_visual(maxf(0,time)-g.fx.visual_time)
			entry.board._process(0)
			entry.board.position=Vector2(-218,-310)
		await process_frame
		await RenderingServer.frame_post_draw
		var path:String=config.out+"/frame-%04d.png" % frame
		if root.get_texture().get_image().save_png(path)!=OK:push_error("Cannot save "+path);quit(1);return
	for entry in entries:entry.g.dispose();entry.board.queue_free()
	await process_frame
	quit()
