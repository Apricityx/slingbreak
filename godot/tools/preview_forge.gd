extends RefCounted
## 熔炉巨像 GIF fixtures. Every frame runs the production 60 Hz controller; the
## script only places real arrow contacts and forces the authored move.
const Forge=preload("res://src/bosses/forge.gd")

static func setup(g:RefCounted,id:String) -> void:
	g.state.level=100;g.state.skillChosenLevel=100;g.state.bossOverride={"level":100,"boss":"forge"};g.generate()
	g.phase="ready";g.board_entrance=null
	var d:RefCounted=g.bosses
	if id in ["forge_meltdown","forge_death"]:d.fight.phase=3;g.bricks.clear();g.obstacles.clear();g.layout();d.model.setup(false)
	g.time=0;g.clock=0;g.presentation_time=0;g.fx.reset();g.pointer=Vector2(390,720)
	d.fight.intro=id!="forge_intro";d.intro_at=-6
	d.model.next_at=1000
	if id=="forge_overheat":d.fight.data.heat=55.0

## A real contact: the arrow starts just short of target and flies into it.
static func shot(g:RefCounted,target:Vector2,from:Vector2=Vector2(0,60)) -> void:
	var arrow:RefCounted=g.launch(target+from,-from*0.9);g.arrows.erase(arrow)
	g.active_arrow=arrow;g.bosses.contact(arrow,true);g.active_arrow=null

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

static func script(entry:Dictionary,g:RefCounted,d:RefCounted,m:RefCounted,at:float) -> void:
	var live:bool=not m.move.is_empty()
	match entry.id:
		"forge_overheat":
			var fuel:Array=g.bricks.filter(func(b):return b.type=="magma")
			for i in range(2):
				if once(entry,"fuel%d" % i,at>=0.4+i*0.7) and not fuel.is_empty():
					g.active_arrow=g.launch(fuel[0].position+Vector2(0,40),Vector2(0,-20));g.arrows.erase(g.active_arrow)
					g.hit(fuel[0],1e9);g.active_arrow=null
			for i in range(3):
				if once(entry,"door%d" % i,at>=2.2+i*0.6) and m.exposed():shot(g,Forge.CENTER)
		"forge_slam":
			if once(entry,"begin",at>=0.2):m.begin("slam");m.move.side=0
			if once(entry,"fist",live and g.time>=m.move.live-0.35):shot(g,m.fist_point(0),Vector2(60,0))
		"forge_meteor":
			if once(entry,"begin",at>=0.2):m.begin("meteor")
			for i in range(m.globs.size()):
				var glob:Dictionary=m.globs[i]
				if once(entry,"glob%d" % roundi(glob.born*1000),not glob.dead and g.time>=glob.born+glob.flight*0.45):shot(g,m.glob_point(glob),Vector2(0,12))
		"forge_bellows":
			if once(entry,"begin",at>=0.2):m.begin("bellows");m.move.side=1
			if once(entry,"nozzle",live and g.time>=m.move.live+1.2):shot(g,Forge.SHOULDERS[1])
		"forge_palm":
			if once(entry,"begin",at>=0.2):m.begin("palm")
			for i in range(3):
				if once(entry,"socket%d" % i,live and m.palm_live() and g.time>=m.move.live+0.7+i*0.7):shot(g,Vector2(m.palm_x(),Forge.PALM_Y))
		"forge_pour":
			if once(entry,"begin",at>=0.2):m.begin("magma");m.move.side=1
			if once(entry,"spout",live and g.time>=m.move.live+1.6):shot(g,m.spout(),Vector2(0,-60))
		"forge_meltdown":
			if once(entry,"begin",at>=0.2):m.begin("meltdown")
			for i in range(3):
				if once(entry,"beat%d" % i,live and g.time>=m.move.live+m.beat_period()*(i+1)+0.05):shot(g,Forge.CENTER)
		"forge_phase":
			if once(entry,"break",at>=0.6):d.fight.hp=0
		"forge_death":
			if once(entry,"break",at>=0.4):d.fight.hp=0
