extends Control
## One clock drives the outgoing cover and incoming game, with a full-size input guard.
const Easing = preload("res://src/ui/easing.gd")
signal finished
signal revealing(progress: float)
const EXIT_SECONDS := 0.64

var session: SlingSession
var visuals: RefCounted
var age := 0.0
var leaving_at := -1.0
var done := false
var art: Control
var content: Control
var skip: Button
var background: ColorRect

func _ready() -> void:
	size=Vector2(412,915)
	z_index=100
	clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	visuals.apply(self)
	background=ColorRect.new()
	background.color=visuals.color("bg");background.size=size
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
	content=Control.new();content.size=size;content.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(content)
	var title:Label=visuals.label("SLING / BREAK",13,"text-2")
	title.position=Vector2(0,270);title.size.x=412;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;content.add_child(title)
	var name:Label=visuals.label("弓引力.",40,"ink",true)
	name.position=Vector2(0,296);name.size.x=412;name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;content.add_child(name)
	art=preload("res://src/ui/intro_art.gd").new();art.name="Art";art.visuals=visuals;art.position=Vector2(12,354);art.size=Vector2(388,278.875)
	content.add_child(art)
	skip=Button.new();skip.text="跳过  →";skip.position=Vector2(300,847);skip.size=Vector2(88,44)
	skip.pressed.connect(leave);add_child(skip);skip.grab_focus()
	_paint()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if done:return
	age+=maxf(0,delta)
	if leaving_at<0:
		_paint()
		if age>=1.86:leave()
	else:
		var progress:=clampf((age-leaving_at)/EXIT_SECONDS,0,1)
		var lift:=Easing.bezier(progress,.22,1,.36,1)
		content.position.y=-22*lift
		content.modulate.a=1-smoothstep(0.0,.62,progress)
		background.modulate.a=1-smoothstep(.08,.92,progress)
		skip.modulate.a=1-smoothstep(0.0,.28,progress)
		revealing.emit(progress)
		# The illustration continues its own trajectory while the sheet closes.
		_paint()
		if progress>=1:finish()

func _paint() -> void:
	art.age=age;art.queue_redraw()

func leave() -> void:
	if done or leaving_at>=0:return
	leaving_at=age
	skip.disabled=true
	revealing.emit(0.0)

func finish() -> void:
	if done:return
	done=true;set_process(false);revealing.emit(1.0);finished.emit();queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_SPACE,KEY_ENTER]:leave()
		# The incoming UI is already visible; keep keyboard focus behind the
		# same guard as pointer input until the handoff has settled.
		get_viewport().set_input_as_handled()
