extends Node
## Godot-owned Vorbis playback, native buses, delay and low-pass effects.
## Pools are bounded and reused. No QuickJS, custom mixer or PCM frame bridge.
const RATE:=48000
const MAX_VOICES:=96
const MOBILE_VOICES:=24
const CACHE_BYTES:=32*1024*1024
const BRICK_EXPLOSION_FILE:="res://assets/audio/brick-explosion.wav"
const BRICK_BREAK_FILES:=["brick-break-1.vorbis","brick-break-2.vorbis","brick-break-3.vorbis"]
const BRICK_BREAK_GAIN:=0.55
const BRICK_HIT_FILES:=["brick-hit-1.vorbis","brick-hit-2.vorbis","brick-hit-3.vorbis"]
const BRICK_HIT_GAIN:=0.32
var simulation: RefCounted
var available:=false
var mobile_output:=false
var voice_count:=MAX_VOICES
var failure:=""
var cues:Dictionary={}
var scores:Dictionary={}
var instruments:Dictionary={}
var cache:Dictionary={}
var cache_bytes:=0
var players:Array[AudioStreamPlayer]=[]
var scheduled:Array=[]
var clock:=0.0
var music_step:=0
var music_next:=0.0
var music_key:=""
var muted:=false
var music_filter:AudioEffectLowPassFilter
var owned_buses:Array[String]=[]
var paused:=false
var pan_effects:Array[AudioEffectPanner]=[]
var played:=0
var ui_played:=0
var music_played:=0
var transition_voices:=0
var music_phase:=0
var music_mood:=""
var mix_levels:Dictionary={}
var mix_targets:Dictionary={}
var mix_speed:=.4
var filter_target:=18000.0
var music_gain:=0.0
var death_at:=-1.0
var death_gain:=0.0
var brick_explosion:AudioStreamWAV
var brick_break_index:=0
var brick_hit_index:=0

func _ready() -> void:
	mobile_output=OS.has_feature("android")
	voice_count=MOBILE_VOICES if mobile_output else MAX_VOICES
	cues=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/cues.json"))
	scores=JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/scores.json"))
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/manifest.json"))
	for entry in manifest.samples:instruments[entry.key]=entry.file
	brick_explosion=_load_wav(BRICK_EXPLOSION_FILE)
	_bus("Sling","Master")
	_bus("SlingEffects","Sling");_bus("SlingUI","Sling")
	if not mobile_output:
		_wet_bus("SlingWet","SlingEffects",105,.18,.16)
		_wet_bus("SlingUIWet","SlingUI",105,.18,.16)
	_bus("SlingMusic","Sling")
	if not mobile_output:
		music_filter=AudioEffectLowPassFilter.new();music_filter.cutoff_hz=18000
		AudioServer.add_bus_effect(AudioServer.get_bus_index("SlingMusic"),music_filter)
		var limiter:=AudioEffectCompressor.new();limiter.threshold=-10;limiter.ratio=6;limiter.attack_us=4000;limiter.release_ms=200
		AudioServer.add_bus_effect(AudioServer.get_bus_index("SlingMusic"),limiter)
		for bus in ["pad","bass","drums","arp","lead","bell","fx"]:
			_bus("Sling_"+bus,"SlingMusic");_wet_bus("Sling_"+bus+"Wet","Sling_"+bus,340,.32,.28)
	for index in range(voice_count):
		var player:=AudioStreamPlayer.new()
		player.bus="SlingEffects"
		player.set_meta("ui",false);add_child(player);players.append(player)
		if not mobile_output:
			var bus:="SlingVoice%d" % index;_bus(bus,"SlingEffects")
			player.bus=bus
			var pan:=AudioEffectPanner.new();AudioServer.add_bus_effect(AudioServer.get_bus_index(bus),pan);pan_effects.append(pan)
	available=true

