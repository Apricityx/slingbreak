extends SceneTree
## Native movie-writer showcase, including the production sampled audio mixer.
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
const Audio=preload("res://src/audio/sound_engine.gd")
var g:RefCounted
var board:Node2D
var audio:Node
var caption:Label
var frame:=0
func _initialize() -> void:call_deferred("setup")
func setup() -> void:
	root.size=Vector2i(412,915);root.content_scale_size=Vector2i.ZERO
	var bg:=ColorRect.new();bg.color=Color("#12171b");bg.size=root.size;root.add_child(bg)
	g=Sim.new();g.start(9128);g.theme="dark"
	preload("res://tools/preview_abyss.gd").setup(g,"eye_intro")
	board=Board.new();board.simulation=g;root.add_child(board);board.scale=Vector2.ONE*0.49;board.set_process(false)
	audio=Audio.new();root.add_child(audio);audio.simulation=g;audio.set_process(false);audio.sync({"soundEnabled":true,"volume":80})
	var font:Font=preload("res://src/ui/presentation.gd").load_font("cjk")
	var title:=Label.new();title.text="深渊之眼 · 蚀月遗像";title.position=Vector2(22,16);title.add_theme_font_override("font",font);title.add_theme_font_size_override("font_size",25);root.add_child(title)
	caption=Label.new();caption.position=Vector2(22,54);caption.add_theme_font_override("font",font);caption.add_theme_font_size_override("font_size",15);root.add_child(caption)
func _process(_delta:float) -> bool:
	if board==null:return false
	var dt:=1.0/30;var t:float=frame*dt
	g.clock=t;g.pointer=Vector2(390+sin(t)*220,700)
	var m:RefCounted=g.bosses.model
	# Real director owns both phase changes, locks, reveals and board entrances.
	if frame in [120,495]:g.bosses.fight.hp=0
	if frame==240:m.begin("mirage")
	if frame==330:m.calm();m.begin("gaze")
	if frame==615:m.begin("doom")
	if frame in [660,690,720]:
		var arrow:RefCounted=g.launch(m.center+Vector2(0,m.Rig.PUPIL_RADIUS+12),Vector2(0,-24));g.bosses.contact(arrow,true);g.arrows.clear()
		if frame==720 and not m.exposed():push_error("Preview third contact failed to break the seal");quit(1);return false
	if frame==795:g.bosses.fight.hp=0
	m.next_at=100
	g.tick(dt);g.presentation_time=g.time;g.fx.advance_visual(dt)
	board._process(dt);board.position=Vector2(14,150)
	caption.text="封印苏醒 · 符文聚合" if t<4 else "第二相 · 旧阵裂解 / 解封" if t<8 else "镜界双瞳 · 凝视与幻影" if t<11 else "视界切割 · 聚焦 / 扫射" if t<16.5 else "终相 · 符印变色 / 新阵亮起" if t<20.5 else "终焉坍缩 · 三击打断" if t<24 else "破盾 · 碎片余波" if t<26.5 else "终幕 · 遗像崩解"
	audio.play_requests(g.sounds);g.sounds.clear();audio._process(dt)
	frame+=1
	if frame>=879:
		audio.shutdown();g.dispose();quit()
	return false
