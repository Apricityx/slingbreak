extends RefCounted
## 星渊巨蟒 GIF fixtures. Every frame runs the production 60 Hz controller; the
## script only places real arrow contacts and forces the authored move.
const Serpent=preload("res://src/bosses/serpent.gd")

static func setup(g:RefCounted,id:String) -> void:
	g.state.level=100;g.state.skillChosenLevel=100;g.state.bossOverride={"level":100,"boss":"serpent"};g.generate()
	g.phase="ready";g.board_entrance=null
	var d:RefCounted=g.bosses
	if id=="serpent_twin":d.fight.phase=3;d.model.setup(false)
	g.time=0;g.clock=0;g.presentation_time=0;g.fx.reset();g.pointer=Vector2(390,720)
	d.fight.intro=id!="serpent_intro";d.intro_at=-6
	if id!="serpent_intro":d.model.reveal()
	# Moves that wait for a low head start with it near the launcher.
	if id in ["serpent_coil","serpent_devour","serpent_break"]:d.model.snakes[0].s=Serpent.bottom_s()+60
	d.model.next_at=1000

## A short real arrow segment from just outside the target, through it.
static func shot(g:RefCounted,to:Vector2,direction:Vector2=Vector2.UP) -> void:
	var from:=to-direction.normalized()*34
	var arrow:RefCounted=g.launch(from,direction.normalized()*40);g.arrows.erase(arrow)
	g.active_arrow=arrow;g.bosses.contact(arrow,true);g.active_arrow=null

static func break_scale(g:RefCounted,brick:RefCounted) -> void:
	var arrow:RefCounted=g.launch(brick.position+Vector2(0,40),Vector2(0,-30));g.arrows.erase(arrow)
	g.active_arrow=arrow;g.hit(brick,1e9);g.active_arrow=null

static func step(entry:Dictionary,time:float) -> void:
	var g:RefCounted=entry.g;var d:RefCounted=g.bosses;var m:RefCounted=d.model
	while float(entry.get("elapsed",0))+1.0/60<=time+0.00001:
		var at:float=float(entry.get("elapsed",0));entry.elapsed=at+1.0/60
		script(entry,g,d,m,at)
		if m.next_at<500 and m.move.is_empty() and not m.exposed():m.next_at=1000
		g.update(1.0/60)
		if g.phase=="clearing" or g.phase=="draft":g.phase="ready"

static func once(entry:Dictionary,key:String,ready:bool) -> bool:
	if not ready or entry.get(key,false):return false
	entry[key]=true;return true

static func head(m:RefCounted,index:int=0) -> Vector2:
	if m.snakes.size()<=index or m.snakes[index].hidden[0]==1:return Vector2(NAN,NAN)
	return m.snakes[index].points[0]

static func script(entry:Dictionary,g:RefCounted,d:RefCounted,m:RefCounted,at:float) -> void:
	match entry.id:
		"serpent_break":
			for i in range(4):
				if once(entry,"scale%d" % i,at>=0.5+i*0.45):
					var visible:Array=m.scales().filter(func(b):return b.position.x>-100)
					if not visible.is_empty():d.fight.data.armor=minf(d.fight.data.armor,45.0);break_scale(g,visible[0])
			for i in range(3):
				if once(entry,"head%d" % i,at>=2.6+i*0.55) and m.exposed() and not is_nan(head(m).x):shot(g,head(m))
		"serpent_coil":
			if once(entry,"begin",at>=0.2):m.begin("coil")
			if once(entry,"hit",at>=1.3) and m.move.get("stage","")=="aim":shot(g,head(m),(head(m)-g.origin).normalized()*-1)
			if once(entry,"punish",at>=2.8) and m.exposed():shot(g,head(m))
		"serpent_dive":
			if once(entry,"begin",at>=0.2):m.begin("dive")
			var gate:Dictionary=m.snakes[0].gate
			if once(entry,"yank",at>=2.2) and gate.get("kind","")=="dive" and m.head_hidden(m.snakes[0]):shot(g,Serpent.at(gate.a+gate.j))
		"serpent_devour":
			if once(entry,"begin",at>=0.2):m.begin("devour")
			for i in range(3):
				if once(entry,"maw%d" % i,at>=1.7+i*0.45) and m.move.get("stage","")=="maw":shot(g,head(m))
		"serpent_eclipse":
			if once(entry,"begin",at>=0.2):m.begin("eclipse")
			for i in range(2):
				if once(entry,"dark%d" % i,at>=1.9+i*0.8) and m.move.get("stage","")=="dark" and not is_nan(head(m).x):shot(g,head(m))
		"serpent_twin":
			if once(entry,"begin",at>=0.2):m.begin("twin")
			if once(entry,"cut",at>=3.0) and m.move.get("stage","")=="split":
				var knot:Vector2=m.knot()
				if not is_nan(knot.x):shot(g,knot,(head(m,1)-head(m,0)).orthogonal())
		"serpent_phase":
			if once(entry,"break",at>=0.6):d.fight.hp=0
		"serpent_death":
			if once(entry,"break",at>=0.4):d.fight.phase=4;d.fight.hp=0
