extends "res://src/core/variants/rule.gd"
## 熔合: most touching pairs of ordinary bricks in a row weld into one double-width
## brick with their combined health. Fewer, bigger targets: one fused break
## pays ×REWARD and counts as a single brick towards the core.
const Progress=preload("res://src/core/progress.gd")
const CHANCE:=0.7
const REWARD:=2.5
## Neighbouring cell centres are 96 apart; the fused brick spans both cells.
const PITCH:=96.0

func title() -> String:return "熔合"
func color() -> String:return "#d0784f"
func note() -> String:return "相邻砖块熔成双宽巨砖 · 巨砖赏金 ×%s" % String.num(REWARD,1)

func shape() -> void:
	var rows:Dictionary={}
	for brick in g.bricks:
		if brick.type!="normal":continue
		var key:=roundi(brick.y)
		if not rows.has(key):rows[key]=[]
		rows[key].append(brick)
	var keys:Array=rows.keys();keys.sort()
	var fused:=0
	for key in keys:
		var row:Array=rows[key]
		row.sort_custom(func(a,b):return a.x<b.x)
		var index:=0
		while index<row.size()-1:
			var left:RefCounted=row[index]
			var right:RefCounted=row[index+1]
			if absf(right.x-left.x-PITCH)<1 and g.rng.randf()<CHANCE:
				var hp:float=left.hp+right.hp
				g.bricks.erase(left);g.bricks.erase(right)
				g.make_brick({"x":(left.x+right.x)*0.5,"y":left.y,"w":PITCH+left.w,"h":left.h,"hp":hp,"max":left.max_hp+right.max_hp,"nativeFlags":{"fused":true}})
				fused+=1;index+=2
			else:index+=1
	g.initial=g.bricks.size()
	data={"fused":fused,"broken":0}

func valid(saved:Dictionary) -> bool:
	return Progress.finite_number(saved.get("fused"),0,120,true) and Progress.finite_number(saved.get("broken"),0,120,true)

func reward_scale(brick:RefCounted) -> float:return REWARD if brick.flags.get("fused",false) else 1.0
func destroyed(brick:RefCounted) -> void:
	if brick.flags.get("fused",false):data.broken=int(data.broken)+1

func status() -> String:return "巨砖 %d / %d" % [int(data.get("broken",0)),int(data.get("fused",0))]
func summary() -> Array:return ["击碎巨砖 %d / %d" % [int(data.get("broken",0)),int(data.get("fused",0))]]
