extends Node
## Godot-owned Vorbis playback, native buses, delay and low-pass effects.
## Pools are bounded and reused. No QuickJS, custom mixer or PCM frame bridge.
const RATE:=48000
const MAX_VOICES:=96
const MOBILE_VOICES:=24
const CACHE_BYTES:=32*1024*1024
const BRICK_BOMB_FILES:=["brick-bomb-1.vorbis","brick-bomb-2.vorbis","brick-bomb-3.vorbis","brick-bomb-4.vorbis"]
const BRICK_BREAK_FILES:=["brick-shatter-1.vorbis","brick-shatter-2.vorbis","brick-shatter-3.vorbis","brick-shatter-4.vorbis"]
const BRICK_BREAK_GAIN:=0.4
# Fixed per-variant detune keeps repeats from phasing; combos climb gently.
const BRICK_BREAK_DETUNE:=[0.0,0.035,-0.025,0.015]
const BRICK_HIT_FILES:=["brick-hit-1.vorbis","brick-hit-2.vorbis","brick-hit-3.vorbis"]
const BRICK_HIT_GAIN:=0.22
const BRICK_BOMB_GAIN:=0.3
# Chain depth lifts each later bomb slightly, so a cascade climbs.
const BRICK_BOMB_DETUNE:=[0.0,-0.03,0.02,-0.015]
const SAMPLED_CUES:={
	"eye_awaken":{"file":"eye-awaken.vorbis","gain":0.32,"interval":0.3},
	"eye_charge":{"file":"eye-charge.vorbis","gain":0.28,"interval":0.3},
	"eye_cast":{"file":"eye-cast.vorbis","gain":0.22,"interval":0.2},
	"eye_beam":{"file":"eye-beam.vorbis","gain":0.24,"interval":0.3},
	"eye_lock":{"file":"eye-lock.vorbis","gain":0.24,"interval":0.12},
	"eye_laser":{"file":"eye-laser.vorbis","gain":0.43,"interval":0.12},
	"eye_infect":{"file":"eye-infect.vorbis","gain":0.34,"interval":0.12},
	"eye_break":{"file":"eye-break.vorbis","gain":0.38,"interval":0.15},
	"eye_hit":{"file":"eye-hit.vorbis","gain":0.24,"interval":0.07},
	"eye_pulse":{"file":"eye-pulse.vorbis","gain":0.22,"interval":0.15},
	"eye_death":{"file":"eye-death.vorbis","gain":0.28,"interval":0.3},
	"shoot":{"file":"arrow-shoot.vorbis","gain":0.24,"interval":0.065},
	"frost":{"file":"frost-freeze.vorbis","gain":0.22,"interval":0.12}
}
# Sampled UI cues (ui-*.vorbis, see ui-credits.json). Variants rotate; "tiers"
# pick by request.n. tap/tick/gold/chime only replace UI requests: bosses and
# gold bricks keep their synthesized recipes. "any" also covers gameplay cues.
const UI_CUES:={
	"tap":{"files":["ui-tap-1.vorbis","ui-tap-2.vorbis","ui-tap-3.vorbis"],"gain":0.3},
	"tick":{"files":["ui-tick-1.vorbis","ui-tick-2.vorbis","ui-tick-3.vorbis","ui-tick-4.vorbis"],"gain":0.3},
	"deal":{"files":["ui-deal.vorbis"],"gain":0.22},
	"pick":{"tiers":["ui-pick-1.vorbis","ui-pick-2.vorbis","ui-pick-3.vorbis"],"gain":0.22},
	"whoosh":{"files":["ui-whoosh.vorbis"],"gain":0.22},
	"slot":{"files":["ui-slot.vorbis"],"gain":0.45},
	"chime":{"files":["ui-chime.vorbis"],"gain":0.3},
	"gold":{"files":["ui-gold.vorbis"],"gain":0.35},
	"reroll":{"files":["ui-reroll.vorbis"],"gain":0.25},
	"upgrade":{"files":["ui-upgrade.vorbis"],"gain":0.2,"any":true}
}
# These recipes contain several loud layers; attenuate the whole event equally.
const IMPACT_GAINS:={"boom":0.4,"win":0.5,"core":0.6,"shatter":0.6,"forge":0.5,"meteor":0.5,"clang":0.6,"abyss":0.5,"devour":0.5}
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
var infection_audio_active:=false
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
var brick_bomb_index:=0
var brick_break_index:=0
var brick_hit_index:=0
var last_bomb_at:=-INF
var last_sampled_cues:Dictionary={}
var ui_cue_index:Dictionary={}
var abyss_music:=preload("res://src/audio/abyss_music.gd").new()
var serpent_music:=preload("res://src/audio/serpent_music.gd").new()
var forge_music:=preload("res://src/audio/forge_music.gd").new()
var clock_music:=preload("res://src/audio/clock_music.gd").new()

