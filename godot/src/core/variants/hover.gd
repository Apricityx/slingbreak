extends "res://src/core/variants/rule.gd"
## 低重力: gravity ×0.55 keeps arrows aloft longer, and an arrow's hit grows
## with its flight time: ×0.6 at release, +0.8 per second, ×2.2 from 2 s on.
## Lobs and long ricochets pay; point-blank snipes are weak. Core bonus ×1.3.
const Progress=preload("res://src/core/progress.gd")
const GRAVITY:=0.55
const FRESH:=0.6
const GROWTH:=0.8
const PEAK:=2.2

func title() -> String:return "低重力"
func color() -> String:return "#8f8fd6"
func note() -> String:return "重力减弱 · 滞空越久伤害越高"
func shape() -> void:data={"best":0.0}
func valid(saved:Dictionary) -> bool:return Progress.finite_number(saved.get("best"),0,PEAK)

static func scale_for(life:float) -> float:return clampf(FRESH+GROWTH*maxf(0.0,life),FRESH,PEAK)
## Seconds of flight needed to reach the peak multiplier.
static func full_time() -> float:return (PEAK-FRESH)/GROWTH

func gravity_scale() -> float:return GRAVITY
## Passive/area damage (no arrow) stays neutral.
func damage_scale(_brick:RefCounted,arrow:Variant) -> float:
	return 1.0 if arrow==null else scale_for(float(arrow.life))

func update(_delta:float) -> void:
	if g.phase!="flying":return
	for arrow in g.arrows:
		var now:=scale_for(float(arrow.life))
		data.best=maxf(float(data.best),now)
		# Mark the moment an arrow reaches full charge, once per arrow.
		if now>=PEAK and not arrow.flags.get("hoverFull",false):
			arrow.flags.hoverFull=true
			if arrow.flags.get("main",false):
				g.fx.ring(arrow.position,Color(color()),36)
				g.fx.floating(arrow.position+Vector2(0,-20),"×%s" % String.num(PEAK,1),Color(color()),17)

func bonus_scale() -> float:return 1.3

func status() -> String:
	var best:=0.0
	for arrow in g.arrows:best=maxf(best,scale_for(float(arrow.life)))
	return "滞空 ×%s" % String.num(best,1) if best>0.0 else "重力 ×0.55"

func summary() -> Array:return ["滞空最高 ×%s" % String.num(float(data.best),1)] if float(data.best)>0.0 else []
