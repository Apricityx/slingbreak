extends RefCounted
## Shared phase flow, resistance and reward attribution. Each boss owns its
## mechanics; CanvasItem presentation reads those same state machines.
const Geometry=preload("res://src/core/geometry.gd")
const Eye=preload("res://src/bosses/eye.gd")
const Clock=preload("res://src/bosses/clock.gd")
const Serpent=preload("res://src/bosses/serpent.gd")
const Forge=preload("res://src/bosses/forge.gd")
const NAMES={"eye":"深渊之眼","forge":"熔炉巨像","serpent":"星渊巨蟒","clock":"时之君主"}
const PHASES={"eye":["结界","幻瞳","终焉"],"forge":["点火","熔铸","暴走"],"serpent":["盘游","裂鳞","星蚀","双生"],"clock":["走时","机芯","午夜"]}
const COLORS={"eye":"#8a5cf0","forge":"#f08a3c","serpent":"#3ec8d6","clock":"#d9ae4f"}
var owner:WeakRef
var g:RefCounted:
	get:return owner.get_ref()
var fight:Dictionary={}
var boss_id:=""
var model:RefCounted
var notices:Array=[]
var wind:=0.0
var intro_at:=0.0
var shift_until:=0.0
var dying_at:=-1.0
var exploded:=false
var recent:Array=[]
var tasks:Array=[]
var weak:bool:
	get:return model!=null and model.exposed()
var rage:bool:
	get:return not fight.is_empty() and fight.phase==fight.phases
var busy:bool:
	get:return dying_at>=0 or g.time<intro_at+2.6 or g.time<shift_until

func _init(simulation:RefCounted) -> void:owner=weakref(simulation)
func reset() -> void:
	fight={};boss_id="";model=null;notices=[];wind=0;intro_at=0;shift_until=0;dying_at=-1;exploded=false;recent.clear();tasks.clear()

func start(restore:bool) -> void:
	var saved:Variant=g.state.get("nativeBoss")
	var restored:bool=restore and saved is Dictionary and preload("res://src/core/progress.gd").valid_boss(saved,g.state.level)
	var override:Variant=g.state.get("bossOverride")
	var is_override:bool=override is Dictionary and override.get("level")==g.state.level and override.get("boss") in NAMES
	if int(g.state.level)%100!=0 and not is_override and not restored:return
	if restored:boss_id=saved.boss
	elif is_override:boss_id=override.boss
	else:
		var deck:Array=g.state.get("bossDeck",[])
		if deck.is_empty():deck=g.shuffle(["eye","serpent","clock"])
		boss_id=deck.pop_front();g.state.bossDeck=deck
	var phases:=4 if boss_id=="serpent" else 3
	var max_hp:float=ceil(g.damage()*(24+6))
	fight={"level":g.state.level,"boss":boss_id,"name":NAMES[boss_id],"phase":1,"phases":phases,"max":max_hp,"hp":max_hp,"hits":0,"paid":0.0,"intro":false,"clock":0.0,"abilities":roll_abilities(),"data":{}}
	if restored:fight=saved.duplicate(true)
	model={"eye":Eye,"clock":Clock,"serpent":Serpent,"forge":Forge}[boss_id].new(self)
	model.setup(restored)
	intro_at=g.time-3 if fight.intro else g.time
	g.core=null

func roll_abilities() -> Array:
	var pool:Array={"eye":["orbit","summon","tear","gaze","mirage"],"clock":["stop","toll","pendulum","rewind","haste"],"serpent":["coil","dive","devour","eclipse","comet"],"forge":["meteor","magma","slam","bellows","palm"]}[boss_id]
	var openers:Array={"eye":["orbit","summon","tear"],"clock":["stop","toll","pendulum"],"serpent":["coil","dive","devour"],"forge":["meteor","slam","palm"]}[boss_id]
	var first:String=g.shuffle(openers)[0]
	pool.erase(first);pool=g.shuffle(pool)
	var result:Array=[[first],pool.slice(0,2),pool.slice(2,4)]
	if boss_id=="serpent":result.append(["twin",g.shuffle([first]+pool)[0]])
	elif boss_id in ["eye","clock"]:result[2].append("doom" if boss_id=="eye" else "midnight")
	return result

