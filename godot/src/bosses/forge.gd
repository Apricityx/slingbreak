extends "res://src/bosses/base.gd"
## 熔炉巨像: a seated iron colossus. Its furnace door is sealed until the heat
## gauge reaches 100: fuel bricks, the shoulder bellows (phase two) and the door
## itself (phase three) stoke it, and every move has one counter that vents the
## furnace at once. Venting opens the door for triple damage; a missed counter
## cools the furnace and armours the board.
const CALL={"slam":["HAMMER","锻锤","蓄力时击中铁拳"],"meteor":["SPIT","喷火","击落空中熔团"],"bellows":["BELLOWS","炉息","射入张开的风箱"],"palm":["IRON PALM","铁掌","击中掌心炉口"],"magma":["POUR","浇铸","击中倾倒的坩埚嘴"],"meltdown":["MELTDOWN","熔毁","心跳亮起时三击炉门"]}
const CENTER:=Vector2(390,420)
const HEAD:=Vector2(390,150)
const SHOULDERS:=[Vector2(262,262),Vector2(518,262)]
const FISTS:=[Vector2(196,652),Vector2(584,652)]
const FUEL:=[Vector2(102,350),Vector2(678,350),Vector2(102,530),Vector2(678,530)]
const DOOR_RADIUS:=46.0
const OPEN_RADIUS:=38.0
const HEAD_RADIUS:=60.0
const FIST_RADIUS:=38.0
const BELLOWS_RADIUS:=30.0
const GLOB_RADIUS:=24.0
const PALM_Y:=850.0
const INTRO_SECONDS:=3.4
const SHIFT_SECONDS:=2.8
const SHIFT_DELAY:=1.2
var center:=CENTER
var globs:Array=[]
var vented_at:=-100.0
var vent_point:=CENTER
var struck_at:=-100.0
var pinged_at:=-100.0
var cooled_at:=-100.0
var puffs:=[-100.0,-100.0]
var fuel_at:=0.0
var draining:=false

func setup(restored:bool) -> void:
	super.setup(restored);globs.clear();vented_at=-100;struck_at=-100;cooled_at=-100;puffs=[-100.0,-100.0];fuel_at=g.time+2.5;draining=false
	if not restored:
		d.fight.data.heat=0.0
		# Clear the silhouette so the body, fists and door read and stay reachable.
		for brick in g.bricks.duplicate():
			if on_body(brick.position,Vector2(brick.w,brick.h)):g.bricks.erase(brick)
		for wall in g.obstacles.duplicate():
			if on_body(wall.position,Vector2(wall.w,wall.h)):g.obstacles.erase(wall)
		for index in range(fuel_target()):stoke(index,true)

## True when a size-wide rect centred at point overlaps the head, torso or fists.
func on_body(point:Vector2,size:Vector2=Vector2.ZERO) -> bool:
	var rect:=Rect2(point-size/2,size)
	if rect.intersects(Rect2(214,190,352,500)):return true
	for pair in [[HEAD,82.0],[FISTS[0],58.0],[FISTS[1],58.0]]:
		if pair[0].clamp(rect.position,rect.end).distance_to(pair[0])<pair[1]:return true
	return false

func fuel_target() -> int:return mini(FUEL.size(),1+int(d.fight.phase))
func fuel_count() -> int:return g.bricks.filter(func(b):return b.type=="magma").size()
func plate_hp() -> float:return maxf(g.base_hp()*2,ceil(g.damage()*(2+d.fight.phase)))

## Places (or converts) one fuel brick at the indexed fuel slot.
func stoke(index:int,initial:bool=false) -> void:
	var point:Vector2=FUEL[index%FUEL.size()]
	# Fuel slots belong to the encounter, not the random obstacle layout.
	if initial:
		for wall in g.obstacles.duplicate():
			if wall.position.distance_to(point)<8:g.obstacles.erase(wall)
	var found:Array=g.bricks.filter(func(b):return b.position.distance_to(point)<8)
	var brick:RefCounted
	if found.is_empty():
		if g.obstacles.any(func(w):return w.position.distance_to(point)<8) or g.bricks.size()>=230:return
		brick=g.make_brick({"x":point.x,"y":point.y});g.initial+=1
	else:brick=found[0]
	if brick.type=="magma":return
	brick.type="magma";brick.hp=ceil(g.base_hp()*1.5);brick.max_hp=brick.hp;brick.flash=0.3
	if not initial:g.fx.burst(point,Color(d.palette().molten),12,1.4);g.cue("hiss",1,point.x)

