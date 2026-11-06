extends "res://src/bosses/base.gd"
## 星渊巨蟒: a star-scaled serpent circling a fixed river around the brick
## island. Its plated body deflects arrows; glowing 逆鳞 (weak scales) drain the
## armour, and an empty armour or a countered move drops the head to the floor
## for triple damage. Every move telegraphs and has one readable counter.
const CENTER:=Vector2(390,500)
const RADII:=Vector2(300,330)
const POWER:=3.2
const SAMPLES:=480
const SPACING:=22.0
const HEAD_RADIUS:=27.0
const NECK_RADIUS:=23.0
const TAIL_RADIUS:=8.0
const BAND:=46.0
const INTRO_SECONDS:=3.4
const SHIFT_SECONDS:=2.8
const SHIFT_DELAY:=1.0
const BREAK_SECONDS:=4.0
const REFILL_SECONDS:=1.2
const LENGTHS:=[40,46,52,58]
const SCALES:=[3,3,4,4]
const CALL={"coil":["COIL","盘击","蓄力时击中蛇首"],"dive":["DIVE","潜渊","射中出口星门"],"devour":["DEVOUR","吞星","向巨口连射"],"eclipse":["ECLIPSE","星蚀","黑暗中命中蛇首两次"],"comet":["COMET","坠星","击碎坠星引燃蛇首"],"twin":["TWIN","双生","斩断星丝或同时命中双首"]}
const Track=preload("res://src/bosses/serpent_track.gd")
var snakes:Array=[]
var ghosts:Array=[]
var sparks:Array=[]
var regrow_queue:Array=[]
var swallowed:Array=[]
var broke_at:=-100.0
var break_point:=Vector2.ZERO
var struck_at:=-100.0
var pinged_at:=-100.0
var clinked_at:=-100.0
var next_comet:=0.0
var emerged_at:=-100.0
var roar_at:=-100.0

# --- Track ------------------------------------------------------------------

static func build_track() -> Dictionary:
	if not Track.cache.is_empty():return Track.cache
	var track:=PackedVector2Array();var normals:=PackedVector2Array()
	var dense:=PackedVector2Array()
	for index in range(2400):
		var angle:float=TAU*index/2400.0
		var c:=cos(angle);var s:=sin(angle)
		dense.append(CENTER+Vector2(signf(c)*pow(absf(c),2.0/POWER)*RADII.x,signf(s)*pow(absf(s),2.0/POWER)*RADII.y))
	var lengths:=PackedFloat32Array([0.0])
	for index in range(1,dense.size()+1):lengths.append(lengths[index-1]+dense[index-1].distance_to(dense[index%dense.size()]))
	var total:float=lengths[lengths.size()-1]
	var cursor:=0
	for index in range(SAMPLES):
		var want:float=total*index/SAMPLES
		while lengths[cursor+1]<want:cursor+=1
		var k:float=(want-lengths[cursor])/maxf(0.001,lengths[cursor+1]-lengths[cursor])
		track.append(dense[cursor].lerp(dense[(cursor+1)%dense.size()],k))
	var low:=0;var high:=0
	for index in range(SAMPLES):
		var tangent:Vector2=(track[(index+1)%SAMPLES]-track[(index-1+SAMPLES)%SAMPLES]).normalized()
		# Clockwise travel on screen: the outward normal is the tangent turned left.
		normals.append(Vector2(tangent.y,-tangent.x))
		if track[index].y>track[low].y or (track[index].y==track[low].y and absf(track[index].x-390)<absf(track[low].x-390)):low=index
		if track[index].y<track[high].y:high=index
	Track.cache={"track":track,"normals":normals,"length":total,"bottom":total*low/SAMPLES,"top":total*high/SAMPLES}
	return Track.cache

static func track_length() -> float:return build_track().length
static func top_s() -> float:return build_track().top
static func bottom_s() -> float:return build_track().bottom

static func at(s:float) -> Vector2:
	var data:=build_track();var track:PackedVector2Array=data.track
	var f:float=fposmod(s,data.length)/data.length*SAMPLES
	var index:=int(f)
	return track[index%SAMPLES].lerp(track[(index+1)%SAMPLES],f-index)

static func normal_at(s:float) -> Vector2:
	var data:=build_track();var normals:PackedVector2Array=data.normals
	var f:float=fposmod(s,data.length)/data.length*SAMPLES
	var index:=int(f)
	return normals[index%SAMPLES].lerp(normals[(index+1)%SAMPLES],f-index).normalized()

