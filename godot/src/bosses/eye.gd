extends "res://src/bosses/base.gd"
## V5 Abyss Eye. Readable loop: chip the twelve-crystal ward (direct hits,
## anchors, tears, watchers) or answer a cast at the open pupil to daze the eye,
## then punish the exposed pupil at ×3.
const CALL={"orbit":["ORBITAL SEAL","碎星结界","击碎金色晶心 · 破盾反击"],"summon":["VOID BLOOM","虚空孵化","法阵闭合前击破中心"],"tear":["FALLEN STARS","陨星之泪","击碎三滴星泪 · 每滴削去结界"],"gaze":["JUDGEMENT GAZE","视界审判","蓄力时瞳孔张开 · 直击打断扫射"],"mirage":["PARALLAX","镜界双瞳","真瞳追踪准星 · 假瞳保持静止"],"doom":["THE LAST LIGHT","终焉坍缩","三击瞳孔打断 · 获得长破绽"]}
const Rig=preload("res://src/render/abyss_rig.gd")
const Pattern=preload("res://src/bosses/eye_pattern.gd")
var center:=Rig.CENTER
var watchers:Array=[]
var wells:Array=[]
var broken_at:=-100.0
var drained_at:=-100.0
var broken_position:=Vector2.ZERO
var broken_direction:=Vector2.DOWN
var phase_at:=-100.0
var phase_revealed:=true
var phase_origin:=Rig.CENTER
var phase_from_mirage:=false
var visuals:=preload("res://src/effects/abyss_events.gd").new()

func charge() -> float:
	if move.get("id")!="doom":return 0.0
	return clampf((g.time-move.live)/(move.end-move.live),0,1)

func intro() -> void:
	next_at=g.time+Rig.INTRO_SECONDS+1.8;g.cue("eye_awaken",1,390,true)
	visuals.emit("intro",center,g.time)

func focus() -> Vector2:return center
## Every eye encounter runs the V5 contract; older saves migrate in setup().
func modern() -> bool:return true
func pick() -> String:return Pattern.choose(d.fight)
func gaze_active() -> bool:return move.get("id")=="gaze" and g.time<move.active_end
func sweeping() -> bool:return move.get("id")=="gaze" and g.time>=move.live and g.time<move.active_end
## The pupil opens to a counter-shot from the lock until the sweep ends.
func counter_open() -> bool:return move.get("id")=="gaze" and g.time>=move.start+0.35 and g.time<move.active_end
func watchers_active() -> bool:return move.is_empty() and not exposed() and not d.busy
func setup(restored:bool) -> void:
	phase_origin=center
	phase_from_mirage=move.get("id")=="mirage"
	super.setup(restored);center=Rig.CENTER;watchers.clear();wells.clear()
	visuals.reset()
	broken_at=-100.0;drained_at=-100.0;phase_at=g.time if not restored and d.fight.phase>1 else -100.0
	phase_revealed=phase_at<0
	if not phase_revealed:
		next_at=g.time+Rig.SHIFT_SECONDS+1.4;visuals.emit("phase",center,g.time)
	if restored:Pattern.migrate(d.fight)
	else:
		if d.fight.phase==1:
			d.fight.data.encounterVersion=0;d.fight.data.sequence={};Pattern.migrate(d.fight)
		else:g.cue("eye_charge",1,390,true)
		d.fight.data.ward=100.0;lash()
		var selected:Array=g.shuffle(g.bricks.filter(func(b):return b.type=="normal"))
		for brick in selected.slice(0,1+d.fight.phase*2):brick.type="void"
		for brick in selected.slice(1+d.fight.phase*2,2+d.fight.phase*3):brick.type="hydra";brick.hp*=1.5;brick.max_hp=brick.hp
	if d.fight.phase>=2:
		for index in range(3):
			var point:=Vector2(198+index*192,710 if index==1 else 650)
			# Restoring or staging a head must never carve holes in saved masonry.
			if not d.occupied(point,70,40):watchers.append({"position":point,"index":index,"blind":false,"born":g.time-index*2.6/3})

func lash() -> void:
	var anchors:Array=g.bricks.filter(func(b):return b.type=="anchor")
	for brick in g.shuffle(g.bricks.filter(func(b):return b.type=="normal" and absf(b.x-390)>=150)):
		if anchors.size()>=(2 if d.fight.phase==1 else 3):break
		if anchors.any(func(a):return a.position.distance_to(brick.position)<260):continue
		brick.type="anchor";brick.hp=minf(round(g.base_hp()*3.2*(1+0.25*(d.fight.phase-1))),ceil(g.boss_reference_damage()*(3+d.fight.phase)));brick.max_hp=brick.hp;anchors.append(brick)

