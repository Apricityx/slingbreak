extends "res://src/core/variants/rule.gd"
## 坚壁核心: the core carries ARMOR plates; each hit strips one and bounces the
## arrow away, with a short guard so one arrow cannot ping-pong it at once.
## Core bonus ×1.8.
const Progress=preload("res://src/core/progress.gd")
const ARMOR:=3
const GUARD:=0.3
const TINT:="#c9873e"

func title() -> String:return "坚壁核心"
func color() -> String:return TINT
func note() -> String:return "核心需命中 %d 次 · 奖金 ×1.8" % ARMOR
func shape() -> void:data={"hp":ARMOR,"guard":0.0}

func valid(saved:Dictionary) -> bool:
	return Progress.finite_number(saved.get("hp"),1,ARMOR,true) and Progress.finite_number(saved.get("guard"),0,GUARD)

func update(delta:float) -> void:
	if float(data.guard)>0:data.guard=maxf(0,float(data.guard)-delta)

func core_hit(_arrow:RefCounted) -> bool:
	if float(data.guard)>0:return false
	if int(data.hp)<=1:data.hp=1;return true
	data.hp=int(data.hp)-1;data.guard=GUARD
	var point:=Vector2(g.core.x,g.core.y)
	g.fx.ring(point,Color(TINT),90);g.fx.burst(point,Color(TINT),18,1.2)
	g.fx.floating(point+Vector2(0,52),"护甲 %d" % int(data.hp),Color(TINT),16)
	g.fx.shake=minf(8,g.fx.shake+3);g.cue("clang",1,point.x,true);g.revision+=1
	return false

func bonus_scale() -> float:return 1.8
func status() -> String:return "护甲 %d" % int(data.hp)
func core_note() -> String:return "还需命中 %d 次" % int(data.hp)
func core_blocked() -> bool:return int(data.hp)>1
func core_progress() -> float:return 1.0-float(int(data.hp)-1)/float(ARMOR-1)
func summary() -> Array:return ["%d 层护甲击穿" % ARMOR]

## Remaining plates as arcs around the core; the guard window dims them.
func draw(canvas:CanvasItem) -> void:
	if g.core==null:return
	var point:Vector2=g.core_display_position()
	var tint:=Color(TINT);tint.a=0.35 if float(data.guard)>0 else 0.8
	var span:=TAU/ARMOR
	for index in range(int(data.hp)):
		var start:float=-PI/2+index*span+0.16
		canvas.draw_arc(point,47,start,start+span-0.32,16,tint,3,true)