func status() -> Dictionary:
	if exposed():return {"text":"过热 %.1fs · 伤害 ×3" % maxf(0,stunned_until-g.time),"state":"exposed"}
	return {"text":"封炉中" if g.time<refill_until else "炉温 %d%%" % roundi(d.fight.data.heat),"state":"shielded"}

func focus() -> Vector2:return CENTER
func intro_seconds() -> float:return INTRO_SECONDS
func shift_seconds() -> float:return SHIFT_SECONDS
func shift_delay() -> float:return SHIFT_DELAY
func heat() -> float:return float(d.fight.data.get("heat",0.0))

func vent(point:Vector2,label:String,arrow:RefCounted=null,duration:float=4) -> void:
	move={};globs.clear();d.wind=0.0
	d.fight.data.heat=100.0;stunned_until=g.time+duration;refill_until=stunned_until+1.2;next_at=refill_until+2;draining=true
	vented_at=g.time;vent_point=point
	if arrow!=null:d.pay(arrow,point,2)
	impact(center,Color(d.palette().molten),300);g.fx.burst(center,Color(d.palette().ember),34,3)
	g.fx.floating(point-Vector2(0,34),label,Color(d.palette().text),20);g.cue("forge",1,390,true);g.cue("boom",1,center.x)
	d.banner("OVERHEAT","过热","炉门开启 · 伤害 ×3","weak")

func add_heat(amount:float,point:Vector2) -> void:
	if exposed() or g.time<refill_until or d.dying_at>=0:return
	d.fight.data.heat=minf(100,heat()+amount)
	g.fx.floating(point-Vector2(0,26),"+%d" % roundi(amount),Color(d.palette().molten),14)
	if heat()>=100:vent(point,"过热",g.active_arrow)
	g.revision+=1

## A missed counter: the furnace banks its fire.
func cool(amount:float) -> void:
	if exposed():return
	d.fight.data.heat=maxf(0,heat()-amount);cooled_at=g.time
	g.fx.floating(center-Vector2(0,70),"冷却 -%d" % roundi(amount),Color(d.palette().smoke),16);g.cue("hiss",1,center.x)
	g.revision+=1

## Converts up to count bricks nearest to point into armoured slag plates.
func armour(point:Vector2,count:int) -> void:
	for brick in g.nearest(point,count,func(b):return b.type=="normal"):
		brick.type="plate";brick.hp=plate_hp();brick.max_hp=brick.hp;brick.flash=0.3
		g.fx.burst(brick.position,Color(d.palette().ironEdge),8,1.2)

func before_hit(brick:RefCounted,depth:int) -> bool:
	if brick.type=="magma" and depth==0 and g.active_arrow!=null:add_heat(6,brick.position)
	return true

func destroyed(brick:RefCounted,depth:int) -> void:
	match brick.type:
		"magma":
			d.hurt(g.damage()*0.8,brick.position);add_heat(24 if depth==0 else 12,brick.position);g.cue("hiss",1,brick.x)
			if depth<6:g.area(brick.position,110,g.damage()*1.2,"",depth+1)
		"plate":d.hurt(g.damage()*0.6,brick.position);add_heat(4,brick.position)
		_:d.hurt(g.damage()*0.15,brick.position);add_heat(2,brick.position)

func intro() -> void:
	super.intro();next_at=g.time+INTRO_SECONDS+2.2
	# Seams ignite, both fists hit the floor, then the furnace door booms.
	d.later(0.25,func():g.cue("hiss",1,390))
	d.later(0.9,func():g.cue("forge",1,390,true))
	for side in range(2):
		d.later(1.55+side*0.3,func():
			g.cue("clang",1,FISTS[side].x);g.fx.burst(FISTS[side]+Vector2(0,30),Color(d.palette().ember),14,1.6);g.fx.shake=maxf(g.fx.shake,7))
	d.later(2.45,func():g.cue("boom",1,390);g.fx.ring(CENTER,Color(d.palette().molten),180);g.fx.shake=maxf(g.fx.shake,9))

