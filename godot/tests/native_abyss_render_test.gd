extends SceneTree
## GPU evidence for the original-size aperture and its real phase animation.
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
var checks:=0
var failures:=0
var board:Node2D
var g:RefCounted
var out:="res://../agent-tmp/godot/abyss-model/"
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func difference(a:Image,b:Image,area:Rect2i) -> float:
	var total:=0.0
	for x in range(area.position.x,area.end.x,3):
		for y in range(area.position.y,area.end.y,3):
			var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
			total+=absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)
	return total
func advance(seconds:float) -> void:
	for i in range(ceili(seconds*60)):
		g.clock+=1.0/60;g.tick(1.0/60);g.presentation_time=g.time
func capture(name:String,show_fx:bool=true) -> Image:
	board._process(0);board.position=Vector2.ZERO
	board.abyss_fx.visible=show_fx and board.abyss_fx.visible
	await process_frame;await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image()
	image.save_png(out+name+".png")
	return image
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Abyss material test requires graphics");quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(780,980)
	var background:=ColorRect.new();background.size=root.size;root.add_child(background)
	for theme in ["dark","light"]:
		for reduced in [false,true]:
			var tag:String=theme+("-reduced" if reduced else "")
			background.color=Color("#171e20" if theme=="dark" else "#d5d9cc")
			g=Sim.new();g.start(9128);g.theme=theme;g.state.performanceMode=reduced
			preload("res://tools/preview_abyss.gd").setup(g,"eye_model")
			board=Board.new();board.simulation=g;root.add_child(board);board.set_process(false)
			advance(0.1)
			var open:=await capture(tag+"-open")
			board.abyss_surface.visible=false
			await process_frame;await RenderingServer.frame_post_draw
			var absent:Image=root.get_texture().get_image()
			check(difference(open,absent,Rect2i(320,42,140,100))>45,"relic actually renders: "+tag)
			check(board.abyss_surface.surfaces.size()==2,"bounded GPU head pool: "+tag)
			check(board.abyss_fx.get_child_count()==13,"fixed twelve-volume pool plus one beam: "+tag)
			check(board.abyss_surface.surfaces[0].polygon[0]==Vector2(-180,-84) and board.abyss_surface.surfaces[0].polygon[2]==Vector2(180,84),"original 360 by 168 carrier: "+tag)
			g.bosses.fight.hp=0;advance(1.0/60)
			advance(0.4)
			var echo:=await capture(tag+"-echo")
			var no_echo:=await capture(tag+"-no-echo",false)
			check(difference(echo,no_echo,Rect2i(50,165,680,620))>40,"outgoing masonry visibly fades into imprints: "+tag)
			advance(0.5)
			var closed:=await capture(tag+"-closed")
			check(difference(open,closed,Rect2i(320,42,140,100))>50,"eyelids visibly close before rupture: "+tag)
			advance(0.75)
			var rupture:=await capture(tag+"-rupture")
			var no_rupture:=await capture(tag+"-no-rupture",false)
			check(difference(rupture,no_rupture,Rect2i(210,15,360,180))>5,"reveal volume and debris visibly render: "+tag)
			advance(1.9)
			var second:=await capture(tag+"-second")
			check(difference(open,second,Rect2i(320,42,140,100))>1,"second form settles visibly on GPU: "+tag)
			g.bosses.fight.hp=0;advance(1.0/60);advance(3.5)
			var final_form:=await capture(tag+"-final")
			check(difference(second,final_form,Rect2i(320,42,140,100))>20,"final form has a distinct warm iris: "+tag)
			var rng_state:int=g.rng.state
			var same:=await capture(tag+"-held")
			check(difference(final_form,same,Rect2i(100,20,580,260))<0.01,"held animation renders identically: "+tag)
			check(g.rng.state==rng_state,"rendering leaves gameplay RNG untouched: "+tag)
			var m:RefCounted=g.bosses.model
			g.state.up.power=30;g.state.up.arrow=24;g.state.skills={"railgun":1}
			m.begin("gaze");advance(2.5)
			var beam:=await capture(tag+"-beam")
			var no_beam:=await capture(tag+"-no-beam",false)
			check(board.abyss_fx.beam.visible and difference(beam,no_beam,Rect2i(20,180,740,680))>35,"real live beam has layered GPU pixels across the board: "+tag)
			check(board.abyss_fx.beam.material.get_shader_parameter("mode")==6 and absf(board.abyss_fx.beam.material.get_shader_parameter("beam_length")-m.center.distance_to(m.beam_endpoint()))<0.01,"finite crimson beam stops at the real clipped endpoint: "+tag)
			check(difference(beam,no_beam,Rect2i(10,800,760,70))<0.01,"laser never reaches the launcher lane: "+tag)
			var eye_pixel:Color=beam.get_pixel(413,104)
			check(eye_pixel.r>eye_pixel.b*1.3,"heated crimson iris is visible in actual shader output: "+tag)
			check(not board.abyss_surface.guidance.visible,"boss counter guidance stays hidden: "+tag)
			m.daze(m.center,"test");advance(0.08)
			var broken:=await capture(tag+"-broken")
			check(not board.abyss_fx.beam.visible and board.abyss_fx.used>0,"interrupt retires the beam but keeps break aftermath: "+tag)
			g.paused=true
			for i in range(10):g.update(1.0/60)
			var held_break:=await capture(tag+"-held-break")
			check(difference(broken,held_break,Rect2i(200,10,380,220))<0.01,"pause freezes both shader and directional debris: "+tag)
			g.paused=false;m.calm();m.next_at=1000;advance(1.1)
			await capture(tag+"-break-tail")
			check(board.abyss_fx.used==0 and board.abyss_fx.volumes.all(func(v):return not v.visible),"break tails release every GPU slot: "+tag)
			var before_fx:int=g.rng.state
			for i in range(30):m.visuals.emit("seal_hit",Vector2(150+i*10,92),g.time)
			await capture(tag+"-pool-limit")
			check(board.abyss_fx.used==12 and board.abyss_fx.get_child_count()==13 and g.rng.state==before_fx,"event overload stays fixed-budget and RNG-independent: "+tag)
			m.visuals.reset()
			g.bosses.model.begin("mirage")
			await capture(tag+"-mirage")
			check(board.abyss_surface.surfaces.all(func(s):return s.visible),"mirage uses both retained heads: "+tag)
			g.bosses.fight.hp=0;advance(1.0/60);advance(0.9);await capture(tag+"-collapse")
			advance(0.5);await capture(tag+"-retired")
			check(not board.abyss_surface.visible,"collapsed head leaves no GPU surface: "+tag)
			check(board.abyss_fx.visible and board.abyss_fx.used>0,"death VFX remain after the head disappears: "+tag)
			advance(1.2)
			var tail:=await capture(tag+"-death-tail")
			var empty_tail:=await capture(tag+"-empty-tail",false)
			check(board.abyss_fx.used==0 and difference(tail,empty_tail,Rect2i(200,5,380,220))<0.01,"death leaves no retained draw commands or shader tails: "+tag)
			g.phase="draft";board._process(0)
			check(not board.abyss_fx.visible and not board.abyss_fx.beam.visible,"leaving combat hides all effect layers: "+tag)
			g.phase="ready";board._process(0);g.dispose()
			await process_frame;await RenderingServer.frame_post_draw
			check(not board.abyss_fx.visible,"reset between queue_redraw and GPU draw safely retires the FX layer: "+tag)
			board.queue_free();await process_frame
	print("Native abyss rendering: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
