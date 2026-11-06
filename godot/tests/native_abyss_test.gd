extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
const Audio=preload("res://src/audio/sound_engine.gd")
const Pattern=preload("res://src/bosses/eye_pattern.gd")
const Rig=preload("res://src/render/abyss_rig.gd")
const Events=preload("res://src/effects/abyss_events.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func advance(g:RefCounted,seconds:float) -> void:
	for i in range(ceili(seconds*60)):
		g.clock+=1.0/60;g.tick(1.0/60);g.presentation_time=g.time
func run() -> void:
	var events:=Events.new()
	for i in range(10000):events.emit("seal_hit",Vector2(i,92),10,Vector2.DOWN)
	check(events.events.size()==Events.CAPACITY and events.serial==10000,"ten thousand simultaneous impulses respect the bounded event budget")
	events.reset();events.emit("ward",Rig.CENTER,10);events.emit("ward",Rig.CENTER,10.02)
	check(events.events.size()==1,"clustered ward contacts coalesce within 45 milliseconds")
	events.emit("ward",Rig.CENTER,10.05)
	check(events.events.size()==2,"later contact retains its own impulse")
	events.advance(10.5)
	check(events.events.is_empty(),"short contact tails expire completely")
	events.emit("cast",Rig.CENTER,11);events.emit("seal_hit",Rig.CENTER,11);events.interrupt()
	check(events.events.size()==1 and events.events[0].kind=="seal_hit","interrupt cancels charge but retains contact aftermath")
	events.reset()
	check(events.events.is_empty() and events.serial==0,"reset clears both events and deterministic seed counter")
	var g:=Sim.new();g.start(9128)
	g.state.level=100;g.state.skillChosenLevel=100;g.state.bossOverride={"level":100,"boss":"eye"};g.generate();g.phase="ready"
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	d.fight.intro=true;d.intro_at=-4;g.time=10
	check(d.fight.abilities==[["orbit","tear"],["gaze","mirage","summon"],["gaze","orbit","doom"]],"authored escalation teaches seal before mirage and finale")
	m.begin("gaze")
	check(m.visuals.events.any(func(e):return e.kind=="cast" and e.ability=="gaze"),"production gaze emits its anticipation")
	var angle:float=m.beam_angle();g.time+=Pattern.ANTICIPATION-0.1;m.update(Pattern.ANTICIPATION-0.1)
	check(is_equal_approx(angle,m.beam_angle()) and not m.move.sounded,"gaze stays locked through the whole charge")
	g.time+=0.2;m.update(0.2)
	check(m.move.sounded and g.sounds.any(func(v):return v.type=="eye_beam"),"beam sound starts at the actual live boundary")
	check(m.visuals.events.filter(func(e):return e.kind=="release").size()==1,"release VFX shares the sound's live boundary")
	m.update(0)
	check(m.visuals.events.filter(func(e):return e.kind=="release").size()==1,"live release is emitted only once")
	m.calm();m.begin("doom");g.time+=0.9
	var probe:RefCounted=g.launch(m.center+Vector2(0,55),Vector2(0,-24));var before_probe:int=m.visuals.serial
	m.contact(probe,false);g.arrows.clear()
	check(m.visuals.serial==before_probe and m.move.hits==0,"prediction-only contacts never emit an impact or seal hit")
	for i in range(3):
		var arrow:RefCounted=g.launch(m.center+Vector2(0,55),Vector2(0,-24))
		m.contact(arrow,true);g.time+=0.2
		check(m.exposed()==(i==2),"doom requires exactly three valid pupil contacts: "+str(i))
	check(m.move.is_empty() and d.fight.data.ward==0 and m.stunned_until-g.time>5,"doom break cancels cast and grants extended punish window")
	check(g.sounds.any(func(v):return v.type=="eye_break"),"break uses its sampled impact")
	check(m.visuals.events.any(func(e):return e.kind=="break") and m.visuals.events.any(func(e):return e.kind=="seal_hit"),"real third collision retains the hit and independent break tail after move cancellation")
	g.time=m.refill_until+0.1;m.update(0.1)
	check(d.fight.data.ward==100,"seal recovers after punish window")
	var saved:Dictionary=g.export_progress()
	check(preload("res://src/core/progress.gd").valid(saved),"authored ability lists retain save compatibility")
	var audio:=Audio.new();root.add_child(audio);audio.set_process(false);audio.simulation=g
	for cue in Audio.SAMPLED_CUES:
		if not cue.begins_with("eye_"):continue
		audio.scheduled.clear();audio.play_requests([{"type":cue,"priority":true,"x":0}])
		check(audio.scheduled.size()==1 and audio.scheduled[0].stream is AudioStreamOggVorbis,"sample decodes without synthetic duplicate: "+cue)
	audio.scheduled.clear();audio._process(0.1)
	var score:AudioStreamPlayer=audio.abyss_music.score
	check(score.playing and score.stream is AudioStreamSynchronized and score.stream.stream_count==5,"five orchestral stems share one synchronized player")
	check(range(5).all(func(i):var stem:AudioStream=score.stream.get_sync_stream(i);return stem is AudioStreamOggVorbis and stem.loop),"every stem is a looping sampled Vorbis stream")
	var lengths:=range(5).map(func(i):return snappedf(score.stream.get_sync_stream(i).get_length(),0.01))
	check(lengths.all(func(l):return l==lengths[0] and l>30),"stems are equal length so the layers cannot drift")
	check(not audio.scheduled.any(func(v):return v.music),"legacy synthesized eye score is bypassed")
	audio.paused=true;audio._process(0.1)
	var stinger:AudioStreamPlayer=audio.abyss_music.stinger
	check(score.stream_paused and (not stinger.playing or stinger.stream_paused),"pause holds the score and its stingers")
	audio.paused=false;m.stunned_until=g.time+4
	m.stunned_until=0
	for step in range(30):audio._process(0.1)
	m.stunned_until=g.time+4
	var before:float=audio.abyss_music.levels[1];audio._process(0.3)
	check(audio.abyss_music.levels[1]<before and audio.abyss_music.levels[4]>0.1,"exposure ducks the pulse and opens the daze layer")
	audio.last_sampled_cues.clear();audio.play_requests([{"type":"eye_charge"}]);audio._process(0.01)
	check(audio.players.any(func(p):return p.playing and p.get_meta("cue","")=="eye_charge"),"charge sample is active before interrupt")
	audio.play_requests([{"type":"eye_break","priority":true}])
	check(not audio.players.any(func(p):return p.playing and p.get_meta("cue","")=="eye_charge"),"breaking seal retires sustained charge sample")
	# Exercise the actual phase controller, not a fixture that sets phase_at.
	m.stunned_until=0;m.move.clear();g.arrows.clear();g.phase="ready";g.clock=g.time;g.presentation_time=g.time
	var old_brick:RefCounted=g.bricks[0];var old_position:Vector2=old_brick.position
	d.fight.hp=0;advance(g,1.0/60)
	var phase_event:Dictionary=m.visuals.events[0]
	old_brick.x+=100
	check(phase_event.kind=="phase" and phase_event.masonry.size()<=96 and phase_event.masonry[0].position==old_position,"phase snapshots bounded value-only masonry independent of discarded bricks")
	check(d.fight.phase==2 and d.busy and g.phase=="entering","phase depletion starts the full cinematic lock")
	check(is_equal_approx(d.shift_until-m.phase_at,Rig.SHIFT_SECONDS),"animation and gameplay share one 3.4-second deadline")
	check(g.bricks.any(func(b):return b.y==170) and g.obstacles.all(func(b):return b.h==44),"phase change preserves the original board layout and obstacle size")
	check(m.center==Vector2(390,92) and Rig.WARD_RADIUS==57 and Rig.PUPIL_RADIUS==43,"relic keeps the original origin and collider sizes")
	check(not g.shoot(0,100),"input cannot launch into the cinematic")
	var hp:float=d.fight.hp;d.hurt(1e6,m.center)
	check(d.fight.hp==hp,"delayed damage cannot skip the next phase while molting")
	advance(g,0.9)
	var closed:Dictionary=Rig.pose(g)
	check(closed.opening<0.01 and closed.spread>0.3,"closing lids precede shell separation")
	check(closed.size==1 and closed.lift==0,"phase animation never enlarges or displaces the model")
	var frozen:float=g.time;var paused_pose:=Rig.pose(g);var paused_events:Array=m.visuals.events.duplicate(true)
	g.paused=true
	for i in range(30):g.update(1.0/60)
	check(g.time==frozen and Rig.pose(g)==paused_pose,"pause freezes every phase-animation channel")
	check(m.visuals.events==paused_events,"pause preserves event ages and outgoing board imprints")
	g.paused=false;g.sounds.clear();advance(g,0.8)
	check(m.phase_revealed and g.sounds.filter(func(v):return v.type=="eye_awaken").size()==1,"reveal cue fires once at the authored rupture boundary")
	check(g.board_entrance.start>g.time,"masonry waits until after the reveal")
	advance(g,1.8)
	check(not d.busy and g.phase=="ready" and g.board_entrance==null,"cinematic completes before control returns")
	check(m.visuals.events.is_empty(),"phase event and masonry snapshot expire at cinematic end")
	check(Rig.pose(g).opening>0.95 and Rig.pose(g).stage==2,"new form settles to the complete second-stage pose")
	g.arrows.clear();d.fight.hp=0;advance(g,1.0/60)
	advance(g,Rig.SHIFT_SECONDS+0.1)
	check(d.fight.phase==3 and Rig.pose(g).stage==3 and not d.busy,"final-stage transformation settles independently")
	var rng_state:int=g.rng.state
	for i in range(100):
		m.visuals.emit("hit",m.center,g.time);m.visuals.impulse(g.time);Rig.pose(g)
	check(g.rng.state==rng_state,"animation sampling cannot consume gameplay RNG")
	var restored:=Sim.new();restored.start(71,JSON.parse_string(JSON.stringify(g.export_progress())))
	check(restored.bosses.fight.phase==3 and restored.bosses.model.phase_at<0,"loading a completed phase does not replay transformation")
	check(restored.bosses.model.visuals.events.is_empty(),"restore never replays old visual events")
	restored.dispose()
	var legacy:Dictionary=g.export_progress()
	var saved_brick:Dictionary=legacy.state.board.bricks[0]
	restored=Sim.new();restored.start(72,JSON.parse_string(JSON.stringify(legacy)))
	check(restored.bricks[0].y==saved_brick.y and restored.bricks[0].hp==saved_brick.hp,"visual redesign preserves saved brick positions and HP")
	var again:=Sim.new();again.start(73,JSON.parse_string(JSON.stringify(restored.export_progress())))
	check(again.bricks[0].y==restored.bricks[0].y and again.bricks[0].h==restored.bricks[0].h,"reloading does not resize the board")
	again.dispose();restored.dispose()
	g.state.sound=false;audio._process(0.1)
	check(not score.playing and not audio.abyss_music.stinger.playing,"mute retires the dedicated score")
	m.calm();m.next_at=1000;g.arrows.clear();d.fight.hp=0;advance(g,1.0/60);advance(g,1.4)
	check(d.exploded and m.visuals.events.any(func(e):return e.kind=="death"),"death aftermath survives the model's disappearance")
	advance(g,1.15)
	check(m.visuals.events.is_empty(),"Director expires death events even while model updates are stopped")
	audio.shutdown();audio.queue_free();g.dispose();await process_frame
	print("Native abyss: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