func begin(id:String) -> void:
	last_move=id
	var side:int=g.rng.randi_range(0,1)
	var rage:bool=d.rage
	move={"id":id,"side":side,"start":g.time,"hits":0,"beats":0}
	match id:
		"slam":move.live=g.time+(1.35 if rage else 1.7);move.end=move.live+0.7
		"meteor":
			var count:=4 if rage else 3
			var targets:Array=g.shuffle(g.bricks.filter(func(b):return b.type=="normal")).slice(0,count).map(func(b):return b.position)
			for point in g.shuffle(d.open_slots().filter(func(p):return not on_body(p,Vector2(84,44)))):
				if targets.size()>=count:break
				targets.append(point)
			var flight:=1.45 if rage else 1.75
			for index in range(targets.size()):
				globs.append({"from":HEAD+Vector2(0,-40),"to":targets[index],"born":g.time+0.7+index*0.42,"flight":flight,"arc":250.0+index*20,"dead":false,"caught":false})
			move.live=g.time+0.7;move.end=g.time+0.7+maxi(0,targets.size()-1)*0.42+flight+0.2;move.count=targets.size()
		"bellows":move.live=g.time+1.4;move.end=move.live+3.4
		"palm":move.live=g.time+0.8;move.end=move.live+7.0
		"magma":move.live=g.time+1.0;move.end=move.live+4.2;move.next=move.live
		"meltdown":move.live=g.time+1.4;move.end=move.live+6.6;move.next=move.live
	var call:Array=CALL[id];d.banner(call[0],call[1],call[2],"weak" if id=="meltdown" else "minor")
	g.cue({"slam":"clang","meteor":"forge","bellows":"whoosh","palm":"clang","magma":"hiss","meltdown":"core"}[id],1,390)

func calm() -> void:
	super.calm();globs.clear()
	if d!=null:d.wind=0.0

## Collider centre of one fist; it rises while a hammer blow winds up.
func fist_point(side:int) -> Vector2:
	var point:Vector2=FISTS[side]
	if move.get("id")=="slam" and move.side==side:
		var k:float=clampf((g.time-move.start)/(move.live-move.start),0,1) if g.time<move.live else 1-clampf((g.time-move.live)/0.12,0,1)
		point.y-=78*sin(k*PI*0.5)
	return point
func fist_armed(side:int) -> bool:return move.get("id")=="slam" and move.side==side and g.time>=move.start+0.25 and g.time<move.live
func palm_x() -> float:return 390+sin((g.time-move.live)*(1.25 if d.rage else 0.95))*180
func palm_live() -> bool:return move.get("id")=="palm" and g.time>=move.live
func spout() -> Vector2:return HEAD+Vector2(78 if move.get("side",1)==1 else -78,-22)
func pouring() -> bool:return move.get("id")=="magma"
## Where the poured slag lands: the stream sweeps across the floor away from the spout.
func pour_x() -> float:return lerpf(102 if move.side==0 else 678,678 if move.side==0 else 102,clampf((g.time-move.live)/(move.end-move.live),0,1))
func glob_point(glob:Dictionary) -> Vector2:
	var k:float=clampf((g.time-glob.born)/glob.flight,0,1)
	return glob.from.lerp(glob.to,k)-Vector2(0,sin(k*PI)*glob.arc)
func beat_period() -> float:return 0.55 if d.rage else 0.7
## True for the short bright window after each meltdown heartbeat.
func heartbeat_lit() -> bool:
	return move.get("id")=="meltdown" and g.time>=move.live and fmod(g.time-move.live,beat_period())<0.3
func shift_progress() -> float:
	return clampf(1-(d.shift_until-g.time)/SHIFT_SECONDS,0,1) if g.time<d.shift_until else 0.0

func ping(point:Vector2,ink:String="ironEdge") -> void:
	if g.time-pinged_at<0.2:return
	pinged_at=g.time;g.fx.ring(point,Color(d.palette()[ink]),30);g.cue("clang",1,point.x)

