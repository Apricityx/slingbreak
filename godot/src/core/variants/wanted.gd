extends "res://src/core/variants/rule.gd"
## 悬赏令: three armoured, well-spread bricks carry a bounty that starts at
## ×START and loses STEP per shot fired this level, never below ×FLOOR. Racing
## to the targets early pays most; ignoring them still clears the level.
const Progress=preload("res://src/core/progress.gd")
const TARGETS:=3
const START:=10.0
const STEP:=0.75
const FLOOR:=3.0
const ARMOUR:=2.5
const SPREAD:=200.0

func title() -> String:return "悬赏令"
func color() -> String:return "#d0573c"
func note() -> String:return "标记的悬赏砖血量 ×2.5；赏金从 ×10 起，每发一箭减 0.75 倍，最低 ×3。不必清完悬赏也能通关。"

func shape() -> void:
	var marked:Array=[]
	for brick in g.shuffle(g.bricks.filter(func(b):return b.type=="normal")):
		if marked.size()>=TARGETS:break
		var crowded:=false
		for other in marked:
			if other.position.distance_to(brick.position)<SPREAD:crowded=true
		if crowded:continue
		marked.append(brick)
	for brick in marked:
		brick.flags.wanted=true;brick.hp=ceil(brick.hp*ARMOUR);brick.max_hp=brick.hp
	data={"total":marked.size(),"claimed":0}

func valid(saved:Dictionary) -> bool:
	return Progress.finite_number(saved.get("total"),0,TARGETS,true) and Progress.finite_number(saved.get("claimed"),0,TARGETS,true) and int(saved.claimed)<=int(saved.total)

func used() -> int:
	return int(g.state.skillRuntime.get("shots",0)) if g.state.skillRuntime is Dictionary else 0

## The current bounty multiplier; it is paid on top of the normal reward.
func bounty() -> float:return maxf(FLOOR,START-STEP*used())

## "7" rather than "7.0"; at most two decimals.
static func times(value:float) -> String:return str(int(value)) if value==floor(value) else String.num(value,2)

static func wanted(brick:RefCounted) -> bool:return brick.flags.get("wanted",false)==true

func reward_scale(brick:RefCounted) -> float:return bounty() if wanted(brick) else 1.0

func destroyed(brick:RefCounted) -> void:
	if not wanted(brick):return
	data.claimed=mini(int(data.total),int(data.claimed)+1)
	g.fx.floating(brick.position-Vector2(0,34),"悬赏 ×%s" % times(bounty()),Color(color()),22)
	g.fx.ring(brick.position,Color(color()),120);g.fx.burst(brick.position,Color("#e0ad2c"),18,1.4)

func remaining() -> int:return int(data.total)-int(data.claimed)

func status() -> String:
	if remaining()<=0:return "悬赏已清"
	return "×%s · 剩 %d" % [times(bounty()),remaining()]

func summary() -> Array:return ["缉拿 %d / %d" % [int(data.claimed),int(data.total)]]

func draw(canvas:CanvasItem) -> void:
	var ink:=Color(color());ink.a=0.55+0.25*sin(float(g.time)*5.0)
	for brick in g.bricks:
		if not wanted(brick):continue
		var radius:float=maxf(brick.w,brick.h)*0.62
		canvas.draw_arc(brick.position,radius,0,TAU,32,ink,2.0,true)
		for i in range(4):
			var direction:=Vector2.RIGHT.rotated(i*PI/2)
			canvas.draw_line(brick.position+direction*(radius-5),brick.position+direction*(radius+5),ink,2.0,true)
