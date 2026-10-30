extends "res://src/bosses/base.gd"
const CALL={"stop":["TIME STOP","时停","击碎发条"],"toll":["TOLL","鸣钟","钟响前击中巨钟"],"pendulum":["PENDULUM","钟摆","连击斩断巨摆"],"rewind":["REWIND","倒流","射中晶壳打断"],"haste":["HASTE","疾走","射中亮起的刻度"],"midnight":["MIDNIGHT","午夜","十二响内三击晶壳"]}
var minute:=-PI/2
var hour:=-PI/2+PI/3
var hour_index:=2
var turn:=0.0
var wound:=1.0
var gears:Array=[]
var history:Array=[]
var frozen:Array=[]
var frozen_until:=0.0
var wave:Dictionary={}
var center:=Vector2(390,470)

func setup(restored:bool) -> void:
	super.setup(restored);minute=-PI/2;hour_index=2;hour=-PI/2+PI/3;turn=0;wound=1;gears.clear();history.clear();frozen.clear();wave.clear()
	if not restored:
		d.fight.data.spring=100.0
		for brick in g.bricks.duplicate():
			if brick.position.distance_to(center)<60:g.bricks.erase(brick)
		for index in range(12):regrow_hour(index,true)
	for brick in g.bricks:
		if brick.type=="hour" and not brick.flags.has("hourIndex"):
			brick.flags.hourIndex=posmod(roundi((atan2((brick.y-470)/0.95,brick.x-390)+PI/2)/(PI/6)),12)
	if d.fight.phase>=2:
		for index in range(3):
			var point:Vector2=[Vector2(240,470),Vector2(540,470),Vector2(390,320)][index]
			gears.append({"position":point,"angle":index*2.1,"direction":-1 if index==1 else 1,"jammed":false})
			for brick in g.bricks.duplicate():
				if absf(brick.x-point.x)<78 and absf(brick.y-point.y)<54:g.bricks.erase(brick)

func hour_point(index:int) -> Vector2:
	var angle:float=-PI/2+index*PI/6
	return center+Vector2(cos(angle),sin(angle)*0.95)*250

func regrow_hour(index:int,initial:bool=false) -> void:
	var point:=hour_point(index)
	if g.obstacles.any(func(w):return absf(w.x-point.x)<76 and absf(w.y-point.y)<46):return
	if g.bricks.any(func(b):return b.type=="hour" and b.flags.get("hourIndex",-1)==index):return
	if not initial and d.occupied(point,50,32):return
	if initial:
		for brick in g.bricks.duplicate():
			if absf(brick.x-point.x)<70 and absf(brick.y-point.y)<40:g.bricks.erase(brick)
	var hp:=maxf(g.base_hp()*2,ceil(g.damage()*(2+d.fight.phase)))
	var brick:RefCounted=g.make_brick({"x":point.x,"y":point.y,"w":56,"h":36,"hp":hp,"max":hp,"type":"hour"})
	brick.flags.hourIndex=index;brick.flash=0.25
	if not initial:g.initial+=1;g.cue("chime",1,point.x)

func status() -> Dictionary:
	return {"text":"停摆 · 伤害 ×3" if exposed() else "发条回紧" if g.time<refill_until else "发条 %d%%" % roundi(d.fight.data.spring),"state":"exposed" if exposed() else "shielded"}

func jam(point:Vector2,label:String,arrow:RefCounted=null,duration:float=4) -> void:
	move={};d.fight.data.spring=0.0;stunned_until=g.time+duration;refill_until=stunned_until+1.2;next_at=refill_until+2
	if arrow!=null:d.pay(arrow,point,2)
	impact(center,Color(d.palette().gem),290);g.fx.floating(point-Vector2(0,34),label,Color(d.palette().text),20);g.cue("jam");d.banner("STALLED","停摆","时核暴露 · 伤害 ×3","weak")

func drain(amount:float,point:Vector2,label:String) -> void:
	if exposed() or g.time<refill_until:return
	d.fight.data.spring=maxf(0,d.fight.data.spring-amount)
	if d.fight.data.spring<=0:jam(point,label,g.active_arrow)
	g.revision+=1

