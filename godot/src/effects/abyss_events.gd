extends RefCounted
## Presentation-only events, emitted by actual Boss state transitions and contacts.
## No entities or callbacks are retained, and no gameplay RNG is consumed.
const CAPACITY:=24
const LENGTHS={"intro":3.2,"phase":3.4,"cast":0.8,"release":0.65,"hit":0.38,
	"ward":0.36,"break":0.95,"resolve":0.75,"death":2.5,"seal_hit":0.52,"inscribe":0.6,"infect":0.65}
var events:Array=[]
var serial:=0
func emit(kind:String,point:Vector2,time:float,direction:Vector2=Vector2.UP,ability:String="") -> void:
	if not LENGTHS.has(kind):return
	advance(time)
	# Clustered hits share one short impulse per 45ms; damage remains untouched.
	if kind in ["hit","ward"]:
		for event in events:
			if event.kind==kind and time-event.born<0.045:return
	serial+=1
	events.append({"kind":kind,"position":point,"born":time,"duration":LENGTHS[kind],
		"direction":direction.normalized() if direction.length_squared()>0 else Vector2.UP,"ability":ability,"seed":serial})
	if events.size()>CAPACITY:events.pop_front()
func advance(time:float) -> void:
	events=events.filter(func(e):return time-e.born<e.duration)
func reset() -> void:events.clear();serial=0
func interrupt() -> void:
	# Stop the charge immediately, but keep contacts and their short aftermath.
	events=events.filter(func(e):return e.kind not in ["cast","release"])
func impulse(time:float) -> float:
	var strength:=0.0
	for event in events:
		if event.kind not in ["hit","ward","seal_hit","break","release"]:continue
		var age:float=time-event.born
		if age>=0:strength=maxf(strength,exp(-age*14)*(0.4 if event.kind=="ward" else 1.0))
	return strength
