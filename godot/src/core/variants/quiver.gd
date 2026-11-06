extends "res://src/core/variants/rule.gd"
## 限箭挑战: clear within par shots (80% of the recorded pace) for a bigger
## core bonus; every spare arrow adds ×0.25, overshooting drops it to ×0.6.
const Progress=preload("res://src/core/progress.gd")

func title() -> String:return "限箭挑战"
func color() -> String:return "#8d78b9"
func note() -> String:return "%d 箭内击破核心 · 奖金翻倍" % int(data.get("par",8))

func shape() -> void:
	var pace:float=float(g.state.get("paceShots",0))
	data={"par":8 if pace<=0 else clampi(ceili(pace*0.8),3,30)}

func valid(saved:Dictionary) -> bool:return Progress.finite_number(saved.get("par"),3,30,true)

func used() -> int:
	return int(g.state.skillRuntime.get("shots",0)) if g.state.skillRuntime is Dictionary else 0

func bonus_scale() -> float:
	var spare:int=int(data.par)-used()
	return 2.0+0.25*spare if spare>=0 else 0.6

func status() -> String:
	var spare:int=int(data.par)-used()
	return "剩余 %d 箭" % spare if spare>=0 else "超出 %d 箭" % -spare

func summary() -> Array:return ["%d / %d 箭" % [used(),int(data.par)]]
