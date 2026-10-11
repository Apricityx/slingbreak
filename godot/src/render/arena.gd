extends Node2D
## Native battlefield input and world presentation.

signal action(method: String, input: Dictionary)
const VIEW_SCALE := 0.52
const VIEW_OFFSET := Vector2(3.2, 0)
const VIEW_SIZE := Vector2(412, 572)
var frame: Dictionary = {}
var dragging := false
var drag := Vector2.ZERO
var keyboard_angle := 0.0
var keyboard_power := 0.85
var touch_id := -1
var simulation: RefCounted:
	set(value):simulation=value;board.simulation=value
var board:=preload("res://src/render/board.gd").new()
var draw_step := 0

func _ready() -> void:
	board.position=VIEW_OFFSET;board.scale=Vector2.ONE*VIEW_SCALE;add_child(board)

func present(value: Dictionary) -> void:
	frame = value
	if frame.get("paused",false) or frame.phase not in ["ready","flying"]:
		dragging = false
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,VIEW_SIZE),Color("#1a1f17") if frame.get("theme")=="dark" else Color("#fafbf7"))

func _world(point: Vector2) -> Vector2:
	return (to_local(point) - VIEW_OFFSET) / VIEW_SCALE

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or frame.is_empty() or frame.get("paused",false) or frame.phase not in ["ready","flying"]:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: keyboard_angle=maxf(-1.1,keyboard_angle-.07)
			KEY_RIGHT: keyboard_angle=minf(1.1,keyboard_angle+.07)
			KEY_UP: keyboard_power=minf(1,keyboard_power+.05)
			KEY_DOWN: keyboard_power=maxf(.2,keyboard_power-.05)
			KEY_SPACE:
				if not event.echo: action.emit("shoot",{"dx":-sin(keyboard_angle)*100*keyboard_power,"dy":cos(keyboard_angle)*100*keyboard_power})
			_: return
		action.emit("keyboard",{"angle":keyboard_angle,"power":keyboard_power})
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		_pointer_button(_world(event.position),event.pressed)
	elif event is InputEventMouseMotion:
		var point := _world(event.position)
		action.emit("pointer",{"active":Rect2(Vector2.ZERO,VIEW_SIZE).has_point(to_local(event.position)),"x":point.x,"y":point.y})
		if dragging: _drag_to(point)
	elif event is InputEventScreenTouch:
		if touch_id<0 and event.pressed:
			touch_id=event.index
			action.emit("pointer",{"touch":true,"active":false})
			_pointer_button(_world(event.position),true)
		elif touch_id==event.index and not event.pressed:
			_pointer_button(_world(event.position),false);touch_id=-1
	elif event is InputEventScreenDrag and event.index==touch_id:
		_drag_to(_world(event.position))

func _pointer_button(point: Vector2,pressed: bool) -> void:
	if pressed and point.distance_to(Vector2(frame.origin.x,frame.origin.y))<=120:
		dragging=true;drag=Vector2.ZERO;draw_step=0
		action.emit("drag",{"active":true,"dx":0,"dy":0})
		get_viewport().set_input_as_handled()
	elif not pressed and dragging:
		dragging=false
		action.emit("drag",{"active":false})
		action.emit("shoot",{"dx":drag.x,"dy":drag.y})
		drag=Vector2.ZERO
		get_viewport().set_input_as_handled()

func _drag_to(point: Vector2) -> void:
	if not dragging: return
	drag=point-Vector2(frame.origin.x,frame.origin.y)
	drag.y=maxf(0,drag.y);drag=drag.limit_length(105)
	action.emit("drag",{"active":true,"dx":drag.x,"dy":drag.y})
	var next_step := int(minf(100,drag.length())/20)
	if next_step > draw_step: action.emit("cue",{"type":"draw","n":next_step,"ui":false})
	draw_step=next_step

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		dragging=false;touch_id=-1;drag=Vector2.ZERO
		action.emit("drag",{"active":false})
