extends "res://src/core/variants/rule.gd"
## 淘金热: a third of the board turns gold, but only for RUSH_SECONDS after the
## first shot; whatever gold is left then fades back to ordinary bricks.
const Progress=preload("res://src/core/progress.gd")
const RUSH_SECONDS:=15.0

func title() -> String:return "淘金热"
func color() -> String:return "#e0ad2c"
func note() -> String:return "首箭后 %d 秒内金矿有效" % int(RUSH_SECONDS)

func shape() -> void:
	data={"clock":0.0,"started":false,"expired":false,"gold":0}
	var normal:Array=g.shuffle(g.bricks.filter(func(b):return b.type=="normal"))
	for brick in normal.slice(0,ceili(normal.size()*0.35)):brick.type="gold"

func valid(saved:Dictionary) -> bool:
	return Progress.finite_number(saved.get("clock"),0,1e9) and saved.get("started") is bool and saved.get("expired") is bool and Progress.finite_number(saved.get("gold"),0,10000,true)

func update(delta:float) -> void:
	if data.started and not data.expired and g.phase in ["ready","flying"]:
		data.clock=float(data.clock)+delta
		if data.clock>=RUSH_SECONDS:_expire()

func _expire() -> void:
	data.expired=true
	for brick in g.bricks:
		if brick.type=="gold":brick.type="normal";brick.flash=0.2;g.fx.burst(brick.position,Color(color()),6,0.6)
	g.events.append({"type":"toast","text":"淘金结束 · 剩余金矿已褪色"});g.revision+=1

func on_shoot() -> void:data.started=true
func destroyed(brick:RefCounted) -> void:
	if brick.type=="gold" and not data.expired:data.gold=int(data.gold)+1

func status() -> String:
	if data.expired:return "已结束"
	if data.started:return "剩余 %.1f 秒" % maxf(0,RUSH_SECONDS-float(data.clock))
	return "首箭开始计时"

# Rush pays through its gold bricks, so it has no core-bonus badge.
func summary() -> Array:return ["淘得金矿 %d 块" % int(data.gold)]
