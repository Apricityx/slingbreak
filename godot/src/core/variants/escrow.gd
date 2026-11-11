extends "res://src/core/variants/shot_rule.gd"
## 奖池: bricks pay half up front; twice that payment goes into a pot that the
## core cashes out with its bonus. Each shot (main arrow plus descendants) that
## ends without a kill loses LOSS of its launch-time pot. Only the unpaid pot is at
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
func note() -> String:return "碎砖先领半价，另存原价入池（上限为核心奖金 ×3）；击破核心兑现。每次发射独立计数，未碎砖扣发射时奖池的 30%。"

func shape() -> void:data={"pot":0.0,"lost":0.0,"open":false,"kills":0}

func valid(saved:Dictionary) -> bool:
	return Progress.finite_number(saved.get("pot"),0,1e18) and Progress.finite_number(saved.get("lost"),0,1e18) and saved.get("open") is bool and Progress.finite_number(saved.get("kills"),0,10000,true)

func cap() -> float:return maxf(1,g.bonus())*CAP

func reward_scale(_brick:RefCounted) -> float:return PAID

func opened(shot:Dictionary) -> void:shot.risk=float(data.pot)

func finished(shot:Dictionary) -> void:
	if int(shot.kills)>0 or float(data.pot)<=0:return
	var loss:float=minf(float(data.pot),round(float(shot.risk)*LOSS))
	if loss<=0:return
	data.pot=float(data.pot)-loss;data.lost=float(data.lost)+loss
	g.fx.floating(Vector2(390,860),"空箭 · 奖池 -%s" % Tallies.format_amount(loss),Color("#c0463a"),22)
	g.fx.ring(Vector2(390,860),Color("#c0463a"),150);g.cue("ricochet")

func destroyed(_brick:RefCounted) -> void:
	if g.phase=="clearing":return
	record_kill()
	# _award has already booked this brick (and any achievement step) into stats.
	var paid:float=float(g.stats.brick)+float(g.stats.mult)
	data.pot=minf(cap(),float(data.pot)+maxf(0,paid-seen)*2.0)
	seen=paid

func core_hit(_arrow:RefCounted) -> bool:
	rounds.clear();data.open=false
	if float(data.pot)>0:
		g.fx.floating(Vector2(g.core.x,g.core.y+70),"奖池兑现 +%s" % Tallies.format_amount(float(data.pot)),Color("#e0ad2c"),26)
	return true

func bonus_scale() -> float:
	var base:float=maxf(1,g.bonus())
	return (base+minf(cap(),float(data.pot)))/base

func status() -> String:
	var shot:=latest()
	return "奖池 %s%s" % [Tallies.format_amount(float(data.pot))," · 本箭 %d 碎" % int(shot.kills) if not shot.is_empty() else " · 命中核心兑现"]

func summary() -> Array:
	var items:Array=["奖池 %s" % Tallies.format_amount(float(data.pot))]
	if float(data.lost)>0:items.append("流失 %s" % Tallies.format_amount(float(data.lost)))
	return items