## Approximate signed distance from the river centre line (negative = island).
static func band_distance(point:Vector2) -> float:
	var v:=point-CENTER
	var f:=pow(absf(v.x)/RADII.x,POWER)+pow(absf(v.y)/RADII.y,POWER)
	if f<=0.000001:return -RADII.x
	var r:=pow(f,1.0/POWER)
	return v.length()*(1-1/r)

static func in_island(point:Vector2,size:Vector2) -> bool:
	for corner in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(-0.5,0.5),Vector2(0.5,0.5)]:
		if band_distance(point+size*corner)>-BAND:return false
	return true

static func radius_at(k:int,count:int) -> float:
	return lerpf(NECK_RADIUS,TAIL_RADIUS,pow(clampf(float(k)/maxf(1,count-1),0,1),1.35))

## Body radius at local segment k (fractional for the renderer's subdivisions).
static func segment_radius(snake:Dictionary,k:float) -> float:
	var r:float=lerpf(NECK_RADIUS,TAIL_RADIUS,pow(clampf(k/maxf(1,snake.total-1),0,1),1.35))
	return r*(0.82 if snake.step<0 else 1.0)

# --- Setup ------------------------------------------------------------------

func length() -> int:return LENGTHS[clampi(d.fight.phase-1,0,3)]

func make_snake(head:float,direction:float=1.0) -> Dictionary:
	return {"s":head,"dir":direction,"count":length(),"total":length(),"first":0,"step":1,"grow_at":-1.0,"lane":0.0,"lane_to":0.0,"gate":{},"slide":{},"reach":Vector2.ZERO,"sway":0.0,"flash":0.0,"fade":1.0,"speed":1.0,"hit_at":-100.0,"points":PackedVector2Array(),"hidden":PackedByteArray(),"chunks":[],"scaled":{},"ghost":false}

func setup(restored:bool) -> void:
	build_track()
	var shifting:bool=not restored and not snakes.is_empty() and d.fight.intro
	ghosts.clear()
	if shifting:
		# The old serpent dives into a gate ahead of its head while the new one
		# pours from a second gate once the board has reassembled.
		for snake in snakes:
			if snake.points.is_empty() or snake.ghost:continue
			fold(snake);snake.ghost=true;snake.slide={};snake.reach=Vector2.ZERO;snake.speed=6.0
			snake.gate={"a":snake.s+40,"u":1e9,"j":0.0,"born":g.time,"entry":true,"exit":false,"kind":"ghost"}
			ghosts.append(snake)
	snakes.clear()
	super.setup(restored)
	sparks.clear();regrow_queue.clear();swallowed.clear()
	broke_at=-100;struck_at=-100;emerged_at=-100;roar_at=-100;next_comet=g.time+3
	for brick in g.bricks.duplicate():
		if brick.type=="scale" or not in_island(brick.position,Vector2(brick.w,brick.h)):g.bricks.erase(brick)
	for wall in g.obstacles.duplicate():
		if not in_island(wall.position,Vector2(wall.w,wall.h)):g.obstacles.erase(wall)
	var data:Dictionary=d.fight.data
	data.erase("snakes")
	if not restored or int(data.get("serpentVersion",0))!=2:data.armor=100.0;data.scales=[]
	data.serpentVersion=2
	var snake:=make_snake(top_s()+g.rng.randf_range(-300,300))
	snakes.append(snake)
	if shifting:
		var exit:float=fposmod(snake.s+track_length()*0.5,track_length())
		hide_until(snake,exit,SHIFT_DELAY+0.15,"shift");next_at=g.time+SHIFT_SECONDS+1.6
	elif not d.fight.intro:hide_until(snake,top_s(),1e6,"intro")
	if data.scales.is_empty():
		var count:int=SCALES[clampi(d.fight.phase-1,0,3)]
		for index in range(count):data.scales.append({"segment":3+roundi((index+0.5)*(snake.count-8)/count),"hp":scale_hp()})
	for saved in data.scales:make_scale(clampi(int(saved.segment),1,snake.count-2),float(saved.hp))
	locate(0)

## Hides the whole body behind an exit gate at track position exit; the head
## appears there after delay seconds of travel at the current speed.
func hide_until(snake:Dictionary,exit:float,delay:float,kind:String) -> void:
	var lead:float=delay*base_speed()*pour(kind)
	snake.s=0.0
	snake.gate={"a":-1e5,"u":1e5+lead,"j":exit+1e5,"born":g.time,"entry":false,"exit":true,"kind":kind}
	snake.speed=pour(kind)

