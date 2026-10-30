extends "res://src/bosses/base.gd"
const Geometry=preload("res://src/core/geometry.gd")
var snakes:Array=[]
var portals:Array=[]
var sparks:Array=[]
var eclipse:Dictionary={}
var split_until:=0.0
var next_comet:=0.0
var cracks:=0
var regrowth:=0

func exposed() -> bool:return snakes.any(func(s):return s.mode in ["stun","coil","maw","rend"])
func focus() -> Vector2:return snakes[0].head if not snakes.is_empty() else Vector2(390,470)
func status() -> Dictionary:
	var text:="鳞甲 %d / 5" % cracks
	if snakes.any(func(s):return s.mode=="stun"):text="倒地 · 破绽"
	elif snakes.any(func(s):return s.mode in ["coil","rend"]):text="蓄力 · 可打断"
	elif snakes.any(func(s):return s.mode=="maw"):text="巨口 · 连射打断"
	elif not portals.is_empty():text="星门 · 射中出口"
	elif not eclipse.is_empty():text="星蚀 · %d / 2" % eclipse.hits
	elif snakes.size()>1:text="双生 · 斩断星丝"
	return {"text":text,"state":"exposed" if exposed() else "shielded"}

func setup(restored:bool) -> void:
	super.setup(restored);snakes.clear();portals.clear();sparks.clear();eclipse.clear();cracks=0;next_comet=g.time+1.5;regrowth=int(d.fight.data.get("regrowth",0))
	var saved:Array=d.fight.data.get("snakes",[]) if restored else []
	if restored and saved.is_empty():saved=[{"hp":g.bricks.filter(func(b):return b.type=="scale").map(func(b):return b.hp)}]
	for brick in g.bricks.duplicate():
		if brick.type=="scale":g.bricks.erase(brick)
	if saved.is_empty():
		var count:int=[32,36,42,48][d.fight.phase-1]
		var hp:Array=[]
		for index in range(count):hp.append(ceil(maxf(g.base_hp(),g.damage()*2)*(1+1.5*maxf(0,5-(count-1-index))/5)))
		saved=[{"hp":hp}]
	for index in range(saved.size()):
		var snake:Dictionary={"head":Vector2(390,150),"angle":PI/2,"trail":[],"segments":[],"mode":"swim","at":g.time,"end":g.time,"cracks":0,"mouth":0,"target":Vector2(390,850),"max":saved[index].get("max",saved[index].hp.size()),"nextRegrow":g.time+4,"guard":0.0,"jaw":0.0}
		for item in saved[index].hp:
			var brick:RefCounted=g.make_brick({"x":390,"y":150,"w":40,"h":40,"hp":item,"max":maxf(item,g.damage()*2),"type":"scale"})
			brick.flags.orbit=true;snake.segments.append(brick)
		snakes.append(snake)
		for step in range(400):
			var t:float=-step*0.02
			snake.trail.append(Vector2(390+sin(t*1.2+index*PI)*230,470+cos(t*0.9)*230))
		snake.head=snake.trail[0]
	if d.has("comet"):
		for brick in g.shuffle(g.bricks.filter(func(b):return b.type=="normal")).slice(0,4):brick.type="star"

func intro() -> void:
	super.intro()
	for snake in snakes:
		snake.mode="emerge";snake.at=g.time;snake.end=g.time+2.6;snake.head=Vector2(390,150);portal(snake.head,snake.end+0.5,true)

func portal(point:Vector2,end:float,exit:bool) -> void:
	portals.append({"position":point,"born":g.time,"end":end,"exit":exit,"hits":0})
	g.fx.ring(point,Color(d.palette().glow),220);g.cue("hiss")

func stun(snake:Dictionary,label:String,duration:float=2.6) -> void:
	snake.mode="stun";snake.at=g.time;snake.end=g.time+duration;snake.cracks=0;cracks=0;snake.guard=snake.end+0.5
	impact(snake.head,Color(d.palette().glow),220);g.fx.floating(snake.head-Vector2(0,35),label,Color(d.palette().text),20)

func destroyed(brick:RefCounted,_depth:int) -> void:
	if brick.type=="scale":
		d.hurt(g.damage()*0.6,brick.position)
		for snake in snakes:
			if brick in snake.segments:
				snake.segments.erase(brick)
				if g.time>=snake.guard:snake.cracks+=1;cracks=maxi(cracks,snake.cracks)
				if snake.cracks>=5:stun(snake,"碎甲")
				if snake.segments.is_empty():stun(snake,"断尾",2)
	elif brick.type=="star":
		for index in range(3):sparks.append({"position":brick.position,"velocity":Vector2.from_angle(-PI/2+(index-1)*0.9)*6,"born":g.time})

