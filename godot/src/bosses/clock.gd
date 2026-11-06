extends "res://src/bosses/base.gd"
## 时之君主: a cleared enamel dial ringed by twelve numeral plaques. The hour
## hand points at the lit plaque; striking it drains the mainspring until the
## movement stalls and the crystal core opens for triple damage.
const CALL={"stop":["TIME STOP","时停","击碎发条钥"],"toll":["TOLL","鸣钟","钟响前击中巨钟"],"pendulum":["PENDULUM","钟摆","连击摆锤 · 摆杆会挡箭"],"rewind":["REWIND","倒流","射中晶壳打断"],"haste":["HASTE","疾走","射中亮起的刻度"],"midnight":["MIDNIGHT","午夜","十二响内三击晶壳"]}
const CENTER:=Vector2(390,470)
const PLAQUE_RADIUS:=250.0
const FACE:=Vector2(330,318)
const CORE_RADIUS:=35.0
const OPEN_RADIUS:=27.0
const INTRO_SECONDS:=3.2
const SHIFT_SECONDS:=2.6
const SHIFT_DELAY:=1.1
const GEARS:=[Vector2(250,566),Vector2(530,570),Vector2(452,394)]
var minute:=-PI/2
var hour:=-PI/2+PI/3
var hour_index:=2
var turn:=0.0
var wound:=1.0
var spin:=0.0
var gears:Array=[]
var history:Array=[]
var frozen:Array=[]
var frozen_until:=0.0
var wave:Dictionary={}
var center:=CENTER
var jammed_at:=-100.0
var jam_point:=CENTER
var struck_at:=-100.0
var pinged_at:=-100.0
var unlit_since:=-1.0

func setup(restored:bool) -> void:
	super.setup(restored);minute=-PI/2;hour_index=2;hour=-PI/2+PI/3;turn=0;wound=1;gears.clear();history.clear();frozen.clear();wave.clear()
	jammed_at=-100;struck_at=-100;unlit_since=-1
	if not restored:
		d.fight.data.spring=100.0
		# Open the dial: only the corners clear of the bezel keep masonry, so the
		# hands, plaques and the core are readable and reachable.
		for brick in g.bricks.duplicate():
			if on_face(brick.position,Vector2(brick.w,brick.h)):g.bricks.erase(brick)
		for wall in g.obstacles.duplicate():
			if on_face(wall.position,Vector2(wall.w,wall.h)):g.obstacles.erase(wall)
		for index in range(12):regrow_hour(index,true)
	for brick in g.bricks:
		if brick.type=="hour" and not brick.flags.has("hourIndex"):
			brick.flags.hourIndex=posmod(roundi((atan2((brick.y-470)/0.95,brick.x-390)+PI/2)/(PI/6)),12)
	if d.fight.phase>=2:
		for index in range(GEARS.size()):
			var point:Vector2=GEARS[index]
			gears.append({"position":point,"angle":index*2.1,"direction":-1 if index==1 else 1,"jammed":false})
			for brick in g.bricks.duplicate():
				if brick.type!="hour" and absf(brick.x-point.x)<78 and absf(brick.y-point.y)<54:g.bricks.erase(brick)

## True when any part of a size-wide rect centred at point lies inside the bezel.
func on_face(point:Vector2,size:Vector2=Vector2.ZERO) -> bool:
	var nearest:=CENTER.clamp(point-size/2,point+size/2)
	var local:Vector2=(nearest-CENTER)/FACE
	return local.length_squared()<1.0

func hour_point(index:int) -> Vector2:
	var angle:float=-PI/2+index*PI/6
	return center+Vector2(cos(angle),sin(angle)*0.95)*PLAQUE_RADIUS

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
	if not initial:g.initial+=1;g.cue("chime",1,point.x);g.fx.burst(point,Color(d.palette().brass),10)

func status() -> Dictionary:
	if exposed():return {"text":"停摆 %.1fs · 伤害 ×3" % maxf(0,stunned_until-g.time),"state":"exposed"}
	return {"text":"发条回紧" if g.time<refill_until else "发条 %d%%" % roundi(d.fight.data.spring),"state":"shielded"}

func focus() -> Vector2:return CENTER
func intro_seconds() -> float:return INTRO_SECONDS
func shift_seconds() -> float:return SHIFT_SECONDS
func shift_delay() -> float:return SHIFT_DELAY