func _load_wav(path:String) -> AudioStreamWAV:
	var bytes:=FileAccess.get_file_as_bytes(path)
	if bytes.size()<44 or bytes.slice(0,4).get_string_from_ascii()!="RIFF" or bytes.slice(8,12).get_string_from_ascii()!="WAVE":return null
	var offset:=12;var channels:=0;var rate:=0;var format:=0;var pcm:=PackedByteArray()
	while offset+8<=bytes.size():
		var chunk:=bytes.slice(offset,offset+4).get_string_from_ascii();var size:=bytes.decode_u32(offset+4);offset+=8
		if chunk=="fmt " and size>=16:
			format=bytes.decode_u16(offset);channels=bytes.decode_u16(offset+2);rate=bytes.decode_u32(offset+4)
		elif chunk=="data":pcm=bytes.slice(offset,mini(offset+size,bytes.size()))
		offset+=size+(size%2)
	if format!=1 or channels<1 or channels>2 or rate<=0 or pcm.is_empty():return null
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.stereo=channels==2;stream.mix_rate=rate;stream.data=pcm;return stream

func _wet_bus(name:String,send:String,delay_ms:float,feedback:float,wet:float) -> void:
	_bus(name,send)
	var delay:=AudioEffectDelay.new();delay.tap1_delay_ms=delay_ms;delay.tap1_level_db=linear_to_db(wet);delay.tap2_active=false;delay.feedback_active=true;delay.feedback_delay_ms=delay_ms;delay.feedback_level_db=linear_to_db(feedback)
	AudioServer.add_bus_effect(AudioServer.get_bus_index(name),delay)

func _bus(name: String,send: String) -> void:
	if AudioServer.get_bus_index(name)>=0:return
	AudioServer.add_bus();var index:=AudioServer.bus_count-1;AudioServer.set_bus_name(index,name);AudioServer.set_bus_send(index,send);owned_buses.append(name)

func sync(frame: Dictionary) -> void:
	if not available:return
	var gain:=float(frame.get("volume",100))/100
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sling"),linear_to_db(maxf(0.00001,gain)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sling"),not frame.get("soundEnabled",true))
	paused=frame.get("paused",false)
	for player in players:player.stream_paused=paused and not player.get_meta("ui",false)
	if not frame.get("soundEnabled",true):
		scheduled.clear()
		for player in players:player.stop()

func _sample(directory: String,file: String) -> AudioStream:
	var key:=directory+file
	if cache.has(key):
		var value:Dictionary=cache[key];cache.erase(key);cache[key]=value;return value.stream
	if file!=file.get_file() or not file.ends_with(".vorbis"):return null
	var bytes:=FileAccess.get_file_as_bytes(directory+file)
	var stream:=AudioStreamOggVorbis.load_from_buffer(bytes)
	if stream==null:failure="Invalid audio resource: "+file;return null
	while cache_bytes+bytes.size()>CACHE_BYTES and not cache.is_empty():
		var oldest:String=cache.keys()[0];cache_bytes-=cache[oldest].bytes;cache.erase(oldest)
	cache[key]={"stream":stream,"bytes":bytes.size()};cache_bytes+=bytes.size()
	return stream