func contact(arrow:RefCounted,live:bool) -> void:
	for gate in portals:
		if not gate.exit:continue
		if not d.bounce_circle(arrow,gate.position,24).is_empty() and live:
			for snake in snakes:
				if snake.mode=="under":snake.head=gate.position;stun(snake,"拽出")
	for snake in snakes:
		if snake.mode in ["under","sink"]:continue
		var hit:Dictionary=d.bounce_circle(arrow,snake.head,31)
		if hit.is_empty():continue
		if not live:return
		if snake.mode in ["coil","rend"]:stun(snake,"打断");d.pay(arrow,hit.point,2)
		elif snake.mode=="maw":
			if g.time>=arrow.flags.get("mawAt",-1):
				arrow.flags.mawAt=g.time+0.2;snake.mouth+=1
				if snake.mouth>=(4 if d.rage else 3):stun(snake,"噎住")
		elif snake.mode=="stun":d.strike(arrow,hit.point,5 if snake.segments.is_empty() else 3)
		else:d.strike(arrow,hit.point,0.25)
		if not eclipse.is_empty():
			eclipse.hits+=1
			if eclipse.hits>=2:eclipse={};stun(snake,"破蚀")
		if snakes.size()==2:
			arrow.flags["twin"+str(snakes.find(snake))]=g.time
			if absf(arrow.flags.get("twin0",-100)-arrow.flags.get("twin1",100))<0.6:merge(true)
		return
	if snakes.size()==2:
		var start:Vector2=snakes[0].head;var finish:Vector2=snakes[1].head
		var contact_value:Dictionary=Geometry.sweep(Rect2(arrow.position-Vector2(3,3),Vector2(6,6)),start,finish,6)
		if not contact_value.is_empty() and live:merge(true)

func begin(id:String) -> void:
	last_move=id;next_at=g.time+2
	var snake:Dictionary=snakes[0]
	match id:
		"coil":
			snake.mode="coil";snake.at=g.time;snake.end=g.time+1.4;snake.target=g.origin;d.banner("COIL","盘击","蓄力时击中蛇首")
		"dive":
			snake.mode="sink";snake.at=g.time;snake.end=g.time+1.3;snake.target=Vector2(g.rng.randf_range(160,620),g.rng.randf_range(250,650));portal(snake.head,g.time+2.5,false);portal(snake.target,g.time+4,true);d.banner("DIVE","潜渊","射中出口星门")
		"devour":snake.mode="maw";snake.at=g.time;snake.end=g.time+3.5;snake.mouth=0;snake.jaw=1;d.banner("DEVOUR","吞星","向口中连射");g.cue("devour")
		"eclipse":eclipse={"at":g.time,"end":g.time+6,"hits":0};d.banner("ECLIPSE","星蚀","命中蛇首打破黑暗")
		"twin":
			if snakes.size()==1:
				snake.mode="rend";snake.at=g.time;snake.end=g.time+1.6;d.banner("TWIN","双生","斩断星丝或同时命中双首")
		"comet":drop_star()

func drop_star() -> void:
	var snake:Dictionary=snakes[0]
	if snake.segments.is_empty():return
	var tip:Vector2=snake.segments.back().position
	var slots:Array=d.open_slots();slots.sort_custom(func(a,b):return a.distance_squared_to(tip)<b.distance_squared_to(tip))
	if not slots.is_empty() and slots[0].distance_to(tip)<180:d.spawn(slots[0],"star")

func split() -> void:
	var first:Dictionary=snakes[0]
	var second:Dictionary=first.duplicate()
	second.head=first.head+Vector2(50,0);second.angle=first.angle+1;second.trail=first.trail.duplicate();second.mode="swim";second.at=g.time;second.segments=[];second.cracks=0
	var half:=int(first.segments.size()/2)
	second.segments=first.segments.slice(half);first.segments=first.segments.slice(0,half);first.mode="swim";first.at=g.time
	snakes.append(second);split_until=g.time+12

func merge(forced:bool=false) -> void:
	if snakes.size()!=2:return
	snakes[0].segments.append_array(snakes[1].segments);snakes.pop_back();snakes[0].max=maxi(snakes[0].max,snakes[0].segments.size())
	if forced:stun(snakes[0],"合体倒地")

