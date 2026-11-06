extends SceneTree
## 星渊巨蟒 redesign contract: a plated body that deflects, weak scales that
## drain the armour into a topple, one readable counter per move, a gate-to-gate
## phase shift and save-stable scales.
const Sim=preload("res://src/core/simulation.gd")
const Serpent=preload("res://src/bosses/serpent.gd")
const Surface=preload("res://src/render/serpent_surface.gd")
const Progress=preload("res://src/core/progress.gd")
const Audio=preload("res://src/audio/sound_engine.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func advance(g:RefCounted,seconds:float) -> void:
	for i in range(ceili(seconds*60)):
		g.clock+=1.0/60;g.tick(1.0/60);g.presentation_time=g.time
func fresh(phase:int=1) -> RefCounted:
	var g:=Sim.new();g.start(9128)
	g.state.level=100;g.state.skillChosenLevel=100;g.state.bossOverride={"level":100,"boss":"serpent"};g.generate();g.phase="ready"
	var d:RefCounted=g.bosses
	if phase>1:d.fight.phase=phase;d.model.setup(false)
	g.time=10;d.fight.intro=true;d.intro_at=0;d.model.reveal();d.model.next_at=1000
	return g
func arrow_at(g:RefCounted,from:Vector2,velocity:Vector2) -> RefCounted:
	var arrow:RefCounted=g.launch(from,velocity);g.arrows.erase(arrow)
	return arrow
## A short arrow segment ending just past the target.
func shoot(g:RefCounted,to:Vector2,direction:Vector2=Vector2.UP) -> RefCounted:
	var arrow:=arrow_at(g,to-direction.normalized()*34,direction.normalized()*40)
	g.active_arrow=arrow;g.bosses.model.contact(arrow,true);g.active_arrow=null
	return arrow
func break_scale(g:RefCounted,brick:RefCounted) -> void:
	g.active_arrow=arrow_at(g,brick.position+Vector2(0,40),Vector2(0,-30));g.hit(brick,1e9);g.active_arrow=null

func run() -> void:
	var g:=fresh();var d:RefCounted=g.bosses;var m:RefCounted=d.model
	check(m.scales().size()==Serpent.SCALES[0],"phase one rides three weak scales")
	check(m.snakes.size()==1 and m.snakes[0].count==Serpent.LENGTHS[0],"one serpent of the phase length")
	check(g.bricks.all(func(b):return b.type=="scale" or Serpent.in_island(b.position,Vector2(b.w,b.h))),"masonry stays on the island inside the river")
	check(d.intro_seconds()==Serpent.INTRO_SECONDS and m.shift_seconds()==Serpent.SHIFT_SECONDS,"serpent owns its intro and shift timing")
	# The plated body deflects an arrow crossing between two bare segments.
	var snake:Dictionary=m.snakes[0];var k:=-1
	for index in range(6,snake.count-2):
		if snake.hidden[index]==0 and snake.hidden[index+1]==0 and not snake.scaled.has(index) and not snake.scaled.has(index+1):k=index;break
	var mid:Vector2=snake.points[k].lerp(snake.points[k+1],0.5)
	var side:Vector2=(snake.points[k+1]-snake.points[k]).orthogonal().normalized()
	var before:float=d.fight.hp
	var bounce:=arrow_at(g,mid+side*40,-side*30)
	m.contact(bounce,true)
	check(bounce.velocity.dot(-side)<0,"a plated segment deflects an arrow")
	check(d.fight.hp==before,"a plate clink deals no damage")
	# Breaking weak scales drains the armour into a topple.
	var hp:float=d.fight.hp
	break_scale(g,m.scales()[0])
	check(d.fight.hp<hp and d.fight.data.armor<=64,"a broken weak scale hurts and drains the armour")
	check(m.scales().size()==Serpent.SCALES[0]-1 and m.regrow_queue.size()==1,"a broken scale queues a single regrow")
	d.fight.data.armor=20.0;break_scale(g,m.scales()[0])
	check(m.exposed() and d.fight.data.armor==0.0,"an empty armour topples the serpent")
	check(m.status().state=="exposed" and Surface.pose(g).front==-1.0,"topple exposes the whole body")
	advance(g,0.6)
	hp=d.fight.hp;shoot(g,m.snakes[0].points[0])
	check(d.fight.hp<hp and m.struck_at==g.time,"the toppled head takes the strike")
	advance(g,Serpent.BREAK_SECONDS+Serpent.REFILL_SECONDS)
	check(not m.exposed() and d.fight.data.armor>=99,"armour re-forms after the break")
	# Coil: a head hit during the aim interrupts the strike.
	g=fresh();d=g.bosses;m=d.model;m.snakes[0].s=Serpent.bottom_s()+60;m.locate(0)
	m.begin("coil");advance(g,0.1)
	check(m.move.stage=="aim","coil aims once the head is low")
	shoot(g,m.snakes[0].points[0])
	check(m.exposed() and m.move.is_empty(),"hitting the coiled head interrupts and topples")
	# An unanswered coil lunges and restores armour.
	g=fresh();d=g.bosses;m=d.model;m.snakes[0].s=Serpent.bottom_s()+60;m.locate(0);d.fight.data.armor=50.0
	m.begin("coil");advance(g,2.0)
	check(not m.exposed() and d.fight.data.armor>=74,"a missed counter lets the lunge restore armour")
	# Dive: shooting the exit gate yanks the serpent out.
	g=fresh();d=g.bosses;m=d.model;m.begin("dive")
	snake=m.snakes[0];g.time+=0.01;snake.s=snake.gate.a+Serpent.SPACING*2;m.locate(0)
	check(m.head_hidden(snake),"the head swims underground after the entry gate")
	shoot(g,Serpent.at(snake.gate.a+snake.gate.j))
	check(m.exposed() and snake.gate.is_empty(),"an arrow through the exit gate yanks the serpent out")
	# Devour and eclipse count head hits up to their topple.
	for spec in [["devour","maw",3],["eclipse","dark",2]]:
		g=fresh();d=g.bosses;m=d.model;m.snakes[0].s=Serpent.bottom_s()+60;m.locate(0)
		m.begin(spec[0]);advance(g,0.1)
		check(m.move.stage==spec[1],"%s opens its %s stage" % [spec[0],spec[1]])
		for i in range(spec[2]):
			check(not m.exposed(),"%s holds before hit %d" % [spec[0],i+1])
			shoot(g,m.snakes[0].points[0]);g.time+=0.3;m.locate(0)
		check(m.exposed(),"%s topples after %d head hits" % [spec[0],spec[2]])
	# Twin: cutting the tether between the heads topples both.
	g=fresh(4);d=g.bosses;m=d.model;m.begin("twin");advance(g,1.4)
	check(m.move.stage=="split" and m.snakes.size()==2,"twin splits the serpent in two")
	var knot:Vector2=m.knot()
	check(not is_nan(knot.x),"the twin heads share a visible knot")
	shoot(g,knot,(m.snakes[1].points[0]-m.snakes[0].points[0]).orthogonal())
	check(m.exposed() and m.snakes.size()==1,"cutting the tether topples and rejoins the serpent")
	# Phase shift: the old serpent dives into a gate as a ghost.
	g=fresh();d=g.bosses;m=d.model;d.fight.hp=0;advance(g,Serpent.SHIFT_DELAY+0.2)
	check(d.fight.phase==2 and not m.ghosts.is_empty(),"phase shift leaves the old serpent diving as a ghost")
	check(m.snakes[0].count==Serpent.LENGTHS[1],"the new serpent grows with the phase")
	# Save and restore keep the armour and the surviving scales.
	g=fresh();d=g.bosses;m=d.model;break_scale(g,m.scales()[0]);d.fight.data.armor=42.0
	var saved:Dictionary=g.export_progress().state
	check(Progress.valid_boss(saved.nativeBoss,saved.level),"serpent save passes validation")
	var restored:=Sim.new();restored.start(9128);restored.state=saved.duplicate(true);restored.generate(true)
	check(restored.bosses.boss_id=="serpent" and restored.bosses.fight.data.armor==42.0,"restore keeps the armour")
	var segments:=func(sim:RefCounted) -> Array:
		var list:Array=sim.bosses.model.scales().map(func(b):return int(b.flags.segment));list.sort();return list
	check(segments.call(restored)==segments.call(g),"restore keeps the surviving weak scales")
	# Sampled score: recorded stems replace the sequencer and follow the fight.
	var credits:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/serpent-credits.json"))
	check(credits.license=="CC0-1.0" and credits.samples.size()==3 and credits.samples.all(func(s):return s.loop and s.author!="" and FileAccess.file_exists("res://assets/"+s.file)),"serpent stems ship CC0 sources and authors")
	g=fresh();d=g.bosses;m=d.model;d.intro_at=g.time
	var audio:=Audio.new();root.add_child(audio);audio.set_process(false);audio.simulation=g
	var music:Node=audio.serpent_music
	for i in range(30):audio._process(0.05)
	check(audio.music_key=="serpent:sampled" and not audio.scheduled.any(func(v):return v.music),"serpent bypasses the synthesized sequencer")
	check(music.stems.size()==3 and music.stems[0].playing and music.stems[0].stream.loop and not music.stems[1].playing,"the intro opens on the looping stalk stem")
	g.time+=Serpent.INTRO_SECONDS
	for i in range(80):audio._process(0.05)
	check(music.levels[1]>0.5 and music.levels[0]<0.01 and not music.stems[0].playing,"phase one crossfades into the hunt stem and retires the stalk")
	audio.paused=true;audio._process(0.1)
	check(music.stems.all(func(p):return p.stream_paused or not p.playing),"pause holds the stems")
	audio.paused=false
	d.fight.data.armor=1.0;break_scale(g,m.scales()[0])
	var ducked:float=music.levels[1]
	for i in range(3):audio._process(0.1)
	check(m.exposed() and music.levels[1]<ducked and audio.filter_target<1000,"a topple ducks the hunt stem and closes the low-pass")
	g=fresh(3);audio.simulation=g;g.bosses.intro_at=-100
	for i in range(80):audio._process(0.05)
	check(music.levels[2]>0.5 and music.levels[1]<0.01 and music.stems[2].playing,"phase three hands the fight to the frenzy stem")
	g.bosses.dying_at=g.time;g.time+=2.4
	for i in range(10):audio._process(0.1)
	check(music.levels.all(func(l):return l<0.01),"death fades every stem")
	g.state.sound=false;audio._process(0.1)
	check(music.stems.all(func(p):return not p.playing),"mute retires the serpent stems")
	audio.shutdown();audio.queue_free();await process_frame
	print("Native serpent: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
