extends Node2D
## Composition root only: simulation, presentation, UI and audio have separate owners.

const Session = preload("res://src/core/session.gd")
const Arena = preload("res://src/render/arena.gd")
const Interface = preload("res://src/ui/interface.gd")
const Audio = preload("res://src/audio/sound_engine.gd")
const Intro = preload("res://src/ui/intro.gd")
const Launcher = preload("res://src/core/launcher.gd")
const LauncherDock = preload("res://src/ui/launcher_dock.gd")
signal startup_ready

var session := Session.new()
var arena: Node2D
var interface: Control
var audio: Node
var save_clock := 0.0
var launcher: Node
var launcher_dock: CanvasLayer

func _ready() -> void:
	var test_mode: bool=get_meta("test_mode",false)
	var aspect_adapter=preload("res://src/ui/aspect_adapter.gd").new()
	add_child(aspect_adapter)
	launcher=Launcher.new();launcher.session=session
	if test_mode and has_meta("launcher_bridge"):launcher.bridge=get_meta("launcher_bridge")
	var attached:bool=launcher.discover()
	var hosted:bool=attached and launcher.is_launcher_mode()
	arena = Arena.new()
	add_child(arena)
	interface = Interface.new()
	if hosted:interface.launcher_mode=true
	add_child(interface)
	audio = Audio.new()
	add_child(audio)
	session.failed.connect(_failed)
	session.changed.connect(arena.present)
	session.changed.connect(interface.present)
	session.changed.connect(aspect_adapter.present)
	session.changed.connect(audio.sync)
	session.sound_requested.connect(audio.play_requests)
	session.events_received.connect(interface.receive_events)
	arena.action.connect(_action)
	interface.action.connect(_action)
	get_viewport().size_changed.connect(_resize)
	_resize()
	if test_mode: set_process(false)
	if not test_mode and not preload("res://src/render/effect_warmup.gd").complete and DisplayServer.get_name()!="headless":
		set_process(false);arena.visible=false;interface.visible=false
		await preload("res://src/render/effect_warmup.gd").prepare(self)
		arena.visible=true;interface.visible=true;set_process(true)
	# Hold the first draft before start() emits its initial frame. Its card
	# reels must begin on screen, rather than finish behind the opening cover.
	interface.startup_covered=not test_mode or get_meta("startup_managed",false)
	interface.variant_cards=not test_mode or get_meta("variant_cards",false)
	if session.start(9128 if test_mode else int(Time.get_unix_time_from_system()), {} if test_mode else session.load_progress()):
		arena.simulation=session.runtime
		audio.simulation=session.runtime
		interface.set_catalog(session.catalog)
		interface.present(session.frame)
		if get_meta("startup_managed",false):
			session.runtime.intro_active=true
		elif not test_mode and not session.frame.reduced:
			_start_intro()
		else:
			interface.startup_covered=false
			interface.present(session.frame)
	if attached and session.ready:
		if hosted:
			launcher_dock=LauncherDock.new();launcher_dock.launcher=launcher;add_child(launcher_dock)
			launcher_dock.set_theme_mode(session.frame.theme)
			launcher_dock.set_reduced(session.frame.reduced)
			session.changed.connect(func(value:Dictionary):launcher_dock.set_theme_mode(value.theme);launcher_dock.set_reduced(value.reduced))
		add_child(launcher)
	else:
		launcher.free();launcher=null
	if session.ready:startup_ready.emit()

func _start_intro() -> void:
	session.runtime.intro_active=true
	arena.visible=false;interface.visible=false
	var intro=Intro.new()
	intro.name="StartupIntro";intro.session=session;intro.visuals=interface.visuals
	intro.revealing.connect(_reveal_intro)
	intro.finished.connect(_finish_intro)
	add_child(intro)

func _reveal_intro(progress: float) -> void:
	arena.visible=true;interface.visible=true
	# Small, unscaled travel keeps text crisp. The board leads the HUD, then
	# the existing draft animation takes over while the cover is fading away.
	var board_amount:=Intro.Easing.bezier(progress,.22,1,.36,1)
	var ui_amount:=Intro.Easing.bezier(clampf((progress-.08)/.92,0,1),.22,1,.36,1)
	arena.position=Vector2(0,238+14*(1-board_amount))
	arena.modulate.a=smoothstep(0.0,.8,progress)
	interface.position=Vector2(0,10*(1-ui_amount))
	interface.modulate.a=smoothstep(.08,.9,progress)
	if progress>=.22 and interface.startup_covered:
		interface.startup_covered=false
		interface.present(session.frame)

func _finish_intro() -> void:
	session.runtime.intro_active=false
	arena.visible=true
	interface.visible=true
	arena.position=Vector2(0,238);arena.modulate.a=1
	interface.position=Vector2.ZERO;interface.modulate.a=1
	interface.startup_covered=false
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
		file.store_string(JSON.stringify(progress,"  "));file.flush()
		var error:=file.get_error();file.close()
		if error!=OK:interface.show_error("无法写入进度文件");return
		interface.show_file_result("游戏进度已导出")
		return
	if method=="importFile":
		# FileAccess accepts SAF content URIs directly; never convert them to paths.
		var file:=FileAccess.open(input.path,FileAccess.READ)
		if file==null:interface.show_error("无法读取进度文件");return
		var text:=file.get_as_text();var error:=file.get_error();file.close()
		if error not in [OK,ERR_FILE_EOF]:interface.show_error("无法读取进度文件");return
		var parser:=JSON.new()
		if parser.parse(text)!=OK or not parser.data is Dictionary or not Session.Progress.valid(parser.data):
			interface.show_error("无效的游戏进度文件");return
		var imported:bool=session.import_progress(parser.data)
		# import_progress replaces the runtime before persisting it. Even if the
		# private save fails, presentation must not retain the disposed runtime.
		arena.simulation=session.runtime;audio.simulation=session.runtime
		# Settings and the native picker own a pause; importing starts a new session.
		session.command("pause",{"paused":true})
		if not imported:interface.show_error("进度已载入，但无法保存到本机，请检查存储空间后重试");return
		interface.show_file_result("游戏进度已导入")
		return
	var result:Variant=session.command(method, input)
	if method=="buy" and result is Dictionary and result.get("accepted",false) and session.runtime.rank("bargain"):
		preload("res://src/render/bargain_feedback.gd").show_at(interface,session.runtime,input.get("key",""))
	if not get_meta("test_mode",false):
		if method=="configure": session.save_settings()
		if method=="reset":
			# Join any old autosave before replacing it with the new run. Reset
			# must survive closing immediately, not wait for the next save tick.
			if not session.save():interface.show_error("游戏已重置，但无法保存到本机，请检查存储空间后重试")
		elif method in ["choose", "buy", "reroll", "swap", "developer", "seenVariant"]: session.request_save()

func _resize() -> void:
	# Stage layout remains fixed; AspectAdapter only adjusts whole-canvas scaling.
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