func has(id:String) -> bool:return not fight.is_empty() and id in fight.abilities[fight.phase-1]
func palette() -> Dictionary:return g.content.palette(g.theme)[{"eye":"rift","clock":"clock","serpent":"serpent","forge":"forge"}[boss_id]]

func status() -> Variant:
	if fight.is_empty():return null
	var value:Dictionary={"text":"崩解中","state":"dying"} if dying_at>=0 else model.status()
	value.merge({"name":fight.name,"phases":fight.phases,"phaseName":PHASES[boss_id][fight.phase-1],"resist":roundi((1-resistance().factor)*10)*10})
	return value

func resistance() -> Dictionary:
	if fight.is_empty():return {"factor":1.0,"pace":1.0,"room":INF}
	recent=recent.filter(func(item):return g.time-item.at<3)
	var used:=0.0
	for item in recent:used+=item.value
	var allowed:=minf(1,(float(fight.clock)+12)/38)
	var lost:float=1-float(fight.hp)/fight.max
	var pace:=1.0 if lost<=allowed else maxf(0.25,1-(lost-allowed)/maxf(0.001,allowed))
	return {"factor":minf(pace,0.25 if used>=0.3*fight.max else 1),"pace":pace,"room":maxf(0,0.3*fight.max-used)}

func hurt(amount:float,point:Vector2) -> void:
	if dying_at>=0 or fight.is_empty() or amount<=0:return
	var r:=resistance()
	var under:=minf(amount,r.room)
	var dealt:=minf(fight.hp,under*r.pace+(amount-under)*minf(r.pace,0.25))
	fight.hp-=dealt;recent.append({"at":g.time,"value":dealt})
	g.fx.ring(point,Color(COLORS[boss_id]),70)
	g.revision+=1

func pay(arrow:RefCounted,point:Vector2,scale:float=1) -> void:
	var money:float=round(g.reward("gold",maxi(1,arrow.kills))*scale)
	fight.paid+=money;g.state.coins+=money;g.level_money+=money;g.shot_money+=money
	g.fx.floating(point,"+%d" % money,Color(palette().text),15)

func strike(arrow:RefCounted,point:Vector2,multiplier:float) -> bool:
	if dying_at>=0 or g.time<arrow.flags.get("bossAt",-1) or arrow.flags.get("bossHits",0)>=6:return false
	arrow.flags.bossAt=g.time+0.12;arrow.flags.bossHits=arrow.flags.get("bossHits",0)+1
	fight.hits+=1;pay(arrow,point);hurt(arrow.damage*multiplier,point)
	g.bounce(arrow);g.cue("eyehit",1,point.x);g.hitstop(0.06)
	return true

func bounce_circle(arrow:RefCounted,point:Vector2,radius:float) -> Dictionary:
	var hit:=Geometry.circle(arrow.position,arrow.position+arrow.velocity,point,radius)
	if hit.is_empty():return {}
	var normal:Vector2=hit.normal
	if arrow.velocity.dot(normal)>=0:return {}
	arrow.position=point+normal*(radius+0.5);arrow.velocity=arrow.velocity.bounce(normal)*0.9;arrow.trail.clear()
	return {"point":point+normal*radius,"normal":normal}

func bounce_bar(arrow:RefCounted,start:Vector2,end:Vector2,radius:float) -> bool:
	var direction:=end-start
	for index in range(5):
		var sample:Vector2=arrow.position+arrow.velocity*index/4.0
		var t:=clampf((sample-start).dot(direction)/maxf(1,direction.length_squared()),0,1)
		var center:=start+direction*t
		if sample.distance_to(center)>=radius:continue
		var normal:Vector2=(sample-center).normalized()
		if normal==Vector2.ZERO:normal=direction.orthogonal().normalized()
		arrow.position=center+normal*(radius+0.5)
		if arrow.velocity.dot(normal)<0:arrow.velocity=arrow.velocity.bounce(normal)*0.9
		return true
	return false