func lit(brick:RefCounted) -> bool:return brick.type=="hour" and brick.flags.get("hourIndex",-1)==hour_index

func before_hit(brick:RefCounted,depth:int) -> bool:
	if brick.flags.get("ward",false) and depth<70:
		brick.flags.ward=false;brick.flash=0.2;g.fx.ring(brick.position,Color(d.palette().ward),50);g.cue("chime");return false
	if lit(brick) and depth==0 and g.active_arrow!=null:
		if move.get("id","")=="haste":jam(brick.position,"卡齿",g.active_arrow)
		else:drain(16,brick.position,"正点")
	return true

func destroyed(brick:RefCounted,depth:int) -> void:
	if depth<3:
		history.append(brick.serialize())
		if history.size()>12:history.pop_front()
	if brick.type=="hour":
		d.hurt(g.damage()*0.5,brick.position)
		if lit(brick) and depth==0:drain(24,brick.position,"正点")
		g.cue("bell",1,brick.x)
	else:d.hurt(g.damage()*0.04,brick.position)

func begin(id:String) -> void:
	last_move=id
	move={"id":id,"start":g.time,"live":g.time+1,"end":g.time+{"stop":2.6,"toll":4.5,"pendulum":8.0,"rewind":3.0,"haste":5.0,"midnight":6.4}[id],"hits":0,"rung":0,"next":g.time+1.4,"target":center+Vector2(0,200)}
	if id=="stop":
		var spots:Array=g.shuffle([3.5,4.5,5.5,6.5,7.5,8.5])
		for index in spots:
			var point:Vector2=center+Vector2.from_angle(-PI/2+index*PI/6)*220
			if not d.occupied(point,50,30):move.target=point;break
	if id=="rewind":move.ghosts=history.duplicate(true);history.clear()
	var call:Array=CALL[id];d.banner(call[0],call[1],call[2],"weak" if id=="midnight" else "minor");g.cue("bell" if id in ["toll","midnight"] else "tick")

func bell_point() -> Vector2:return Vector2(390+sin((g.time-move.start)*(1.7 if d.rage else 1.3))*250,800)
func bob_point() -> Vector2:
	var k:=clampf((g.time-move.start)/(move.live-move.start),0,1)
	var angle:float=0 if g.time<move.live else sin((g.time-move.live)*(1.6 if d.rage else 1.25))*0.55
	return center+Vector2(sin(angle),cos(angle))*360*k

func contact(arrow:RefCounted,live:bool) -> void:
	var hit:Dictionary=d.bounce_circle(arrow,center,27 if exposed() else 35)
	if not hit.is_empty():
		if not live:return
		if exposed():d.strike(arrow,hit.point,3);return
		if g.time<arrow.flags.get("caseAt",-1):return
		arrow.flags.caseAt=g.time+0.15
		if move.get("id")=="rewind":jam(hit.point,"打断",arrow)
		elif move.get("id")=="midnight" and g.time>=move.live:
			move.hits+=1
			if move.hits>=3:jam(hit.point,"停摆",arrow,5.5)
		return
	if not exposed():
		for pair in [[minute,235],[hour,155]]:
			if d.bounce_bar(arrow,center+Vector2.from_angle(pair[0])*36,center+Vector2.from_angle(pair[0])*pair[1],7):return
	for gear in gears:
		var contact_value:Dictionary=d.bounce_circle(arrow,gear.position,37)
		if contact_value.is_empty():continue
		if live and not gear.jammed and absf(wrapf(contact_value.normal.angle()-gear.angle,-PI,PI))<0.6:
			gear.jammed=true;drain(100 if gears.all(func(v):return v.jammed) else 30,gear.position,"卡死")
		return
	if move.is_empty():return
	var id:String=move.id
	if id not in ["stop","toll","pendulum"]:return
	var point:Vector2=move.target if id=="stop" else bell_point() if id=="toll" else bob_point()
	if d.bounce_circle(arrow,point,21 if id=="stop" else 29 if id=="toll" else 33).is_empty() or not live:return
	if id=="pendulum":
		if g.time<arrow.flags.get("bobAt",-1):return
		arrow.flags.bobAt=g.time+0.2;move.hits+=1
		if move.hits<(4 if d.rage else 3):return
	if id=="toll":
		for brick in g.bricks:brick.flags.ward=false
	jam(point,{"stop":"停摆","toll":"碎音","pendulum":"断摆"}[id],arrow)