func pour(kind:String) -> float:return 4.6 if kind in ["intro","shift"] else 1.0
func base_speed() -> float:return 150.0 if d.rage else 120.0
func scale_hp() -> float:return maxf(g.base_hp(),ceil(g.damage()*(1.6+0.4*d.fight.phase)))

func make_scale(segment:int,hp:float) -> RefCounted:
	var brick:RefCounted=g.make_brick({"x":-500,"y":-500,"w":30,"h":30,"hp":hp,"max":maxf(hp,scale_hp()),"type":"scale"})
	brick.flags.orbit=true;brick.flags.segment=segment
	return brick

func scales() -> Array:return g.bricks.filter(func(b):return b.type=="scale")

# --- Body -------------------------------------------------------------------

## Maps a virtual track coordinate through the snake's gate; NAN = underground.
func display(snake:Dictionary,v:float) -> float:
	var gate:Dictionary=snake.gate
	if gate.is_empty() or v<gate.a:return v
	if v<gate.a+gate.u:return NAN
	return v+gate.j-gate.u

func head_hidden(snake:Dictionary) -> bool:return is_nan(display(snake,snake.s))
func tail_v(snake:Dictionary) -> float:return snake.s-(snake.count-1)*SPACING

## Collapses a finished gate: the virtual coordinate jumps by the gate span.
func fold(snake:Dictionary) -> void:
	if snake.gate.is_empty():return
	var gate:Dictionary=snake.gate
	# Anything still underground pops out with the head at the exit.
	snake.s=maxf(snake.s,gate.a+gate.u)+gate.j-gate.u
	snake.gate={}

## World position of local segment k (0 = head) or NAN when hidden.
func segment_point(snake:Dictionary,k:int) -> Vector2:
	var v:float=display(snake,snake.s-k*SPACING)
	if is_nan(v):return Vector2(NAN,NAN)
	var s:float=v*snake.dir
	var wiggle:float=sin(s*0.021)*9.0+snake.lane
	var point:=at(s)+normal_at(s)*wiggle
	var weight:float=pow(maxf(0,1-k/8.0),2)
	if weight>0:point+=snake.reach*weight+normal_at(s)*snake.sway*weight
	return point

func locate(_delta:float) -> void:
	for snake in snakes+ghosts:
		var points:=PackedVector2Array();var hidden:=PackedByteArray()
		points.resize(snake.count);hidden.resize(snake.count)
		for k in range(snake.count):
			var point:=segment_point(snake,k)
			hidden[k]=1 if is_nan(point.x) else 0
			points[k]=Vector2(-500,-500) if hidden[k]==1 else point
		snake.points=points;snake.hidden=hidden
		# Broad phase: bounding circles over runs of eight bars.
		var chunks:Array=[]
		for start in range(0,snake.count-1,8):
			var finish:int=mini(start+8,snake.count-1)
			var middle:Vector2=points[(start+finish)/2]
			var reach:=0.0
			for k in range(start,finish+1):reach=maxf(reach,middle.distance_to(points[k]))
			chunks.append({"start":start,"end":finish,"center":middle,"radius":reach+NECK_RADIUS+4})
		snake.chunks=chunks
		snake.scaled={}
	for brick in scales():
		var owner_snake:Variant=null;var k:=0
		for snake in snakes:
			k=(int(brick.flags.segment)-snake.first)*snake.step
			if k>=0 and k<snake.count:owner_snake=snake;break
		if owner_snake==null or owner_snake.hidden[k]==1:brick.position=Vector2(-500,-500);continue
		brick.position=owner_snake.points[k];owner_snake.scaled[k]=true

func knot() -> Vector2:
	if snakes.size()<2 or head_hidden(snakes[0]) or head_hidden(snakes[1]):return Vector2(NAN,NAN)
	return snakes[0].points[0].lerp(snakes[1].points[0],0.5)+Vector2(0,sin(g.time*3)*14)

func head_radius(snake:Dictionary) -> float:return HEAD_RADIUS*(1.25 if exposed() else 1.0)*(0.82 if snake.step<0 else 1.0)
func focus() -> Vector2:
	if snakes.is_empty() or snakes[0].points.is_empty() or snakes[0].hidden[0]==1:return CENTER
	return snakes[0].points[0]
func intro_seconds() -> float:return INTRO_SECONDS
func shift_seconds() -> float:return SHIFT_SECONDS
func shift_delay() -> float:return SHIFT_DELAY

# --- Motion -----------------------------------------------------------------

