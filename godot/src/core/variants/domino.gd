extends "res://src/core/variants/rule.gd"
## 多米诺: bricks are sturdier (×HP), but every broken brick topples its row
## neighbours a beat later for PUSH × arrow damage, so cracks ripple sideways.
const Progress=preload("res://src/core/progress.gd")
const HP:=1.5
const PUSH:=0.75
const DELAY:=0.12
## Row neighbours only: one column apart (96) on the same row.
const REACH:=110.0
## Transient ripple queue [{at, x, y}]; lost on save, which only drops a
## pending push. Never holds brick references.
var pending:Array=[]

func title() -> String:return "多米诺"
func color() -> String:return "#c9764a"
func note() -> String:return "砖块更硬 · 碎砖推倒左右邻砖 · 奖金 ×1.3"

func shape() -> void:
	data={"toppled":0}
	for brick in g.bricks:brick.hp=ceil(brick.hp*HP);brick.max_hp=brick.hp

func valid(saved:Dictionary) -> bool:return Progress.finite_number(saved.get("toppled"),0,100000,true)

func destroyed(brick:RefCounted) -> void:
	if pending.size()<64:pending.append({"at":g.time+DELAY,"x":brick.x,"y":brick.y})

func neighbours(x:float,y:float) -> Array:
	return g.bricks.filter(func(b):return absf(b.y-y)<12 and absf(b.x-x)>1 and absf(b.x-x)<=REACH)

func update(_delta:float) -> void:
	if pending.is_empty() or g.phase=="clearing":return
	var due:Array=pending.filter(func(p):return g.time>=float(p.at))
	if due.is_empty():return
	pending=pending.filter(func(p):return g.time<float(p.at))
	for item in due:
		var origin:=Vector2(float(item.x),float(item.y))
		for target in neighbours(origin.x,origin.y):
			if g.phase=="clearing":return
			g.fx.burst(target.position.move_toward(origin,target.w*0.5),Color(color()),5,0.6)
			g.hit(target,g.damage()*PUSH,1)
			if not target in g.bricks:data.toppled=int(data.toppled)+1

func bonus_scale() -> float:return 1.3
func status() -> String:return "已推倒 %d" % int(data.get("toppled",0))
func summary() -> Array:return ["推倒 %d 块" % int(data.get("toppled",0))]