## A crystal lights only once fully regrown, matching the shader ring.
func crystals() -> int:return floori(d.fight.data.ward/Pattern.CHIP+0.001)
func status() -> Dictionary:
	if g.time<d.shift_until:return {"text":"解封中","state":"shielded"}
	if sweeping():return {"text":"视界扫射","state":"shielded"}
	if counter_open():return {"text":"瞳孔张开 · 击瞳打断","state":"exposed"}
	return {"text":"失神 · 伤害 ×3" if exposed() else "结界重塑" if g.time<refill_until else "结界 %d / 12" % crystals(),"state":"exposed" if exposed() else "shielded"}

func daze(point:Vector2,label:String,arrow:RefCounted=null,duration:float=4) -> void:
	var interrupted:String=move.get("id","")
	visuals.interrupt()
	if interrupted in ["summon","tear"]:visuals.emit("resolve",point,g.time,(point-center).normalized(),interrupted)
	if interrupted=="gaze":g.cue("eye_laser_stop",1,center.x)
	for brick in g.bricks.duplicate():
		if brick.flags.get("orbit",false):g.fx.burst(brick.position,Color(d.palette().shield),8);g.bricks.erase(brick)
	move={};d.fight.data.ward=0.0;stunned_until=g.time+duration;refill_until=stunned_until+1.2;next_at=refill_until+2
	for watcher in watchers:watcher.blind=false
	if arrow!=null:d.pay(arrow,point,2)
	broken_at=g.time;broken_position=center
	broken_direction=(point-center).normalized() if point!=center else Vector2.DOWN
	visuals.emit("break",center,g.time,broken_direction)
	g.fx.shake=maxf(g.fx.shake,4 if g.reduced else 8);g.hitstop(0.08);g.fx.flash=maxf(g.fx.flash,0.12)
	g.fx.floating(point-Vector2(0,34),label,Color(d.palette().text),20);g.cue("eye_break",1,point.x,true);d.banner("SEAL BROKEN","失神","巨眼暴露 · 伤害 ×3","weak")

func drain(amount:float,point:Vector2,label:String,arrow:RefCounted=null) -> void:
	if exposed() or g.time<refill_until or not d.fight.intro:return
	d.fight.data.ward=maxf(0,d.fight.data.ward-amount);drained_at=g.time
	if d.fight.data.ward<=0.01:daze(point,label,arrow if arrow!=null else g.active_arrow)
	g.revision+=1

## A direct seal contact: one crystal and a small wound, a few per arrow.
func chip(arrow:RefCounted,hit:Dictionary) -> void:
	visuals.emit("ward",hit.point,g.time,hit.normal);g.cue("eye_hit",1,hit.point.x)
	var count:int=arrow.flags.get("chips",0)
	if count>=Pattern.CHIP_LIMIT or g.time<refill_until:return
	arrow.flags.chips=count+1
	# Every chip darkens exactly one lit crystal and discards partial regrowth.
	d.hurt(g.damage()*0.3,hit.point);drain(d.fight.data.ward-maxf(0,crystals()-1)*Pattern.CHIP,hit.point,"碎盾",arrow)

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
	last_move=id;Pattern.accepted(d.fight,id)
	var duration:float={"orbit":7.0 if d.rage else 8.0,"summon":3.0 if d.rage else 3.5,"tear":0.8+Pattern.TEAR_GAP*2+Pattern.TEAR_FALL,"gaze":Pattern.ANTICIPATION+Pattern.SWEEP+Pattern.RECOVERY,"mirage":5.5 if d.rage else 6.5,"doom":5.8}[id]
	move={"id":id,"start":g.time,"live":g.time+0.8,"end":g.time+duration,"hits":0,"target":Vector2(390,650),"seen":{},"made":0,"dir":-1 if g.rng.randf()<0.5 else 1,"sounded":false}
	if id=="gaze":
		move.live=g.time+Pattern.ANTICIPATION;move.active_end=move.live+Pattern.SWEEP;move.end=move.active_end+Pattern.RECOVERY
		g.cue("eye_lock",1,center.x,true)
	if id=="tear":
		var lanes:Array=g.shuffle([150.0,270.0,390.0,510.0,630.0])
		move.tears=[]
		for i in range(Pattern.TEARS):move.tears.append({"x":lanes[i],"at":move.live+i*Pattern.TEAR_GAP,"side":[-1,1,0][i],"state":"fall"})
	if id=="orbit":
		var count:=8 if d.rage else 6
		var heart:int=g.rng.randi_range(0,count-1)
		for index in range(count):
			var angle:float=index*TAU/count
			var point:=center+Vector2(cos(angle)*132,sin(angle)*38+14)
			var hp:float=ceil(g.boss_reference_damage()*1.5) if index==heart else maxf(2,round(g.base_hp()*1.2))
			var brick:RefCounted=g.make_brick({"x":point.x,"y":point.y,"w":40,"h":26,"hp":hp,"max":hp,"type":"shard"})
			brick.flags={"orbit":true,"slot":index,"count":count,"heart":index==heart}
	if id=="summon":
		var slots:Array=d.open_slots().filter(func(p):return p.y>=500 and p.y<=760)
		if not slots.is_empty():move.target=slots[g.rng.randi_range(0,slots.size()-1)]
	if id=="mirage":move.real=170 if g.rng.randf()<0.5 else 610
	visuals.emit("cast",center,g.time,Vector2.DOWN,id)
	var call:Array=CALL[id]
	d.banner(call[0],call[1],call[2],"weak" if id in ["doom","gaze"] else "minor");g.cue("eye_charge" if id in ["doom","gaze"] else "eye_cast",1,center.x,true)

