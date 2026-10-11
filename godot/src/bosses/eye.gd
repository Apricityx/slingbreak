extends "res://src/bosses/base.gd"
const CALL={"orbit":["CRYSTAL RING","晶环","击碎发光的晶心"],"summon":["SUMMON","召唤","阵成前击中法阵"],"tear":["TEAR","泪滴","落地前击碎晶泪"],"gaze":["GAZE","凝视","逆着光束射入巨眼"],"mirage":["MIRAGE","幻瞳","射中追着准星的真眼"],"doom":["DOOM","终焉","蓄满前三击瞳孔"]}
var center:=Vector2(390,92)
var watchers:Array=[]
var wells:Array=[]

func focus() -> Vector2:return center
func setup(restored:bool) -> void:
	super.setup(restored);center=Vector2(390,92);watchers.clear();wells.clear()
	if not restored:
		d.fight.data.ward=100.0;lash()
		var selected:Array=g.shuffle(g.bricks.filter(func(b):return b.type=="normal"))
		for brick in selected.slice(0,1+d.fight.phase*2):brick.type="void"
		for brick in selected.slice(1+d.fight.phase*2,3+d.fight.phase*4):brick.type="hydra";brick.hp*=1.5;brick.max_hp=brick.hp
	if d.fight.phase>=2:
		for index in range(3):
			var point:=Vector2(198+index*192,710 if index==1 else 650)
			for brick in g.bricks.duplicate():
				if absf(brick.x-point.x)<70 and absf(brick.y-point.y)<40:g.bricks.erase(brick)
			watchers.append({"position":point,"index":index,"blind":false,"born":g.time-index*2.6/3})

func lash() -> void:
	var anchors:Array=g.bricks.filter(func(b):return b.type=="anchor")
	for brick in g.shuffle(g.bricks.filter(func(b):return b.type=="normal" and absf(b.x-390)>=150)):
		if anchors.size()>=(2 if d.fight.phase==1 else 3):break
		if anchors.any(func(a):return a.position.distance_to(brick.position)<260):continue
		brick.type="anchor";brick.hp=minf(round(g.base_hp()*3.2*(1+0.25*(d.fight.phase-1))),ceil(g.damage()*(3+d.fight.phase)));brick.max_hp=brick.hp;anchors.append(brick)

func status() -> Dictionary:
	return {"text":"失神 · 伤害 ×3" if exposed() else "结界重塑" if g.time<refill_until else "结界 %d%%" % roundi(d.fight.data.ward),"state":"exposed" if exposed() else "shielded"}

func daze(point:Vector2,label:String,arrow:RefCounted=null,duration:float=4) -> void:
	for brick in g.bricks.duplicate():
		if brick.flags.get("orbit",false):g.fx.burst(brick.position,Color(d.palette().shield),8);g.bricks.erase(brick)
	move={};d.fight.data.ward=0.0;stunned_until=g.time+duration;refill_until=stunned_until+1.2;next_at=refill_until+2
	for watcher in watchers:watcher.blind=false
	if arrow!=null:d.pay(arrow,point,2)
	impact(center,Color(d.palette().shield),280);g.fx.floating(point-Vector2(0,34),label,Color(d.palette().text),20);g.cue("core");d.banner("DAZED","失神","巨眼暴露 · 伤害 ×3","weak")

func drain(amount:float,point:Vector2,label:String) -> void:
	if exposed() or g.time<refill_until or not d.fight.intro:return
	d.fight.data.ward=maxf(0,d.fight.data.ward-amount)
	if d.fight.data.ward<=0:daze(point,label,g.active_arrow)
	g.revision+=1

func before_hit(brick:RefCounted,depth:int) -> bool:
	if brick.type=="anchor" and depth==0 and g.active_arrow!=null:drain(8,brick.position,"断链")
	return true