func update(delta:float) -> void:
	for snake in snakes+ghosts:
		snake.flash=maxf(0,snake.flash-delta*3)
		snake.lane=move_toward(snake.lane,snake.lane_to,delta*40)
		advance(snake,delta)
	ghosts=ghosts.filter(func(s):return g.time-s.gate.born<2.2 and tail_v(s)<s.gate.a)
	if move.get("stage","")!="":step_move()
	pose_heads(delta)
	locate(delta)
	step_sparks(delta)
	if d.busy:return
	step_armor(delta)
	step_regrow()
	if d.has("comet") and g.time>=next_comet and not exposed():next_comet=g.time+(2.6 if d.rage else 3.6);drop_star()
	if ready_move():begin(pick())

func advance(snake:Dictionary,delta:float) -> void:
	if not snake.slide.is_empty():
		var k:float=clampf((g.time-snake.slide.start)/0.65,0,1)
		snake.s=snake.slide.from+snake.slide.by*(1-pow(1-k,3))
		if k>=1:snake.slide={}
		return
	if exposed() and not snake.ghost:return
	var gate:Dictionary=snake.gate
	var poured:bool=gate.get("kind","") in ["intro","shift"]
	if snake.ghost:pass
	elif not poured:snake.speed=move_toward(snake.speed,speed_factor(),delta*3)
	elif gate.is_empty() or snake.s>=gate.a+gate.u:snake.speed=move_toward(snake.speed,1.0,delta*1.5)
	var before:float=snake.s
	snake.s+=base_speed()*snake.speed*delta
	if not gate.is_empty():
		var exit:float=gate.a+gate.u
		if before<exit and snake.s>=exit and gate.kind!="ghost":emerge(snake,false)
		if gate.kind!="ghost" and tail_v(snake)>=exit:
			fold(snake)
			if move.get("stage","")=="under":finish_move()

func speed_factor() -> float:
	match move.get("stage",""):
		"wait":return 1.8
		"aim","lunge","maw","rend":return 0.0
		"dark":return 0.7
		"under":return 1.4
	if g.time<refill_until:return 0.0
	return 1.0

func pose_heads(delta:float) -> void:
	for snake in snakes:
		var reach:=Vector2.ZERO;var sway:=0.0
		var head:Vector2=at(display(snake,snake.s)*snake.dir) if not head_hidden(snake) else CENTER
		var stage:String=move.get("stage","")
		if exposed():
			var age:float=g.time-broke_at
			sway=sin(age*5.2)*16*clampf(age/0.6,0,1)*clampf((stunned_until-g.time)/0.5,0,1)
		elif stage=="aim":
			var back:Vector2=(head-g.origin).normalized()
			reach=back*36*clampf((g.time-move.at)/0.4,0,1)+Vector2(sin(g.time*40),cos(g.time*37))*2.5
		elif stage=="lunge":
			var k:float=clampf((g.time-move.at)/0.24,0,1)
			var target:Vector2=move.target-head
			target=target.limit_length(260)
			reach=target*(k*k) if g.time<move.impact else target*(1-smoothstep(0,0.55,g.time-move.impact))
		elif stage=="maw":
			reach=(CENTER+Vector2(0,40)-head).limit_length(150)*smoothstep(0,0.5,g.time-move.at)
		elif d.busy and roar_at>0:
			var age:float=g.time-roar_at
			if age<1.2:reach=(head-CENTER).normalized()*-40*sin(clampf(age/1.2,0,1)*PI)
		snake.reach=snake.reach.lerp(reach,minf(1,delta*(30 if stage=="lunge" else 10)))
		snake.sway=lerpf(snake.sway,sway,minf(1,delta*12))

# --- Moves ------------------------------------------------------------------

func pick() -> String:
	var choices:Array=d.fight.abilities[d.fight.phase-1].duplicate()
	if "twin" in choices and last_move!="twin" and last_move!="":return "twin"
	var others:Array=choices.filter(func(id):return id!=last_move and id!="twin")
	if others.is_empty():others=choices.filter(func(id):return id!="twin")
	if others.is_empty():return choices[0]
	return others[g.rng.randi_range(0,others.size()-1)]

