extends "res://src/core/variants/rule.gd"
## 弹射蓄能: arrows charge up on every rebound. A fresh arrow hits at ×0.6;
## each wall/obstacle rebound adds +0.6 (up to 4 charges, ×3.0), so bank shots
## are the way through. Core bonus ×1.4.
const Progress=preload("res://src/core/progress.gd")
const FRESH:=0.6
const STEP:=0.6
const CHARGES:=4

func title() -> String:return "弹射蓄能"
func color() -> String:return "#d9a640"
func note() -> String:return "直射伤害 ×0.6，每次撞墙或障碍反弹 +0.6 倍，最多 ×3。范围与被动伤害不变 · 奖金 ×1.4"
func shape() -> void:data={"charged":0,"best":0}
func valid(saved:Dictionary) -> bool:
	return Progress.finite_number(saved.get("charged"),0,1e9,true) and Progress.finite_number(saved.get("best"),0,CHARGES,true)

## Charge carried by one arrow (skill fragments start at zero like any arrow).
static func charge(arrow:Variant) -> int:
	if arrow==null:return 0
	return clampi(int(arrow.flags.get("carom",0)),0,CHARGES)

static func scale_for(charges:int) -> float:return FRESH+STEP*clampi(charges,0,CHARGES)

## Passive/area damage (no arrow) stays neutral so area skills are not nerfed.
func damage_scale(_brick:RefCounted,arrow:Variant) -> float:
	return 1.0 if arrow==null else scale_for(charge(arrow))

func bounced(arrow:RefCounted) -> void:
	var now:=charge(arrow)
	if now>=CHARGES:return
	now+=1;arrow.flags.carom=now
	data.charged=int(data.charged)+1;data.best=maxi(int(data.best),now)
	var ink:=Color(color())
	g.fx.ring(arrow.position,ink,22+8*now)
	g.fx.floating(arrow.position+Vector2(0,-18),"×%s" % String.num(scale_for(now),1),ink,15+now)

func bonus_scale() -> float:return 1.4
func status() -> String:return "反弹 +0.6"
func summary() -> Array:return ["蓄能 %d 次" % int(data.charged),"最高 ×%s" % String.num(scale_for(int(data.best)),1)]
