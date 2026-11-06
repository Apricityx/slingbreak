extends SceneTree
## V5 Abyss Eye contract: twelve-crystal ward, gaze counter / sweep, star tears
## and save migration, all driven through the real launcher and fixed tick.
const Sim=preload("res://src/core/simulation.gd")
const Audio=preload("res://src/audio/sound_engine.gd")
const Progress=preload("res://src/core/progress.gd")
const Pattern=preload("res://src/bosses/eye_pattern.gd")
const Rig=preload("res://src/render/abyss_rig.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func game(seed:int=9128) -> RefCounted:
	var g:=Sim.new();g.start(seed)
	g.state.level=100;g.state.skillChosenLevel=100;g.state.bossOverride={"level":100,"boss":"eye"};g.generate()
	g.phase="ready";g.board_entrance=null;g.bosses.fight.intro=true;g.bosses.intro_at=-4
	g.bosses.model.next_at=1000;g.bosses.fight.hp=10000;g.bosses.fight.max=10000
	return g
func empty(g:RefCounted) -> void:g.bricks.clear();g.obstacles.clear()
func advance(g:RefCounted,seconds:float) -> void:
	for i in range(ceili(seconds*60)):
		g.clock+=1.0/60;g.tick(1.0/60);g.presentation_time=g.time
func until(g:RefCounted,done:Callable,seconds:float) -> bool:
	for i in range(ceili(seconds*60)):
		if done.call():return true
		advance(g,1.0/60)
	return done.call()
func aim(g:RefCounted,point:Vector2) -> bool:return g.shoot((g.origin-point).normalized().x*100,(g.origin-point).normalized().y*100)
func run() -> void:
	var g:=game();var m:RefCounted=g.bosses.model
	check(m.modern() and int(g.bosses.fight.data.encounterVersion)==Pattern.VERSION,"fresh encounter runs the V5 contract")
	check(m.pick()=="orbit" and m.crystals()==12,"phase one opens on the orbital seal with twelve crystals")
	# A real central shot chips crystals; one arrow can never strip the ward alone.
	empty(g);var hp:float=g.bosses.fight.hp
	check(aim(g,m.center),"ward shot uses the real launcher")
	check(until(g,func():return m.visuals.events.any(func(e):return e.kind=="ward"),1.5),"chips emit ward events for the crystal flash")
	advance(g,2.0)
	var lost:int=12-m.crystals()
	check(lost>=1 and lost<=Pattern.CHIP_LIMIT and not m.exposed(),"direct contact chips 1..%d crystals, got %d" % [Pattern.CHIP_LIMIT,lost])
	check(g.bosses.fight.hp<hp,"each chip leaves a small wound")
	g.dispose()
	# Gaze: a pupil hit during the charge interrupts before any brick changes.
	g=game();m=g.bosses.model;empty(g)
	g.make_brick({"x":102,"y":530,"hp":100,"max":100})
	m.begin("gaze")
	check(m.move.live-m.move.start>=2.0 and m.counter_open()==false,"gaze lock has a readable anticipation before the pupil opens")
	advance(g,0.5)
	check(m.counter_open() and not m.sweeping() and m.status().state=="exposed","pupil opens to a counter during the charge")
	check(aim(g,m.center),"counter shot launches from the normal origin")
	check(until(g,func():return m.exposed(),1.6),"real flight into the open pupil dazes the eye")
	check(m.move.is_empty() and absf(m.stunned_until-g.time-4)<0.1,"counter cancels the sweep and grants the full window")
	check(g.sounds.any(func(c):return c.type=="eye_laser_stop") and not g.sounds.any(func(c):return c.type=="eye_laser"),"interrupt stops the cast before the beam sample")
	check(g.bricks.all(func(b):return b.type=="normal"),"no petrification after a counter")
	hp=g.bosses.fight.hp;g.phase="ready";g.next_shot_at=0;check(aim(g,m.center),"punish shot launches while dazed")
	advance(g,1.4);check(g.bosses.fight.hp<hp,"dazed pupil takes punish damage")
	g.dispose()
	# Gaze failure: one bounded sweep petrifies a few bricks and keeps geometry.
	g=game();m=g.bosses.model
	var snapshot:Dictionary={}
	for b in g.bricks:snapshot[b.id]=[b.position,b.w,b.h,b.type]
	var count:int=g.bricks.size();m.begin("gaze")
	advance(g,Pattern.ANTICIPATION-0.05)
	check(g.bricks.all(func(b):return b.type==snapshot[b.id][3]),"charge never writes the board")
	advance(g,0.1)
	check(m.sweeping() and g.sounds.any(func(c):return c.type=="eye_laser"),"sweep starts with the sampled laser")
	var first_angle:float=m.beam_angle()
	for i in range(int(Pattern.SWEEP*60)-8):
		advance(g,1.0/60)
		var end:Vector2=m.beam_endpoint()
		if end.y>Pattern.BEAM_FLOOR+0.5 or end.x<19.5 or end.x>760.5:check(false,"beam leaves the board at %s" % end);break
	check(absf(m.beam_angle()-first_angle)>Pattern.ARC*1.6,"beam sweeps across the board")
	advance(g,Pattern.RECOVERY+0.3)
	var changed:=0
	for b in g.bricks:
		var old:Array=snapshot[b.id]
		check([b.position,b.w,b.h]==old.slice(0,3),"petrify preserves geometry: %d" % b.id)
		if old[3]!=b.type:changed+=1;check(old[3]=="normal" and b.type=="hydra","only normal bricks petrify")
	check(changed>=1 and changed<=Pattern.PETRIFY_LIMIT,"sweep petrifies a bounded set, got %d" % changed)
	check(g.bricks.size()==count and m.move.is_empty(),"sweep spawns nothing and recovers cleanly")
	check(g.sounds.any(func(c):return c.type=="eye_laser_stop"),"recovery retires the laser voice")
	g.dispose()
	# The beam burns arrows that sit in it.
	g=game();m=g.bosses.model;empty(g);m.begin("gaze");advance(g,Pattern.ANTICIPATION+Pattern.SWEEP*0.5)
	check(aim(g,Vector2(390,500)),"arrow launched into the beam")
	var arrow:RefCounted=g.arrows[0]
	arrow.position=m.center+Vector2.from_angle(m.beam_angle())*200;arrow.pierce=3;advance(g,1.0/60)
	check(arrow.pierce<=0 or not g.arrows.has(arrow),"beam burns an arrow in its path")
	g.dispose()
	tears()
	migration()
	endings()
	await audio()
	await music()
	print("Native eye V5: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
func tears() -> void:
	# Landed tears restore the seal and leave a little hydra masonry.
	var g:=game();var m:RefCounted=g.bosses.model
	m.begin("tear");g.bosses.fight.data.ward=50.0
	check(m.move.tears.size()==Pattern.TEARS and m.live_tears().is_empty(),"three tears gather before they fall")
	var lanes:Array=m.move.tears.map(func(t):return t.x)
	check(lanes.size()==3 and lanes[0]!=lanes[1] and lanes[1]!=lanes[2] and lanes[0]!=lanes[2],"each tear owns its own lane")
	var hydra:int=g.bricks.filter(func(b):return b.type=="hydra").size()
	check(until(g,func():return m.move.is_empty(),8),"uncaught tear cast resolves")
	check(m.move.is_empty() and g.bosses.fight.data.ward>50.0+Pattern.TEARS*10,"landed tears restore the ward")
	check(g.bricks.filter(func(b):return b.type=="hydra").size()>=hydra and g.bricks.size()<=228,"landed tears regrow bounded masonry")
	g.dispose()
	# Catching every tear through real arrow contact always breaks the seal.
	g=game();m=g.bosses.model;empty(g);m.begin("tear")
	for i in range(Pattern.TEARS):
		var tear:Dictionary=m.move.tears[i]
		until(g,func():return g.time>=tear.at+0.3,4)
		check(tear.state=="fall","tear %d is still falling before the catch" % i)
		g.next_shot_at=0;g.phase="ready"
		check(aim(g,m.tear_point(tear)),"tear catch shot %d" % i)
		var arrow:RefCounted=g.arrows[g.arrows.size()-1]
		var target:Vector2=m.tear_point(tear)+Vector2(0,30)
		arrow.position=target;arrow.previous=target
		advance(g,1.0/60)
		check(tear.state=="caught","real contact catches tear %d" % i)
		if i<Pattern.TEARS-1:check(not m.exposed(),"a single tear only weakens the seal")
		for a in g.arrows.duplicate():a.pierce=0
	check(m.exposed() and m.move.is_empty(),"the third caught tear dazes the eye")
	g.dispose()
func migration() -> void:
	# V4 (and older) saves resume on the V5 pools with phase and cursor kept.
	var g:=game();var m:RefCounted=g.bosses.model
	g.bosses.fight.phase=2;m.begin("gaze")
	check(m.pick()=="mirage","accepted gaze advances the phase-two sequence")
	m.calm();advance(g,0.1)
	var payload:Dictionary=JSON.parse_string(JSON.stringify(g.export_progress()))
	check(Progress.valid(payload),"V5 progress validates across JSON")
	var restored:=Sim.new();restored.start(1,payload)
	check(restored.bosses.model.pick()=="mirage" and restored.bosses.model.move.is_empty(),"restore resumes the next authored beat")
	check(restored.bosses.model.visuals.events.is_empty(),"restore replays no transient events")
	restored.dispose()
	payload.state.nativeBoss.data.encounterVersion=4
	payload.state.nativeBoss.abilities=[["orbit","summon"],["gaze","mirage"],["doom"]]
	check(Progress.valid(payload),"V4 saves still validate")
	restored=Sim.new();restored.start(2,payload)
	var fight:Dictionary=restored.bosses.fight
	check(int(fight.data.encounterVersion)==Pattern.VERSION and fight.abilities[1]==["gaze","mirage","summon"],"V4 save migrates to V5 pools")
	check(int(fight.phase)==2 and restored.bosses.model.pick()=="mirage","migration keeps phase and authored cursor")
	check(restored.bricks.size()==g.bricks.size(),"migration preserves saved masonry")
	restored.dispose()
	payload.state.nativeBoss.data.encounterVersion=3;payload.state.nativeBoss.data.sequence={"1":-1}
	check(not Progress.valid(payload),"invalid sequence rejected before restore")
	g.dispose()
func endings() -> void:
	# Pause freezes the sweep; phase change and death retire the beam at once.
	for ending in ["phase","death"]:
		var g:=game();var m:RefCounted=g.bosses.model
		m.begin("gaze");advance(g,Pattern.ANTICIPATION+0.3)
		var held:float=g.time;var angle:float=m.beam_angle()
		g.paused=true
		for i in range(120):g.update(1.0/60)
		check(g.time==held and m.beam_angle()==angle,"pause freezes the sweep: "+ending)
		g.paused=false;g.sounds.clear()
		var types:Dictionary={}
		for b in g.bricks:types[b.id]=b.type
		if ending=="death":g.bosses.fight.phase=3
		g.bosses.fight.hp=0;advance(g,1.0/60)
		check(m.move.is_empty() and g.sounds.any(func(c):return c.type=="eye_laser_stop"),"transition cancels the sweep and its sample: "+ending)
		advance(g,1)
		check(g.bricks.all(func(b):return not types.has(b.id) or types[b.id]==b.type or b.type!="hydra"),"no orphan petrification after "+ending)
		g.dispose()
func audio() -> void:
	var audio:=Audio.new();root.add_child(audio);audio.set_process(false)
	for cue in ["eye_lock","eye_laser","eye_infect","eye_hit","eye_break"]:
		audio.scheduled.clear();audio.play_requests([{"type":cue,"priority":true}])
		check(audio.scheduled.size()==1 and audio.scheduled[0].stream is AudioStreamOggVorbis,"decoded real sample: "+cue)
	audio.scheduled.clear();audio.last_sampled_cues.clear();audio.play_requests([{"type":"eye_laser"}]);audio._process(0.01)
	check(audio.players.any(func(p):return p.playing and p.get_meta("cue","")=="eye_laser"),"sampled laser voice starts")
	audio.play_requests([{"type":"eye_laser_stop"}])
	check(not audio.players.any(func(p):return p.playing and p.get_meta("cue","")=="eye_laser"),"stop control cannot leave a sustained laser voice")
	var g:=game();var m:RefCounted=g.bosses.model;m.begin("gaze");advance(g,Pattern.ANTICIPATION+0.2);audio.simulation=g
	audio.last_sampled_cues.clear();audio.play_requests([{"type":"eye_laser"}]);audio._process(0.01)
	check(audio.players.any(func(p):return p.playing and p.get_meta("cue","")=="eye_laser"),"live sweep owns its laser voice")
	audio.sync({"paused":true});audio._process(0.01)
	check(audio.players.any(func(p):return p.stream_paused and p.get_stream_playback()!=null and p.get_meta("cue","")=="eye_laser"),"pause holds the active beam")
	audio.sync({"paused":false});g.dispose();audio._process(0.01)
	check(not audio.players.any(func(p):return p.playing and p.get_meta("cue","")=="eye_laser"),"session reset retires the laser")
	audio.simulation=null
	audio.shutdown();audio.queue_free();await process_frame
func music() -> void:
	var credits:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/eye-music-credits.json"))
	check(credits.license=="CC0-1.0" and credits.sources.size()>40 and credits.sources.all(func(s):return s.sha256.length()==64 and s.source.contains(credits.commit)),"score ships pinned CC0 VSCO-2-CE sources and hashes")
	var loops:Array=credits.outputs.filter(func(o):return o.loop)
	check(loops.size()==5 and credits.outputs.size()==7 and credits.outputs.all(func(o):return FileAccess.file_exists("res://assets/"+o.file)),"five stems and two stingers ship")
	check(loops.all(func(o):return o.frames==loops[0].frames),"stems share one sample-exact length")
	var audio:=Audio.new();root.add_child(audio);audio.set_process(false)
	var music:Node=audio.abyss_music
	var g:=game();var d:RefCounted=g.bosses;var m:RefCounted=d.model;audio.simulation=g
	for i in range(20):audio._process(0.05)
	check(audio.music_key=="eye:sampled" and music.score.playing and not music.stinger.playing,"fight opens on the stems without a stinger")
	check(music.levels[0]>0.5 and music.levels[1]>0.3 and music.levels[3]<0.05,"phase one carries bed and pulse, the theme waits")
	m.begin("gaze");advance(g,m.move.live-g.time-0.5)
	for i in range(10):audio._process(0.05)
	check(music.levels[2]>0.7 and music.levels[1]<0.2,"gaze charge thins the pulse under the starlight")
	advance(g,m.move.live-g.time-0.05)
	for i in range(6):audio._process(0.02)
	check(music.levels.all(func(l):return l<0.2),"the score drops out just before the sweep fires")
	advance(g,0.3)
	for i in range(10):audio._process(0.05)
	check(music.levels[3]>0.35,"the horn theme answers the sweep")
	m.move.clear();m.next_at=1000;g.arrows.clear();d.fight.hp=0;advance(g,1.0/60);audio._process(0.01)
	check(d.fight.phase==2 and music.stinger.playing and music.stinger.stream==music.cues.get("shift"),"a live phase shift fires the rupture stinger")
	for i in range(20):audio._process(0.05)
	check(music.levels[0]<0.3 and music.levels[1]<0.05,"the stems duck under the stinger")
	advance(g,Rig.SHIFT_SECONDS+0.5);m.next_at=1000;m.move.clear();m.refill_until=0;m.stunned_until=0
	for i in range(40):audio._process(0.05)
	check(music.levels[3]>0.3 and music.levels[1]>0.5,"phase two blooms into the theme")
	audio.sync({"paused":true});audio._process(0.01)
	check(music.score.stream_paused and music.stinger.stream_paused,"pause holds the score")
	audio.sync({"paused":false});audio._process(0.01)
	d.fight.phase=d.fight.phases;m.move.clear();m.next_at=1000;g.arrows.clear();d.fight.hp=0;advance(g,1.0/60);audio._process(0.01)
	check(d.dying_at>=0 and music.stinger.playing and music.stinger.stream==music.cues.get("finale"),"collapse plays the finale once")
	advance(g,2.0)
	for i in range(40):audio._process(0.05)
	check(music.levels.all(func(l):return l<0.05),"stems fade out under the finale")
	g.dispose();audio._process(0.01)
	check(not music.score.playing and not music.stinger.playing,"leaving the fight stops the score")
	audio.simulation=null;audio.shutdown();audio.queue_free();await process_frame
