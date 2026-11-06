extends "res://src/core/variants/rule.gd"
## 折射核心: the core only accepts an arrow that has already bounced off a wall,
## the ceiling or an obstacle; direct hits glance off. Core bonus ×1.5.
const Progress=preload("res://src/core/progress.gd")
const TINT:="#5fb3c8"

func title() -> String:return "折射核心"
func color() -> String:return TINT
func note() -> String:return "箭矢须先反弹才能击破核心 · 奖金 ×1.5"
func shape() -> void:data={"denied":0}
func valid(saved:Dictionary) -> bool:return Progress.finite_number(saved.get("denied"),0,100000,true)

func core_hit(arrow:RefCounted) -> bool:
	if arrow.flags.get("bankedReady",false):return true
	data.denied=int(data.denied)+1
	# The host reflects a denied arrow off the core and reports it as a bounce;
	# that rebound must not arm the arrow, so mark it for bounced() to skip.
	arrow.flags.bankedDeny=g.time
	var point:=Vector2(g.core.x,g.core.y)
	g.fx.ring(point,Color(TINT),58);g.fx.burst(arrow.position,Color(TINT),8,0.6);g.cue("clang",1,point.x)
	if not arrow.flags.get("bankedHinted",false):
		arrow.flags.bankedHinted=true;g.fx.floating(point+Vector2(0,48),"需先反弹",Color(TINT),15)
	return false

func bounced(arrow:RefCounted) -> void:
	if arrow.flags.has("bankedDeny"):
		var denied_at:float=float(arrow.flags.bankedDeny)
		arrow.flags.erase("bankedDeny")
		if is_equal_approx(denied_at,g.time) and g.core!=null and Rect2(g.core.x-45,g.core.y-45,90,90).has_point(arrow.position):return
	if arrow.flags.get("bankedReady",false):return
	arrow.flags.bankedReady=true
	if arrow.color.a<=0:arrow.color=Color(TINT)

func bonus_scale() -> float:return 1.5
func status() -> String:return "需先反弹"
func summary() -> Array:return ["挡回直击 %d 次" % int(data.denied)] if int(data.denied)>0 else ["一击折射"]

func draw(canvas:CanvasItem) -> void:
	if g.core==null:return
	var point:Vector2=g.core_display_position()
	var tint:=Color(TINT);tint.a=0.45
	canvas.draw_arc(point,46,0,TAU,48,tint,1.5,true)
