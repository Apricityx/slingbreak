extends "res://src/core/variants/shot_rule.gd"
## 加注: once the core is up, every shot that starts with the core showing and
## kills at least QUOTA bricks (or every brick left) immediately raises the
## core bonus by STEP up to ×CAP. Shots settle independently with descendants;
## ending short busts to ×1. A core hit cashes out without an unfinished-shot fine.
const Progress=preload("res://src/core/progress.gd")
const QUOTA:=3
const STEP:=0.5
const CAP:=4.0

func title() -> String:return "加注"
func color() -> String:return "#b5893a"
func note() -> String:return "核心现身后，每次发射击碎 3 砖立即加注 +0.5（最多 ×4，含衍生箭）；不足 3 砖则需清空余砖。该箭结束未达标，赌注归 ×1；命中核心直接兑现。"

func shape() -> void:data={"stake":1.0,"best":1.0,"open":false,"armed":false,"kills":0,"busts":0}

func valid(saved:Dictionary) -> bool:
	for key in ["stake","best"]:
		if not Progress.finite_number(saved.get(key),1,CAP):return false
	for key in ["open","armed"]:
		if not saved.get(key) is bool:return false
	return Progress.finite_number(saved.get("kills"),0,10000,true) and Progress.finite_number(saved.get("busts"),0,10000,true)

func opened(shot:Dictionary) -> void:
	shot.armed=g.core!=null;shot.quota=mini(QUOTA,g.bricks.size())
	# No bricks means cash-out only, never a zero-target free raise.
	if int(shot.quota)==0:shot.armed=false

## "7" rather than "7.0"; at most two decimals.
static func times(value:float) -> String:return str(int(value)) if value==floor(value) else String.num(value,2)

func destroyed(_brick:RefCounted) -> void:
	if g.phase!="clearing":record_kill()

## Bricks still needed this shot; a thin board lowers the bar.
func quota() -> int:return maxi(1,mini(QUOTA,g.bricks.size()))

func scored(shot:Dictionary) -> void:
	if shot.done or not shot.armed:return
	# Other volleys may clear the remaining board. Credit only this shot's
	# actual kills, and allow its final brick to complete a now-thin board.
	if int(shot.kills)>=int(shot.quota) or g.bricks.is_empty():
		shot.done=true;_raise(Vector2(g.core.x,g.core.y+60) if g.core!=null else Vector2(390,140))

func finished(shot:Dictionary) -> void:
	if not shot.armed:return
	var point:=Vector2(390,140)
	if g.core!=null:point=Vector2(g.core.x,g.core.y+60)
	if float(data.stake)>1.0:
		data.stake=1.0;data.busts=int(data.busts)+1
		g.fx.floating(point,"失手 · 赌注归一",Color("#c0463a"),22);g.fx.ring(point,Color("#c0463a"),130)

func _raise(point:Vector2) -> void:
	if float(data.stake)>=CAP:return
	data.stake=minf(CAP,float(data.stake)+STEP);data.best=maxf(float(data.best),float(data.stake))
	g.fx.floating(point,"加注 ×%s" % times(float(data.stake)),Color("#e0ad2c"),22);g.fx.ring(point,Color(color()),120)

func core_hit(_arrow:RefCounted) -> bool:
	# Cashing out ends the shot; it never busts the stake already on the table.
	rounds.clear();data.open=false;data.armed=false
	return true

func bonus_scale() -> float:return float(data.stake)

func status() -> String:
	if g.core==null:return "核心现身后开局"
	var shot:=latest()
	return "赌注 ×%s%s" % [times(float(data.stake))," · 本箭 %d/%d" % [int(shot.kills),int(shot.quota)] if not shot.is_empty() and shot.armed else " · 命中核心兑现"]

func summary() -> Array:
	var items:Array=["最高 ×%s" % times(float(data.best))]
	if int(data.busts)>0:items.append("失手 %d 次" % int(data.busts))
	return items

func draw(canvas:CanvasItem) -> void:
	if g.core==null or float(data.stake)<=1.0:return
	var point:Vector2=g.core_display_position()
	var ink:=Color(color());ink.a=0.5
	var share:float=(float(data.stake)-1.0)/(CAP-1.0)
	canvas.draw_arc(point,48,-PI/2,-PI/2+TAU*share,40,ink,3.0,true)
