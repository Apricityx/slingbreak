extends SceneTree
## 熔炉巨像 movie-writer showcase with the production sampled score. The 60 Hz
## controller and Director own every phase change; the script only forces the
## authored move and places real arrow contacts.
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
const Audio=preload("res://src/audio/sound_engine.gd")
const Fixture=preload("res://tools/preview_forge.gd")
const Forge=preload("res://src/bosses/forge.gd")
var g:RefCounted
var board:Node2D
var audio:Node
var caption:Label
var frame:=0
var entry:={}
func _initialize() -> void:call_deferred("setup")
func setup() -> void:
	root.size=Vector2i(412,915);root.content_scale_size=Vector2i.ZERO
	var bg:=ColorRect.new();bg.color=Color("#12171b");bg.size=root.size;root.add_child(bg)
	g=Sim.new();g.start(9128);g.theme="dark"
	Fixture.setup(g,"forge_intro");g.bosses.intro_at=0
	board=Board.new();board.simulation=g;root.add_child(board);board.scale=Vector2.ONE*0.49;board.set_process(false)
	audio=Audio.new();root.add_child(audio);audio.simulation=g;audio.set_process(false);audio.sync({"soundEnabled":true,"volume":80})
	var font:Font=preload("res://src/ui/presentation.gd").load_font("cjk")
	var title:=Label.new();title.text="熔炉巨像 · 采样配乐";title.position=Vector2(22,16);title.add_theme_font_override("font",font);title.add_theme_font_size_override("font_size",25);root.add_child(title)
	caption=Label.new();caption.position=Vector2(22,54);caption.add_theme_font_override("font",font);caption.add_theme_font_size_override("font_size",15);root.add_child(caption)
func once(key:String,ready:bool) -> bool:
	if not ready or entry.get(key,false):return false
	entry[key]=true;return true
## Authored beats on the real game clock; each returns once its contacts land.
func script(at:float) -> void:
	var d:RefCounted=g.bosses;var m:RefCounted=d.model;var live:bool=not m.move.is_empty()
	if once("slam",at>=5.0):m.begin("slam");m.move.side=0
	if once("fist",live and m.move.get("id")=="slam" and g.time>=m.move.live-0.35):Fixture.shot(g,m.fist_point(0),Vector2(60,0))
	# The slam counter vents the furnace; fuel then reheats the sealed door.
	for i in range(2):
		if once("fuel%d" % i,at>=12.4+i*1.2):
			var fuel:Array=g.bricks.filter(func(b):return b.type=="magma")
			if not fuel.is_empty():
				g.active_arrow=g.launch(fuel[0].position+Vector2(0,40),Vector2(0,-20));g.arrows.erase(g.active_arrow)
				g.hit(fuel[0],1e9);g.active_arrow=null
	for i in range(3):
		if once("door%d" % i,at>=7.6+i*0.8 and m.exposed()):Fixture.shot(g,Forge.CENTER)
	if once("phase2",at>=17.0):m.stunned_until=0;d.fight.hp=0
	if once("bellows",at>=21.0):m.begin("bellows");m.move.side=1
	if once("nozzle",live and m.move.get("id")=="bellows" and g.time>=m.move.live+1.2):Fixture.shot(g,Forge.SHOULDERS[1])
	if once("meltdown",at>=27.0 and m.move.is_empty() and not m.exposed()):m.begin("meltdown")
	for i in range(3):
		if once("beat%d" % i,live and m.move.get("id")=="meltdown" and g.time>=m.move.live+m.beat_period()*(i+2)+0.05):Fixture.shot(g,Forge.CENTER)
	if once("phase3",at>=36.0):m.stunned_until=0;d.fight.hp=0
	if once("slam3",at>=40.0):m.begin("slam");m.move.side=1
	if once("fist3",live and m.move.get("id")=="slam" and at>=40.0 and g.time>=m.move.live-0.35):Fixture.shot(g,m.fist_point(1),Vector2(-60,0))
	if once("death",at>=47.0):m.stunned_until=0;d.fight.hp=0
func label(t:float) -> String:
	return "点火 · 熔炉自下而上燃起" if t<5 else "第一相 · 余烬 / 锻锤" if t<7 else "开炉 · 炉火咆哮压过乐队" if t<11.5 else "燃料加温 · 炉床随炉温升高" if t<17 else "转相 · 只剩炉床" if t<20 else "第二相 · 鼓与提琴 / 风箱" if t<27 else "熔毁 · 金属乐接管" if t<36 else "第三相 · 交响金属 / 开炉压低" if t<47 else "熄火 · 低通收拢"
func _process(_delta:float) -> bool:
	if board==null:return false
	var dt:=1.0/30;var t:float=frame*dt
	g.pointer=Vector2(390+sin(t)*220,700)
	# Two 60 Hz production ticks per 30 fps movie frame.
	for i in range(2):
		var at:float=frame*dt+i/60.0
		script(at)
		var m:RefCounted=g.bosses.model
		if m!=null and m.next_at<500 and m.move.is_empty() and not m.exposed():m.next_at=1000
		g.clock+=1.0/60;g.tick(1.0/60)
	g.presentation_time=g.time;g.fx.advance_visual(dt)
	board._process(dt);board.position=Vector2(14,150)
	caption.text=label(t)
	audio.play_requests(g.sounds);g.sounds.clear();audio._process(dt)
	frame+=1
	if frame>=int(51.5*30):
		audio.shutdown();g.dispose();quit()
	return false