func begin(id:String) -> void:
	settle();last_move=id
	var snake:Dictionary=snakes[0]
	move={"id":id,"stage":"wait","at":g.time,"start":g.time,"hits":0,"hit_at":-100.0,"gulped":0,"impact":INF}
	match id:
		"dive":
			move.stage="under";var entry:float=snake.s+70
			var options:Array=[]
			for index in range(24):
				var s:float=entry+track_length()*(0.3+index*0.02)
				if at(s*snake.dir).y>640:options.append(s)
			var exit:float=options[g.rng.randi_range(0,options.size()-1)] if not options.is_empty() else entry+track_length()*0.5
			var under:float=base_speed()*1.4*(1.8 if d.rage else 2.2)
			snake.gate={"a":entry,"u":under,"j":exit-entry,"born":g.time,"entry":true,"exit":true,"kind":"dive"}
		"comet":
			move.stage="";for index in range(4):d.later(0.25+index*0.3,drop_star)
			var started:float=g.time
			d.later(1.6,func():if move.get("id","")=="comet" and move.start==started:finish_move())
		"twin":move.stage="rend";move.at=g.time
	var call:Array=CALL[id];d.banner(call[0],call[1],call[2],"weak" if id=="twin" else "minor")
	g.cue("hiss" if id in ["dive","eclipse","comet"] else "serpent",1,focus().x)

## Ends any split body or open dive so a new move starts from one serpent.
func settle() -> void:
	if snakes.is_empty():return
	var snake:Dictionary=snakes[0]
	if snakes.size()>1:
		var other:Dictionary=snakes.pop_back()
		if not other.points.is_empty() and other.hidden[0]==0:g.fx.burst(other.points[0],Color(d.palette().twin),16,1.6)
	snake.count=snake.total;snake.lane_to=0.0;snake.grow_at=-1.0
	fold(snake)

func split() -> void:
	var first:Dictionary=snakes[0]
	var keep:int=first.total/2
	var second:Dictionary=make_snake(-(first.s-(first.total-1)*SPACING),-1.0)
	second.count=first.total-keep;second.total=second.count;second.first=first.total-1;second.step=-1
	first.count=keep;first.lane_to=-12.0;second.lane_to=12.0
	snakes.append(second)
	for snake in snakes:snake.flash=1.0
	g.fx.ring(first.points[keep] if keep<first.points.size() else focus(),Color(d.palette().twin),200);g.cue("serpent");g.hitstop(0.08)
	locate(0)

func step_move() -> void:
	var snake:Dictionary=snakes[0]
	var age:float=g.time-move.at
	match move.stage:
		"wait":
			var low:bool=not head_hidden(snake) and not snake.points.is_empty() and snake.points[0].y>600
			if move.id=="eclipse" or low or age>6:
				move.at=g.time
				move.stage={"coil":"aim","devour":"maw","eclipse":"dark"}[move.id]
				if move.id=="coil":move.target=g.origin+Vector2(0,-40);g.cue("hiss",1,snake.points[0].x)
				if move.id=="devour":move.next=g.time+0.7;g.cue("devour",1,snake.points[0].x)
		"aim":
			if age>=(1.1 if d.rage else 1.4):move.stage="lunge";move.at=g.time;move.impact=g.time+0.24
		"lunge":
			if g.time>=move.impact and not move.get("struck",false):
				move.struck=true;g.fx.shake=maxf(g.fx.shake,9);g.cue("serpent",1,390);g.hitstop(0.06)
				g.fx.ring(move.target,Color(d.palette().weak),150);restore(25,move.target,"扑空")
			if age>=0.9:finish_move()
		"maw":
			if g.time>=move.next and not head_hidden(snake):
				move.next=g.time+0.6
				var mouth:Vector2=snake.points[0]
				var picked:Array=g.nearest(mouth,1,func(b):return b.type!="scale" and not b.flags.get("orbit",false) and b.position.distance_to(mouth)<240)
				if not picked.is_empty():
					var brick:RefCounted=picked[0]
					swallowed.append({"from":brick.position,"at":g.time,"color":g.fx.brick_color(brick.type)})
					g.bricks.erase(brick);g.revision+=1;g.cue("gulp",1,mouth.x);restore(6,mouth,"吞")
			if age>=3.6:finish_move()
		"dark":
			if age>=6:restore(25,focus(),"星蚀");relocate();finish_move()
		"rend":
			if age>=1.2:split();move.stage="split";move.at=g.time
		"split":
			var tether:=knot()
			if age>=(9.0 if d.rage else 10.0) or snakes.size()<2:
				move.stage="merge";move.at=g.time
				if snakes.size()>1:snakes[1].lane_to=0.0
				restore(25,tether if not is_nan(tether.x) else focus(),"合体")
		"merge":
			if snakes.size()>1:
				snakes[1].fade=maxf(0,1-age/0.8)
				if snakes[1].fade<=0:
					var other:Dictionary=snakes.pop_back()
					if not other.points.is_empty() and other.hidden[0]==0:g.fx.burst(other.points[0],Color(d.palette().twin),20,2)
					snake.grow_at=g.time
			elif snake.count<snake.total:
				if g.time>=snake.grow_at:snake.grow_at=g.time+0.04;snake.count+=1
			else:snake.lane_to=0.0;finish_move()
	swallowed=swallowed.filter(func(item):return g.time-item.at<0.5)

