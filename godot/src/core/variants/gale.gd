extends "res://src/core/variants/rule.gd"
## 侧风: a crosswind slowly swings left and right; the aiming preview bends with
## it, so the player leans into the wind. Core bonus ×1.5.
## The wind is a pure function of the saved phase, so a restored level resumes
## the same gust; the phase only advances while the level is live.
const Progress=preload("res://src/core/progress.gd")
## Peak wind, velocity per 60 Hz tick: a full-power straight shot drifts about
## 60-70 px by the time it reaches the core row; a forge bellows push is ~0.056.
const PEAK:=0.07
## Radians of phase per second: one full left-right swing every ~21 s, so one
## arrow's flight (< 2 s) sees an almost steady wind.
const RATE:=0.3
## Starting phase keeps the first gust well away from calm.
const START:=PI*0.5

func title() -> String:return "侧风"
func color() -> String:return "#6fa8c7"
func note() -> String:return "横风左右摇摆 · 瞄准时顺风修正"
func shape() -> void:data={"phase":START+PI*float(g.rng.randi_range(0,1))}
func valid(saved:Dictionary) -> bool:return Progress.finite_number(saved.get("phase"),0,1e9)

func update(delta:float) -> void:
	if not g.phase in ["ready","flying"]:return
	var before:float=wind()
	data.phase=float(data.phase)+delta*RATE
	# Signal each change of direction once, at the top of the board.
	if signf(before)!=signf(wind()) and absf(before)>0.0:
		g.fx.ring(Vector2(390,150),Color(color()),120)
		g.fx.floating(Vector2(390,150),"风向 "+arrow_text(),Color(color()),18)

func wind() -> float:return PEAK*sin(float(data.get("phase",START)))
func bonus_scale() -> float:return 1.5

func arrow_text() -> String:
	var value:float=wind()
	if absf(value)<PEAK*0.15:return "≈"
	var mark:String="→" if value>0 else "←"
	return mark if absf(value)<PEAK*0.65 else mark+mark

func status() -> String:return "风向 "+arrow_text()
func summary() -> Array:return ["横风摇摆"]

## Subtle wind sock: a short arrow near the top-left whose length tracks the wind.
func draw(canvas:CanvasItem) -> void:
	var value:float=wind()/PEAK
	var center:=Vector2(90,46)
	var ink:=Color(color());ink.a=0.55
	canvas.draw_circle(center,3.0,ink)
	if absf(value)<0.05:return
	var tip:=center+Vector2(46*value,0)
	canvas.draw_line(center,tip,ink,3.0,true)
	var back:=Vector2(-signf(value)*9,0)
	canvas.draw_line(tip,tip+back+Vector2(0,-6),ink,3.0,true)
	canvas.draw_line(tip,tip+back+Vector2(0,6),ink,3.0,true)
