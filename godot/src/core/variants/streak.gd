extends "res://src/core/variants/rule.gd"
## 连杀赏: an arrow's first GATE-1 kills (and all passive damage) pay ×LOW;
## from its GATE-th kill on, every brick pays ×HIGH on top of the usual combo.
## Long single-arrow runs pay far more, scattered single kills pay less.
const Progress=preload("res://src/core/progress.gd")
const GATE:=3
const LOW:=0.5
const HIGH:=2.0

func title() -> String:return "连杀赏"
func color() -> String:return "#c4513f"
func note() -> String:return "单箭三连起 · 砖块 ×2"

func shape() -> void:data={"boosted":0,"best":0}

func valid(saved:Dictionary) -> bool:
	return Progress.finite_number(saved.get("boosted"),0,10000,true) and Progress.finite_number(saved.get("best"),0,10000,true)

## The scoring arrow's kill count, already including the brick being paid.
func kills() -> int:
	var arrow:Variant=g.active_arrow
	return int(arrow.kills) if arrow!=null else 0

func reward_scale(_brick:RefCounted) -> float:return HIGH if kills()>=GATE else LOW

func destroyed(brick:RefCounted) -> void:
	var count:=kills()
	data.best=maxi(int(data.best),count)
	if count<GATE:return
	data.boosted=int(data.boosted)+1
	if count==GATE:
		g.fx.floating(brick.position-Vector2(0,40),"连杀赏 ×2",Color(color()),22)
		g.fx.ring(brick.position,Color(color()),110)

func status() -> String:return "已赏 %d 块" % int(data.boosted)

func summary() -> Array:return ["连杀砖 %d 块" % int(data.boosted),"最长 %d 连" % int(data.best)]