func _ready() -> void:
	mobile_output=OS.has_feature("android")
	voice_count=MOBILE_VOICES if mobile_output else MAX_VOICES
	cues=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/cues.json"))
	scores=JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/scores.json"))
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/manifest.json"))
	for entry in manifest.samples:instruments[entry.key]=entry.file
	_bus("Sling","Master")
	_bus("SlingEffects","Sling");_bus("SlingUI","Sling")
	# Leave headroom for overlapping effects. No makeup gain: quiet hits stay quiet.
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SlingEffects"),-3.0)
	var effects_compressor:=AudioEffectCompressor.new()
	effects_compressor.threshold=-12;effects_compressor.ratio=6;effects_compressor.attack_us=1000;effects_compressor.release_ms=120;effects_compressor.gain=0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SlingEffects"),effects_compressor)
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
	add_child(abyss_music);add_child(serpent_music);add_child(forge_music);add_child(clock_music)

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
		abyss_music.stop();serpent_music.stop();forge_music.stop();clock_music.stop()
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
		if request.type in ["eye_break","eye_death","eye_awaken","eye_laser_stop"]:
			var sustained:Array=["eye_charge","eye_beam","eye_cast","eye_pulse","eye_laser","eye_lock"]
			_stop_cues(sustained)
			if request.type=="eye_laser_stop":continue
		if SAMPLED_CUES.has(request.type):
			var cue:Dictionary=SAMPLED_CUES[request.type]
			# Frost bricks are priority events; still bound chain-reaction overlap.
			if clock-float(last_sampled_cues.get(request.type,-INF))<float(cue.interval):continue
			var cue_sample:=_sample("res://assets/audio/",cue.file)
			if cue_sample!=null:
				last_sampled_cues[request.type]=clock
				var cue_ui:bool=request.get("ui",false)
				_schedule(cue_sample,clock,float(cue.gain),"SlingUI" if cue_ui else "SlingEffects",request.get("priority",false),cue_ui,clampf((float(request.get("x",390))-390)/520,-.65,.65),request.type)
			continue
		if UI_CUES.has(request.type) and (request.get("ui",false) or UI_CUES[request.type].get("any",false)):
			var ui_cue:Dictionary=UI_CUES[request.type]
			var file:String
			if ui_cue.has("tiers"):file=ui_cue.tiers[clampi(int(request.get("n",0)),0,ui_cue.tiers.size()-1)]
			else:
				var turn:int=ui_cue_index.get(request.type,0);file=ui_cue.files[turn%ui_cue.files.size()];ui_cue_index[request.type]=turn+1
			var ui_sample:=_sample("res://assets/audio/",file)
			if ui_sample!=null:
				var sample_ui:bool=request.get("ui",false)
				_schedule(ui_sample,clock,float(ui_cue.gain),"SlingUI" if sample_ui else "SlingEffects",request.get("priority",false),sample_ui,clampf((float(request.get("x",390))-390)/520,-.65,.65))
			continue
		var normal_break:bool=request.type=="brick_break"
		if request.type=="brick_hit":
			var hit_sample:=_sample("res://assets/audio/",BRICK_HIT_FILES[brick_hit_index])
			brick_hit_index=(brick_hit_index+1)%BRICK_HIT_FILES.size()
			if hit_sample!=null:
				var hit_ui:bool=request.get("ui",false)
				_schedule(hit_sample,clock,BRICK_HIT_GAIN,"SlingUI" if hit_ui else "SlingEffects",request.get("priority",false),hit_ui,clampf((float(request.get("x",390))-390)/520,-.65,.65))
			continue
		if request.type=="bomb":
			# Priority may steal a voice, but must not bypass explosion density control.
			if clock-last_bomb_at<0.08:continue
			last_bomb_at=clock
			var bomb_ui:bool=request.get("ui",false)
			var bomb_bus:String="SlingUI" if bomb_ui else "SlingEffects"
			var bomb_sample:=_sample("res://assets/audio/",BRICK_BOMB_FILES[brick_bomb_index])
			var bomb_pitch:float=1.0+BRICK_BOMB_DETUNE[brick_bomb_index]+0.025*clampi(int(request.get("n",0))-1,0,6)
			brick_bomb_index=(brick_bomb_index+1)%BRICK_BOMB_FILES.size()
			if bomb_sample!=null:_schedule(bomb_sample,clock,BRICK_BOMB_GAIN,bomb_bus,request.get("priority",false),bomb_ui,clampf((float(request.get("x",390))-390)/520,-.65,.65),"",bomb_pitch)
			continue
		var cue_type:String="break" if normal_break else request.type
		if not cues.has(cue_type):continue
		var voices:Array=cues[cue_type][clampi(int(request.get("n",1)),0,20)]
		if normal_break:
			var sample:=_sample("res://assets/audio/",BRICK_BREAK_FILES[brick_break_index])
			var pitch:float=1.0+BRICK_BREAK_DETUNE[brick_break_index]+0.012*clampi(int(request.get("n",1))-1,0,12)
			brick_break_index=(brick_break_index+1)%BRICK_BREAK_FILES.size()
			if sample!=null:
				var ui:bool=request.get("ui",false)
				_schedule(sample,clock,BRICK_BREAK_GAIN,"SlingUI" if ui else "SlingEffects",request.get("priority",false),ui,clampf((float(request.get("x",390))-390)/520,-.65,.65),"",pitch)
			# Replace only the dry impact/noise pair; retain both combo notes.
			voices=voices.slice(2)
		for voice in voices:
			var stream:=_sample("res://assets/audio/",voice.file)
			var ui:bool=request.get("ui",false)
			var bus:String=("SlingUIWet" if ui else "SlingWet") if voice.wet and not mobile_output else ("SlingUI" if ui else "SlingEffects")
			if stream!=null:_schedule(stream,clock+voice.delay,float(IMPACT_GAINS.get(cue_type,1.0)),bus,request.get("priority",false),ui,clampf((float(request.get("x",390))-390)/520,-.65,.65))

