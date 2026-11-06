extends "res://src/core/variants/rule.gd"
## 重箭: arrows are heavier. Gravity ×1.35 drops the arc, every arrow hits ×1.6
## harder, and each wall/obstacle rebound chips one point of pierce, so a heavy
## arrow survives only a few ricochets. Core bonus ×1.3.
## The preview shares gravity_scale(), so the dropped arc is shown while aiming.
const Progress=preload("res://src/core/progress.gd")
const GRAVITY:=1.35
const DAMAGE:=1.6
## Extra pierce at launch so heavy arrows are not weaker than plain ones on a
## straight shot; it is what the rebounds wear away.
const PADDING:=1

func title() -> String:return "重箭"
func color() -> String:return "#a7815b"
func note() -> String:return "箭矢更重 · 下坠更快 · 伤害 ×1.6 · 反弹消耗穿透"
func shape() -> void:data={"shattered":0}
func valid(saved:Dictionary) -> bool:return Progress.finite_number(saved.get("shattered"),0,1e9,true)

func gravity_scale() -> float:return GRAVITY
func damage_scale(_brick:RefCounted,_arrow:Variant) -> float:return DAMAGE
func bonus_scale() -> float:return 1.3

func launched(arrow:RefCounted) -> void:
	arrow.pierce+=PADDING;arrow.flags.ballast=true

func bounced(arrow:RefCounted) -> void:
	if not arrow.flags.get("ballast",false) or arrow.pierce<=0:return
	arrow.pierce-=1
	if arrow.pierce<=0:
		# advance_arrow() removes it at the end of this step; mark the shatter.
		data.shattered=int(data.shattered)+1
		g.fx.burst(arrow.position,Color(color()),10,0.8)
		g.fx.shake=minf(8,g.fx.shake+1.0)

func status() -> String:return "伤害 ×1.6"
func summary() -> Array:
	return ["伤害 ×1.6","碎箭 %d" % int(data.shattered)] if int(data.shattered)>0 else ["伤害 ×1.6"]
