extends "res://src/core/variants/rule.gd"
## 闪移核心: the core jumps between fixed slots along the top every PERIOD
## seconds; a ring marks the next slot for the final WARN seconds. Bonus ×1.6.
const Progress=preload("res://src/core/progress.gd")
const SLOTS:=[150.0,270.0,390.0,510.0,630.0]
const Y:=80.0
const PERIOD:=2.6
const WARN:=0.8
const TINT:="#6f8fd8"

func title() -> String:return "闪移核心"
func color() -> String:return TINT
func note() -> String:return "核心每 %.1f 秒闪移 · 奖金 ×1.6" % PERIOD

func shape() -> void:data={"clock":0.0,"slot":2,"next":_pick(2),"blinks":0}

func valid(saved:Dictionary) -> bool:
	var last:=SLOTS.size()-1
	return Progress.finite_number(saved.get("clock"),0,PERIOD) and Progress.finite_number(saved.get("slot"),0,last,true) and Progress.finite_number(saved.get("next"),0,last,true) and saved.get("slot")!=saved.get("next") and Progress.finite_number(saved.get("blinks"),0,1e6,true)

func _pick(avoid:int) -> int:
	var choice:int=g.rng.randi_range(0,SLOTS.size()-2)
	return choice+1 if choice>=avoid else choice

func slot_point(index:int) -> Vector2:return Vector2(float(SLOTS[index]),Y)

func core_spawned() -> void:_place()

func _place() -> void:
	if g.core==null:return
	var point:=slot_point(int(data.slot))
	g.core.x=point.x;g.core.y=point.y

func update(delta:float) -> void:
	if g.core==null:return
	_place()
	if not g.phase in ["ready","flying"]:return
	data.clock=float(data.clock)+delta
	if float(data.clock)>=PERIOD:_blink()

func _blink() -> void:
	var from:=slot_point(int(data.slot))
	data.slot=int(data.next);data.next=_pick(int(data.slot));data.clock=0.0;data.blinks=int(data.blinks)+1
	_place()
	g.fx.burst(from,Color(TINT),10,0.8);g.fx.ring(slot_point(int(data.slot)),Color(TINT),80);g.cue("ricochet",1,g.core.x)
	g.revision+=1

func bonus_scale() -> float:return 1.6
func status() -> String:
	if g.core==null:return "核心未显现"
	return "%.1f 秒后闪移" % maxf(0,PERIOD-float(data.clock))
func summary() -> Array:return ["闪移 %d 次" % int(data.blinks)]

## Telegraph: a closing ring and a thin tether at the next slot.
func draw(canvas:CanvasItem) -> void:
	if g.core==null:return
	var left:float=PERIOD-float(data.clock)
	if left>WARN:return
	var t:float=1.0-left/WARN
	var target:=slot_point(int(data.next))
	var tint:=Color(TINT);tint.a=0.25+0.5*t
	canvas.draw_arc(target,lerpf(60,34,t),0,TAU,40,tint,2,true)
	tint.a*=0.4
	canvas.draw_line(g.core_display_position(),target,tint,1,true)
