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
	for file in audio.BRICK_BOMB_FILES:
		var bomb_stream:=audio._sample("res://assets/audio/",file) as AudioStreamOggVorbis
		check(bomb_stream!=null and bomb_stream.get_length()>1.0 and bomb_stream.get_length()<1.3,"bomb variant is a bounded sampled Vorbis: "+file)
	check(audio.players.size()==96,"bounded Godot player pool")
	check(audio._sample("res://assets/audio/","../manifest.json")==null,"audio paths cannot escape the sample directory")
	var credits:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/credits.json"))
	check(credits.author=="Tuomo Untinen (Reemax)" and credits.license=="CC-BY 3.0" and credits.files.size()==2,"sampled launch/frost assets ship attribution and license")
	for fixture in [{"type":"shoot","file":"arrow-shoot.vorbis","gain":0.24,"duration":0.36,"interval":0.065},{"type":"frost","file":"frost-freeze.vorbis","gain":0.22,"duration":0.20,"interval":0.12}]:
		audio.scheduled.clear()
		audio.play_requests([{"type":fixture.type,"x":0,"priority":true}])
		check(audio.scheduled.size()==1,"sample replaces the complete synthetic recipe: "+fixture.type)
		var voice:Dictionary=audio.scheduled[0]
		check(voice.stream==audio._sample("res://assets/audio/",fixture.file) and absf(voice.stream.get_length()-fixture.duration)<0.01,"edited short sample decodes: "+fixture.type)
		check(voice.bus=="SlingEffects" and voice.pan<0 and voice.priority and is_equal_approx(voice.volume,fixture.gain),"sample keeps quiet dry routing, pan and priority: "+fixture.type)
		for index in range(40):audio.play_requests([{"type":fixture.type,"priority":true}])
		check(audio.scheduled.size()==1,"priority chains cannot stack sampled cue: "+fixture.type)
		var played_before:=audio.played
		audio.paused=true;audio._process(0.01)
		check(audio.played==played_before and audio.scheduled.size()==1,"paused battlefield holds sampled cue: "+fixture.type)
		audio.paused=false
		audio.clock+=fixture.interval+0.001
		audio.play_requests([{"type":fixture.type,"x":780}])
		check(audio.scheduled.size()==2 and audio.scheduled[1].pan>0,"sample resumes after density window: "+fixture.type)
		audio.sync({"soundEnabled":false})
		check(audio.scheduled.is_empty(),"mute clears sampled cue: "+fixture.type)
		audio.sync({"soundEnabled":true})
	audio.play_requests([{"type":"shatter"}])
	check(audio.scheduled.size()==audio.cues.shatter[1].size(),"generic shatter retains its existing recipe")
	audio.scheduled.clear()
	var hit_variants:Array=[]
	for index in range(4):
		audio.scheduled.clear()
		audio.play_requests([{"type":"brick_hit","x":780}])
		check(audio.scheduled.size()==1,"surviving hit replaces both synthesized voices with one sample")
		var hit_voice:Dictionary=audio.scheduled[0]
		hit_variants.append(hit_voice.stream)
		check(hit_voice.stream is AudioStreamOggVorbis and hit_voice.stream.get_length()>0 and hit_voice.stream.get_length()<0.6,"light hit decodes with a short tail")
		check(hit_voice.bus=="SlingEffects" and hit_voice.pan>0 and is_equal_approx(hit_voice.volume,0.22) and is_equal_approx(hit_voice.at,audio.clock),"hit is immediate, dry, spatial and softer than break")
	check(hit_variants[0]!=hit_variants[1] and hit_variants[1]!=hit_variants[2] and hit_variants[0]!=hit_variants[2] and hit_variants[0]==hit_variants[3],"three hit variants rotate without immediate repetition")
	audio.scheduled.clear()
	var ui_credits:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/ui-credits.json"))
	check(ui_credits.license=="CC0-1.0" and ui_credits.sources.size()==22 and ui_credits.sources.all(func(s):return s.sha256.length()==64),"sampled UI cues pin CC0 sources")
	var shipped:Array=ui_credits.outputs.map(func(o):return o.file)
	var ui_streams:Array=[]
	for type in audio.UI_CUES:
		var entry:Dictionary=audio.UI_CUES[type]
		for file in entry.get("files",entry.get("tiers",[])):
			var stream:=audio._sample("res://assets/audio/",file);ui_streams.append(stream)
			check(shipped.has(file) and stream is AudioStreamOggVorbis and stream.get_length()>0.02 and stream.get_length()<0.9,"UI sample decodes short and is credited: "+file)
		audio.scheduled.clear()
		audio.play_requests([{"type":type,"ui":true}])
		check(audio.scheduled.size()==1 and audio.scheduled[0].ui and audio.scheduled[0].bus=="SlingUI" and audio.scheduled[0].volume<=0.45,"UI cue plays one dry sampled voice: "+type)
	var taps:Array=[]
	for index in range(4):
		audio.scheduled.clear();audio.play_requests([{"type":"tap","ui":true}]);taps.append(audio.scheduled[0].stream)
	check(taps[0]!=taps[1] and taps[1]!=taps[2] and taps[0]==taps[3],"UI tap variants rotate")
	var picks:Array=[]
	for n in [0,1,2,9]:
		audio.scheduled.clear();audio.play_requests([{"type":"pick","n":n,"ui":true}]);picks.append(audio.scheduled[0].stream.get_length())
	check(picks[0]<picks[1] and picks[1]<picks[2] and picks[2]==picks[3],"pick sample grows with rarity and clamps")
	for type in ["tap","tick","gold","chime"]:
		audio.scheduled.clear()
		audio.play_requests([{"type":type,"ui":false}])
		check(audio.scheduled.size()==audio.cues[type][1].size() and not audio.scheduled.any(func(v):return ui_streams.has(v.stream)),"gameplay %s keeps its synthesized recipe" % type)
	audio.scheduled.clear()
	audio.play_requests([{"type":"upgrade"}])
	check(audio.scheduled.size()==1 and not audio.scheduled[0].ui and audio.scheduled[0].bus=="SlingEffects","gameplay reward uses the sampled upgrade cue")
	audio.scheduled.clear()
	var variants:Array=[]
	var pitches:Array=[]
	for index in range(5):
		audio.scheduled.clear()
		audio.play_requests([{"type":"brick_break","n":17,"x":0}])
		check(audio.scheduled.size()==3,"normal break has one sampled shatter and two combo notes")
		var impact:Dictionary=audio.scheduled[0]
		variants.append(impact.stream);pitches.append(impact.pitch)
		check(impact.stream is AudioStreamOggVorbis and absf(impact.stream.get_length()-0.26)<0.01,"layered shatter decodes with a short 260 ms tail")
		check(impact.bus=="SlingEffects" and impact.pan<0 and is_equal_approx(impact.volume,0.4),"layered shatter keeps a dry, attenuated spatial mix")
		var notes:Array=audio.cues["break"][17].slice(2)
		for note_index in range(2):
			var voice:Dictionary=audio.scheduled[note_index+1]
			check(voice.stream==audio._sample("res://assets/audio/",notes[note_index].file) and is_equal_approx(voice.at,audio.clock+notes[note_index].delay) and is_equal_approx(voice.pitch,1.0),"combo pitch and timing preserved")
	var distinct:=true
	for a in range(4):
		for b in range(a+1,4):distinct=distinct and variants[a]!=variants[b]
	check(distinct and variants[0]==variants[4],"four distinct shatter variants rotate without immediate repetition")
	check(pitches.all(func(p):return p>1.1 and p<1.2),"long combos lift shatter pitch within a narrow band")
	audio.scheduled.clear()
	audio.play_requests([{"type":"brick_break","n":1,"x":390}])
	check(absf(audio.scheduled[0].pitch-1.0)<0.04,"first break of a shot stays near natural pitch")
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
	var frost_brick:RefCounted=g.make_brick({"x":700,"y":200,"hp":1,"type":"frost"})
	g.hit(frost_brick,2)
	check(g.sounds.any(func(v):return v.type=="frost" and v.priority),"destroying frost brick requests sampled frost cue")
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
	var bomb_streams:Array=audio.BRICK_BOMB_FILES.map(func(file):return audio._sample("res://assets/audio/",file))
	var first_bomb:Array=audio.scheduled.filter(func(v):return v.stream in bomb_streams)
	check(first_bomb.size()==1 and first_bomb[0].pan>0 and first_bomb[0].stream==bomb_streams[0],"bomb cue schedules one sampled explosion voice")
	check(first_bomb.all(func(v):return is_equal_approx(v.volume,audio.BRICK_BOMB_GAIN) and v.volume<0.35),"explosion sample is attenuated rather than full scale")
	audio.clock+=0.081;audio.play_requests([{"type":"bomb","n":4,"priority":true}])
	var chained:Array=audio.scheduled.filter(func(v):return v.stream in bomb_streams)
	check(chained.size()==2 and chained[1].stream==bomb_streams[1],"successive bombs rotate sampled variants")
	check(chained[1].pitch>chained[0].pitch and chained[1].pitch<1.1,"chain depth lifts later bombs within a narrow range")
	var before_bombs:=audio.scheduled.size()
	for index in range(40):audio.play_requests([{"type":"bomb","priority":true}])
	check(audio.scheduled.size()==before_bombs,"priority chain explosions cannot stack at the same instant")
	audio.clock+=0.081;audio.play_requests([{"type":"bomb","priority":true}])
	check(audio.scheduled.size()==before_bombs+1,"explosion sound resumes after density window")
	var effects_bus:=AudioServer.get_bus_index("SlingEffects")
	check(is_equal_approx(AudioServer.get_bus_volume_db(effects_bus),-3.0),"effects bus reserves mix headroom without changing UI or music")
	var compressor:AudioEffectCompressor=AudioServer.get_bus_effect(effects_bus,0)
	check(compressor!=null and compressor.threshold==-12 and compressor.ratio==6 and compressor.gain==0,"effects peaks are compressed without boosting quiet sounds")
	var loud_start:=audio.scheduled.size()
	audio.play_requests([{"type":"boom"},{"type":"win"},{"type":"core"}])
	check(audio.scheduled.slice(loud_start).all(func(v):return v.volume<=0.6),"heavy synthesized layers are attenuated together")
	check(audio.scheduled.any(func(v):return v.pan<0),"spatial effects preserve left pan")
	var ui_before:=audio.ui_played
	session.command("pause",{"paused":true})
	for i in range(60):audio._process(1.0/60)
	check(audio.ui_played>ui_before,"paused UI cues reach Godot players")
	check(audio.scheduled.any(func(v):return not v.ui),"paused gameplay cues remain held")
	check(audio.players.any(func(p):return p.playing and p.get_meta("ui",false) and not p.stream_paused),"UI output is not paused with the battlefield")
	session.command("pause",{"paused":false});audio._process(.1)
	check(not audio.scheduled.any(func(v):return v.bus=="SlingEffects" and v.at<=audio.clock),"resume releases due gameplay cues")
	# Every boss now plays dedicated sampled stems, covered by native_abyss_test,
	# native_serpent_test, native_forge_test and native_clock_test.
	session.command("configure",{"volume":0})
	check(audio.scheduled.is_empty() and not audio.players.any(func(p):return p.playing),"mute retires queued and playing voices")
	check(audio.failure=="","all requested Vorbis instruments decode")
	audio.shutdown();audio.queue_free();await process_frame
	check(AudioServer.bus_count==baseline,"owned audio buses are released")
	session.finish_save();session.runtime.dispose()
	print("Native audio: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