func destroyed(brick:RefCounted,depth:int) -> void:
	if brick.type=="anchor":drain(22,brick.position,"断链");d.hurt(g.damage()*0.5,brick.position)
	elif brick.flags.get("heart",false):daze(brick.position,"碎心",g.active_arrow)
	elif depth<3 and brick.type!="shard":d.hurt(g.damage()*0.03,brick.position)
	if brick.type=="void":
		wells.append({"position":brick.position,"until":g.time+2.6,"next":g.time+0.3,"source":g.active_arrow})
		if wells.size()>4:wells.pop_front()
	if brick.type=="hydra" and brick.w>=60:
		var point:Vector2=brick.position
		var hp:float=maxf(1,round(brick.max_hp*0.5))
		d.later(0.24,func():
			if g.bricks.size()>228:return
			for side in [-1,1]:g.make_brick({"x":point.x+side*22,"y":point.y,"w":40,"h":44,"hp":hp,"max":hp});g.initial+=1
		)

func begin(id:String) -> void:
	last_move=id
	var duration:float={"orbit":7.0 if d.rage else 8.0,"summon":3.0 if d.rage else 3.5,"tear":3.5,"gaze":4.4 if d.rage else 5.0,"mirage":5.5 if d.rage else 6.5,"doom":5.8}[id]
	move={"id":id,"start":g.time,"live":g.time+0.8,"end":g.time+duration,"hits":0,"target":Vector2(390,650),"seen":{},"made":0,"dir":-1 if g.rng.randf()<0.5 else 1}
	if id=="orbit":
		var count:=8 if d.rage else 6
		var heart:int=g.rng.randi_range(0,count-1)
		for index in range(count):
			var angle:float=index*TAU/count
			var point:=center+Vector2(cos(angle)*132,sin(angle)*38+14)
			var hp:float=ceil(g.damage()*1.5) if index==heart else maxf(2,round(g.base_hp()*1.2))
			var brick:RefCounted=g.make_brick({"x":point.x,"y":point.y,"w":40,"h":26,"hp":hp,"max":hp,"type":"shard"})
			brick.flags={"orbit":true,"slot":index,"count":count,"heart":index==heart}
	if id=="summon":
		var slots:Array=d.open_slots().filter(func(p):return p.y>=500 and p.y<=760)
		if not slots.is_empty():move.target=slots[g.rng.randi_range(0,slots.size()-1)]
	if id=="tear":move.target=Vector2(g.rng.randf_range(250,530),860)
	if id=="mirage":move.real=170 if g.rng.randf()<0.5 else 610
	var call:Array=CALL[id];d.banner(call[0],call[1],call[2],"weak" if id=="doom" else "minor");g.cue("abyss" if id=="doom" else "void")

func tear_point() -> Vector2:
	var t:float=maxf(0,g.time-move.live)
	var k:=minf(1,t/0.8)
	return Vector2(390+(move.target.x-390)*k+sin(t*2.4)*26*k,146+t*(300 if d.rage else 260)+t*t*20)

func beam_angle() -> float:
	var t:=clampf((g.time-move.live)/(move.end-move.live),0,1)
	return PI/2+move.dir*(1.05-2.1*t)

