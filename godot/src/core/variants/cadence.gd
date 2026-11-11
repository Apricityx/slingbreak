extends "res://src/core/variants/rule.gd"
## 节拍: the first shot starts a metronome. Shots loosed on any beat build a
## streak that hits harder but quickens the beat; an off-beat shot breaks the
## streak. The best streak raises the core bonus (×1 to ×1.8).
const Progress=preload("res://src/core/progress.gd")
const WINDOW:=0.16       # seconds either side of a beat
const MAX_STREAK:=8
var shown:=""

func title() -> String:return "节拍"
func color() -> String:return "#5fa3b8"
func note() -> String:return "首箭启动节拍；听提示音，在亮拍前后 0.16 秒出箭。每拍只计一次，合拍逐渐加速、增伤；失拍重置连拍，最佳连拍奖励最多 ×1.8。"

func shape() -> void:data={"started":false,"phase":0.0,"streak":0,"best":0,"beats":0,"beat":0,"claimed":-1,"interval":1.3}

func restored() -> void:
	data.beat=int(data.get("beat",0));data.claimed=int(data.get("claimed",0))
	data.interval=float(data.get("interval",1.3));data.phase=fmod(float(data.phase),period())

func valid(saved:Dictionary) -> bool:
	if not saved.get("started") is bool or not Progress.finite_number(saved.get("phase"),0,2):return false
	for key in ["streak","best"]:
		if not Progress.finite_number(saved.get(key),0,MAX_STREAK,true):return false
	if not Progress.finite_number(saved.get("beat",0),0,1e9,true) or not Progress.finite_number(saved.get("claimed",-1),-1,1e9,true):return false
	if not Progress.finite_number(saved.get("interval",1.3),0.9,1.3):return false
	return Progress.finite_number(saved.get("beats"),0,1e6,true)

## The beat quickens from 1.3 s to 0.9 s as the streak grows.
func period() -> float:return float(data.get("interval",1.3))
func beat_id() -> int:return int(data.get("beat",0))+(1 if float(data.phase)>period()*0.5 else 0)
func available() -> bool:return offset()<=WINDOW and beat_id()>int(data.get("claimed",-1))
## Damage for arrows of an on-beat shot: ×1.15 at streak 1, ×1.85 at streak 8.
func strike(streak:int) -> float:return 1.05+0.1*streak

## Seconds to the nearest beat (phase 0 and phase==period are both beats).
func offset() -> float:
	var t:float=float(data.phase)
	return minf(t,period()-t)

func update(delta:float) -> void:
	if not data.started or g.paused or not g.phase in ["ready","flying"]:return
	data.phase=float(data.phase)+delta
	while float(data.phase)>=period():
		data.phase=float(data.phase)-period();data.beat=int(data.get("beat",0))+1
		data.interval=1.3-0.05*int(data.streak)
		g.cue("cadence_tick",1,g.origin.x,true)

func launched(arrow:RefCounted) -> void:
	var source:RefCounted=arrow.source
	if source!=null and source.flags.has("beatScale"):arrow.flags.beatScale=source.flags.beatScale
	elif arrow.flags.get("main",false):arrow.flags.beatScale=_preview()

## The main arrow is launched just before on_shoot(); judge the same beat here.
func _preview() -> float:
	if not data.started or not available():return 1.0
	return strike(mini(MAX_STREAK,int(data.streak)+1))

func damage_scale(_brick:RefCounted,arrow:Variant) -> float:
	return float(arrow.flags.get("beatScale",1.0)) if arrow is RefCounted else 1.0

func on_shoot() -> void:
	if not data.started:
		# The first shot is the downbeat; the metronome starts here.
		data.started=true;data.phase=0.0;data.beat=0;data.claimed=0
		g.cue("cadence_tick",1,g.origin.x,true)
		g.fx.ring(g.origin,Color(color()),120)
	elif available():
		data.streak=mini(MAX_STREAK,int(data.streak)+1);data.best=maxi(int(data.best),int(data.streak))
		data.beats=int(data.beats)+1;data.claimed=beat_id()
		g.fx.ring(g.origin,Color(color()),110+10*int(data.streak))
		g.fx.floating(g.origin-Vector2(0,96),"合拍 ×%d" % int(data.streak),Color(color()),16+int(data.streak))
	elif offset()>WINDOW:
		if int(data.streak)>=2:g.fx.floating(g.origin-Vector2(0,96),"失拍",Color("#8a9480"),15)
		data.streak=0
	_sync()

func bonus_scale() -> float:return 1.0+0.1*int(data.best)

func status() -> String:
	if not data.started:return "首箭定拍"
	return "%s · 连拍 %d" % ["现在出箭" if available() else "下拍 %.1fs" % maxf(0,period()-float(data.phase)),int(data.streak)]

func summary() -> Array:return ["最佳连拍 %d" % int(data.best),"合拍 %d 次" % int(data.beats)]

func draw(canvas:CanvasItem) -> void:
	# A metronome ring around the bow fills toward the next beat; it brightens
	# inside the timing window.
	if not data.started:return
	var t:float=float(data.phase)/period()
	var ink:=Color(color());ink.a=0.95 if available() else 0.4
	canvas.draw_arc(g.origin,58,-PI/2,-PI/2+TAU*t,40,ink,4.0)
	if available():canvas.draw_circle(g.origin+Vector2(0,-58),7.0,ink)

func _sync() -> void:
	var text:=status()
	if text!=shown:shown=text;g.revision+=1
