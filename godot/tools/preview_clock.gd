extends RefCounted
## 时之君主 GIF fixtures. Every frame runs the production 60 Hz controller; the
## script only places real arrow contacts and forces the authored move.
const Clock=preload("res://src/bosses/clock.gd")

static func setup(g:RefCounted,id:String) -> void:
	g.state.level=100;g.state.skillChosenLevel=100;g.state.bossOverride={"level":100,"boss":"clock"};g.generate()
	g.phase="ready";g.board_entrance=null
	var d:RefCounted=g.bosses
	if id in ["clock_midnight","clock_haste"]:d.fight.phase=3 if id=="clock_midnight" else 2;d.model.setup(false)
	g.time=0;g.clock=0;g.presentation_time=0;g.fx.reset();g.pointer=Vector2(390,720)
	d.fight.intro=id!="clock_intro";d.intro_at=-6
	d.model.next_at=1000

static func shot(g:RefCounted,from:Vector2,to:Vector2) -> void:
	var arrow:RefCounted=g.launch(from,(to-from).normalized()*minf(40,from.distance_to(to)));g.arrows.erase(arrow)
	g.active_arrow=arrow
	var brick:RefCounted=null
	for b in g.bricks:
		if b.position.distance_to(to)<8:brick=b
	if brick!=null:g.hit(brick,arrow.damage)
	else:g.bosses.contact(arrow,true)
	g.active_arrow=null

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
	var core:=Clock.CENTER+Vector2(0,70)
	match entry.id:
		"clock_stall":
			for i in range(3):
				if once(entry,"lit%d" % i,at>=0.4+i*0.55) and m.lit_plaque()!=null:
					d.fight.data.spring=minf(d.fight.data.spring,40.0)
					shot(g,m.lit_plaque().position+Vector2(0,70),m.lit_plaque().position)
			for i in range(3):
				if once(entry,"core%d" % i,at>=2.2+i*0.7) and m.exposed():shot(g,core,Clock.CENTER)
		"clock_pendulum":
			if once(entry,"begin",at>=0.2):m.begin("pendulum")
			for i in range(3):
				if once(entry,"bob%d" % i,at>=2.0+i*0.9) and not m.move.is_empty():
					var bob:Vector2=m.bob_point();shot(g,bob+Vector2(0,60),bob)
			if once(entry,"core",at>=5.6) and m.exposed():shot(g,core,Clock.CENTER)
		"clock_stop":
			if once(entry,"begin",at>=0.2):m.begin("stop")
			if once(entry,"key",at>=2.0) and not m.move.is_empty():shot(g,m.move.target+Vector2(0,60),m.move.target)
		"clock_toll":
			if once(entry,"begin",at>=0.2):m.begin("toll")
			if once(entry,"bell",at>=2.4) and not m.move.is_empty():shot(g,m.bell_point()+Vector2(0,60),m.bell_point())
		"clock_rewind":
			for b in g.bricks.duplicate():
				if b.type!="hour" and once(entry,"break%d" % b.get_instance_id(),at>=0.2 and b.y<300):m.destroyed(b,0);g.bricks.erase(b)
			if once(entry,"begin",at>=0.8):m.begin("rewind")
			if once(entry,"case",at>=2.6) and not m.move.is_empty():shot(g,core,Clock.CENTER)
		"clock_haste":
			if once(entry,"begin",at>=0.2):m.begin("haste")
			if once(entry,"lit",at>=2.4) and m.lit_plaque()!=null:shot(g,m.lit_plaque().position+Vector2(0,70),m.lit_plaque().position)
		"clock_midnight":
			if once(entry,"begin",at>=0.2):m.begin("midnight")
			for i in range(3):
				if once(entry,"case%d" % i,at>=1.8+i*0.6) and not m.move.is_empty():shot(g,core,Clock.CENTER)
		"clock_phase":
			if once(entry,"break",at>=0.6):d.fight.hp=0
		"clock_death":
			if once(entry,"break",at>=0.4):d.fight.phase=3;d.fight.hp=0
