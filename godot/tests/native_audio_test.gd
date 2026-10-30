extends SceneTree
## Scheduling/routing checks use Godot players. They do not measure hardware latency.
const Audio=preload("res://src/audio/sound_engine.gd")
const Session=preload("res://src/core/session.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("_run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func _run() -> void:
	var baseline:=AudioServer.bus_count
	var audio:=Audio.new();root.add_child(audio);audio.set_process(false)
	var session:=Session.new();session.start(7281);audio.simulation=session.runtime
	session.changed.connect(audio.sync);session.sound_requested.connect(audio.play_requests)
	check(audio.available and audio.cues.size()==38,"all effect recipes load independently")
	check(audio.brick_explosion is AudioStreamWAV,"brick explosion uses a decoded WAV sample")
	check(audio.players.size()==96,"bounded Godot player pool")
	check(audio._sample("res://assets/audio/","../manifest.json")==null,"audio paths cannot escape the sample directory")
	var hit_variants:Array=[]
	for index in range(4):
		audio.scheduled.clear()
		audio.play_requests([{"type":"brick_hit","x":780}])
		check(audio.scheduled.size()==1,"surviving hit replaces both synthesized voices with one sample")
		var hit_voice:Dictionary=audio.scheduled[0]
		hit_variants.append(hit_voice.stream)
		check(hit_voice.stream is AudioStreamOggVorbis and hit_voice.stream.get_length()>0 and hit_voice.stream.get_length()<0.6,"light hit decodes with a short tail")
		check(hit_voice.bus=="SlingEffects" and hit_voice.pan>0 and is_equal_approx(hit_voice.volume,0.32) and is_equal_approx(hit_voice.at,audio.clock),"hit is immediate, dry, spatial and softer than break")
	check(hit_variants[0]!=hit_variants[1] and hit_variants[1]!=hit_variants[2] and hit_variants[0]!=hit_variants[2] and hit_variants[0]==hit_variants[3],"three hit variants rotate without immediate repetition")
	audio.scheduled.clear()
	audio.play_requests([{"type":"tap","ui":true}])
	check(audio.scheduled.size()==2 and audio.scheduled.all(func(v):return v.ui and not hit_variants.has(v.stream)),"UI tap retains its original synthesized pair")
	var variants:Array=[]
	for index in range(4):
		audio.scheduled.clear()
		audio.play_requests([{"type":"brick_break","n":17,"x":0}])
		check(audio.scheduled.size()==3,"normal break has one sampled impact and two combo notes")
		var impact:Dictionary=audio.scheduled[0]
		variants.append(impact.stream)
		check(impact.stream is AudioStreamOggVorbis and impact.stream.get_length()>0 and impact.stream.get_length()<1.5,"stone impact decodes with a short bounded tail")
		check(impact.bus=="SlingEffects" and impact.pan<0 and is_equal_approx(impact.volume,0.55),"stone impact is dry, attenuated and spatial")
		var notes:Array=audio.cues["break"][17].slice(2)
		for note_index in range(2):
			var voice:Dictionary=audio.scheduled[note_index+1]
			check(voice.stream==audio._sample("res://assets/audio/",notes[note_index].file) and is_equal_approx(voice.at,audio.clock+notes[note_index].delay),"combo pitch and timing preserved")
	check(variants[0]!=variants[1] and variants[1]!=variants[2] and variants[0]!=variants[2] and variants[0]==variants[3],"three distinct impact variants rotate without immediate repetition")
	audio.scheduled.clear()
	audio.play_requests([{"type":"break","n":1}])
	check(audio.scheduled.size()==4,"special bricks retain their original four-voice break recipe")
	audio.scheduled.clear()
	var g:RefCounted=session.runtime
	g.sounds.clear();g.last_sounds.clear();g.phase="aiming";g.threshold=9999
	var brick:RefCounted=g.make_brick({"x":200,"y":200,"hp":1,"type":"normal"})
	g.hit(brick,2)
	check(g.sounds.any(func(v):return v.type=="brick_break") and not g.sounds.any(func(v):return v.type=="break"),"normal brick destruction requests sampled break")
	g.cue("break")
	check(not g.sounds.any(func(v):return v.type=="break"),"normal and special breaks share the existing throttle")
	g.sounds.clear();g.last_sounds.clear()
	for type in ["normal","bomb"]:
		var survivor:RefCounted=g.make_brick({"x":100,"y":100,"hp":10,"type":type})
		g.hit(survivor,1)
		check(survivor.hp==9 and g.bricks.has(survivor) and g.sounds.size()==1 and g.sounds[0].type=="brick_hit","surviving brick requests only sampled hit: "+type)
		g.hit(survivor,1)
		check(survivor.hp==8 and g.sounds.size()==1,"30 ms hit throttle does not suppress damage")
		g.cue("tap")
		check(g.sounds.size()==1,"hit shares existing tap throttle")
		g.clock+=0.031;g.hit(survivor,1)
		check(g.sounds.size()==2,"hit cue resumes after 30 ms")
		g.bricks.erase(survivor);g.sounds.clear();g.last_sounds.clear()
	audio.play_requests([{"type":"tap","x":0,"ui":false},{"type":"reroll","ui":true}])
	audio.play_requests([{"type":"bomb","x":412,"priority":true}])
	check(audio.scheduled.any(func(v):return v.stream==audio.brick_explosion and v.pan>0),"bomb cue schedules the brick explosion sample")
	check(audio.scheduled.any(func(v):return v.pan<0),"spatial effects preserve left pan")
	var ui_before:=audio.ui_played
	session.command("pause",{"paused":true})
	for i in range(60):audio._process(1.0/60)
	check(audio.ui_played>ui_before,"paused UI cues reach Godot players")
	check(audio.scheduled.any(func(v):return not v.ui),"paused gameplay cues remain held")
	check(audio.players.any(func(p):return p.playing and p.get_meta("ui",false) and not p.stream_paused),"UI output is not paused with the battlefield")
	session.command("pause",{"paused":false});audio._process(.1)
	check(not audio.scheduled.any(func(v):return v.bus=="SlingEffects" and v.at<=audio.clock),"resume releases due gameplay cues")
	for id in ["eye","serpent","clock"]:
		# This fast test advances game time without waiting for real AudioServer
		# playback. Release the prior fixture's players before starting a new one.
		for player in audio.players:player.stop()
		audio.scheduled.clear();audio.music_key=""
		session.command("enterBoss",{"id":id})
		var music_before:=audio.music_played
		for step in range(600):session.update(1.0/60);audio._process(1.0/60)
		check(audio.music_played>music_before+10,"adaptive score schedules native voices "+id)
		check(audio.cache_bytes<=audio.CACHE_BYTES and audio.scheduled.size()<=256,"cache and schedule remain bounded "+id)
		var frozen_step:=audio.music_step
		session.command("pause",{"paused":true})
		for step in range(60):audio._process(1.0/60)
		check(audio.music_step==frozen_step,"pause holds score timeline "+id)
		session.command("pause",{"paused":false})
		var before_transition:=audio.transition_voices
		session.runtime.bosses.model.stunned_until=session.runtime.time+2
		if id=="serpent":session.runtime.bosses.model.snakes[0].mode="stun"
		audio._process(.1)
		check(audio.transition_voices>before_transition,"stun schedules the score's native chord "+id)
		before_transition=audio.transition_voices
		session.runtime.bosses.dying_at=session.runtime.time;audio._process(.1)
		check(audio.music_key.ends_with(":dying"),"death changes score mood "+id)
		check(audio.transition_voices>before_transition,"collapse schedules riser, crash and stinger "+id)
		var step_before:=audio.music_step
		var gain_before:=audio.music_gain
		audio._process(1.0)
		check(audio.music_gain<gain_before,"collapse fades music gain "+id)
		check(audio.music_step>step_before and audio.music_mood=="dying","collapse advances time without playing regular notes "+id)
	session.command("configure",{"volume":0})
	check(audio.scheduled.is_empty() and not audio.players.any(func(p):return p.playing),"mute retires queued and playing voices")
	check(audio.failure=="","all requested Vorbis instruments decode")
	audio.shutdown();audio.queue_free();await process_frame
	check(AudioServer.bus_count==baseline,"owned audio buses are released")
	print("Native audio: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
