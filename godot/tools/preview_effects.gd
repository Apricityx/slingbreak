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
	var boss:bool=config.skills.all(func(id):return fixtures[id].kind in ["abyss_boss","clock_boss","forge_boss","serpent_boss"])
	var sculpture:bool=config.skills.all(func(id):return fixtures[id].get("framing","")=="sculpture")
	var wide:bool=config.skills.all(func(id):return fixtures[id].get("framing","")=="wide")
	var cell:=Vector2i(700,410) if sculpture else Vector2i(406,532) if boss else Vector2i(560,470) if wide else Vector2i(360,300)
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(columns*cell.x,rows*cell.y+42)
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
		var hp:float=100 if fixtures[id].kind=="explosive_skill" else 80 if fixtures[id].kind=="skill_batch_nine" else 12
		for row in range(5):
			for col in range(5):g.make_brick({"x":220+col*85,"y":340+row*50,"hp":hp,"max":hp,"w":76,"h":36})
		for point in fixtures[id].get("bombs",[]):
			# Real bomb bricks in the grid: their kills run the production chain.
			for brick in g.bricks:
				if brick.position==Vector2(point[0],point[1]):
					brick.type="bomb";brick.hp=1.0
		var origin:=Vector2((i%columns)*cell.x,42+(i/columns)*cell.y)
		if fixtures[id].kind=="abyss_boss":preload("res://tools/preview_abyss.gd").setup(g,id)
		if fixtures[id].kind=="clock_boss":preload("res://tools/preview_clock.gd").setup(g,id)
		if fixtures[id].kind=="forge_boss":preload("res://tools/preview_forge.gd").setup(g,id)
		if fixtures[id].kind=="serpent_boss":preload("res://tools/preview_serpent.gd").setup(g,id)
		if fixtures[id].kind=="skill_batch_eight":preload("res://tools/preview_skill_batch_eight.gd").setup(g)
		var title:String=fixtures[id].get("label",g.content.by_id[id].name if g.content.by_id.has(id) else id)
		label_at(title+" · "+id,origin+Vector2(12,6),font,17,ink)
		var container:=SubViewportContainer.new();container.position=origin+Vector2(8,32);root.add_child(container)
		var viewport:=SubViewport.new();viewport.size=Vector2i(684,368) if sculpture else Vector2i(390,490) if boss else Vector2i(540,430) if wide else Vector2i(344,260);viewport.transparent_bg=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport)
		if fixtures[id].kind=="normal_brick":
			# The live board composites over an opaque page. A transparent
			# target would double-apply alpha where the broken brick was removed.
			viewport.transparent_bg=false
			var page:=ColorRect.new();page.color=bg;page.size=Vector2(4000,4000);page.position=Vector2(-2000,-2000);viewport.add_child(page)
		var board:=Board.new();board.simulation=g;viewport.add_child(board);board.set_process(false)
		if boss:board.scale=Vector2.ONE*(1.0 if sculpture else 0.5)
		elif fixtures[id].has("zoom"):board.scale=Vector2.ONE*fixtures[id].zoom
		entries.append({"g":g,"board":board,"id":id,"fixture":fixtures[id],"fired":false})
		if fixtures[id].kind=="skill_batch_seven":
			entries[-1].crop=preload("res://tools/preview_skill_batch_seven.gd").setup(g,id)
	for frame in range(config.frames):
		var time:float=(frame/float(config.fps)-0.2)*config.speed
		for entry in entries:
			var g:RefCounted=entry.g
			if entry.fixture.kind=="abyss_boss":
				preload("res://tools/preview_abyss.gd").step(entry,time)
			elif entry.fixture.kind=="clock_boss":
				preload("res://tools/preview_clock.gd").step(entry,time)
			elif entry.fixture.kind=="forge_boss":
				preload("res://tools/preview_forge.gd").step(entry,time)
			elif entry.fixture.kind=="serpent_boss":
				preload("res://tools/preview_serpent.gd").step(entry,time)
			elif entry.fixture.kind=="income":
				preload("res://tools/preview_income.gd").step(entry,time)
			elif entry.fixture.kind=="skill_batch_seven":
				preload("res://tools/preview_skill_batch_seven.gd").step(entry,time)
			elif entry.fixture.kind=="skill_batch_nine":
				preload("res://tools/preview_skill_batch_nine.gd").step(entry,time)
			elif entry.fixture.kind=="explosive_skill":
				preload("res://tools/preview_explosive_skills.gd").step(entry,time)
			elif entry.fixture.kind=="skill_batch_six":
				preload("res://tools/preview_skill_batch_six.gd").step(entry,time)
			elif entry.fixture.kind=="skill_batch_eight":
				preload("res://tools/preview_skill_batch_eight.gd").step(entry,time)
			elif entry.fixture.kind=="skill_batch_five":
				preload("res://tools/preview_skill_batch_five.gd").step(entry,time)
			elif entry.fixture.kind=="normal_brick":
				# Real kill path (simulation.hit), struck by an arrow travelling
				# up-right; each target breaks at its own time for chain reads.
				if entry.get("arrow")==null:
					entry.arrow=g.launch(Vector2(300,700),Vector2(260,-640));g.arrows.erase(entry.arrow);entry.hits=0
				while entry.hits<entry.fixture.targets.size() and time>=entry.fixture.targets[entry.hits][2]:
					var target:Array=entry.fixture.targets[entry.hits];entry.hits+=1
					for brick in g.bricks.duplicate():
						if brick.position==Vector2(target[0],target[1]):g.active_arrow=entry.arrow;g.hit(brick,1000);g.active_arrow=null
			elif time>=0 and not entry.fired:
				if entry.fixture.kind=="batch_four_live":
					preload("res://tools/preview_skill_batch_four.gd").fire(g,entry.id)
				elif entry.fixture.kind in ["storm_chain","lightning_chain"]:
					# Use the production kill/nearest/hop path, not a made-up arc.
					g.state.skills={"storm":1} if entry.fixture.kind=="storm_chain" else {}
					g.initial=1000
					for brick in g.bricks.duplicate():
						if brick.position==Vector2(390,440):g.bricks.erase(brick)
					var electric:RefCounted=g.make_brick({"x":390,"y":440,"hp":1,"max":1,"type":"lightning"})
					g.hit(electric,100)
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
				entry.fired=true
			if entry.id not in ["eye_gaze_counter","eye_gaze_failure","eye_ward"]:g.fx.advance_visual(maxf(0,time)-g.fx.visual_time)
			entry.board._process(0)
			entry.board.position=Vector2(-48,25) if sculpture else Vector2.ZERO if boss else entry.get("crop",Vector2(-120,-225) if wide else Vector2(-218,-310))
			if entry.fixture.has("zoom"):entry.board.position=entry.board.get_viewport_rect().size*0.5-Vector2(390,440)*entry.fixture.zoom
		await process_frame
		await RenderingServer.frame_post_draw
		var path:String=config.out+"/frame-%04d.png" % frame
		if root.get_texture().get_image().save_png(path)!=OK:push_error("Cannot save "+path);quit(1);return
	for entry in entries:entry.g.dispose();entry.board.queue_free()
	await process_frame
	quit()
