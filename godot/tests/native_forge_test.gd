extends SceneTree
## 熔炉巨像 redesign contract: a clear silhouette with regrowing fuel, a sealed
## door fed by heat, one venting counter per move, failures that cool and armour,
## and save-stable state.
const Sim=preload("res://src/core/simulation.gd")
const Forge=preload("res://src/bosses/forge.gd")
const Surface=preload("res://src/render/forge_surface.gd")
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
	g.state.level=100;g.state.skillChosenLevel=100;g.state.bossOverride={"level":100,"boss":"forge"};g.generate();g.phase="ready"
	var d:RefCounted=g.bosses
	if phase>1:d.fight.phase=phase;g.bricks.clear();g.obstacles.clear();g.layout();d.model.setup(false)
	g.time=10;g.presentation_time=10;d.fight.intro=true;d.intro_at=0;d.model.next_at=1000
	return g
## An arrow just below target, flying up into it.
func shot(g:RefCounted,target:Vector2,from:Vector2=Vector2(0,60)) -> RefCounted:
	var arrow:RefCounted=g.launch(target+from,-from*0.9);g.arrows.erase(arrow)
	return arrow
func fire(g:RefCounted,target:Vector2,from:Vector2=Vector2(0,60)) -> RefCounted:
	var arrow:=shot(g,target,from)
	g.active_arrow=arrow;g.bosses.model.contact(arrow,true);g.active_arrow=null
	return arrow

