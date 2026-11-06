extends "res://src/core/variants/rule.gd"
## 塌方: bricks have weight. The board starts settled, and whenever a brick
## breaks the stack above it slides down its column until it lands on a brick,
## a wall or the floor, so dug tunnels keep refilling; core bonus ×1.5.
const Progress=preload("res://src/core/progress.gd")
const ROW:=60.0
## Fall speed in board units per second (one row in about 0.14 s).
const SPEED:=420.0
## Transient: true while something may still be falling. Not saved; a restored
## board simply re-checks once.
var settling:=true

func title() -> String:return "塌方"
func color() -> String:return "#b08a5c"
func note() -> String:return "破砖后上方砖块下坠 · 奖金 ×1.5"

func shape() -> void:
	var floor_y:=0.0
	for item in g.bricks+g.obstacles:floor_y=maxf(floor_y,item.y)
	data={"floor":floor_y,"fallen":0}
	# Start compact: every brick sits on its support before the first shot.
	var targets:=_targets()
	for brick in targets:brick.y=targets[brick]
	settling=false

func valid(saved:Dictionary) -> bool:
	return Progress.finite_number(saved.get("floor"),150,900) and Progress.finite_number(saved.get("fallen"),0,100000,true)

static func column(x:float) -> int:return roundi((x-102)/96.0)

## Resting y for every brick: each column stacks bottom-up on the floor or on
## the nearest wall below. Bricks never move up.
func _targets() -> Dictionary:
	var columns:Dictionary={}
	for item in g.bricks+g.obstacles:
		var key:=column(item.x)
		if not columns.has(key):columns[key]=[]
		columns[key].append(item)
	var result:Dictionary={}
	for key in columns:
		var stack:Array=columns[key]
		stack.sort_custom(func(a,b):return a.y>b.y)
		var support:float=float(data.floor)+ROW
		for item in stack:
			if item.type=="obstacle":support=item.y;continue
			var target:float=maxf(item.y,support-ROW)
			result[item]=target;support=target
	return result

func destroyed(_brick:RefCounted) -> void:settling=true

func update(delta:float) -> void:
	if not settling:return
	var targets:=_targets()
	var moving:=false
	var step:=SPEED*delta
	for brick in targets:
		var target:float=targets[brick]
		if brick.y>=target:continue
		brick.y=minf(target,brick.y+step);moving=true
		if brick.y>=target:
			data.fallen=int(data.fallen)+1;brick.flash=0.14
			g.fx.burst(brick.position+Vector2(0,brick.h*0.5),Color(color()),4,0.4)
	if moving:g.revision+=1
	settling=moving

func bonus_scale() -> float:return 1.5
func status() -> String:return "已塌落 %d" % int(data.get("fallen",0))
func summary() -> Array:return ["塌落 %d 次" % int(data.get("fallen",0))]