func contact(arrow:RefCounted,live:bool) -> void:
	var id:String=move.get("id","")
	var notch:bool=id=="gaze" and g.time>=move.live and absf(wrapf((arrow.position-center).angle()-beam_angle(),-PI,PI))<0.3
	var circles:Array=[{"point":center,"kind":"eye"}]
	if id=="mirage":circles=[{"point":Vector2(170,92),"kind":"real" if move.real==170 else "fake"},{"point":Vector2(610,92),"kind":"real" if move.real==610 else "fake"}]
	for item in circles:
		var hit:Dictionary=d.bounce_circle(arrow,item.point,43 if exposed() or notch or id=="doom" else 57)
		if hit.is_empty():continue
		if not live:return
		if exposed():d.strike(arrow,hit.point,3);return
		if g.time<arrow.flags.get("wardAt",-1):return
		arrow.flags.wardAt=g.time+0.15
		if item.kind=="real" or notch:daze(hit.point,"识破" if item.kind=="real" else "迎瞳",arrow);return
		if id=="doom" and g.time>=move.live:
			move.hits+=1;g.fx.ring(center,Color(d.palette().weak),60+move.hits*30)
			if move.hits>=3:daze(hit.point,"破灭",arrow,5.5)
			return
		d.fight.data.ward=minf(100,d.fight.data.ward+(10 if item.kind=="fake" else 0));g.cue("ricochet");return
	for watcher in watchers:
		var hit:Dictionary=d.bounce_circle(arrow,watcher.position,25)
		if hit.is_empty():continue
		if live and not watcher.blind and fposmod(g.time-watcher.born,2.6)<2.6*0.45 and not exposed():
			watcher.blind=true;drain(100 if watchers.all(func(w):return w.blind) else 25,watcher.position,"刺瞎")
		return
	if id in ["summon","tear"]:
		var point:Vector2=move.target if id=="summon" else tear_point()
		if not d.bounce_circle(arrow,point,26 if id=="summon" else 18).is_empty() and live:daze(point,"破阵" if id=="summon" else "碎泪",arrow)

func update(delta:float) -> void:
	if not move.is_empty() and move.id=="mirage":center.x=lerpf(center.x,float(move.real),minf(1,delta*6))
	else:center.x=lerpf(center.x,390,minf(1,delta*6))
	for brick in g.bricks:
		if brick.flags.get("orbit",false):
			var angle:float=(g.time-move.get("start",g.time))*(1.2 if d.rage else 0.8)+brick.flags.slot*TAU/brick.flags.count
			brick.position=center+Vector2(cos(angle)*132,sin(angle)*38+14)
	for well in wells:
		for arrow in g.arrows:
			var difference:Vector2=well.position-arrow.position
			var distance:=difference.length()
			if distance>4 and distance<230:
				var force:=difference.normalized()*(1-distance/230)*1.1*delta*60
				arrow.velocity=(arrow.velocity+force+force.orthogonal()*0.35).limit_length(maxf(18,g.speed()))
		if g.time>=well.next and g.time<well.until:
			well.next=g.time+0.3
			g.skills.with_source(well.source,func():
				for brick in g.near(well.position,125):g.hit(brick,g.damage()*0.7,1)
			)
	wells=wells.filter(func(w):return w.until>g.time)
	if d.busy:return
	if not exposed():
		if g.time<refill_until:d.fight.data.ward=100*(1-(refill_until-g.time)/1.2)
		else:
			if d.fight.data.ward<1:lash();d.fight.data.ward=100.0
			var count:int=g.bricks.filter(func(b):return b.type=="anchor").size()
			d.fight.data.ward=minf(100,d.fight.data.ward+delta*(1.5+count*1.5)*(1.3 if d.rage else 1))
	if ready_move():begin(pick())
	if move.is_empty():return
	if move.id=="gaze" and g.time>=move.live:
		for point in d.open_slots():
			if move.made>=6 or move.seen.has(point):continue
			if absf(wrapf((point-center).angle()-beam_angle(),-PI,PI))<0.07:
				move.seen[point]=true
				if g.rng.randf()<0.4:d.spawn(point,"hydra");move.made+=1
	var expired:bool=g.time>=move.end or move.id=="tear" and g.time>=move.live and tear_point().y>=860
	if not expired:return
	var id:String=move.id
	if id=="orbit":
		for brick in g.bricks.duplicate():
			if brick.flags.get("orbit",false):g.bricks.erase(brick)
	regrow(8 if id=="doom" else 5,"hydra" if id=="summon" else "normal")
	d.fight.data.ward=minf(100,d.fight.data.ward+(100 if id=="doom" else 35))
	finish_move()

func calm() -> void:super.calm();wells.clear()
func music_mood() -> String:return "stun" if exposed() else "mend" if g.time<refill_until else "doom" if move.get("id")=="doom" else "glare" if not move.is_empty() else "fight"