func contact(arrow:RefCounted,live:bool) -> void:
	# Airborne globs sit in front of the body, so they are caught first.
	for glob in globs:
		if glob.dead or g.time<glob.born or glob_point(glob).distance_to(arrow.position)>GLOB_RADIUS:continue
		if not live:continue
		var point:=glob_point(glob)
		glob.dead=true;glob.caught=true;move.hits=move.get("hits",0)+1
		d.pay(arrow,point,1);g.fx.burst(point,Color(d.palette().molten),18,1.6);g.cue("shatter",1,point.x)
		if move.get("id")=="meteor" and move.hits>=move.count:vent(point,"击落",arrow)
		else:add_heat(15,point)
		return
	var hit:Dictionary=d.bounce_circle(arrow,center,OPEN_RADIUS if exposed() else DOOR_RADIUS)
	if not hit.is_empty():
		if not live:return
		if exposed():
			if d.strike(arrow,hit.point,3):struck_at=g.time
			return
		if g.time<arrow.flags.get("doorAt",-1):return
		arrow.flags.doorAt=g.time+0.15
		if move.get("id")=="meltdown" and heartbeat_lit():
			move.hits+=1;g.fx.ring(center,Color(d.palette().weak),70+move.hits*20);g.cue("core",1,hit.point.x)
			if move.hits>=3:vent(hit.point,"熔毁",arrow,5.5)
		elif d.fight.phase>=3 and move.get("id")!="meltdown":add_heat(5,hit.point);ping(hit.point,"molten")
		else:ping(hit.point)
		return
	if pouring() and not d.bounce_circle(arrow,spout(),26).is_empty():
		if live:vent(spout(),"断流",arrow)
		return
	if palm_live():
		var x:=palm_x()
		var socket:Dictionary=d.bounce_circle(arrow,Vector2(x,PALM_Y),22)
		if not socket.is_empty():
			if not live or g.time<arrow.flags.get("palmAt",-1):return
			arrow.flags.palmAt=g.time+0.2;move.hits+=1;g.fx.burst(socket.point,Color(d.palette().molten),12,1.4);g.cue("clang",1,x)
			if move.hits>=(4 if d.rage else 3):vent(socket.point,"震掌",arrow)
			return
		for span in [[-78,-22],[22,78]]:
			if d.bounce_bar(arrow,Vector2(x+span[0],PALM_Y+4),Vector2(x+span[1],PALM_Y+4),13):
				if live:ping(arrow.position)
				return
	for side in range(2):
		if palm_live() and move.side==side:continue
		var fist:Dictionary=d.bounce_circle(arrow,fist_point(side),FIST_RADIUS)
		if fist.is_empty():continue
		if live:
			if fist_armed(side):vent(fist.point,"破锤",arrow)
			else:ping(fist.point)
		return
	for side in range(2):
		var shoulder:Dictionary=d.bounce_circle(arrow,SHOULDERS[side],BELLOWS_RADIUS)
		if shoulder.is_empty():continue
		if not live:return
		if move.get("id")=="bellows" and move.side==side:vent(shoulder.point,"回火",arrow);return
		if d.fight.phase>=2 and g.time>=arrow.flags.get("bellowsAt",-1):
			arrow.flags.bellowsAt=g.time+0.3;puffs[side]=g.time;add_heat(8,shoulder.point);g.cue("whoosh",1,shoulder.point.x)
		else:ping(shoulder.point)
		return
	var head:Dictionary=d.bounce_circle(arrow,HEAD,HEAD_RADIUS)
	if not head.is_empty() and live:ping(head.point)

## Lays a slag plate at point, reusing a normal brick already there.
func slag(point:Vector2) -> void:
	var found:Array=g.bricks.filter(func(b):return b.position.distance_to(point)<30)
	if found.is_empty():
		if d.occupied(point,50,30) or on_body(point,Vector2(84,44)) or g.bricks.size()>=230:return
		found=[g.make_brick({"x":point.x,"y":point.y})];g.initial+=1
	var brick:RefCounted=found[0]
	if brick.type!="normal":return
	brick.type="plate";brick.hp=plate_hp();brick.max_hp=brick.hp;brick.flash=0.3
	g.fx.burst(point,Color(d.palette().molten),10,1.3);g.cue("hiss",1,point.x)

