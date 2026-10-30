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
