extends Node2D
## Composition root only: simulation, presentation, UI and audio have separate owners.

const Session = preload("res://src/core/session.gd")
const Arena = preload("res://src/render/arena.gd")
const Interface = preload("res://src/ui/interface.gd")
const Audio = preload("res://src/audio/sound_engine.gd")
const Intro = preload("res://src/ui/intro.gd")

var session := Session.new()
var arena: Node2D
var interface: Control
var audio: Node
var save_clock := 0.0

func _ready() -> void:
	arena = Arena.new()
	add_child(arena)
	interface = Interface.new()
	add_child(interface)
	audio = Audio.new()
	add_child(audio)
	session.failed.connect(_failed)
	session.changed.connect(arena.present)
	session.changed.connect(interface.present)
	session.changed.connect(audio.sync)
	session.sound_requested.connect(audio.play_requests)
	session.events_received.connect(interface.receive_events)
	arena.action.connect(_action)
	interface.action.connect(_action)
	get_viewport().size_changed.connect(_resize)
	_resize()
	var test_mode: bool=get_meta("test_mode",false)
	if test_mode: set_process(false)
	if session.start(9128 if test_mode else int(Time.get_unix_time_from_system()), {} if test_mode else session.load_progress()):
		arena.simulation=session.runtime
		audio.simulation=session.runtime
		interface.set_catalog(session.catalog)
		interface.present(session.frame)
		if not test_mode and not session.frame.reduced:
			session.runtime.intro_active=true
			arena.visible=false
			interface.visible=false
			var intro=Intro.new()
			intro.session=session;intro.visuals=interface.visuals
			intro.finished.connect(_finish_intro)
			add_child(intro)

func _finish_intro() -> void:
	session.runtime.intro_active=false
	arena.visible=true
	interface.visible=true
	if session.frame.phase=="draft": interface.present(session.frame)

func _process(delta: float) -> void:
	session.poll_save()
	session.update(delta)
	save_clock += delta
	if save_clock >= 5.0:
		save_clock = 0.0
		session.request_save()

func _action(method: String, input: Dictionary) -> void:
	if method=="exportFile":
		var progress = session.call_method("exportProgress",{})
		var file := FileAccess.open(input.path,FileAccess.WRITE)
		if file==null: interface.show_error("无法写入进度文件");return
		file.store_string(JSON.stringify(progress,"  "));file.close()
		return
	if method=="importFile":
		var progress = JSON.parse_string(FileAccess.get_file_as_string(input.path))
		if not progress is Dictionary or not session.import_progress(progress): interface.show_error("无效的游戏进度文件")
		else:arena.simulation=session.runtime;audio.simulation=session.runtime
		return
	var result:Variant=session.command(method, input)
	if method=="buy" and result is Dictionary and result.get("accepted",false) and session.runtime.rank("bargain"):
		preload("res://src/render/bargain_feedback.gd").show_at(interface,session.runtime,input.get("key",""))
	if not get_meta("test_mode",false):
		if method=="configure": session.save_settings()
		if method in ["choose", "buy", "reroll", "swap", "reset"]: session.request_save()

func _resize() -> void:
	# Stage layout remains fixed; the engine scales the whole 412 × 915 canvas.
	arena.position = Vector2(0, 238)
	arena.scale = Vector2.ONE
	interface.size = Vector2(412, 915)
	# Board coordinates add a fixed 0.52 scale. UI cards and modal sheets are
	# also animated with non-unit Control scales, so let Godot rebuild the
	# glyph atlas for the effective scale instead of stretching one raster.
	arena.board.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	interface.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		session.save()
		session.command("pause", {"paused":true})
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		session.save()
		get_tree().quit()

func _failed(message: String) -> void:
	push_error(message)
	if interface != null: interface.show_error(message)

func _exit_tree() -> void:
	session.finish_save()
	if session.runtime!=null:session.runtime.dispose()