func update(delta:float) -> void:
	for snake in snakes:
		var speed:float=150 if d.rage else 110
		match snake.mode:
			"swim","emerge":
				var desired:=Vector2(390+sin(g.time*0.4+snakes.find(snake)*PI)*230,470+sin(g.time*0.7+1)*230)
				snake.angle=lerp_angle(snake.angle,(desired-snake.head).angle(),minf(1,delta*2))
				snake.head+=Vector2.from_angle(snake.angle)*speed*delta
				if snake.mode=="emerge" and g.time>=snake.end:snake.mode="swim"
			"coil":
				if g.time>=snake.end:snake.mode="lunge";snake.angle=(snake.target-snake.head).angle();snake.end=g.time+1.1
			"lunge":
				snake.head+=Vector2.from_angle(snake.angle)*600*delta
				for brick in g.near(snake.head,40):
					if not brick.flags.get("orbit",false):g.hit(brick,1e12,70)
				if g.time>=snake.end:snake.mode="swim";snake.at=g.time
			"sink":
				if g.time>=snake.end:snake.mode="under";snake.end=g.time+1.2
			"under":
				if g.time>=snake.end:snake.head=snake.target;snake.mode="swim";snake.at=g.time;impact(snake.head,Color(d.palette().glow))
			"rend":
				if g.time>=snake.end:split();break
			"maw":
				if not snake.has("fedAt"):snake.fedAt=g.time
				if g.time>=snake.fedAt:
					snake.fedAt=g.time+0.6
					var selected:Array=g.nearest(snake.head,1,func(b):return not b.flags.get("orbit",false))
					if not selected.is_empty():g.bricks.erase(selected[0]);g.cue("gulp")
				if g.time>=snake.end:snake.mode="swim";snake.at=g.time;snake.jaw=0
			"stun":
				if g.time>=snake.end:snake.mode="swim";snake.at=g.time
		snake.head.x=clampf(snake.head.x,70,710);snake.head.y=clampf(snake.head.y,150,850)
		if snake.mode not in ["under","sink"]:
			if snake.trail.is_empty() or snake.head.distance_to(snake.trail[0])>=3:
				snake.trail.push_front(snake.head)
				if snake.trail.size()>1400:snake.trail.pop_back()
			var index:=0
			var traveled:=0.0
			for segment in snake.segments:
				var target_distance:float=(snake.segments.find(segment)+1)*42
				while index+1<snake.trail.size() and traveled<target_distance:
					traveled+=snake.trail[index].distance_to(snake.trail[index+1]);index+=1
				segment.position=snake.trail[mini(index,snake.trail.size()-1)]
		else:
			for segment in snake.segments:segment.position=Vector2(-500,-500)
		if snake.segments.size()<snake.max and g.time>=snake.nextRegrow and not d.busy and snake.mode in ["swim","stun"]:
			snake.nextRegrow=g.time+0.2
			var hp:float=ceil(g.damage()*4*(1+0.5*regrowth))
			var brick:RefCounted=g.make_brick({"x":snake.head.x,"y":snake.head.y,"w":40,"h":40,"hp":hp,"max":hp,"type":"scale"});brick.flags.orbit=true;snake.segments.append(brick);g.cue("regrow")
	for spark in sparks:
		var selected:Array=snakes.duplicate();selected.sort_custom(func(a,b):return a.head.distance_squared_to(spark.position)<b.head.distance_squared_to(spark.position))
		if selected.is_empty():continue
		var difference:Vector2=selected[0].head-spark.position
		spark.velocity=spark.velocity.lerp(difference.normalized()*14,minf(1,delta*4));spark.position+=spark.velocity*delta*60
		if difference.length()<36:d.hurt(g.damage()*0.9,selected[0].head);spark.born=-100;g.cue("chime")
	sparks=sparks.filter(func(s):return g.time-s.born<3.5)
	portals=portals.filter(func(p):return g.time<p.end)
	if not eclipse.is_empty() and g.time>=eclipse.end:eclipse={}
	if snakes.size()==2 and g.time>=split_until:merge()
	if d.busy:return
	if d.has("comet") and g.time>=next_comet:next_comet=g.time+(1.4 if d.rage else 2.2);drop_star()
	if g.time>=next_at and snakes.all(func(s):return s.mode=="swim"):
		var choices:Array=d.fight.abilities[d.fight.phase-1].duplicate()
		var id:String=choices[g.rng.randi_range(0,choices.size()-1)]
		begin(id);next_at=g.time+(5.5 if d.rage else 7.5)

func persist() -> void:d.fight.data.snakes=snakes.map(func(s):return {"max":s.max,"hp":s.segments.map(func(b):return b.hp)})
func music_mood() -> String:return "stun" if snakes.any(func(s):return s.mode=="stun") else "eclipse" if not eclipse.is_empty() else "devour" if snakes.any(func(s):return s.mode=="maw") else "fight"
func calm() -> void:super.calm();portals.clear();sparks.clear();eclipse.clear()
