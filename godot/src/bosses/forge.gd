extends "res://src/bosses/base.gd"
var center:=Vector2(390,470)
var meteors:Array=[]
var slam:Dictionary={}
var wind:Dictionary={}
var palm:Dictionary={}
var meteor_at:=0.0
var slam_at:=0.0
var wind_at:=0.0

func setup(restored:bool) -> void:
	super.setup(restored);meteors.clear();slam.clear();wind.clear();palm={"x":390.0,"hits":0,"down":0.0} if d.has("palm") else {}
	if not restored:
		d.fight.data.heat=0.0
		for brick in g.bricks.duplicate():
			if brick.position.distance_to(center)<20:g.bricks.erase(brick)
		for dx in range(-1,2):
			for dy in range(-1,2):
				if dx==0 and dy==0:continue
				var point:=center+Vector2(dx*96,dy*60)
				var selected:Array=g.bricks.filter(func(b):return b.position==point)
				var brick:RefCounted=g.make_brick({"x":point.x,"y":point.y}) if selected.is_empty() else selected[0]
				brick.type="plate";brick.hp=maxf(g.base_hp()*2,ceil(g.damage()*(3+d.fight.phase)));brick.max_hp=brick.hp
		for brick in g.shuffle(g.bricks.filter(func(b):return b.type=="normal")).slice(0,9 if d.has("magma") else 3):brick.type="magma"
	meteor_at=g.time+3;slam_at=g.time+5;wind_at=g.time+4

func status() -> Dictionary:return {"text":"过热 · 伤害 ×2" if exposed() else "炉温 %d%%" % roundi(d.fight.data.heat),"state":"exposed" if exposed() else "shielded"}
func heat(amount:float) -> void:
	if exposed():return
	d.fight.data.heat=minf(100,d.fight.data.heat+amount)
	if d.fight.data.heat>=100:
		d.fight.data.heat=0.0;stunned_until=g.time+6;impact(center,Color(d.palette().molten),520);d.banner("OVERHEAT","过热","心核伤害翻倍","weak");g.cue("forge")

func destroyed(brick:RefCounted,depth:int) -> void:
	d.hurt(g.damage()*(1 if brick.type=="plate" else 0.12),brick.position);heat(10 if brick.type=="magma" else 8 if brick.type=="plate" else 4)
	if brick.type=="magma" and depth<6:
		g.area(brick.position,125,g.damage()*1.6,"",depth+1)
		if d.has("magma"):
			for target in g.near(brick.position,125).filter(func(b):return b.type=="normal").slice(0,2):target.type="magma"
	elif exposed() and depth<3:g.area(brick.position,100,g.damage()*0.8,"",depth+1)

func contact(arrow:RefCounted,live:bool) -> void:
	var hit:Dictionary=d.bounce_circle(arrow,center,33)
	if not hit.is_empty() and live:
		if d.strike(arrow,hit.point,6 if exposed() else 3):heat(6);g.cue("clang")
	if not palm.is_empty() and g.time>=palm.down:
		if d.bounce_bar(arrow,Vector2(palm.x-50,835),Vector2(palm.x+50,835),14) and live and g.time>=arrow.flags.get("palmAt",-1):
			arrow.flags.palmAt=g.time+0.2;palm.hits+=1
			if palm.hits>=4:palm.down=g.time+(4 if d.rage else 6);palm.hits=0;d.pay(arrow,arrow.position,2);impact(arrow.position,Color(d.palette().ember),120)
	for meteor in meteors:
		if not meteor.dead and g.time>=meteor.born and meteor.position.distance_to(arrow.position)<26 and live:meteor.dead=true;d.pay(arrow,meteor.position,1.5);heat(12);g.fx.burst(meteor.position,Color(d.palette().molten),20);g.cue("shatter")

func launch_meteors() -> void:
	var targets:Array=g.shuffle(g.bricks).slice(0,4 if d.rage else 3)
	for index in range(targets.size()):
		meteors.append({"start":Vector2(390+(index-1)*14,88),"target":targets[index].position,"position":Vector2(390,88),"born":g.time+0.35+index*0.22,"duration":1.25,"arc":g.rng.randf_range(120,200),"dead":false})
	d.banner("METEOR","陨火","可在空中击落");g.cue("forge")

func update(delta:float) -> void:
	if not palm.is_empty():
		var target:float=390+sin(g.time*0.8)*150
		if g.drag!=null and g.drag.dy>5:target=390-g.drag.dx/g.drag.dy*135
		palm.x=move_toward(palm.x,clampf(target,110,670),(130 if d.rage else 90)*delta)
	for meteor in meteors:
		if meteor.dead or g.time<meteor.born:continue
		var t:=clampf((g.time-meteor.born)/meteor.duration,0,1)
		meteor.position=meteor.start.lerp(meteor.target,t)-Vector2(0,sin(t*PI)*meteor.arc)
		if t>=1:
			meteor.dead=true
			var selected:Array=g.bricks.filter(func(b):return b.position.distance_to(meteor.target)<30)
			if selected.is_empty():d.spawn(meteor.target,"magma")
			else:selected[0].type="magma"
			g.fx.ring(meteor.target,Color(d.palette().ember),90);g.cue("meteor")
	meteors=meteors.filter(func(m):return not m.dead)
	if not slam.is_empty():
		if g.time>=slam.at and not slam.hit:
			slam.hit=true
			for brick in g.bricks.duplicate():
				if absf(brick.x-slam.x)<48:g.hit(brick,g.damage()*2.5,70)
			for brick in g.bricks:
				if absf(brick.x-slam.x)<48:brick.type="plate"
			impact(Vector2(slam.x,800),Color(d.palette().ember),160);g.cue("clang")
		if g.time>=slam.end:slam={}
	if not wind.is_empty():
		var k:=clampf(minf((g.time-wind.start)/0.5,(wind.end-g.time)/0.5),0,1)
		d.wind=wind.direction*0.22*pow(1000.0/60.0,2)*0.001*k
		if g.time>=wind.end:wind={};d.wind=0
	if d.busy:return
	if d.has("meteor") and g.time>=meteor_at:meteor_at=g.time+(5 if d.rage else 7);launch_meteors()
	if d.has("slam") and slam.is_empty() and g.time>=slam_at:
		slam_at=g.time+(6.5 if d.rage else 8.5)
		if not g.bricks.is_empty():slam={"x":g.bricks[g.rng.randi_range(0,g.bricks.size()-1)].x,"at":g.time+1.2,"end":g.time+1.9,"hit":false};d.banner("HAMMER","锻锤","避开锻打列")
	if d.has("bellows") and wind.is_empty() and g.time>=wind_at:
		wind_at=g.time+(7 if d.rage else 9.5);wind={"direction":-1 if g.rng.randf()<0.5 else 1,"start":g.time+0.9,"end":g.time+4.4};d.banner("BELLOWS","炉息", "←" if wind.direction<0 else "→")

func calm() -> void:super.calm();meteors.clear();slam.clear();wind.clear();d.wind=0