# --- Armour and breaks ------------------------------------------------------

func step_armor(delta:float) -> void:
	if exposed():return
	if g.time<refill_until:d.fight.data.armor=100*(1-(refill_until-g.time)/REFILL_SECONDS)
	else:
		if d.fight.data.armor<1 and broke_at>0:d.fight.data.armor=100.0
		d.fight.data.armor=minf(100,d.fight.data.armor+delta*(4.0 if d.rage else 3.0))

func restore(amount:float,point:Vector2,label:String) -> void:
	if exposed() or g.time<refill_until:return
	d.fight.data.armor=minf(100,d.fight.data.armor+amount)
	g.fx.floating(point-Vector2(0,40),"%s +%d" % [label,roundi(amount)],Color(d.palette().glow),15);g.revision+=1

func drain(amount:float,point:Vector2,arrow:RefCounted=null) -> void:
	if exposed() or g.time<refill_until or d.busy:return
	d.fight.data.armor=maxf(0,d.fight.data.armor-amount)
	g.fx.floating(point-Vector2(0,24),"-%d" % roundi(amount),Color(d.palette().weak),14)
	if d.fight.data.armor<=0:topple(point,"碎甲",arrow)
	g.revision+=1

## Breaks the serpent: the head slides to the floor of the river, dazed and
## open to triple damage, while the armour re-forms from head to tail.
func topple(point:Vector2,label:String,arrow:RefCounted=null,duration:float=BREAK_SECONDS) -> void:
	settle();move={}
	d.fight.data.armor=0.0;stunned_until=g.time+duration;refill_until=stunned_until+REFILL_SECONDS;next_at=refill_until+1.6
	broke_at=g.time;break_point=point
	for snake in snakes:
		fold(snake)
		var current:float=snake.s
		var delta:float=wrapf(bottom_s()-current,-track_length()/2,track_length()/2)
		snake.slide={"start":g.time,"from":snake.s,"by":delta};snake.flash=1.0;snake.speed=0.0
	if arrow!=null:d.pay(arrow,point,2)
	impact(point,Color(d.palette().glow),240);g.fx.burst(point,Color(d.palette().star),26,2.4)
	g.fx.floating(point-Vector2(0,40),label,Color(d.palette().text),20);g.cue("serpent",1,point.x,true)
	d.banner("BROKEN","倒地","蛇首 · 伤害 ×3","weak")
	g.revision+=1

# --- Contact ----------------------------------------------------------------

func contact(arrow:RefCounted,live:bool) -> void:
	if snakes.is_empty():return
	# A dive exit can be shot before the head arrives: the serpent is yanked out.
	var snake:Dictionary=snakes[0]
	if snake.gate.get("kind","")=="dive" and head_hidden(snake):
		var exit:=at(snake.gate.a+snake.gate.j)
		if not d.bounce_circle(arrow,exit,30).is_empty():
			if live:yank(snake,arrow)
			return
	for each in snakes:
		if each.points.is_empty() or each.hidden[0]==1:continue
		var hit:Dictionary=d.bounce_circle(arrow,each.points[0],head_radius(each))
		if hit.is_empty():continue
		if live:head_hit(each,arrow,hit.point)
		return
	if snakes.size()>1 and live and move.get("stage","")=="split":
		var a:Vector2=snakes[0].points[0];var b:Vector2=snakes[1].points[0]
		if snakes[0].hidden[0]==0 and snakes[1].hidden[0]==0:
			var mid:=knot()
			for pair in [[a,mid],[mid,b]]:
				if Geometry2D.segment_intersects_segment(arrow.position,arrow.position+arrow.velocity,pair[0],pair[1])!=null:
					topple(mid,"斩丝",arrow);return
	if exposed():return
	for each in snakes:
		if body_hit(each,arrow,live):return

func body_hit(snake:Dictionary,arrow:RefCounted,live:bool) -> bool:
	var probe:Vector2=arrow.position+arrow.velocity*0.5
	var span:float=arrow.velocity.length()*0.5+NECK_RADIUS+12
	for chunk in snake.chunks:
		if probe.distance_to(chunk.center)>chunk.radius+span:continue
		for k in range(maxi(1,chunk.start),chunk.end):
			if snake.hidden[k]==1 or snake.hidden[k+1]==1:continue
			if snake.scaled.has(k) or snake.scaled.has(k+1):continue
			var radius:float=segment_radius(snake,k)*0.9+3
			if d.bounce_bar(arrow,snake.points[k],snake.points[k+1],radius):
				if live:clink(arrow.position)
				return true
	return false