func play_requests(requests: Array) -> void:
	if not available:return
	for request in requests:
		var normal_break:bool=request.type=="brick_break"
		if request.type=="brick_hit":
			var hit_sample:=_sample("res://assets/audio/",BRICK_HIT_FILES[brick_hit_index])
			brick_hit_index=(brick_hit_index+1)%BRICK_HIT_FILES.size()
			if hit_sample!=null:
				var hit_ui:bool=request.get("ui",false)
				_schedule(hit_sample,clock,BRICK_HIT_GAIN,"SlingUI" if hit_ui else "SlingEffects",request.get("priority",false),hit_ui,clampf((float(request.get("x",390))-390)/520,-.65,.65))
			continue
		if request.type=="bomb":
			var bomb_ui:bool=request.get("ui",false)
			var bomb_bus:String="SlingUI" if bomb_ui else "SlingEffects"
			if brick_explosion!=null:_schedule(brick_explosion,clock,1.0,bomb_bus,request.get("priority",false),bomb_ui,clampf((float(request.get("x",390))-390)/520,-.65,.65))
			continue
		var cue_type:String="break" if normal_break else request.type
		if not cues.has(cue_type):continue
		var voices:Array=cues[cue_type][clampi(int(request.get("n",1)),0,20)]
		if normal_break:
			var sample:=_sample("res://assets/audio/",BRICK_BREAK_FILES[brick_break_index])
			brick_break_index=(brick_break_index+1)%BRICK_BREAK_FILES.size()
			if sample!=null:
				var ui:bool=request.get("ui",false)
				_schedule(sample,clock,BRICK_BREAK_GAIN,"SlingUI" if ui else "SlingEffects",request.get("priority",false),ui,clampf((float(request.get("x",390))-390)/520,-.65,.65))
			# Replace only the dry impact/noise pair; retain both combo notes.
			voices=voices.slice(2)
		for voice in voices:
			var stream:=_sample("res://assets/audio/",voice.file)
			var ui:bool=request.get("ui",false)
			var bus:String=("SlingUIWet" if ui else "SlingWet") if voice.wet and not mobile_output else ("SlingUI" if ui else "SlingEffects")
			if stream!=null:_schedule(stream,clock+voice.delay,1.0,bus,request.get("priority",false),ui,clampf((float(request.get("x",390))-390)/520,-.65,.65))

func _schedule(stream: AudioStream,at: float,volume: float,bus: String,priority: bool=false,ui:bool=false,pan:float=0) -> void:
	if scheduled.size()>=256:
		if not priority:return
		scheduled.pop_front()
	scheduled.append({"stream":stream,"at":at,"volume":volume,"bus":bus,"priority":priority,"ui":ui,"pan":pan,"music":bus.begins_with("Sling_")})

func _music() -> void:
	if simulation==null or simulation.paused:return
	var fight:Dictionary=simulation.bosses.fight
	if fight.is_empty() or not scores.has(fight.boss) or simulation.phase=="clearing" or not simulation.state.sound:
		if music_key!="":
			scheduled=scheduled.filter(func(voice):return not voice.music)
			for player in players:
				if player.get_meta("music",false):player.stop()
		music_key="";music_phase=0;music_mood="";death_at=-1;music_gain=0;return
	var score:Dictionary=scores[fight.boss]
	var phase:int=clampi(int(fight.phase)-1,0,score.phases.size()-1)
	var mood:String="dying" if simulation.bosses.dying_at>=0 else "intro" if simulation.time-simulation.bosses.intro_at<2.6 else simulation.bosses.model.music_mood()
	var key:String=fight.boss+":"+str(phase)+":"+mood
	if key!=music_key:
		var same_boss:=music_key.begins_with(fight.boss+":")
		if not same_boss:music_step=0;music_next=clock+0.08;music_phase=0;music_mood="";music_gain=0
		var transitions:Dictionary=score.phases[phase].get("transitions",{})
		if music_phase>0 and phase+1>music_phase:_transition(transitions.get("phase",[]))
		if mood!=music_mood:_transition(transitions.get(mood,[]))
		music_key=key;music_phase=phase+1;music_mood=mood
		var levels:Dictionary=score.mix[mini(phase,score.mix.size()-1)].duplicate()
		var shape:Dictionary=score.moods.get(mood,{})
		for bus in shape:levels[bus]=float(levels.get(bus,0))*-shape[bus] if shape[bus]<0 else shape[bus]
		mix_targets=levels;mix_speed=.05 if mood=="stun" else .4
		filter_target=float(score.filter.get(mood,520 if mood=="eclipse" else 1600 if mood=="intro" else 18000))
		if mood=="dying":death_at=clock;death_gain=music_gain
		else:death_at=-1
	var pattern:Dictionary=score.phases[phase].get(mood,score.phases[phase].fight)
	if music_next<clock:music_next=clock+.05
	while music_next<clock+0.14:
		var voices:Array=pattern.voices[music_step%pattern.voices.size()] if mood!="dying" else []
		for voice in voices:
			if not instruments.has(voice.key):continue
			var stream:=_sample("res://assets/music/",instruments[voice.key])
			if stream!=null:_schedule(stream,music_next,float(voice.get("volume",0.1)),"Sling_"+voice.get("bus","fx")+("Wet" if voice.get("wet",false) and not mobile_output else ""),false,false,float(voice.get("pan",0)))
		music_step+=1;music_next+=60.0/pattern.bpm/4

