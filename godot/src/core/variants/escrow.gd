extends "res://src/core/variants/rule.gd"
## 奖池: bricks pay half up front; twice that payment goes into a pot that the
## core cashes out with its bonus. A shot (main arrow plus volley) that ends
## without a kill loses LOSS of the pot. Only this level's unpaid pot is at
## risk, never banked coins. The pot is capped at CAP × the core bonus.
const Progress=preload("res://src/core/progress.gd")
const Tallies=preload("res://src/effects/income_tallies.gd")
const PAID:=0.5
const LOSS:=0.3
const CAP:=3.0
## Brick income already seen (stats.brick+stats.mult); both reset with the rule.
var seen:=0.0

func title() -> String:return "奖池"
func color() -> String:return "#c98a2e"
func note() -> String:return "砖块半价入池 · 空箭流失三成"

func shape() -> void:data={"pot":0.0,"lost":0.0,"open":false,"kills":0}

func valid(saved:Dictionary) -> bool:
	return Progress.finite_number(saved.get("pot"),0,1e18) and Progress.finite_number(saved.get("lost"),0,1e18) and saved.get("open") is bool and Progress.finite_number(saved.get("kills"),0,10000,true)

func cap() -> float:return maxf(1,g.bonus())*CAP

func reward_scale(_brick:RefCounted) -> float:return PAID

## A main arrow fired with nothing else in the air begins a new shot.
func launched(arrow:RefCounted) -> void:
	if not arrow.flags.get("main",false) or g.arrows.size()!=1 or g.skills.pending():return
	_settle();data.open=true;data.kills=0

func update(_delta:float) -> void:
	if g.phase=="ready" and data.open:_settle()

func _settle() -> void:
	if not data.open:return
	data.open=false
	if int(data.kills)>0 or float(data.pot)<=0:return
	var loss:float=round(float(data.pot)*LOSS)
	data.pot=float(data.pot)-loss;data.lost=float(data.lost)+loss
	g.fx.floating(Vector2(390,860),"空箭 · 奖池 -%s" % Tallies.format_amount(loss),Color("#c0463a"),22)
	g.fx.ring(Vector2(390,860),Color("#c0463a"),150);g.cue("ricochet")

func destroyed(_brick:RefCounted) -> void:
	if g.phase=="clearing":return
	if data.open:data.kills=int(data.kills)+1
	# _award has already booked this brick (and any achievement step) into stats.
	var paid:float=float(g.stats.brick)+float(g.stats.mult)
	data.pot=minf(cap(),float(data.pot)+maxf(0,paid-seen)*2.0)
	seen=paid

func core_hit(_arrow:RefCounted) -> bool:
	data.open=false
	if float(data.pot)>0:
		g.fx.floating(Vector2(g.core.x,g.core.y+70),"奖池兑现 +%s" % Tallies.format_amount(float(data.pot)),Color("#e0ad2c"),26)
	return true

func bonus_scale() -> float:
	var base:float=maxf(1,g.bonus())
	return (base+minf(cap(),float(data.pot)))/base

func status() -> String:
	return "奖池 %s" % Tallies.format_amount(float(data.pot))

func summary() -> Array:
	var items:Array=["奖池 %s" % Tallies.format_amount(float(data.pot))]
	if float(data.lost)>0:items.append("流失 %s" % Tallies.format_amount(float(data.lost)))
	return items
