extends Node
## 深渊之眼 adaptive score: five sample-aligned orchestral stems layered by one
## AudioStreamSynchronized (one player, one clock, no drift), plus one-shot stingers.
## Rendered from CC0 VSCO-2-CE samples by tools/prepare_eye_music.py.
const STEMS=["bed","pulse","stars","theme","daze"]
const STINGERS=["shift","finale"]
const Rig=preload("res://src/render/abyss_rig.gd")
var score:=AudioStreamPlayer.new()
var stinger:=AudioStreamPlayer.new()
var levels:Array[float]=[0.0,0.0,0.0,0.0,0.0]
var cues:={}
var seen_phase_at:=-100.0
var finale_played:=false
func _ready() -> void:
	for player in [score,stinger]:player.bus="SlingMusic";add_child(player)
	score.name="EyeScore";stinger.name="EyeStinger"
func load_sample(file:String) -> AudioStreamOggVorbis:
	return AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes("res://assets/music/eye-%s.vorbis" % file))
func ensure_score() -> bool:
	if score.stream!=null:return true
	var sync:=AudioStreamSynchronized.new();sync.stream_count=STEMS.size()
	for i in range(STEMS.size()):
		var stem:=load_sample(STEMS[i])
		if stem==null:return false
		stem.loop=true;sync.set_sync_stream(i,stem);sync.set_sync_stream_volume(i,-80.0)
	score.stream=sync;return true
func cue(id:String,offset:float=0.0) -> void:
	if not cues.has(id):cues[id]=load_sample(id)
	if cues[id]==null:return
	stinger.stream=cues[id];stinger.play(offset)
## Mix targets [bed, pulse, stars, theme, daze] from the encounter state.
func targets(g:RefCounted) -> Dictionary:
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	var phase:int=d.fight.phase
	var mix:Array=[0.85,0.5,0.35,0.0,0.0];var response:=0.9
	if phase>=2:mix=[0.9,0.7,0.4,0.45,0.0]
	if d.rage:mix=[1.0,0.9,0.55,0.85,0.0]
	var intro:float=g.time-d.intro_at
	if intro>=0 and intro<d.intro_seconds():
		# The bed and the starlight rise with the eyelid; the pulse enters on control.
		var k:float=clampf(intro/d.intro_seconds(),0,1);mix=[0.85*k,0.0,0.7*k,0.0,0.0];response=0.3
	if m.move.get("id")=="gaze":
		var to_release:float=m.move.live-g.time
		if to_release>0.15:mix=[0.7,0.12,0.9,0.0,0.0];response=0.25
		elif to_release> -0.08:mix=[0.12,0.0,0.08,0.0,0.0];response=0.04
		elif g.time<m.move.active_end:mix=[1.0,mix[1],0.5,maxf(mix[3],0.5),0.0];response=0.15
	if m.move.get("id")=="doom":mix=[1.0,1.0,0.8,1.0,0.0];response=0.4
	if m.exposed():mix=[0.5,0.04,0.12,0.0,1.0];response=0.15
	elif g.time<m.refill_until:mix=[0.75,0.2,0.3,0.0,0.6]
	var shift_age:float=g.time-m.phase_at
	if shift_age>=0 and shift_age<Rig.SHIFT_SECONDS:
		# Duck under the stinger, then let the new phase bloom in on the reveal.
		mix=[0.15,0.0,0.1,0.0,0.0] if shift_age<Rig.REVEAL_AT+0.6 else mix;response=0.2
	if d.dying_at>=0:
		var fade:float=1-clampf((g.time-d.dying_at)/1.8,0,1)
		for i in range(mix.size()):mix[i]*=fade
		response=0.25
	return {"mix":mix,"response":response}
func present(g:RefCounted,delta:float,held:bool) -> void:
	var active:bool=g!=null and g.bosses.boss_id=="eye" and g.phase not in ["draft","clearing"] and g.state.sound
	if not active:
		stop();return
	score.stream_paused=held;stinger.stream_paused=held
	if held or not ensure_score():return
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	if not score.playing:
		score.play();seen_phase_at=m.phase_at;finale_played=d.dying_at>=0
	# A restored save already sits past its shift; only a live transition gets the stinger.
	if m.phase_at!=seen_phase_at:
		seen_phase_at=m.phase_at
		var age:float=g.time-m.phase_at
		if age>=0 and age<0.25:cue("shift",age)
	if d.dying_at>=0 and not finale_played:finale_played=true;cue("finale")
	var plan:=targets(g)
	for i in range(STEMS.size()):
		levels[i]=lerpf(levels[i],plan.mix[i],1-exp(-delta/plan.response))
		score.stream.set_sync_stream_volume(i,linear_to_db(maxf(0.00001,levels[i])))
func stop() -> void:
	score.stop();stinger.stop()
	for i in range(levels.size()):levels[i]=0.0
	finale_played=false