func jam(point:Vector2,label:String,arrow:RefCounted=null,duration:float=4) -> void:
	move={};d.fight.data.spring=0.0;stunned_until=g.time+duration;refill_until=stunned_until+1.2;next_at=refill_until+2
	jammed_at=g.time;jam_point=point;frozen_release()
	if arrow!=null:d.pay(arrow,point,2)
	impact(center,Color(d.palette().gem),290);g.fx.burst(center,Color(d.palette().brass),30,3)
	g.fx.floating(point-Vector2(0,34),label,Color(d.palette().text),20);g.cue("jam");d.banner("STALLED","停摆","时核开启 · 伤害 ×3","weak")

func frozen_release() -> void:
	if frozen.is_empty():return
	for arrow in frozen:g.arrows.append(arrow)
	frozen.clear();g.phase="flying"

func drain(amount:float,point:Vector2,label:String) -> void:
	if exposed() or g.time<refill_until:return
	d.fight.data.spring=maxf(0,d.fight.data.spring-amount)
	g.fx.floating(point-Vector2(0,26),"-%d" % roundi(amount),Color(d.palette().gem),14)
	if d.fight.data.spring<=0:jam(point,label,g.active_arrow)
	g.revision+=1

func lit(brick:RefCounted) -> bool:return brick.type=="hour" and brick.flags.get("hourIndex",-1)==hour_index
func lit_plaque() -> RefCounted:
	for brick in g.bricks:
		if lit(brick):return brick
	return null

func before_hit(brick:RefCounted,depth:int) -> bool:
	if brick.flags.get("ward",false) and depth<70:
		brick.flags.ward=false;brick.flash=0.2;g.fx.ring(brick.position,Color(d.palette().ward),50);g.cue("chime");return false
	if lit(brick) and depth==0 and g.active_arrow!=null:
		if move.get("id","")=="haste":jam(brick.position,"卡齿",g.active_arrow)
		else:drain(20,brick.position,"正点")
	return true

func destroyed(brick:RefCounted,depth:int) -> void:
	if depth<3 and brick.type!="hour":
		history.append(brick.serialize())
		if history.size()>12:history.pop_front()
	if brick.type=="hour":
		d.hurt(g.damage()*0.5,brick.position)
		if lit(brick) and depth==0:drain(30,brick.position,"正点")
		g.cue("bell",1,brick.x);g.fx.burst(brick.position,Color(d.palette().brass),14,1.5)
	else:d.hurt(g.damage()*0.04,brick.position)

func intro() -> void:
	super.intro();next_at=g.time+INTRO_SECONDS+2.5
	# The numerals light in sequence while the dial assembles.
	for index in range(12):d.later(0.7+index*0.11,func():g.cue("tick",1,hour_point(index).x))
	d.later(2.25,func():g.cue("chime",1,390,true))

func begin(id:String) -> void:
	last_move=id
	move={"id":id,"start":g.time,"live":g.time+1,"end":g.time+{"stop":2.6,"toll":4.5,"pendulum":8.0,"rewind":3.0,"haste":5.0,"midnight":6.4}[id],"hits":0,"rung":0,"next":g.time+1.4,"target":center+Vector2(0,200)}
	if id=="stop":
		var spots:Array=g.shuffle([3.5,4.5,5.5,6.5,7.5,8.5])
		for index in spots:
			var point:Vector2=center+Vector2.from_angle(-PI/2+index*PI/6)*200
			if not d.occupied(point,50,30):move.target=point;break
	if id=="rewind":move.ghosts=history.duplicate(true);history.clear()
	var call:Array=CALL[id];d.banner(call[0],call[1],call[2],"weak" if id=="midnight" else "minor");g.cue("bell" if id in ["toll","midnight"] else "tick")

func bell_point() -> Vector2:return Vector2(390+sin((g.time-move.start)*(1.7 if d.rage else 1.3))*250,800)
func bob_angle() -> float:return 0.0 if g.time<move.live else sin((g.time-move.live)*(1.6 if d.rage else 1.25))*0.55
func bob_point() -> Vector2:
	var k:=clampf((g.time-move.start)/(move.live-move.start),0,1)
	var angle:=bob_angle()
	return center+Vector2(sin(angle),cos(angle))*360*k
func shift_progress() -> float:
	var span:float=SHIFT_SECONDS
	return clampf(1-(d.shift_until-g.time)/span,0,1) if g.time<d.shift_until else 0.0

