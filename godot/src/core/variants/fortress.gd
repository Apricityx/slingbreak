extends "res://src/core/variants/rule.gd"
## 要塞: a thinner armoured board; marked weak bricks breach nearby walls and
## damage their neighbours, creating routes rather than a pure health tax.

func title() -> String:return "要塞"
func color() -> String:return "#8a9480"
func note() -> String:return "砖少血厚（血量 ×1.6）· 击碎橙色弱点可炸开附近障碍、震伤邻砖 · 奖金 ×2"

func shape() -> void:
	# Extra walls stay out of the open central lane and off existing walls.
	var added:=0
	for brick in g.shuffle(g.bricks.filter(func(b):return b.type=="normal" and absf(b.x-390)>=192)):
		if added>=4 or g.obstacles.size()>=12:break
		var crowded:=false
		for wall in g.obstacles:
			if wall.position.distance_to(brick.position)<104:crowded=true
		if crowded:continue
		g.bricks.erase(brick);g.make_obstacle({"x":brick.x,"y":brick.y});added+=1
	var thin:Array=g.shuffle(g.bricks.filter(func(b):return b.type=="normal"))
	for brick in thin.slice(0,floori(thin.size()*0.2)):g.bricks.erase(brick)
	var weak:Array=[]
	for brick in g.shuffle(g.bricks.filter(func(b):return b.type=="normal" and g.obstacles.any(func(w):return w.position.distance_to(b.position)<=160))):
		if weak.size()>=3:break
		if weak.any(func(other):return other.position.distance_to(brick.position)<180):continue
		weak.append(brick);brick.flags.fortressWeak=true
	for brick in g.bricks:
		if brick.flags.get("fortressWeak",false):continue
		brick.hp=ceil(brick.hp*1.6);brick.max_hp=brick.hp
	g.initial=g.bricks.size()

func destroyed(brick:RefCounted) -> void:
	if not brick.flags.get("fortressWeak",false):return
	for wall in g.obstacles.duplicate():
		if wall.position.distance_to(brick.position)<=160:g.obstacles.erase(wall);g.fx.burst(wall.position,Color(color()),12,1)
	g.fx.ring(brick.position,Color("#c9873e"),160);g.fx.floating(brick.position-Vector2(0,35),"突破弱点",Color("#c9873e"),20)
	for target in g.near(brick.position,160):g.hit(target,g.damage()*1.5,1)
	g.cue("boom",1,brick.x)

func draw(canvas:CanvasItem) -> void:
	for brick in g.bricks:
		if not brick.flags.get("fortressWeak",false):continue
		var ink:=Color("#c9873e")
		canvas.draw_rect(brick.bounds.grow(4),ink,false,3)
		var mark:Vector2=brick.position+Vector2(0,-brick.h*0.5-11)
		canvas.draw_line(mark+Vector2(-7,-4),mark+Vector2(0,4),ink,3,true)
		canvas.draw_line(mark+Vector2(0,4),mark+Vector2(7,-4),ink,3,true)

func bonus_scale() -> float:return 2.0
func status() -> String:return "弱点剩 %d · 奖金 ×2" % g.bricks.filter(func(b):return b.flags.get("fortressWeak",false)).size()
