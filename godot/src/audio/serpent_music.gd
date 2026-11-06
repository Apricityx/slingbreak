extends Node
## 星渊巨蟒 sampled score: three looping orchestral recordings driven by the
## fight state. Stalk carries the intro, eclipse and the gate-to-gate phase
## shift; hunt carries phases one and two; frenzy takes over from phase three
## or rage. A toppled serpent ducks the fight stem and closes the low-pass,
## a dive muffles it underground. A stem restarts from its top only after it
## has fully faded, so a phase lands on a fresh downbeat instead of mid-bar.
const FILES=["serpent-stalk.vorbis","serpent-hunt.vorbis","serpent-frenzy.vorbis"]
const Serpent=preload("res://src/bosses/serpent.gd")
const SILENT:=0.01
var stems:Array[AudioStreamPlayer]=[]
var levels:Array[float]=[0.0,0.0,0.0]
## Low-pass cutoff the sound engine applies to the SlingMusic bus.
var cutoff:=18000.0
func _ready() -> void:
	for file in FILES:
		var player:=AudioStreamPlayer.new();player.bus="SlingMusic";add_child(player);stems.append(player)
func active(g:RefCounted) -> bool:
	return g!=null and g.bosses.boss_id=="serpent" and g.bosses.model!=null and g.phase not in ["draft","clearing"] and g.state.sound
## Target levels and response time for the current fight state.
func mix(g:RefCounted) -> Dictionary:
	var d:RefCounted=g.bosses;var m:RefCounted=d.model
	var fierce:int=2 if d.fight.phase>=3 or d.rage else 1
	var targets:Array[float]=[0.0,0.0,0.0];targets[fierce]=0.6
	var response:=0.9;cutoff=18000.0
	var stage:String=m.move.get("stage","")
	if g.time-d.intro_at<Serpent.INTRO_SECONDS:targets=[0.62,0.0,0.0];response=0.6
	elif stage=="dark":targets[0]=0.5;targets[fierce]=0.14;cutoff=1400.0;response=0.5
	elif stage=="under":targets[fierce]=0.42;cutoff=700.0;response=0.35
	elif stage in ["aim","maw","split"]:targets[fierce]=0.7;response=0.4
	if not m.ghosts.is_empty():targets=[0.66,0.0,0.0];cutoff=2400.0;response=0.45
	if m.exposed():
		targets[0]=minf(targets[0],0.12);targets[fierce]=0.2;cutoff=900.0;response=0.12
	if d.dying_at>=0:
		var fade:float=1-clampf((g.time-d.dying_at)/2.2,0,1)
		for i in range(3):targets[i]*=fade
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