func contact(arrow:RefCounted,live:bool) -> void:
	var hit:Dictionary=d.bounce_circle(arrow,center,OPEN_RADIUS if exposed() else CORE_RADIUS)
	if not hit.is_empty():
		if not live:return
		if exposed():
			if d.strike(arrow,hit.point,3):struck_at=g.time
			return
		if g.time<arrow.flags.get("caseAt",-1):return
		arrow.flags.caseAt=g.time+0.15
		if move.get("id")=="rewind":jam(hit.point,"打断",arrow)
		elif move.get("id")=="midnight" and g.time>=move.live:
			move.hits+=1;g.fx.ring(center,Color(d.palette().weak),70+move.hits*18);g.cue("chime",1,hit.point.x)
			if move.hits>=3:jam(hit.point,"停摆",arrow,5.5)
		elif g.time-pinged_at>0.25:
			pinged_at=g.time;g.fx.ring(hit.point,Color(d.palette().rim),34);g.cue("tick",1,hit.point.x)
		return
	if not exposed():
		for pair in [[minute,235],[hour,155]]:
			if d.bounce_bar(arrow,center+Vector2.from_angle(pair[0])*36,center+Vector2.from_angle(pair[0])*pair[1],7):return
	for gear in gears:
		var contact_value:Dictionary=d.bounce_circle(arrow,gear.position,37)
		if contact_value.is_empty():continue
		if live and not gear.jammed and absf(wrapf(contact_value.normal.angle()-gear.angle,-PI,PI))<0.6:
			gear.jammed=true;g.fx.burst(gear.position,Color(d.palette().gem),12,1.5);g.cue("clang",1,gear.position.x)
			drain(100 if gears.all(func(v):return v.jammed) else 30,gear.position,"卡死")
		return
	if move.is_empty():return
	var id:String=move.id
	if id not in ["stop","toll","pendulum"]:return
	var point:Vector2=move.target if id=="stop" else bell_point() if id=="toll" else bob_point()
	if id=="pendulum" and g.time>=move.live:
		# The rod is a live, swinging bar: it deflects shots that miss the bob.
		var top:Vector2=center+(point-center).normalized()*48
		if d.bounce_bar(arrow,top,point-(point-center).normalized()*34,5):return
	if d.bounce_circle(arrow,point,21 if id=="stop" else 29 if id=="toll" else 33).is_empty() or not live:return
	if id=="pendulum":
		if g.time<arrow.flags.get("bobAt",-1):return
		arrow.flags.bobAt=g.time+0.2;move.hits+=1;g.fx.burst(point,Color(d.palette().brass),10,1.2);g.cue("clang",1,point.x)
		if move.hits<(4 if d.rage else 3):return
	if id=="toll":
		for brick in g.bricks:brick.flags.ward=false
	jam(point,{"stop":"停摆","toll":"碎音","pendulum":"断摆"}[id],arrow)

func update(delta:float) -> void:
	var shifting:bool=g.time<d.shift_until
	spin+=delta*(0.25 if exposed() else 4.0 if shifting else 3.0 if move.get("id")=="haste" else -2.5 if move.get("id")=="rewind" else 1.0)
	if not frozen.is_empty():
		if g.time>=frozen_until:
			for arrow in frozen:arrow.velocity=-arrow.velocity*0.8;g.arrows.append(arrow)
			frozen.clear();g.phase="flying";g.cue("chime")
		return
	if shifting:
		# The hands whirl forward while the new board assembles.
		minute+=delta*TAU*1.6;hour+=delta*TAU*0.3
	elif exposed():
		# Stall: hands fall open into a V above the core, clear of the launch lane.
		minute=lerp_angle(minute,-PI/2-0.62,minf(1,delta*5));hour=lerp_angle(hour,-PI/2+0.62,minf(1,delta*5))
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
	# A destroyed lit numeral reforms, so there is always an on-the-hour target.
	if lit_plaque()==null and move.get("id")!="midnight":
		if unlit_since<0:unlit_since=g.time
		elif g.time-unlit_since>=1.6:regrow_hour(hour_index);unlit_since=-1
	else:unlit_since=-1
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

func explode() -> bool:
	var ink:Color=Color(d.palette().brass)
	g.fx.ring(CENTER,Color(d.palette().gem),520);g.fx.ring(CENTER,ink,760)
	g.fx.burst(CENTER,ink,70,4);g.fx.burst(CENTER,Color(d.palette().gem),40,3)
	for index in range(12):g.fx.burst(hour_point(index),ink,6,2)
	# The numerals shatter with the dial instead of floating over an empty board.
	for brick in g.bricks.duplicate():
		if brick.type=="hour":g.hit(brick,1e12,99)
	g.fx.flash=0.9;g.fx.shake=14;g.cue("shatter");g.cue("bell",1,390,true)
	return true
