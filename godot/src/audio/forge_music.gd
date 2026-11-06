extends Node
## 熔炉巨像 sampled score: a furnace bed under three looping recordings that
## escalate with the phase. Smoulder carries the ignition and phase one, stoke
## phase two, inferno phase three or rage and every meltdown. The bed follows
## the heat gauge and roars while the furnace is open; the fight stem ducks
## under it. A phase shift drops to the bed alone so the next stem restarts on
## its own downbeat; ignition and death sweep the low-pass open and shut.
const FILES=["forge-furnace.vorbis","forge-smoulder.vorbis","forge-stoke.vorbis","forge-inferno.vorbis"]
const Forge=preload("res://src/bosses/forge.gd")
const SILENT:=0.01
var stems:Array[AudioStreamPlayer]=[]
var levels:Array[float]=[0.0,0.0,0.0,0.0]
## Low-pass cutoff the sound engine applies to the SlingMusic bus.
var cutoff:=18000.0
func _ready() -> void:
	for file in FILES:
		var player:=AudioStreamPlayer.new();player.bus="SlingMusic";add_child(player);stems.append(player)
func active(g:RefCounted) -> bool:
	return g!=null and g.bosses.boss_id=="forge" and g.bosses.model!=null and g.phase not in ["draft","clearing"] and g.state.sound
## Stem index carrying the current phase.
func fight_stem(d:RefCounted) -> int:
	return 3 if d.fight.phase>=3 or d.rage else 2 if d.fight.phase==2 else 1
## Target levels and response time for the current fight state.
func mix(g:RefCounted) -> Dictionary:
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	var fierce:=fight_stem(d)
	var targets:Array[float]=[0.0,0.0,0.0,0.0]
	targets[0]=0.16+0.3*clampf(m.heat()/100.0,0,1);targets[fierce]=0.6
	var response:=0.9;cutoff=18000.0
	var ignition:float=(g.time-d.intro_at)/Forge.INTRO_SECONDS
	if ignition<1:
		# The colossus lights from the base up; the score opens with it.
		targets=[0.2+0.3*ignition,0.62,0.0,0.0];cutoff=lerpf(600.0,18000.0,ignition*ignition);response=0.5
	elif g.time<d.shift_until:targets=[0.5,0.0,0.0,0.0];cutoff=2400.0;response=0.45
	elif m.move.get("id")=="meltdown":
		targets[3]=0.72
		if fierce!=3:targets[fierce]=0.0
		response=0.4
	elif not m.move.is_empty():targets[fierce]=0.68;response=0.6
	if m.exposed():
		targets[0]=0.7;targets[fierce]=minf(targets[fierce],0.24);targets[3]=minf(targets[3],0.24)
		cutoff=3200.0;response=0.15
	if d.dying_at>=0:
		var fade:float=1-clampf((g.time-d.dying_at)/2.2,0,1)
		for i in range(1,4):targets[i]*=fade
		# Embers linger past the music but settle before the board clears at 2.8s.
		targets[0]*=1-clampf((g.time-d.dying_at)/2.5,0,1)
		cutoff=lerpf(18000.0,500.0,1-fade);response=0.2
	return {"targets":targets,"response":response}
func present(g:RefCounted,delta:float,held:bool) -> void:
	if not active(g):
		stop();return
	var state:=mix(g)
	for i in range(stems.size()):
		var player:=stems[i]
		player.stream_paused=held
		if held:continue
		var target:float=state.targets[i]
		levels[i]=lerpf(levels[i],target,1-exp(-delta/state.response))
		if target<=0 and levels[i]<SILENT:
			levels[i]=0.0;player.stop();continue
		if player.stream==null:
			var stream:=AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes("res://assets/music/"+FILES[i]))
			if stream==null:continue
			stream.loop=true;player.stream=stream
		if not player.playing:player.play()
		player.volume_db=linear_to_db(maxf(0.00001,levels[i]))
func stop() -> void:
	for i in range(stems.size()):stems[i].stop();levels[i]=0.0
	cutoff=18000.0
