extends "res://src/core/variants/rule.gd"
## 要塞: extra walls on the flanks, a thinner but armoured board; core bonus ×2.

func title() -> String:return "要塞"
func color() -> String:return "#8a9480"
func note() -> String:return "砖少血厚 · 奖金 ×2"

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
	for brick in g.bricks:brick.hp=ceil(brick.hp*2.5);brick.max_hp=brick.hp
	g.initial=g.bricks.size()

func bonus_scale() -> float:return 2.0
func status() -> String:return "奖金 ×2"