func later(delay:float,callback:Callable) -> void:
	if tasks.size()<256:tasks.append({"at":g.time+delay,"callback":callback})

func occupied(point:Vector2,width:float=60,height:float=35) -> bool:
	for brick in g.bricks+g.obstacles:
		if not brick.flags.get("orbit",false) and absf(brick.x-point.x)<width and absf(brick.y-point.y)<height:return true
	return false

func open_slots() -> Array:
	var result:Array=[]
	for row in range(10):
		for column in range(7):
			var point:=Vector2(102+column*96,170+row*60)
			if not occupied(point):result.append(point)
	return result

func spawn(point:Vector2,type:String="normal") -> void:
	if g.bricks.size()>=230 or occupied(point) or dying_at>=0:return
	var brick=g.make_brick({"x":point.x,"y":point.y,"type":type,"hp":g.base_hp(),"max":g.base_hp()})
	brick.flash=0.3;g.initial+=1;g.fx.burst(point,Color(COLORS[boss_id]),8);g.revision+=1

func banner(kicker:String,title:String,note:String="",tone:String="minor") -> void:
	notices=[{"key":str(g.time),"kind":"rift-callout","tone":tone,"kicker":kicker,"title":title,"note":note,"until":g.time+2.4}]
	g.revision+=1

func contact(arrow:RefCounted,live:bool=true) -> void:
	if model!=null and fight.intro and not busy:model.contact(arrow,live)
func before_hit(brick:RefCounted,depth:int) -> bool:return model.before_hit(brick,depth) if model!=null else true
func destroyed(brick:RefCounted,depth:int) -> void:
	if model!=null and depth<70 and dying_at<0:model.destroyed(brick,depth)

func update(delta:float) -> void:
	if fight.is_empty() or g.phase=="draft":return
	if not fight.intro and g.phase=="ready":
		fight.intro=true;intro_at=g.time;g.locked_until=g.clock+(0.4 if g.reduced else 2.6)
		banner("WARNING",fight.name,"第 %d 相" % fight.phase);model.intro()
	var due:Array=[]
	var keep:Array=[]
	for task in tasks:
		if task.at<=g.time:due.append(task)
		else:keep.append(task)
	tasks=keep
	for task in due:task.callback.call()
	if not notices.is_empty() and notices[0].until<=g.time:notices=[];g.revision+=1
	if dying_at>=0:
		var age:float=g.time-dying_at
		if age>=1.3 and not exploded:
			exploded=true;g.fx.ring(model.focus(),Color(COLORS[boss_id]),1100);g.fx.burst(model.focus(),Color(COLORS[boss_id]),90,4);g.fx.flash=2;g.cue("shatter");g.cue("win")
		if age>=2.8:
			for brick in g.bricks.duplicate():g.hit(brick,1e12,99)
			g.clear()
		return
	model.update(delta)
	if not busy:fight.clock+=delta
	if fight.hp<=0:
		for arrow in g.arrows:g.fx.linger_trail(arrow)
		g.arrows.clear();tasks.clear();recent.clear()
		if fight.phase<fight.phases:
			fight.phase+=1;fight.max=ceil(g.damage()*(24+6*fight.phase));fight.hp=fight.max;fight.clock=0
			g.bricks.clear();g.obstacles.clear();g.layout();model.setup(false)
			g.phase="entering";g.board_entrance={"start":g.time,"end":g.time+1.3};shift_until=g.time+1.3;g.locked_until=g.clock+1.3
			banner("PHASE %d / %d" % [fight.phase,fight.phases],PHASES[boss_id][fight.phase-1],"", "rage" if rage else "shift")
		else:dying_at=g.time;model.calm();banner("COLLAPSE",fight.name+" · 崩解","","seal")
		g.fx.shake=16;g.fx.flash=1.4;g.fx.ring(model.focus(),Color(COLORS[boss_id]),900);g.hitstop(0.16);g.revision+=1

func serialize() -> Dictionary:
	if model!=null:model.persist()
	return fight.duplicate(true)
