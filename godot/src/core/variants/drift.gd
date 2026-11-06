extends "res://src/core/variants/rule.gd"
## 游移核心: once the core appears it sweeps left and right; core bonus ×2.
const Progress=preload("res://src/core/progress.gd")

func title() -> String:return "游移核心"
func color() -> String:return "#a4d65e"
func note() -> String:return "核心会左右游移 · 奖金 ×2"
func shape() -> void:data={"phase":0.0}
func valid(saved:Dictionary) -> bool:return Progress.finite_number(saved.get("phase"),0,1e9)

func update(delta:float) -> void:
	if g.core==null:return
	data.phase=float(data.phase)+delta
	g.core.x=390+250*sin(float(data.phase)*1.1)

func bonus_scale() -> float:return 2.0
func status() -> String:return "奖金 ×2"
