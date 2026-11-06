extends "res://src/core/variants/rule.gd"
## 加注: once the core is up, every shot that starts with the core showing and
## kills at least QUOTA bricks (or every brick left) raises the core bonus by
## STEP up to ×CAP; a shot short of the quota busts the stake back to ×1.
## Hitting the core cashes out the current stake; that last shot neither
## raises nor busts it. Only this level's core bonus is ever at stake.
const Progress=preload("res://src/core/progress.gd")
const QUOTA:=3
const STEP:=0.5
const CAP:=4.0

func title() -> String:return "加注"
func color() -> String:return "#b5893a"
func note() -> String:return "核心现身后 · 三连加注 · 失手归一"

func shape() -> void:data={"stake":1.0,"best":1.0,"open":false,"armed":false,"kills":0,"busts":0}

func valid(saved:Dictionary) -> bool:
	for key in ["stake","best"]:
		if not Progress.finite_number(saved.get(key),1,CAP):return false
	for key in ["open","armed"]:
		if not saved.get(key) is bool:return false
	return Progress.finite_number(saved.get("kills"),0,10000,true) and Progress.finite_number(saved.get("busts"),0,10000,true)

## A main arrow fired with nothing else in the air begins a new shot.
func launched(arrow:RefCounted) -> void:
	if not arrow.flags.get("main",false) or g.arrows.size()!=1 or g.skills.pending():return
	_settle()
	data.open=true;data.kills=0;data.armed=g.core!=null

## "7" rather than "7.0"; at most two decimals.
static func times(value:float) -> String:return str(int(value)) if value==floor(value) else String.num(value,2)

func update(_delta:float) -> void:
	if g.phase=="ready" and data.open:_settle()

func destroyed(_brick:RefCounted) -> void:
	if data.open and data.armed and g.phase!="clearing":data.kills=int(data.kills)+1

## Bricks still needed this shot; a thin board lowers the bar.
func quota() -> int:return maxi(1,mini(QUOTA,g.bricks.size()+int(data.kills)))

func _settle() -> void:
	if not data.open:return
	data.open=false
	if not data.armed:return
	data.armed=false
	var point:=Vector2(390,140)
	if g.core!=null:point=Vector2(g.core.x,g.core.y+60)
	if int(data.kills)>=quota():
		_raise(point)
	elif float(data.stake)>1.0:
		data.stake=1.0;data.busts=int(data.busts)+1
		g.fx.floating(point,"失手 · 赌注归一",Color("#c0463a"),22);g.fx.ring(point,Color("#c0463a"),130)

func _raise(point:Vector2) -> void:
	if float(data.stake)>=CAP:return
	data.stake=minf(CAP,float(data.stake)+STEP);data.best=maxf(float(data.best),float(data.stake))
	g.fx.floating(point,"加注 ×%s" % times(float(data.stake)),Color("#e0ad2c"),22);g.fx.ring(point,Color(color()),120)

func core_hit(_arrow:RefCounted) -> bool:
	# Cashing out ends the shot; it never busts the stake already on the table.
	data.open=false;data.armed=false
	return true

func bonus_scale() -> float:return float(data.stake)

func status() -> String:
	if g.core==null:return "核心现身后开局"
	return "赌注 ×%s" % times(float(data.stake))

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