func tear_point(tear:Dictionary) -> Vector2:return Pattern.tear_position(tear,g.time,center)
func live_tears() -> Array:
	if move.get("id")!="tear":return []
	return move.tears.filter(func(t):return t.state=="fall" and g.time>=t.at)

func beam_angle() -> float:
	if move.get("id")!="gaze":return PI/2
	return Pattern.sweep_angle(move,g.time)
func beam_endpoint() -> Vector2:return Pattern.beam_end(center,beam_angle())

func contact(arrow:RefCounted,live:bool) -> void:
	var id:String=move.get("id","")
	var circles:Array=[{"point":center,"kind":"eye"}]
	if id=="mirage":circles=[{"point":Vector2(170,Rig.CENTER.y),"kind":"real" if move.real==170 else "fake"},{"point":Vector2(610,Rig.CENTER.y),"kind":"real" if move.real==610 else "fake"}]
	var counter:bool=counter_open()
	for item in circles:
		var hit:Dictionary=d.bounce_circle(arrow,item.point,Rig.PUPIL_RADIUS if exposed() or counter or id=="doom" else Rig.WARD_RADIUS)
		if hit.is_empty():continue
		if not live:return
		if exposed():
			if d.strike(arrow,hit.point,3):visuals.emit("hit",hit.point,g.time,hit.normal)
			return
		if g.time<arrow.flags.get("wardAt",-1):return
		arrow.flags.wardAt=g.time+0.15
		if item.kind=="real" or counter:daze(hit.point,"识破" if item.kind=="real" else "迎瞳",arrow);return
		if id=="doom" and g.time>=move.live:
			move.hits+=1;visuals.emit("seal_hit",center,g.time,hit.normal);g.cue("eye_hit",1,hit.point.x)
			if move.hits>=3:daze(hit.point,"破灭",arrow,5.5)
			return
		if item.kind=="fake":
			visuals.emit("ward",hit.point,g.time,hit.normal);g.cue("eye_hit",1,hit.point.x)
			d.fight.data.ward=minf(100,d.fight.data.ward+Pattern.CHIP);return
		chip(arrow,hit);return
	for watcher in watchers:
		if not watchers_active():break
		var hit:Dictionary=d.bounce_circle(arrow,watcher.position,25)
		if hit.is_empty():continue
		if live and not watcher.blind and fposmod(g.time-watcher.born,2.6)<2.6*0.45 and not exposed():
			watcher.blind=true;drain(100 if watchers.all(func(w):return w.blind) else 25,watcher.position,"刺瞎",arrow)
		return
	if id=="summon":
		if not d.bounce_circle(arrow,move.target,26).is_empty() and live:daze(move.target,"破阵",arrow)
	for tear in live_tears():
		var point:=tear_point(tear)
		if d.bounce_circle(arrow,point,20).is_empty():continue
		if not live:return
		tear.state="caught";d.pay(arrow,point)
		visuals.emit("resolve",point,g.time,(point-center).normalized(),"tear")
		g.fx.burst(point,Color(d.palette().shield),14,2);g.cue("eye_break",1,point.x)
		var caught:int=move.tears.filter(func(t):return t.state=="caught").size()
		g.fx.floating(point-Vector2(0,26),"碎泪 %d / %d" % [caught,Pattern.TEARS],Color(d.palette().text),16)
		# Clearing every tear always breaks the seal, whatever the anchors restored.
		if caught>=Pattern.TEARS:daze(point,"碎泪",arrow)
		else:drain(Pattern.TEAR_DRAIN,point,"碎泪",arrow)
		return

