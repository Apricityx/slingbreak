extends "res://src/core/variants/rule.gd"
## 伪装砖: a share of ordinary-looking bricks hide a true identity, revealed by
## the first hit before its damage lands: a special brick (it then breaks and
## fires as that type) or armour that triples its health. Neutral payout.
const Progress=preload("res://src/core/progress.gd")
const SHARE:=0.4
## Weighted outcomes; "armor" stays a normal brick with ×ARMOR health.
const OUTCOMES:=["bomb","bomb","lightning","lightning","frost","prism","gold","armor","armor","armor"]
const ARMOR:=3.0
const NAMES:={"bomb":"炸弹","lightning":"闪电","frost":"冰霜","prism":"棱镜","gold":"金矿","armor":"铁甲"}

func title() -> String:return "伪装砖"
func color() -> String:return "#7d8fa8"
func note() -> String:return "部分普通砖暗藏特殊砖或铁甲"

func shape() -> void:
	var normal:Array=g.shuffle(g.bricks.filter(func(b):return b.type=="normal"))
	var hidden:Array=normal.slice(0,ceili(normal.size()*SHARE))
	for brick in hidden:brick.flags.mimic=true
	data={"revealed":0,"armored":0}

func valid(saved:Dictionary) -> bool:
	for key in ["revealed","armored"]:
		if not Progress.finite_number(saved.get(key),0,240,true):return false
	return true

func unrevealed() -> int:return g.bricks.filter(func(b):return b.flags.get("mimic",false)).size()

## The first hit on a mimic flips it before the damage is applied, so a lethal
## reveal still detonates as the new type in the same hit.
func damage_scale(brick:RefCounted,_arrow:Variant) -> float:
	if brick.flags.get("mimic",false):_reveal(brick)
	return 1.0

func _reveal(brick:RefCounted) -> void:
	brick.flags.erase("mimic")
	var outcome:String=OUTCOMES[g.rng.randi_range(0,OUTCOMES.size()-1)]
	if outcome=="armor":
		brick.max_hp=ceil(brick.max_hp*ARMOR);brick.hp=ceil(brick.hp*ARMOR);data.armored=int(data.armored)+1
	else:
		brick.type=outcome;data.revealed=int(data.revealed)+1
	var ink:Color=Color(color()) if outcome=="armor" else g.fx.brick_color(outcome)
	brick.flash=0.22;g.fx.ring(brick.position,ink,54);g.fx.floating(brick.position+Vector2(0,-26),NAMES[outcome],ink,15)
	g.revision+=1

func status() -> String:return "未揭晓 %d" % unrevealed()
func summary() -> Array:return ["揭晓特殊砖 %d" % int(data.get("revealed",0)),"铁甲 %d" % int(data.get("armored",0))]
