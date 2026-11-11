extends "res://src/core/variants/rule.gd"
## 过热: the bow fires far faster, but every shot adds heat and hot arrows hit
## softer. At full heat the bow vents: a slow draw until it cools, and each vent
## costs part of the ×1.8 core bonus (never below ×1).
const Progress=preload("res://src/core/progress.gd")
const HEAT_PER_SHOT:=0.2
const COOL:=0.18         # heat shed per base draw interval, across upgrade tiers
const RESUME:=0.3        # a vented bow resumes once heat falls below this
const START_BONUS:=1.8
const VENT_COST:=0.3
var shown:=""

func title() -> String:return "过热"
func color() -> String:return "#d9663d"
func note() -> String:return "拉弓加速至正常的 0.4–0.8 倍间隔；热箭伤害最低 ×0.65。热满后暂时减速，每次过热扣 0.3 倍奖金（×1.8 → ×1）；停射可冷却。"

func shape() -> void:data={"heat":0.0,"vented":false,"bonus":START_BONUS,"vents":0}

func valid(saved:Dictionary) -> bool:
	return Progress.finite_number(saved.get("heat"),0,1) and saved.get("vented") is bool and Progress.finite_number(saved.get("bonus"),1,START_BONUS) and Progress.finite_number(saved.get("vents"),0,1e6,true)

func update(delta:float) -> void:
	if g.paused or not g.phase in ["ready","flying"]:return
	data.heat=maxf(0,float(data.heat)-COOL*delta/maxf(0.1,g.draw_interval()))
	if data.vented and float(data.heat)<RESUME:
		data.vented=false;g.events.append({"type":"toast","text":"弓身已冷却 · 恢复连射"})
	_sync()

## Cold bows draw at ×0.4, hot ones at ×0.8; a venting bow is slower than normal.
func interval_scale() -> float:
	return 1.6 if data.vented else lerpf(0.4,0.8,float(data.heat))

## Arrows keep the heat they were loosed with; full heat hits at ×0.65.
func launched(arrow:RefCounted) -> void:
	if not arrow.flags.has("heatScale"):
		var source:RefCounted=arrow.source
		arrow.flags.heatScale=float(source.flags.get("heatScale",1.0)) if source!=null else lerpf(1.0,0.65,float(data.heat))

func damage_scale(_brick:RefCounted,arrow:Variant) -> float:
	return float(arrow.flags.get("heatScale",1.0)) if arrow is RefCounted else 1.0

func on_shoot() -> void:
	if data.vented:return
	data.heat=minf(1,float(data.heat)+HEAT_PER_SHOT)
	if data.heat>=1:
		data.vented=true;data.vents=int(data.vents)+1
		data.bonus=maxf(1,float(data.bonus)-VENT_COST)
		g.events.append({"type":"toast","text":"弓身过热 · 奖金降至 ×%s" % String.num(float(data.bonus),1)})
		g.fx.ring(g.origin,Color(color()),160);g.fx.burst(g.origin,Color(color()),18,1.2);g.fx.shake=minf(8,g.fx.shake+3)
	_sync()

func bonus_scale() -> float:return snappedf(float(data.bonus),0.01)

func status() -> String:
	if data.vented:return "冷却中 · 奖金 ×%s" % String.num(bonus_scale(),1)
	return "热度 %d%% · 伤害 ×%s" % [roundi(float(data.heat)*100),String.num(lerpf(1,0.65,float(data.heat)),2)]

func summary() -> Array:return ["过热 %d 次" % int(data.vents)]

func draw(canvas:CanvasItem) -> void:
	# A heat gauge arc hugs the bow; it glows while venting.
	var heat:float=float(data.heat)
	if heat<=0.01:return
	var ink:=Color(color());ink.a=0.55 if data.vented else 0.18+0.3*heat
	canvas.draw_arc(g.origin,64,-PI*0.85,-PI*0.85+PI*0.7*heat,32,ink,3.0)

func _sync() -> void:
	var text:=status()
	if text!=shown:shown=text;g.revision+=1
