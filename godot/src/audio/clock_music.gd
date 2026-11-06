extends Node
## 时之君主 sampled score: an original D-minor lament rendered from VSCO-2-CE
## orchestral samples (tools/prepare_clock_music.py). Five equal-length stems run
## sample-locked in one AudioStreamSynchronized so the tick-tock never drifts
## from the harp gear-train: escapement (claves, pizzicato), movement (harp,
## change-rung glock, spiccato), tension (tremolo, timpani), chime (tubular bells,
## pads) and rewind (movement and chime reversed). The one player's pitch is the
## mainspring: time stop sags it like a stopped tape, haste winds it faster.
const FILES=["clock-escapement.vorbis","clock-movement.vorbis","clock-tension.vorbis","clock-chime.vorbis","clock-rewind.vorbis"]
const CUES={"windup":"clock-windup.vorbis","strike":"clock-strike.vorbis","unwind":"clock-unwind.vorbis"}
const Clock=preload("res://src/bosses/clock.gd")
const SILENT:=0.01
var bed:=AudioStreamPlayer.new()
var cue:=AudioStreamPlayer.new()
var stream:AudioStreamSynchronized
var levels:Array[float]=[0.0,0.0,0.0,0.0,0.0]
var pitch:=1.0
## Low-pass cutoff the sound engine applies to the SlingMusic bus.
var cutoff:=18000.0
## Last fired stinger per trigger, so each event strikes once.
var struck:Dictionary={}
func _ready() -> void:
	bed.bus="SlingMusic";cue.bus="SlingMusic";add_child(bed);add_child(cue)
func active(g:RefCounted) -> bool:
	return g!=null and g.bosses.boss_id=="clock" and g.bosses.model!=null and g.phase not in ["draft","clearing"] and g.state.sound
## Target levels, pitch and response time for the current fight state.
func mix(g:RefCounted) -> Dictionary:
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	var id:String=m.move.get("id","")
	var phase:int=3 if d.rage else int(d.fight.phase)
	var targets:Array[float]=[]
	targets.assign([[0.62,0.5,0.0,0.22,0.0],[0.6,0.6,0.3,0.2,0.0],[0.6,0.62,0.56,0.26,0.0]][clampi(phase,1,3)-1])
	var response:=0.8;var tone:=1.0;cutoff=18000.0
	if g.time-d.intro_at<Clock.INTRO_SECONDS:
		# The dial assembles over bells and pads; the escapement starts on the hour.
		targets=[0.0,0.22,0.0,0.6,0.0];cutoff=2400.0;response=0.5
	elif g.time<d.shift_until:targets=[0.0,0.0,0.0,0.62,0.0];cutoff=3000.0;response=0.4
	elif not m.frozen.is_empty():
		# Time stop: the whole movement sags like a stopped tape and the ticks stop.
		targets[0]=0.0;tone=0.55;cutoff=900.0;response=0.25
	elif id=="rewind":targets=[0.0,0.0,targets[2]*0.6,0.0,0.68];cutoff=6000.0;response=0.3
	elif id=="haste" and g.time>=m.move.live:targets[0]=0.72;targets[1]=0.66;tone=1.12;response=0.3
	elif id=="midnight":targets=[0.52,0.5,0.66,0.62,0.0];response=0.4
	elif id!="":targets[2]=maxf(targets[2],0.3)
	if m.exposed():
		# Stalled mainspring: the escapement falls silent and only the bells ring.
		targets=[0.0,0.12,0.0,0.55,0.0];cutoff=3200.0;response=0.12
	if d.dying_at>=0:
		var fade:float=1-clampf((g.time-d.dying_at)/1.8,0,1)
		for i in range(targets.size()):targets[i]*=fade
		tone=lerpf(1.0,0.7,1-fade);response=0.2
	return {"targets":targets,"pitch":tone,"response":response}
func present(g:RefCounted,delta:float,held:bool) -> void:
	if not active(g):
		stop();return
	bed.stream_paused=held;cue.stream_paused=held
	if held:return
	if stream==null:
		stream=AudioStreamSynchronized.new();stream.stream_count=FILES.size()
		for i in range(FILES.size()):
			var part:=AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes("res://assets/music/"+FILES[i]))
			if part==null:stream=null;return
			part.loop=true;stream.set_sync_stream(i,part);stream.set_sync_stream_volume(i,-80.0)
		bed.stream=stream
	var state:=mix(g)
	var audible:=false
	for i in range(levels.size()):
		levels[i]=lerpf(levels[i],state.targets[i],1-exp(-delta/state.response))
		if state.targets[i]<=0 and levels[i]<SILENT:levels[i]=0.0
		audible=audible or levels[i]>0
		stream.set_sync_stream_volume(i,linear_to_db(maxf(0.00001,levels[i])))
	pitch=lerpf(pitch,state.pitch,1-exp(-delta/0.35));bed.pitch_scale=pitch
	# All stems restart together on bar one only once the whole bed has faded.
	if not audible:bed.stop()
	elif not bed.playing:bed.play()
	stingers(g)
## One-shot cues on the intro, every phase shift and stall, and the death.
func stingers(g:RefCounted) -> void:
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	if g.time-d.intro_at<0.2:fire("intro",d.intro_at,"windup")
	if g.time<d.shift_until:fire("shift",d.shift_until,"strike")
	if m.exposed() and g.time-m.jammed_at<0.2:fire("stall",m.jammed_at,"strike")
	if d.dying_at>=0:fire("death",d.dying_at,"unwind")
func fire(trigger:String,at:float,name:String) -> void:
	if is_equal_approx(float(struck.get(trigger,-1e9)),at):return
	struck[trigger]=at
	cue.stream=AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes("res://assets/audio/"+CUES[name]))
	cue.set_meta("cue",name);cue.volume_db=linear_to_db(0.6);cue.play()
func stop() -> void:
	bed.stop();cue.stop();struck.clear();pitch=1.0;bed.pitch_scale=1.0
	for i in range(levels.size()):levels[i]=0.0
	cutoff=18000.0
