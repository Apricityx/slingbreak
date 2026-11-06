extends CanvasLayer
## Floating launch orb. The host owns readiness; animations never grant permission.
const Presentation=preload("res://src/ui/presentation.gd")
const RingShader=preload("res://src/ui/launcher_ring.gdshader")
const HudActionLayout=preload("res://src/ui/hud_action_layout.gd")
var visuals:=Presentation.new()
var launcher: Node
var body: Control
var ring: ColorRect
var ink: ShaderMaterial
var readout: Control
var percent: Label
var enter: Button
var play_icon: TextureRect
var message: Label
var current_theme:=""
var state: Dictionary={}
var reduced:=false
var displayed_progress:=0.0
var target_progress:=-1.0
var ready_mix:=0.0
var clock:=0.0
var ready_age:=0.0
var interaction:=0.0
var interaction_target:=0.0
var meter_motion: Tween
var reveal_motion: Tween

class RoundButton extends Button:
	func _has_point(point: Vector2) -> bool:
		return point.distance_squared_to(size*.5)<=pow(minf(size.x,size.y)*.5,2)

func _ready() -> void:
	layer=20
	body=Control.new();body.name="LauncherDock";body.size=HudActionLayout.LAUNCH_RECT.size
	body.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.pivot_offset=body.size*.5;add_child(body)
	ink=ShaderMaterial.new();ink.shader=RingShader
	# Glow has overscan, but the visible face and hit target match the 46px market.
	ring=ColorRect.new();ring.position=Vector2(-11,-11);ring.size=Vector2(68,68);ring.material=ink;ring.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_child(ring)
	readout=Control.new();readout.size=body.size;readout.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_child(readout)
	percent=visuals.label("0%",13,"on-panel",true);percent.position=Vector2(3,12);percent.size=Vector2(40,22);percent.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;percent.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;readout.add_child(percent)
	enter=RoundButton.new();enter.name="EnterMainGame";enter.size=body.size;enter.text="启动";body.add_child(enter)
	enter.add_theme_font_size_override("font_size",11)
	play_icon=visuals.image(enter,"play",visuals.color("on-panel"),Vector2(10,10));play_icon.position=Vector2(18,8);play_icon.size=Vector2(10,10)
	enter.pressed.connect(func():
		if state.get("phase","")=="save_error":launcher.retry_save()
		else:launcher.request_enter()
	)
	enter.mouse_entered.connect(func():interaction_target=1.0)
	enter.mouse_exited.connect(func():interaction_target=0.0)
	enter.button_down.connect(func():interaction_target=-1.0)
	enter.button_up.connect(func():interaction_target=0.0)
	enter.focus_entered.connect(func():ink.set_shader_parameter("focused",true))
	enter.focus_exited.connect(func():ink.set_shader_parameter("focused",false))
	# Only failures need persistent text. Stage descriptions remain available as tooltips.
	message=visuals.label("",11,"ink",true);message.position=Vector2(58,4);message.size=Vector2(202,40)
	message.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_child(message)
	visuals.pointer_through(readout)
	set_theme_mode("light")
	get_viewport().size_changed.connect(_place)
	_place();launcher.state_changed.connect(present);present(launcher.state)

func _place() -> void:
	# Gameplay and the market share the fixed stage; never anchor this to window height.
	body.position=HudActionLayout.LAUNCH_RECT.position

func set_theme_mode(mode: String) -> void:
	if current_theme==mode:return
	current_theme=mode;visuals.mode=mode;visuals.apply(body)
	ink.set_shader_parameter("plate_color",visuals.color("panel"))
	ink.set_shader_parameter("track_color",visuals.mix(visuals.color("on-panel"),visuals.color("panel"),.19))
	ink.set_shader_parameter("accent_color",visuals.color("accent-bar"))
	percent.add_theme_color_override("font_color",visuals.color("on-panel"))
	message.add_theme_color_override("font_color",visuals.color("ink"))
	for key in ["normal","hover","pressed","disabled","focus"]:
		var face:=StyleBoxEmpty.new();face.content_margin_top=10;enter.add_theme_stylebox_override(key,face)
	for key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]:enter.add_theme_color_override(key,visuals.color("on-panel"))
	play_icon.texture=visuals.icon("play",visuals.color("on-panel"))

func set_reduced(value: bool) -> void:
	reduced=value;ink.set_shader_parameter("reduced_motion",value)
	if reduced:
		if meter_motion!=null:meter_motion.kill()
		if reveal_motion!=null:reveal_motion.kill()
		_set_progress(maxf(0,target_progress));_set_reveal(1.0 if state.get("ready",false) or state.get("phase","")=="save_error" else 0.0)
		body.scale=Vector2.ONE;interaction=0;ink.set_shader_parameter("interaction",0.0)

func _process(delta: float) -> void:
	if reduced:return
	clock+=delta;ready_age+=delta
	interaction=move_toward(interaction,interaction_target,delta*7)
	ink.set_shader_parameter("clock",clock);ink.set_shader_parameter("ready_age",ready_age);ink.set_shader_parameter("interaction",interaction)
	body.scale=Vector2.ONE*(1.0+interaction*.025)

func _set_progress(value: float) -> void:
	displayed_progress=value;ink.set_shader_parameter("progress",value/100.0);percent.text="%d%%" % roundi(value)
	_sync_entry()

func _set_reveal(value: float) -> void:
	ready_mix=value;ink.set_shader_parameter("ready_mix",value)
	readout.modulate.a=1-value;readout.position.y=-2*value
	enter.modulate.a=value;enter.position.y=3*(1-value)
	_sync_entry()

func _sync_entry() -> void:
	if enter==null:return
	var failed:bool=state.get("phase","")=="save_error"
	enter.disabled=not failed and (not state.get("ready",false) or state.get("phase","")!="ready" or ready_mix<.999 or displayed_progress<99.95)

func _meter(value: float) -> void:
	if is_equal_approx(target_progress,value):return
	target_progress=value
	if meter_motion!=null:meter_motion.kill()
	if reduced or DisplayServer.get_name()=="headless":_set_progress(value);return
	meter_motion=create_tween();meter_motion.tween_method(_set_progress,displayed_progress,value,.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func present(value: Dictionary) -> void:
	var was_ready:bool=state.get("ready",false)
	state=value.duplicate()
	var ready:bool=value.ready
	var failed:bool=value.phase=="save_error"
	_meter(100.0 if ready else minf(99,float(value.progress)))
	body.tooltip_text=value.message
	enter.tooltip_text="重试保存小游戏进度" if failed else "保存小游戏进度并进入主游戏"
	enter.visible=ready or failed;_sync_entry()
	message.text="保存失败，已有存档保留" if failed else "";message.visible=failed
	ink.set_shader_parameter("failed",failed);ink.set_shader_parameter("busy",value.phase in ["entering","saving"])
	play_icon.visible=value.phase=="ready"
	match value.phase:
		"entering":enter.text="启动中"
		"saving":enter.text="保存中"
		"saved":enter.text="已保存"
		"save_error":enter.text="重试"
		_:enter.text="启动"
	if failed:
		if reveal_motion!=null:reveal_motion.kill()
		_set_reveal(1.0)
	elif ready!=was_ready:
		if reveal_motion!=null:reveal_motion.kill()
		ready_age=0.0
		if reduced or DisplayServer.get_name()=="headless":_set_reveal(1.0 if ready else 0.0)
		else:
			reveal_motion=create_tween()
			if ready:reveal_motion.tween_interval(.36)
			reveal_motion.tween_method(_set_reveal,ready_mix,1.0 if ready else 0.0,.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	elif not ready:_set_reveal(0.0)