func run() -> void:
	var g:=fresh();var d:RefCounted=g.bosses;var m:RefCounted=d.model
	check(g.bricks.all(func(b):return b.type=="magma" or not m.on_body(b.position,Vector2(b.w,b.h))),"no masonry overlaps the colossus")
	check(g.obstacles.all(func(w):return not m.on_body(w.position,Vector2(w.w,w.h))),"no wall overlaps the colossus")
	check(m.fuel_count()==2,"phase one opens with two fuel bricks")
	var third:=fresh(3)
	check(third.bosses.model.fuel_count()==4,"phase three stokes all four fuel slots")
	check(third.obstacles.all(func(w):return Forge.FUEL.all(func(p):return w.position.distance_to(p)>=8)),"fuel slots displace random obstacles")
	third.dispose()
	check(d.intro_seconds()==Forge.INTRO_SECONDS and m.shift_seconds()==Forge.SHIFT_SECONDS,"forge owns its intro and shift timing")
	# Sealed door: a ping, a bounce and no heat.
	var arrow:=fire(g,Forge.CENTER)
	check(arrow.velocity.y>0 and m.heat()==0.0 and not m.exposed(),"the sealed door deflects without heat")
	# Fuel bricks stoke the furnace until it vents.
	var fuel:RefCounted=g.bricks.filter(func(b):return b.type=="magma")[0]
	g.active_arrow=shot(g,fuel.position);m.destroyed(fuel,0);g.active_arrow=null
	check(m.heat()==24.0,"a broken fuel brick adds twenty-four heat")
	m.add_heat(80,Forge.CENTER)
	check(m.exposed() and m.heat()==100.0,"a full gauge vents the furnace")
	var hp:float=d.fight.hp;fire(g,Forge.CENTER)
	check(d.fight.hp<hp and m.struck_at==g.time,"the open furnace takes the strike")
	m.add_heat(10,Forge.CENTER);check(m.heat()==100.0,"no heat is banked while vented")
	g.time=m.stunned_until+0.6;m.update(1.0/60)
	check(not m.exposed() and m.heat()<100 and m.heat()>0 and m.status().text=="封炉中","the door reseals and the gauge drains")
	advance(g,m.refill_until+0.1-g.time)
	check(m.heat()==0.0,"refill ends with an empty gauge")
	# Hammer: an armed fist vents; once landed the slam cools and slags.
	g=fresh();d=g.bosses;m=d.model;m.begin("slam");g.time=m.move.start+0.6
	var fist:Vector2=m.fist_point(m.move.side)
	check(fist.y<Forge.FISTS[m.move.side].y-20,"the hammer fist rises while winding up")
	fire(g,fist,Vector2(60*(1 if m.move.side==0 else -1),0));check(m.exposed(),"hitting the raised fist vents")
	g=fresh();d=g.bosses;m=d.model;m.add_heat(30,Forge.CENTER);m.begin("slam")
	var plates:int=g.bricks.filter(func(b):return b.type=="plate").size()
	advance(g,m.move.live-g.time+0.1)
	check(m.heat()<=10.5 and g.bricks.filter(func(b):return b.type=="plate").size()>plates,"a landed hammer cools the furnace and lays slag")
	# Spit: every glob caught in the air vents.
	g=fresh();d=g.bosses;m=d.model;m.begin("meteor")
	for glob in m.globs:
		g.time=glob.born+glob.flight*0.5;fire(g,m.glob_point(glob),Vector2(0,12))
	check(m.exposed(),"catching every glob vents the furnace")
	# Bellows: the open shoulder vents, its draft pushes arrows sideways.
	g=fresh();d=g.bosses;m=d.model;m.begin("bellows");g.time=m.move.live+1.0;m.update(1.0/60)
	check(absf(d.wind)>0 and signf(d.wind)==(1.0 if m.move.side==0 else -1.0),"the bellows blows away from its shoulder")
	fire(g,Forge.SHOULDERS[m.move.side]);check(m.exposed() and d.wind==0.0,"shooting the open bellows vents and stills the draft")
	g=fresh(2);d=g.bosses;m=d.model;g.presentation_time=g.time;fire(g,Forge.SHOULDERS[0])
	check(m.heat()==8.0 and Surface.pose(g).bellows.x>0.9,"phase-two bellows pump heat between moves")
	# Iron palm: three socket hits vent; the knuckle bars deflect.
	g=fresh();d=g.bosses;m=d.model;m.begin("palm");g.time=m.move.live+0.5
	var bar:=fire(g,Vector2(m.palm_x()+50,Forge.PALM_Y+4))
	check(bar.velocity.y>0 and m.move.hits==0,"knuckle bars deflect without counting")
	for i in range(3):g.time+=0.25;fire(g,Vector2(m.palm_x(),Forge.PALM_Y))
	check(m.exposed(),"three palm socket hits vent")
	# Pour: hitting the tipped spout cuts the stream.
	g=fresh();d=g.bosses;m=d.model;m.begin("magma");g.time=m.move.live+0.5;g.presentation_time=g.time
	check(absf(Surface.pose(g).tilt)>0.2,"the crucible tips toward its spout")
	fire(g,m.spout(),Vector2(0,-60));check(m.exposed(),"the spout counter vents")
	# Meltdown: only lit heartbeats count; three vent for longer.
	g=fresh(3);d=g.bosses;m=d.model;m.begin("meltdown");g.time=m.move.live+0.45
	fire(g,Forge.CENTER);check(m.move.hits==0,"a dark beat does not count")
	for i in range(3):g.time=m.move.live+m.beat_period()*(i+1)+0.05;fire(g,Forge.CENTER)
	check(m.exposed() and is_equal_approx(m.stunned_until-g.time,5.5),"three lit beats vent for five and a half seconds")
	g=fresh(3);d=g.bosses;m=d.model;m.begin("meltdown")
	plates=g.bricks.filter(func(b):return b.type=="plate").size()
	advance(g,m.move.end-g.time+0.1)
	check(m.move.is_empty() and m.heat()==0.0 and g.bricks.filter(func(b):return b.type=="plate").size()>plates,"a missed meltdown erupts, empties the gauge and armours the board")
	# Fuel regrows into empty slots.
	g=fresh();d=g.bosses;m=d.model
	for b in g.bricks.filter(func(b):return b.type=="magma"):g.bricks.erase(b)
	advance(g,6.0)
	check(m.fuel_count()>=1,"spent fuel reforms in its slot")
	# Save and restore keep the encounter valid without a format change.
	d.fight.data.heat=42.0
	var saved:Dictionary=g.export_progress().state
	check(Progress.valid_boss(saved.nativeBoss,saved.level),"forge save passes validation")
	var restored:=Sim.new();restored.start(9128);restored.state=saved.duplicate(true);restored.generate(true)
	check(restored.bosses.boss_id=="forge" and restored.bosses.fight.data.heat==42.0,"restore keeps the heat gauge")
	check(restored.bosses.model.fuel_count()==m.fuel_count(),"restore keeps the fuel bricks")
	# Sampled score: recorded stems over a furnace bed replace the sequencer.
	var credits:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/forge-credits.json"))
	check(credits.license=="CC0-1.0" and credits.samples.size()==4 and credits.samples.all(func(s):return s.loop and s.author!="" and s.sha256.length()==64 and FileAccess.file_exists("res://assets/"+s.file)),"forge stems ship CC0 sources, authors and hashes")
	g=fresh();d=g.bosses;m=d.model;d.intro_at=g.time
	var audio:=Audio.new();root.add_child(audio);audio.set_process(false);audio.simulation=g
	var music:Node=audio.forge_music
	audio._process(0.05);audio._process(0.05)
	check(audio.filter_target<2000,"ignition opens on a closed low-pass")
	for i in range(30):audio._process(0.05)
	check(audio.music_key=="forge:sampled" and not audio.scheduled.any(func(v):return v.music),"forge bypasses the synthesized sequencer")
	check(music.stems.size()==4 and music.stems[0].playing and music.stems[1].playing and music.stems.all(func(p):return p.stream==null or p.stream.loop) and not music.stems[2].playing,"ignition lights the furnace bed under the smoulder stem")
	g.time+=Forge.INTRO_SECONDS
	for i in range(60):audio._process(0.05)
	check(music.levels[1]>0.5 and is_equal_approx(audio.filter_target,18000),"phase one settles on the open smoulder stem")
	var cold:float=music.levels[0];d.fight.data.heat=100.0
	for i in range(60):audio._process(0.05)
	check(music.levels[0]>cold+0.2,"the furnace bed follows the heat gauge")
	audio.paused=true;audio._process(0.1)
	check(music.stems.all(func(p):return p.stream_paused or not p.playing),"pause holds the stems")
	audio.paused=false;m.stunned_until=g.time+4
	var roar:float=music.levels[0];var ducked:float=music.levels[1]
	for i in range(4):audio._process(0.1)
	check(music.levels[0]>roar and music.levels[1]<ducked,"an open furnace roars over a ducked fight stem")
	m.stunned_until=0;m.begin("meltdown")
	for i in range(60):audio._process(0.05)
	check(music.levels[3]>0.6 and music.levels[1]<0.01 and not music.stems[1].playing,"meltdown hands the score to the inferno stem")
	m.move.clear();d.fight.phase=2;d.shift_until=g.time+Forge.SHIFT_SECONDS
	for i in range(50):audio._process(0.05)
	check(music.levels[0]>0.4 and music.stems.slice(1).all(func(p):return not p.playing),"a phase shift drops to the furnace bed alone")
	g.time=d.shift_until
	for i in range(60):audio._process(0.05)
	check(music.levels[2]>0.5 and music.stems[2].playing,"phase two enters on the stoke stem")
	g=fresh(3);audio.simulation=g;g.bosses.intro_at=-100
	for i in range(80):audio._process(0.05)
	check(music.levels[3]>0.5 and music.levels[2]<0.01 and not music.stems[2].playing,"phase three hands the fight to the inferno stem")
	g.bosses.dying_at=g.time;g.time+=2.4
	for i in range(10):audio._process(0.1)
	check(music.levels.slice(1).all(func(l):return l<0.01) and audio.filter_target<600,"death fades the music and closes the low-pass")
	g.time+=1.0
	for i in range(10):audio._process(0.1)
	check(music.levels[0]<0.01,"the furnace embers die last")
	g.state.sound=false;audio._process(0.1)
	check(music.stems.all(func(p):return not p.playing),"mute retires the forge stems")
	audio.shutdown();audio.queue_free();await process_frame
	print("Native forge: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
