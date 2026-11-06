extends SceneTree
## 时之君主 redesign contract: an open dial, a drainable lit numeral, a stall
## pose clear of the launch lane, a rod that blocks, and save-stable state.
const Sim=preload("res://src/core/simulation.gd")
const Clock=preload("res://src/bosses/clock.gd")
const Surface=preload("res://src/render/clock_surface.gd")
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
func fresh() -> RefCounted:
	var g:=Sim.new();g.start(9128)
	g.state.level=100;g.state.skillChosenLevel=100;g.state.bossOverride={"level":100,"boss":"clock"};g.generate();g.phase="ready"
	return g
func arrow_at(g:RefCounted,from:Vector2,velocity:Vector2) -> RefCounted:
	var arrow:RefCounted=g.launch(from,velocity);g.arrows.erase(arrow)
	return arrow

func run() -> void:
	var g:=fresh();var d:RefCounted=g.bosses;var m:RefCounted=d.model
	var hours:Array=g.bricks.filter(func(b):return b.type=="hour")
	check(hours.size()==12,"twelve numeral plaques ring the dial")
	check(g.bricks.all(func(b):return b.type=="hour" or not m.on_face(b.position,Vector2(b.w,b.h))),"no masonry overlaps the bezel")
	check(g.obstacles.all(func(w):return not m.on_face(w.position,Vector2(w.w,w.h))),"no wall overlaps the bezel")
	check(m.lit_plaque()!=null and m.lit_plaque().flags.hourIndex==m.hour_index,"the hour hand starts on a lit plaque")
	check(d.intro_seconds()==Clock.INTRO_SECONDS and m.shift_seconds()==Clock.SHIFT_SECONDS,"clock owns its intro and shift timing")
	g.time=10;d.fight.intro=true;d.intro_at=g.time;g.presentation_time=g.time
	check(d.busy,"intro holds the fight while the dial assembles")
	var pose:Dictionary=Surface.pose(g)
	check(pose.rise==0.0,"dial starts untraced at intro")
	g.time+=Clock.INTRO_SECONDS+0.1;g.presentation_time=g.time
	check(not d.busy and Surface.pose(g).rise==1.0,"intro releases with the dial fully risen")
	# Drain the spring through the lit numeral until the movement stalls.
	var lit:RefCounted=m.lit_plaque()
	g.active_arrow=arrow_at(g,lit.position+Vector2(0,60),Vector2(0,-8))
	var before:float=d.fight.data.spring
	m.before_hit(lit,0)
	check(d.fight.data.spring==before-20,"hitting the lit plaque drains twenty")
	d.fight.data.spring=15.0;m.before_hit(lit,0)
	check(m.exposed() and d.fight.data.spring==0.0,"a drained mainspring stalls the movement")
	check(m.status().state=="exposed","stall exposes the core")
	for i in range(60):m.update(1.0/60);g.time+=1.0/60;g.presentation_time=g.time
	var lane:Callable=func(angle:float) -> bool:return Vector2.from_angle(angle).y<-0.5
	check(lane.call(m.minute) and lane.call(m.hour),"stalled hands open upward, clear of the launch lane")
	check(Surface.pose(g).stall>0.9,"stall envelope blooms on the dial")
	var strike:=arrow_at(g,Clock.CENTER+Vector2(0,60),Vector2(0,-50))
	var hp:float=d.fight.hp;m.contact(strike,true)
	check(d.fight.hp<hp and m.struck_at==g.time,"an exposed core takes the strike")
	# Pendulum: the swinging rod is a collider.
	g=fresh();d=g.bosses;m=d.model;g.time=10;d.fight.intro=true;d.intro_at=0
	m.begin("pendulum");g.time=m.move.live+0.6
	var bob:Vector2=m.bob_point();var mid:Vector2=Clock.CENTER.lerp(bob,0.55)
	var side:Vector2=(bob-Clock.CENTER).normalized().orthogonal()
	var shot:=arrow_at(g,mid+side*20,-side*16)
	m.contact(shot,true)
	check(shot.velocity.dot(-side)<0,"the pendulum rod deflects a crossing arrow")
	check(m.move.hits==0,"a rod deflection does not count as a bob hit")
	# A destroyed lit numeral reforms so there is always a target.
	g=fresh();d=g.bosses;m=d.model;g.time=10;d.fight.intro=true;d.intro_at=0;m.next_at=1000
	g.bricks.erase(m.lit_plaque())
	advance(g,1.0)
	check(m.lit_plaque()==null,"lit plaque waits before reforming")
	advance(g,1.0)
	check(m.lit_plaque()!=null,"lit plaque reforms after 1.6 seconds")
	# Save and restore keep the encounter valid without a format change.
	d.fight.data.spring=42.0
	var saved:Dictionary=g.export_progress().state
	check(Progress.valid_boss(saved.nativeBoss,saved.level),"clock save passes validation")
	var restored:=Sim.new();restored.start(9128);restored.state=saved.duplicate(true);restored.generate(true)
	check(restored.bosses.boss_id=="clock" and restored.bosses.fight.data.spring==42.0,"restore keeps the mainspring")
	check(restored.bricks.filter(func(b):return b.type=="hour").size()==g.bricks.filter(func(b):return b.type=="hour").size(),"restore keeps the numeral plaques")
	# Sampled score: sample-locked VSCO-2-CE stems replace the sequencer.
	var credits:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/clock-credits.json"))
	check(credits.license=="CC0-1.0" and credits.sources.size()>50 and credits.sources.all(func(s):return s.sha256.length()==64 and s.source.contains(credits.collections[0].get_file())),"clock score ships pinned CC0 sources and hashes")
	check(credits.outputs.size()==8 and credits.outputs.all(func(o):return FileAccess.file_exists("res://assets/"+o.file)),"every rendered stem and stinger ships")
	check(credits.outputs.filter(func(o):return o.loop).all(func(o):return is_equal_approx(o.duration,32.0)),"loop stems share one 16-bar length")
	g=fresh();d=g.bosses;m=d.model;d.intro_at=g.time
	var audio:=Audio.new();root.add_child(audio);audio.set_process(false);audio.simulation=g
	var music:Node=audio.clock_music
	for i in range(20):audio._process(0.05)
	check(audio.music_key=="clock:sampled" and not audio.scheduled.any(func(v):return v.music),"clock bypasses the synthesized sequencer")
	check(music.bed.playing and music.stream is AudioStreamSynchronized and music.stream.stream_count==5,"five stems play locked in one synchronized stream")
	check(music.levels[0]<0.01 and music.levels[3]>0.4 and audio.filter_target<3000,"the dial assembles over bells before the escapement starts")
	check(music.cue.playing and music.cue.get_meta("cue")=="windup","the intro winds the mainspring")
	g.time+=Clock.INTRO_SECONDS
	for i in range(60):audio._process(0.05)
	check(music.levels[0]>0.5 and music.levels[1]>0.4 and is_equal_approx(audio.filter_target,18000),"phase one ticks over the gear-train")
	audio.paused=true;audio._process(0.1)
	check(music.bed.stream_paused,"pause holds the stems")
	audio.paused=false;m.frozen=[g.launch(Vector2(390,1500),Vector2(0,-900))]
	for i in range(30):audio._process(0.05)
	check(music.pitch<0.65 and music.levels[0]<0.05 and audio.filter_target<1000,"time stop sags the movement like a stopped tape")
	m.frozen.clear();m.begin("rewind")
	for i in range(30):audio._process(0.05)
	check(music.levels[4]>0.5 and music.levels[1]<0.05 and music.pitch>0.95,"rewind hands the score to the reversed stem")
	m.move={"id":"haste","live":g.time,"start":g.time,"end":g.time+5}
	for i in range(30):audio._process(0.05)
	check(music.pitch>1.08 and music.levels[4]<0.05,"haste winds the movement faster")
	m.move={};m.jam(m.center,"test")
	for i in range(4):audio._process(0.1)
	check(music.levels[0]<0.1 and music.levels[3]>0.4 and music.cue.get_meta("cue")=="strike","a stall stops the escapement and strikes the hour")
	m.stunned_until=0;d.dying_at=g.time;g.time+=2.0
	for i in range(10):audio._process(0.1)
	check(music.levels.all(func(l):return l<0.01) and music.cue.get_meta("cue")=="unwind" and music.pitch<0.8,"death unwinds the movement")
	g.state.sound=false;audio._process(0.1)
	check(not music.bed.playing and not music.cue.playing,"mute retires the clock stems")
	audio.shutdown();audio.queue_free();await process_frame
	print("Native clock: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