func _transition(voices:Array) -> void:
	for voice in voices:
		if not instruments.has(voice.key):failure="Missing transition instrument";continue
		var stream:=_sample("res://assets/music/",instruments[voice.key])
		if stream!=null:
			_schedule(stream,clock+voice.get("delay",0),voice.volume,"Sling_fxWet" if voice.get("wet",false) and not mobile_output else "Sling_fx",true)
			transition_voices+=1

func _mix(delta:float,held:bool) -> void:
	if held:
		if death_at>=0:death_at+=delta
		return
	if death_at>=0:music_gain=death_gain*(1-clampf((clock-death_at)/6.5,0,1))
	else:music_gain=lerpf(music_gain,0.55 if music_key!="" else 0.0,1-exp(-delta/.4))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SlingMusic"),linear_to_db(maxf(.00001,music_gain)))
	for bus in ["pad","bass","drums","arp","lead","bell","fx"]:
		var target:float=mix_targets.get(bus,1.0 if bus=="fx" else 0.0)
		var value:=lerpf(float(mix_levels.get(bus,0)),target,1-exp(-delta/mix_speed))
		mix_levels[bus]=value
		if not mobile_output:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sling_"+bus),linear_to_db(maxf(.00001,value)))
	if not mobile_output:
		music_filter.cutoff_hz=lerpf(music_filter.cutoff_hz,filter_target,1-exp(-delta/(.3 if filter_target<1000 else .6)))

func _process(delta: float) -> void:
	if not available:return
	clock+=delta
	var held:bool=paused or simulation!=null and simulation.intro_active
	if held:
		music_next+=delta
		for voice in scheduled:
			if not voice.ui:voice.at+=delta
	else:_music()
	_mix(delta,held)
	var keep:Array=[]
	for voice in scheduled:
		if voice.at>clock or held and not voice.ui:keep.append(voice);continue
		var player:AudioStreamPlayer=null
		for candidate in players:
			if not candidate.playing:player=candidate;break
		if player==null:
			if not voice.priority:continue
			for candidate in players:
				if not candidate.get_meta("ui",false):player=candidate;break
			if player==null:player=players[0]
			player.stop()
		var index:int=players.find(player)
		if mobile_output:
			# Keep Android/OpenSL on a short, stable bus graph. Some devices emit
			# a continuous zero PCM stream when many dynamic buses/effects are used.
			player.bus="SlingMusic" if voice.music else ("SlingUI" if voice.ui else "SlingEffects")
		else:
			pan_effects[index].pan=voice.pan
			AudioServer.set_bus_send(AudioServer.get_bus_index(player.bus),voice.bus)
		player.set_meta("ui",voice.ui);player.set_meta("music",voice.music);player.stream_paused=false
		player.stream=voice.stream;player.volume_db=linear_to_db(maxf(0.00001,voice.volume));player.play(maxf(0,clock-voice.at))
		played+=1;ui_played+=1 if voice.ui else 0;music_played+=1 if voice.music else 0
	scheduled=keep

func shutdown() -> void:
	available=false;set_process(false);scheduled.clear();cache.clear();cache_bytes=0
	for player in players:player.stop();player.stream=null

func _exit_tree() -> void:
	shutdown()
	for bus in owned_buses:
		var index:=AudioServer.get_bus_index(bus)
		if index>0:AudioServer.remove_bus(index)
