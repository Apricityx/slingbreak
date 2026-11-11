extends "res://src/core/variants/rule.gd"
## 压境: after the first shot the whole formation creeps toward the bow; every
## destroyed brick shoves it back up. The core bonus shrinks from ×2 to ×1 as
## the front line advances, and the front stops well above the bow.
const Progress=preload("res://src/core/progress.gd")
const ADVANCE:=4.0      # px per second while the level is live
const PUSH:=3.0         # px of recoil banked per destroyed brick
const RECOIL_SPEED:=90.0
const FLOOR:=870.0      # lowest allowed brick bottom edge (bow sits at y=970)
const MAX_ROOM:=96.0
var shown:=""

func title() -> String:return "压境"
func color() -> String:return "#c4664a"
func note() -> String:return "首箭后砖阵持续压近，击碎砖块可逼退；奖金随压近从 ×2 降至 ×1。底线会挡住砖阵，不会直接判负。"

func shape() -> void:
	var lowest:=0.0
	for item in g.bricks+g.obstacles:lowest=maxf(lowest,item.y+item.h/2)
	data={"started":false,"offset":0.0,"recoil":0.0,"room":clampf(FLOOR-lowest,0,MAX_ROOM),"front":0}

func valid(saved:Dictionary) -> bool:
	if not saved.get("started") is bool or not Progress.finite_number(saved.get("room"),0,MAX_ROOM):return false
	return Progress.finite_number(saved.get("offset"),0,float(saved.room)) and Progress.finite_number(saved.get("recoil"),0,1e6) and Progress.finite_number(saved.get("front"),0,1e6,true)

func update(delta:float) -> void:
	if not data.started or g.paused or not g.phase in ["ready","flying"]:return
	var offset:float=float(data.offset)
	var recoil:float=minf(float(data.recoil),offset)
	var back:float=minf(recoil,RECOIL_SPEED*delta)
	var target:float=clampf(offset+ADVANCE*delta-back,0,float(data.room))
	data.recoil=recoil-back
	if target!=offset:_shift(target-offset);data.offset=target
	if target>=float(data.room) and offset<float(data.room):
		data.front=int(data.front)+1
		g.events.append({"type":"toast","text":"砖阵已压至底线 · 奖金降至 ×1"})
		g.fx.ring(Vector2(390,FLOOR),Color(color()),300)
	_sync()

func _shift(dy:float) -> void:
	for item in g.bricks+g.obstacles:item.y+=dy

func on_shoot() -> void:data.started=true

func destroyed(_brick:RefCounted) -> void:
	if data.started:data.recoil=float(data.recoil)+PUSH

func bonus_scale() -> float:
	if float(data.room)<=0:return 2.0
	return snappedf(2.0-float(data.offset)/float(data.room),0.01)

func status() -> String:
	if not data.started:return "首箭后开始压近"
	if float(data.offset)>=float(data.room):return "已压至底线"
	return "奖金 ×%.1f" % bonus_scale()

func summary() -> Array:return ["压近 %d 像素" % roundi(float(data.offset))]

func draw(canvas:CanvasItem) -> void:
	# A faint floor line marks how far the formation may advance.
	if float(data.room)<=0:return
	var ink:=Color(color());ink.a=0.12+0.3*float(data.offset)/float(data.room)
	canvas.draw_line(Vector2(60,FLOOR),Vector2(720,FLOOR),ink,2.0)

func _sync() -> void:
	var text:=status()
	if text!=shown:shown=text;g.revision+=1