func update(delta:float) -> void:
	if not frozen.is_empty():
		if g.time>=frozen_until:
			for arrow in frozen:arrow.velocity=-arrow.velocity*0.8;g.arrows.append(arrow)
			frozen.clear();g.phase="flying";g.cue("chime")
		return
	if exposed():minute=lerp_angle(minute,PI/2+0.15,minf(1,delta*3));hour=lerp_angle(hour,PI/2-0.15,minf(1,delta*3))
	else:
		var factor:float=-2.5 if move.get("id")=="rewind" else 3.0 if move.get("id")=="haste" and g.time>=move.live else 1.0
		var amount:float=delta*0.9*wound*factor*(1.4 if d.rage else 1)
		if move.get("id")=="midnight":minute=lerp_angle(minute,-PI/2,minf(1,delta*4));hour_index=0
		else:
			minute+=amount;turn+=amount
			while turn>=TAU:turn-=TAU;hour_index=posmod(hour_index+1,12);g.cue("tick")
			while turn<0:turn+=TAU;hour_index=posmod(hour_index-1,12);g.cue("tick")
		hour=lerp_angle(hour,-PI/2+hour_index*PI/6,minf(1,delta*14))
	for gear in gears:
		if not exposed() and not gear.jammed:gear.angle+=delta*1.2*gear.direction
	if not wave.is_empty():
		var previous:float=wave.radius;wave.radius+=delta*650
		for brick in g.bricks:
			var distance:float=brick.position.distance_to(center)
			if wave.warded<wave.cap and distance>=previous and distance<wave.radius:brick.flags.ward=true;wave.warded+=1
		if wave.radius>760:wave={}
	if d.busy:return
	if not exposed():
		if g.time<refill_until:d.fight.data.spring=100*(1-(refill_until-g.time)/1.2)
		else:
			if d.fight.data.spring<1:
				for gear in gears:gear.jammed=false
				d.fight.data.spring=100.0
			d.fight.data.spring=minf(100,d.fight.data.spring+delta*3*(1.3 if d.rage else 1))
	if ready_move():begin(pick())
	if move.is_empty():return
	if move.id in ["toll","midnight"] and g.time>=move.next:
		move.next=g.time+(0.4 if move.id=="midnight" else 1.2);move.rung+=1;g.cue("bell");g.fx.ring(center,Color(d.palette().ward),60+move.rung*30)
	if g.time<move.end and not (move.id=="toll" and move.rung>=3) and not (move.id=="midnight" and move.rung>=12):return
	match move.id:
		"stop":
			frozen=g.arrows.duplicate();g.arrows.clear();frozen_until=g.time+(2.4 if d.rage else 2);d.fight.data.spring=minf(100,d.fight.data.spring+30);g.cue("timestop")
		"toll":wave={"radius":24.0,"cap":14 if d.rage else 10,"warded":0}
		"rewind":
			for saved in move.ghosts:
				var data:Dictionary=saved.duplicate(true)
				d.later(0.1,func():
					if not d.occupied(Vector2(data.x,data.y)) and g.bricks.size()<230:data.hp=data.max;g.make_brick(data);g.initial+=1
				)
			d.fight.data.spring=100.0
		"midnight":
			for index in range(12):regrow_hour(index)
			d.fight.data.spring=100.0;wound=minf(1.9,wound+0.3)
		"haste":
			for index in g.shuffle(range(12)).slice(0,3):regrow_hour(index)
		"pendulum":wound=minf(1.9,wound+0.3);d.fight.data.spring=minf(100,d.fight.data.spring+40)
	finish_move()

func music_mood() -> String:
	if exposed():return "stun"
	if g.time<refill_until:return "wind"
	if not frozen.is_empty():return "frozen"
	if move.get("id") in ["rewind","midnight"]:return move.id
	if move.get("id")=="haste" and g.time>=move.live:return "haste"
	return "wind" if not move.is_empty() else "fight"
