extends "res://src/core/variants/rule.gd"
## 沙漏: each accepted shot grants its draw cooldown plus an aiming grace.
## Once another shot is available, old arrows cannot pause the decision clock.
const Progress=preload("res://src/core/progress.gd")
const START:=2.5
const FLOOR:=1.0
const DRAIN:=0.1        # bonus lost per idle second (15 s of hesitation total)
const GRACE:=0.8
var shown:=""

func title() -> String:return "沙漏"
func color() -> String:return "#c9a46a"
func note() -> String:return "首箭后，拉弓冷却结束再给 0.8 秒瞄准；继续等待每秒减少 0.1 倍奖金（×2.5 → ×1）。场上仍有箭也会计时，暂停不扣。"

func shape() -> void:data={"started":false,"bonus":START,"idle":0.0}

func valid(saved:Dictionary) -> bool:
	return saved.get("started") is bool and Progress.finite_number(saved.get("bonus"),FLOOR,START) and Progress.finite_number(saved.get("idle"),0,1e9)

## Sand only falls while the player could shoot right now and isn't.
func draining() -> bool:
	return data.started and not g.paused and g.phase in ["ready","flying"] and g.time>=g.next_shot_at+GRACE and float(data.bonus)>FLOOR

func update(delta:float) -> void:
	if draining():
		var before:float=float(data.bonus)
		data.bonus=maxf(FLOOR,before-DRAIN*delta);data.idle=float(data.idle)+delta
		if data.bonus<=FLOOR:g.events.append({"type":"toast","text":"沙漏流尽 · 奖金已降至 ×1"})
		elif floorf(before*2)!=floorf(float(data.bonus)*2):g.fx.floating(g.origin-Vector2(0,90),"奖金 ×%.1f" % float(data.bonus),Color(color()),16)
	_sync()

func on_shoot() -> void:data.started=true

func bonus_scale() -> float:return snappedf(float(data.bonus),0.01)

func status() -> String:
	if not data.started:return "首箭后开始计时"
	if float(data.bonus)<=FLOOR:return "沙漏已尽"
	return "奖金 ×%.1f%s" % [float(data.bonus)," 流失中" if draining() else ""]

func summary() -> Array:return ["犹豫 %.1f 秒" % float(data.idle)]

func draw(canvas:CanvasItem) -> void:
	# A thin arc above the bow shows the remaining sand.
	if not data.started:return
	var share:float=(float(data.bonus)-FLOOR)/(START-FLOOR)
	if share<=0:return
	var ink:=Color(color());ink.a=0.45 if draining() else 0.22
	canvas.draw_arc(g.origin,70,-PI/2-PI*0.4*share,-PI/2+PI*0.4*share,32,ink,3.0)

func _sync() -> void:
	var text:=status()
	if text!=shown:shown=text;g.revision+=1
