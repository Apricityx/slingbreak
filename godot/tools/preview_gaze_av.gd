extends SceneTree
## Two reproducible paths on the same production board; all arrows use shoot().
const Sim=preload("res://src/core/simulation.gd")
const Board=preload("res://src/render/board.gd")
const Audio=preload("res://src/audio/sound_engine.gd")
const Preview=preload("res://tools/preview_abyss.gd")
var g:RefCounted
var board:Node2D
var audio:Node
var caption:Label
var state_label:Label
var entry:Dictionary
var frame:=0
func _initialize() -> void:call_deferred("setup")
func label_at(size:int,at:Vector2) -> Label:
	var label:=Label.new();label.position=at
	label.add_theme_font_override("font",preload("res://src/ui/presentation.gd").load_font("cjk"))
	label.add_theme_font_size_override("font_size",size);label.add_theme_color_override("font_color",Color("#dde4d2"));root.add_child(label);return label
func setup() -> void:
	# Match the project's Movie Maker viewport; crop the unused bottom in the
	# encoded deliverable, rather than resizing an already-recording viewport.
	root.size=Vector2i(412,915);root.content_scale_size=Vector2i.ZERO;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var bg:=ColorRect.new();bg.color=Color("#191f1b");bg.size=root.size;root.add_child(bg)
	label_at(22,Vector2(14,15)).text="星云裂隙 · 猩红侵染"
	caption=label_at(14,Vector2(14,48));state_label=label_at(14,Vector2(14,620))
	board=Board.new();root.add_child(board);board.scale=Vector2.ONE*0.5;board.set_process(false)
	audio=Audio.new();root.add_child(audio);audio.set_process(false);audio.sync({"soundEnabled":true,"volume":75})
	reset("eye_nebula")
func reset(id:String) -> void:
	if g!=null:g.dispose()
	g=Sim.new();g.start(9128);g.theme="dark";Preview.setup(g,id)
	board.simulation=g;audio.simulation=g;entry={"g":g,"id":id,"fired":false}
func _process(_delta:float) -> bool:
	if g==null:return false
	if frame==120:reset("eye_gaze_failure")
	if frame==360:reset("eye_gaze_counter")
	var time:float=(frame if frame<120 else frame-120 if frame<360 else frame-360)/30.0
	Preview.step(entry,time)
	board._process(0);board.position=Vector2(11,105)
	caption.text="① 撕开裂缝 · 星云中显瞳" if frame<120 else "② 视界审判 · 扫射石化砖块" if frame<360 else "③ 脚本拉弓 · 迎瞳打断审判"
	var m:RefCounted=g.bosses.model
	state_label.text="裂隙苏醒" if frame<120 else "审判结束" if m.move.is_empty() else "锁定蓄力 → 瞳孔张开 → 扫射"
	if m.sweeping():state_label.text="扫射中 · 已石化 %d 块" % m.move.made
	if m.exposed():state_label.text="失神 %.1fs · 伤害 ×3" % (m.stunned_until-g.time)
	if g.drag!=null:state_label.text="拉弓中 · 等待释放"
	audio.play_requests(g.sounds);g.sounds.clear();audio._process(1.0/30)
	frame+=1
	if frame>=630:
		audio.shutdown();g.dispose();g=null;quit()
	return false
