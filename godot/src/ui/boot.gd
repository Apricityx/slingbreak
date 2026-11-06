extends Node
## Lightweight entry: keep the exact engine splash on screen while the heavy
## composition root loads. No fake progress, minimum duration or loading labels.
const COVER = preload("res://assets/boot/splash.png")
const MAIN := "res://scenes/main.tscn"
const REVEAL_SECONDS := 0.64
var cover: ColorRect
var layer: CanvasLayer
var app: Node
var revealing := false
var elapsed := 0.0
var reduced := false
var failed := false
signal reveal_started

func _ready() -> void:
	layer=CanvasLayer.new();layer.layer=100;add_child(layer)
	cover=ColorRect.new();cover.color=Color("#d5d9cc")
	cover.mouse_filter=Control.MOUSE_FILTER_STOP
	layer.add_child(cover);cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art:=TextureRect.new();art.texture=COVER
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cover.add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Defer heavy script loading until the branded frame has actually been drawn.
	_begin.call_deferred()

func _begin() -> void:
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	# This is deliberately a resting illustration, not a spinner whose motion
	# would stutter while Godot instantiates scripts/fonts on the main thread.
	var scene:=load(MAIN) as PackedScene
	if scene==null:
		_fail("无法打开小游戏，请重新启动。")
		return
	app=scene.instantiate();app.set_meta("startup_managed",true)
	if get_meta("test_mode",false):app.set_meta("test_mode",true)
	app.startup_ready.connect(_prepared)
	app.session.failed.connect(_fail)
	add_child(app)

func _process(delta: float) -> void:
	if failed:return
	if revealing:
		elapsed+=maxf(0,delta)
		var progress:=1.0 if reduced else clampf(elapsed/REVEAL_SECONDS,0,1)
		app._reveal_intro(progress)
		cover.modulate.a=1-smoothstep(0.08,0.92,progress)
		if progress>=1:
			app._finish_intro();layer.queue_free();set_process(false)
		return

func _prepared() -> void:
	# Main emits this only after real resource/FX preparation and the initial UI.
	reduced=app.session.frame.reduced
	app.session.runtime.intro_active=true
	app._reveal_intro(0.0)
	# Submit a complete incoming frame under the opaque cover before unveiling it.
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	revealing=true
	reveal_started.emit()

func _fail(message: String) -> void:
	failed=true
	var label:=Label.new();label.text=message
	var font:=FontFile.new();font.data=FileAccess.get_file_as_bytes("res://assets/fonts/cjk.bin")
	label.add_theme_font_override("font",font)
	label.add_theme_color_override("font_color",Color("#34412f"))
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(label);label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.position.y-=100

func _input(event: InputEvent) -> void:
	# Keyboard must not activate the incoming draft under an opaque cover either.
	if is_processing() and event is InputEventKey:get_viewport().set_input_as_handled()