func clink(point:Vector2) -> void:
	if g.time-clinked_at<0.12:return
	clinked_at=g.time;g.fx.burst(point,Color(d.palette().star),5,0.9);g.cue("clang",1,point.x)

func head_hit(snake:Dictionary,arrow:RefCounted,point:Vector2) -> void:
	if exposed():
		if d.strike(arrow,point,3):struck_at=g.time;snake.flash=1.0
		return
	if g.time<arrow.flags.get("headAt",-1):return
	arrow.flags.headAt=g.time+0.2;snake.flash=1.0;snake.hit_at=g.time
	match move.get("stage",""):
		"aim":topple(point,"打断",arrow);return
		"maw":
			move.hits+=1;g.fx.ring(point,Color(d.palette().weak),50+move.hits*16);g.cue("gulp",1,point.x)
			if move.hits>=(4 if d.rage else 3):topple(point,"噎住",arrow)
			return
		"dark":
			move.hits+=1;g.fx.ring(point,Color(d.palette().star),90);g.cue("chime",1,point.x)
			if move.hits>=2:topple(point,"破蚀",arrow)
			return
		"split":
			var other:Dictionary=snakes[1 if snake==snakes[0] else 0] if snakes.size()>1 else snake
			g.fx.ring(point,Color(d.palette().twin),60);g.cue("chime",1,point.x)
			if other!=snake and g.time-other.hit_at<0.8:topple(point,"双破",arrow)
			return
	if g.time-pinged_at>0.2:pinged_at=g.time;g.fx.ring(point,Color(d.palette().glow),36);g.cue("tick",1,point.x)

func yank(snake:Dictionary,arrow:RefCounted) -> void:
	var gate:Dictionary=snake.gate
	snake.s=gate.a+gate.u;emerge(snake,true);fold(snake)
	topple(at(snake.s*snake.dir),"拽出",arrow)

func emerge(snake:Dictionary,yanked:bool) -> void:
	var gate:Dictionary=snake.gate
	var point:=at((gate.a+gate.j)*snake.dir)
	emerged_at=g.time
	g.fx.ring(point,Color(d.palette().glow),130);g.fx.burst(point,Color(d.palette().star),18,2);g.cue("hiss",1,point.x)
	if gate.kind=="dive" and not yanked:
		g.fx.shake=maxf(g.fx.shake,6);g.cue("serpent",1,point.x);restore(20,point,"破门")

func before_hit(brick:RefCounted,depth:int) -> bool:
	if brick.type=="scale" and depth==0 and g.active_arrow!=null:drain(6,brick.position,g.active_arrow)
	return true

func destroyed(brick:RefCounted,_depth:int) -> void:
	match brick.type:
		"scale":
			d.hurt(g.damage()*1.2,brick.position);drain(30,brick.position,g.active_arrow)
			g.fx.burst(brick.position,Color(d.palette().weak),18,2);g.cue("shatter",1,brick.x)
			regrow_queue.append(g.time+4.5)
		"star":
			for index in range(3):sparks.append({"position":brick.position,"velocity":Vector2.from_angle(-PI/2+(index-1)*0.9)*360,"born":g.time})
			d.hurt(g.damage()*0.1,brick.position)
		_:d.hurt(g.damage()*0.05,brick.position)

func step_regrow() -> void:
	if regrow_queue.is_empty() or g.time<regrow_queue[0]:return
	regrow_queue.pop_front()
	var have:Array=scales()
	if have.size()>=SCALES[clampi(d.fight.phase-1,0,3)]:return
	var used:Array=have.map(func(b):return int(b.flags.segment))
	var total:int=snakes[0].total
	var best:=4;var gap:=-1
	for index in range(10):
		var candidate:int=g.rng.randi_range(3,total-6)
		var nearest:=999
		for item in used:nearest=mini(nearest,absi(item-candidate))
		if nearest>gap:gap=nearest;best=candidate
	var brick:=make_scale(best,scale_hp());brick.flash=0.4
	g.initial+=1;g.cue("regrow");g.revision+=1
	if regrow_queue.size()>0:regrow_queue[0]=maxf(regrow_queue[0],g.time+1.0)

func relocate() -> void:
	var have:Array=scales()
	var total:int=snakes[0].total
	for index in range(have.size()):
		have[index].flags.segment=clampi(3+roundi((index+g.rng.randf_range(0.2,0.8))*(total-8)/have.size()),3,total-4);have[index].flash=0.4

