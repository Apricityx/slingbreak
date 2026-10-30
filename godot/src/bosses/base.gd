extends RefCounted
var owner:WeakRef
var d:RefCounted:
	get:return owner.get_ref()
var g:RefCounted:
	get:return d.g
var next_at:=0.0
var move:Dictionary={}
var last_move:=""
var stunned_until:=0.0
var refill_until:=0.0

func _init(director:RefCounted) -> void:owner=weakref(director)
func setup(_restored:bool) -> void:calm();next_at=g.time+2.5
func intro() -> void:next_at=g.time+5.1
func calm() -> void:move.clear();stunned_until=0;refill_until=0
func exposed() -> bool:return g.time<stunned_until
func status() -> Dictionary:return {"text":"战斗中","state":"exposed" if exposed() else "shielded"}
func focus() -> Vector2:return Vector2(390,470)
func before_hit(_brick:RefCounted,_depth:int) -> bool:return true
func destroyed(_brick:RefCounted,_depth:int) -> void:pass
func update(_delta:float) -> void:pass
func contact(_arrow:RefCounted,_live:bool) -> void:pass
func persist() -> void:pass
func music_mood() -> String:return "stun" if exposed() else "fight"

func impact(point:Vector2,ink:Color,radius:float=140) -> void:
	g.fx.ring(point,ink,radius);g.fx.burst(point,ink,24,2);g.fx.shake=maxf(g.fx.shake,10);g.hitstop(0.14);g.cue("shatter",1,point.x)

func pick() -> String:
	var choices:Array=d.fight.abilities[d.fight.phase-1].duplicate()
	var finale:String="doom" if d.boss_id=="eye" else "midnight" if d.boss_id=="clock" else ""
	if finale in choices and last_move!="" and last_move!=finale:return finale
	if finale!="":choices.erase(finale)
	var others:Array=choices.filter(func(id):return id!=last_move)
	if not others.is_empty():choices=others
	return choices[g.rng.randi_range(0,choices.size()-1)]

func ready_move() -> bool:return not d.busy and not exposed() and g.time>=refill_until and move.is_empty() and g.time>=next_at

func finish_move() -> void:
	move.clear();next_at=g.time+(1.8 if d.rage else 2.6)

func regrow(count:int,type:String="normal") -> void:
	var points:Array=g.shuffle(d.open_slots()).slice(0,count)
	for index in range(points.size()):
		var point:Vector2=points[index]
		d.later(0.1+index*0.08,func():d.spawn(point,type))