func update(delta:float) -> void:
	visuals.advance(g.time)
	if not phase_revealed and g.time>=phase_at+Rig.REVEAL_AT:
		phase_revealed=true;g.cue("eye_awaken",1,390,true)
		g.fx.shake=maxf(g.fx.shake,4 if g.reduced else 12)
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
			if g.time>=drained_at+Pattern.REGEN_DELAY:d.fight.data.ward=minf(100,d.fight.data.ward+delta*(0.5+count*1.6)*(1.3 if d.rage else 1))
	if ready_move():begin(pick())
	if move.is_empty():return
	if not move.sounded and g.time>=move.live:
		move.sounded=true
		visuals.emit("release",center,g.time,Vector2.from_angle(beam_angle()) if move.id=="gaze" else Vector2.DOWN,move.id)
		g.cue("eye_beam" if move.id=="gaze" else "eye_pulse",1,center.x)
		if move.id=="gaze":g.cue("eye_laser",1,center.x,true);g.fx.shake=maxf(g.fx.shake,3 if g.reduced else 6)
	if sweeping():sweep()
	if move.id=="tear":
		for tear in live_tears():
			if tear_point(tear).y<840:continue
			# A landed tear crystallises masonry and restores part of the seal.
			tear.state="landed";var point:=tear_point(tear)
			visuals.emit("inscribe",Vector2(point.x,800),g.time,Vector2.DOWN,"tear");g.cue("eye_infect",1,point.x)
			regrow(2,"hydra");d.fight.data.ward=minf(100,d.fight.data.ward+12)
		if move.tears.all(func(t):return t.state!="fall"):move.end=minf(move.end,g.time)
	if g.time<move.end:return
	var id:String=move.id
	var resolve_point:Vector2=move.target if id=="summon" else center
	if id!="tear":visuals.emit("resolve",resolve_point,g.time,Vector2.DOWN,id)
	if id=="doom":g.cue("eye_break",1,center.x,true);g.fx.shake=maxf(g.fx.shake,12)
	if id=="orbit":
		for brick in g.bricks.duplicate():
			if brick.flags.get("orbit",false):g.bricks.erase(brick)
	if id=="gaze":
		g.cue("eye_laser_stop",1,center.x)
		d.banner("JUDGEMENT","审判结束","%d 块砖被石化" % move.made if move.made>0 else "扫射落空")
	elif id!="tear":regrow(8 if id=="doom" else 5,"hydra" if id=="summon" else "normal")
	d.fight.data.ward=minf(100,d.fight.data.ward+(100 if id=="doom" else 0 if id in ["gaze","tear"] else 35))
	finish_move()

## The sweeping beam petrifies the masonry it crosses and burns arrows in it.
func sweep() -> void:
	var dir:=Vector2.from_angle(beam_angle());var reach:float=center.distance_to(beam_endpoint())
	for brick in g.bricks:
		if move.made>=Pattern.PETRIFY_LIMIT:break
		if brick.type!="normal" or move.seen.has(brick.id):continue
		var delta:Vector2=brick.position-center;var along:float=delta.dot(dir)
		if along<60 or along>reach or absf(delta.cross(dir))>16:continue
		move.seen[brick.id]=true;move.made+=1
		brick.type="hydra";brick.hp=ceil(brick.hp*1.4);brick.max_hp=maxf(brick.max_hp,brick.hp);brick.flash=0.3;g.revision+=1
		visuals.emit("infect",brick.position,g.time,dir,"gaze");g.cue("eye_infect",1,brick.x)
	for arrow in g.arrows:
		var delta:Vector2=arrow.position-center;var along:float=delta.dot(dir)
		if along<75 or along>reach or absf(delta.cross(dir))>9 or arrow.pierce<=0:continue
		arrow.pierce=0;g.fx.burst(arrow.position,Color("#ff4466"),8,1)

func calm() -> void:
	if gaze_active():g.cue("eye_laser_stop",1,center.x)
	super.calm();wells.clear();visuals.interrupt()
func music_mood() -> String:return "stun" if exposed() else "mend" if g.time<refill_until else "doom" if move.get("id")=="doom" else "glare" if not move.is_empty() else "fight"