func drop_star() -> void:
	if snakes.is_empty() or d.dying_at>=0:return
	var snake:Dictionary=snakes[0]
	var tip:Vector2=snake.points[snake.count-1] if snake.points.size()>=snake.count and snake.hidden[snake.count-1]==0 else CENTER
	var slots:Array=d.open_slots().filter(func(p):return in_island(p,Vector2(80,40)))
	if slots.is_empty():return
	slots.sort_custom(func(a,b):return a.distance_squared_to(tip)<b.distance_squared_to(tip))
	var point:Vector2=slots[g.rng.randi_range(0,mini(2,slots.size()-1))]
	g.fx.ring(tip,Color(d.palette().star),40);d.spawn(point,"star")

func step_sparks(delta:float) -> void:
	for spark in sparks:
		var target:=Vector2(NAN,NAN)
		for snake in snakes:
			if snake.points.is_empty() or snake.hidden[0]==1:continue
			if is_nan(target.x) or snake.points[0].distance_squared_to(spark.position)<target.distance_squared_to(spark.position):target=snake.points[0]
		if is_nan(target.x):continue
		var offset:Vector2=target-spark.position
		spark.velocity=spark.velocity.lerp(offset.normalized()*620,minf(1,delta*3.5));spark.position+=spark.velocity*delta
		if offset.length()<HEAD_RADIUS+6:
			spark.born=-100;g.cue("chime",1,target.x);g.fx.burst(target,Color(d.palette().spark),10,1.4)
			d.hurt(g.damage()*0.6,target);drain(15,target)
	sparks=sparks.filter(func(s):return g.time-s.born<3.0)

# --- Presentation -----------------------------------------------------------

func status() -> Dictionary:
	if exposed():return {"text":"倒地 %.1fs · 伤害 ×3" % maxf(0,stunned_until-g.time),"state":"exposed"}
	if g.time<refill_until:return {"text":"鳞甲回覆","state":"shielded"}
	var text:="鳞甲 %d%% · 击碎逆鳞" % roundi(d.fight.data.get("armor",100))
	match move.get("stage",""):
		"aim":text="盘击 · 蓄力中打断"
		"under":text="潜渊 · 射中出口星门"
		"maw":text="吞星 %d / %d" % [move.hits,4 if d.rage else 3]
		"dark":text="星蚀 %d / 2" % move.hits
		"split":text="双生 · 斩断星丝"
	return {"text":text,"state":"shielded"}

func music_mood() -> String:
	if exposed():return "stun"
	match move.get("stage",""):
		"dark":return "eclipse"
		"maw":return "devour"
	return "fight"

func calm() -> void:
	super.calm();settle();sparks.clear();regrow_queue.clear()
	for snake in snakes:snake.slide={};snake.reach=Vector2.ZERO;snake.sway=0.0;snake.speed=1.0;snake.fade=1.0

func intro() -> void:
	super.intro();next_at=g.time+INTRO_SECONDS+1.6
	var snake:Dictionary=snakes[0]
	hide_until(snake,top_s()-140,0.9,"intro")
	d.later(0.25,func():g.cue("hiss",1,at(top_s()-140).x))
	d.later(INTRO_SECONDS-1.1,func():roar_at=g.time;g.cue("serpent",1,390,true);g.fx.ring(focus(),Color(d.palette().eye),180);g.fx.shake=maxf(g.fx.shake,7))

## Shows the whole serpent at once (restored saves and preview fixtures).
func reveal() -> void:
	for snake in snakes:snake.gate={};snake.speed=1.0;snake.s=top_s()+g.rng.randf_range(0,600)
	locate(0)

func persist() -> void:
	d.fight.data.serpentVersion=2
	d.fight.data.scales=scales().map(func(b):return {"segment":int(b.flags.segment),"hp":b.hp})

func explode() -> bool:
	var ink:=Color(d.palette().star);var glow:=Color(d.palette().glow)
	for snake in snakes:
		for k in range(0,snake.points.size(),4):
			if snake.hidden[k]==0:g.fx.burst(snake.points[k],ink if k%8==0 else glow,5,1.6)
	g.fx.ring(focus(),glow,620);g.fx.ring(focus(),Color(d.palette().eye),300);g.fx.burst(focus(),ink,60,4)
	for brick in g.bricks.duplicate():
		if brick.type=="scale":g.hit(brick,1e12,99)
	g.fx.flash=1.0;g.fx.shake=14;g.cue("shatter");g.cue("serpent",1,390,true)
	return true