func _stop_cues(cues_to_stop:Array) -> void:
	if "eye_laser" in cues_to_stop and "eye_lock" in cues_to_stop:infection_audio_active=false
	scheduled=scheduled.filter(func(v):return v.get("cue","") not in cues_to_stop)
	for player in players:
		if player.get_meta("cue","") in cues_to_stop:player.stop()

func _schedule(stream: AudioStream,at: float,volume: float,bus: String,priority: bool=false,ui:bool=false,pan:float=0,cue:String="",pitch:float=1.0) -> void:
	if scheduled.size()>=256:
		if not priority:return
		scheduled.pop_front()
	scheduled.append({"stream":stream,"at":at,"volume":volume,"bus":bus,"priority":priority,"ui":ui,"pan":pan,"cue":cue,"pitch":pitch,"music":bus.begins_with("Sling_")})
	if cue in ["eye_laser","eye_lock"]:infection_audio_active=true

func _music() -> void:
	if simulation==null or simulation.paused:return
	var fight:Dictionary=simulation.bosses.fight
	if fight.is_empty() or not scores.has(fight.boss) or simulation.phase=="clearing" or not simulation.state.sound:
		if music_key!="":
			scheduled=scheduled.filter(func(voice):return not voice.music)
			for player in players:
				if player.get_meta("music",false):player.stop()
		music_key="";music_phase=0;music_mood="";death_at=-1;music_gain=0;return
	if fight.boss=="eye":
		if music_key!="eye:sampled":
			scheduled=scheduled.filter(func(voice):return not voice.music)
			for player in players:
				if player.get_meta("music",false):player.stop()
		music_key="eye:sampled";music_phase=fight.phase;music_mood=simulation.bosses.model.music_mood();death_at=-1;filter_target=18000
		return
	if fight.boss=="serpent":
		# Recorded orchestral stems replace the sequencer; they own the low-pass.
		if music_key!="serpent:sampled":
			scheduled=scheduled.filter(func(voice):return not voice.music)
			for player in players:
				if player.get_meta("music",false):player.stop()
		music_key="serpent:sampled";music_phase=fight.phase;music_mood=simulation.bosses.model.music_mood();death_at=-1;filter_target=serpent_music.cutoff
		return
	if fight.boss=="forge":
		# Recorded stems over a furnace bed replace the sequencer; they own the low-pass.
		if music_key!="forge:sampled":
			scheduled=scheduled.filter(func(voice):return not voice.music)
			for player in players:
				if player.get_meta("music",false):player.stop()
		music_key="forge:sampled";music_phase=fight.phase;music_mood=simulation.bosses.model.music_mood();death_at=-1;filter_target=forge_music.cutoff
		return
	if fight.boss=="clock":
		# Sample-locked orchestral stems replace the sequencer; they own the low-pass.
		if music_key!="clock:sampled":
			scheduled=scheduled.filter(func(voice):return not voice.music)
			for player in players:
				if player.get_meta("music",false):player.stop()
		music_key="clock:sampled";music_phase=fight.phase;music_mood=simulation.bosses.model.music_mood();death_at=-1;filter_target=clock_music.cutoff
		return
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
	if simulation!=null and infection_audio_active:
		var d:RefCounted=simulation.bosses
		# Session reset can discard the model without sending a final cue. Never
		# carry a positional laser into the menu or the following encounter.
		if d.boss_id!="eye" or d.model==null or not d.model.gaze_active():
			_stop_cues(["eye_laser","eye_lock"])
	clock+=delta
	var held:bool=paused or simulation!=null and simulation.intro_active
	if held:
		music_next+=delta
		for voice in scheduled:
			if not voice.ui:voice.at+=delta
	else:_music()
	_mix(delta,held)
	abyss_music.present(simulation,delta,held)
	serpent_music.present(simulation,delta,held)
	forge_music.present(simulation,delta,held)
	clock_music.present(simulation,delta,held)
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
		player.set_meta("cue",voice.get("cue",""))
		player.stream=voice.stream;player.pitch_scale=voice.get("pitch",1.0);player.volume_db=linear_to_db(maxf(0.00001,voice.volume));player.play(maxf(0,clock-voice.at))
		played+=1;ui_played+=1 if voice.ui else 0;music_played+=1 if voice.music else 0
	scheduled=keep

func shutdown() -> void:
	abyss_music.stop();serpent_music.stop();forge_music.stop();clock_music.stop()
	available=false;set_process(false);scheduled.clear();cache.clear();cache_bytes=0
	for player in players:player.stop();player.stream=null

func _exit_tree() -> void:
	shutdown()
	for bus in owned_buses:
		var index:=AudioServer.get_bus_index(bus)
		if index>0:AudioServer.remove_bus(index)