func update(delta:float) -> void:
	var id:String=move.get("id","")
	for glob in globs:
		if glob.dead or g.time<glob.born+glob.flight:continue
		glob.dead=true;slag(glob.to);g.fx.ring(glob.to,Color(d.palette().ember),80);g.cue("meteor",1,glob.to.x)
	globs=globs.filter(func(v):return not v.dead)
	if id=="bellows":
		var k:float=clampf(minf((g.time-move.live)/0.4,(move.end-g.time)/0.4),0,1) if g.time>=move.live else 0.0
		d.wind=(1 if move.side==0 else -1)*0.2*pow(1000.0/60.0,2)*0.001*k
	if d.busy:return
	if not exposed():
		if g.time<refill_until:d.fight.data.heat=100*clampf((refill_until-g.time)/1.2,0,1)
		elif draining or heat()>=99.5:d.fight.data.heat=0.0;draining=false
		elif heat()>0:d.fight.data.heat=maxf(0,heat()-delta*(1.6 if d.rage else 1.0))
	# Spent fuel reforms in its slot, so the furnace can always be stoked.
	if g.time>=fuel_at:
		fuel_at=g.time+(4.0 if d.rage else 5.5)
		if fuel_count()<fuel_target():
			for index in range(fuel_target()):
				if not g.bricks.any(func(b):return b.type=="magma" and b.position.distance_to(FUEL[index])<8):stoke(index);break
	if ready_move():begin(pick());id=move.id
	if move.is_empty():return
	if id=="slam" and g.time>=move.live and not move.get("landed",false):
		move.landed=true
		var ground:Vector2=FISTS[move.side]+Vector2(0,40)
		for brick in g.near(ground,190).duplicate():g.hit(brick,g.damage()*0.6,70)
		for brick in g.nearest(ground,3 if d.rage else 2,func(b):return b.type=="normal"):slag(brick.position)
		impact(ground,Color(d.palette().ember),190);g.fx.shake=maxf(g.fx.shake,14);g.cue("clang",1,ground.x);cool(20)
	if id=="magma" and g.time>=move.next and g.time<move.end:
		move.next=g.time+(0.6 if d.rage else 0.8)
		var x:=pour_x()
		var slots:Array=d.open_slots().filter(func(p):return p.y>=650 and not on_body(p,Vector2(84,44)))
		slots.sort_custom(func(a,b):return absf(a.x-x)<absf(b.x-x))
		if not slots.is_empty():slag(slots[0])
	if id=="meltdown" and g.time>=move.next and g.time<move.end:
		move.next=g.time+beat_period();move.beats+=1;g.cue("core",1,390);g.fx.ring(center,Color(d.palette().weak),60)
	if g.time<move.end:return
	match id:
		"meteor":
			if move.hits<move.count:cool(15)
		"bellows":d.wind=0.0;cool(25);armour(SHOULDERS[move.side]+Vector2(0,320),2)
		"palm":
			var x:=palm_x();impact(Vector2(x,PALM_Y),Color(d.palette().ember),150)
			armour(Vector2(x,700),3 if d.rage else 2);cool(20)
		"magma":cool(15)
		"meltdown":
			impact(center,Color(d.palette().weak),260);armour(center,6 if d.rage else 4)
			d.fight.data.heat=0.0;g.cue("boom",1,390);d.banner("ERUPTION","喷发","炉温归零","minor")
	finish_move()

func music_mood() -> String:
	if exposed():return "stun"
	if move.get("id")=="meltdown":return "meltdown"
	return "fight"

func explode() -> bool:
	var ink:Color=Color(d.palette().molten)
	g.fx.ring(CENTER,ink,560);g.fx.ring(CENTER,Color(d.palette().ember),820)
	g.fx.burst(CENTER,ink,70,4);g.fx.burst(HEAD,Color(d.palette().ember),30,3)
	for point in SHOULDERS+FISTS:g.fx.burst(point,Color(d.palette().ironEdge),12,2.4)
	for brick in g.bricks.duplicate():
		if brick.type in ["magma","plate"]:g.hit(brick,1e12,99)
	g.fx.flash=1.0;g.fx.shake=18;g.cue("boom");g.cue("forge",1,390,true)
	return true
