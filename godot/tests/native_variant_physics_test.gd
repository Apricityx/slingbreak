extends SceneTree
## Ballistic level variants (gale, ballast, carom, hover): hook values, flight
## and preview changes, rebound/airtime effects, settlement text and restore.
const Sim=preload("res://src/core/simulation.gd")
const Progress=preload("res://src/core/progress.gd")
const IDS:=["gale","ballast","carom","hover"]
var failures:=0
var checks:=0
var sims:Array=[]

func _initialize() -> void:call_deferred("_run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

## Level 7 is an ordinary level; an override forces `id` on it (empty = plain).
func level(id:String,seed_value:int=4411) -> RefCounted:
	var sim:=Sim.new();sims.append(sim);sim.start(seed_value,{})
	sim.state.level=7;sim.state.skills={};sim.state.skillChosenLevel=7;sim.state.board=null
	sim.state.variantOverride={"level":7,"id":id}
	sim.generate();sim.phase="ready"
	return sim

func restored(saved:Dictionary) -> RefCounted:
	var sim:=Sim.new();sim.start(1,saved);sims.append(sim);sim.phase="ready"
	return sim

## Full-power release straight up (or at `angle` radians from vertical).
func release(sim:RefCounted,angle:float=0.0,power:float=1.0) -> Vector2:
	return Vector2(sin(angle),-cos(angle))*sim.speed()*(0.56+0.44*power)

func highest(path:PackedVector2Array) -> Vector2:
	var best:=path[0]
	for point in path:if point.y<best.y:best=point
	return best

## Fly a real arrow on an empty board, returning its positions per tick.
func fly(sim:RefCounted,velocity:Vector2,ticks:int) -> PackedVector2Array:
	sim.bricks.clear();sim.obstacles.clear();sim.phase="flying"
	var arrow:RefCounted=sim.launch(sim.origin,velocity)
	var points:=PackedVector2Array([sim.origin])
	for i in range(ticks):
		if not sim.arrows.has(arrow):break
		sim.advance_arrow(arrow,1.0/60);points.append(arrow.position)
	return points

func round_trip(sim:RefCounted,id:String) -> RefCounted:
	var saved:Dictionary=sim.export_progress()
	check(Progress.valid(saved),"%s board passes validation" % id)
	var back:=restored(saved)
	check(back.variants.id==id and back.variants.rule.data==sim.variants.rule.data,"%s restore keeps rule data" % id)
	return back

func rejects(id:String,bad:Array) -> void:
	for data in bad:
		var variant:Dictionary=data.duplicate();variant.id=id
		check(not Progress.valid_variant(variant),"%s rejects malformed data %s" % [id,str(data)])

func _run() -> void:
	var plain:=level("")
	check(plain.variants.id=="","plain reference level has no variant")
	var plain_up:=highest(plain.predict(plain.origin,release(plain),2400))
	check(plain_up.y<60 and absf(plain_up.x-390)<1,"plain straight shot reaches the top")
	for id in IDS:
		var sim:=level(id)
		check(sim.variants.id==id and sim.variants.rule.title().length()>=2 and sim.variants.rule.title().length()<=4,"%s forced with a short title" % id)
		check(sim.variants.bonus_scale()>1.0 and sim.variants.summary().items.has("奖金 ×%s" % String.num(sim.variants.bonus_scale(),2)),"%s pays a bonus badge" % id)
		check(sim.snapshot().variant.text.begins_with(sim.variants.rule.title()+" · "),"%s shows a HUD suffix" % id)
		# Every rule keeps a straight full-power shot reaching the core row (y≈80).
		var top:=highest(sim.predict(sim.origin,release(sim),2400))
		check(top.y<120,"%s straight shot still reaches the core row (%s)" % [id,str(top)])
	_gale(plain)
	_ballast(plain)
	_carom()
	_hover(plain)
	for sim in sims:sim.dispose()
	print("Native variants physics: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func _gale(plain:RefCounted) -> void:
	var gale:=level("gale");gale.obstacles.clear()
	var rule:RefCounted=gale.variants.rule
	check(is_equal_approx(absf(gale.variants.wind()),rule.PEAK),"gale starts at a full gust")
	check(level("gale").variants.rule.data.phase==rule.data.phase,"gale seeds its gust deterministically")
	check(gale.variants.gravity_scale()==1.0 and gale.variants.damage_scale(gale.bricks[0],null)==1.0,"gale only adds wind")
	var side:float=signf(gale.variants.wind())
	var path:PackedVector2Array=gale.predict(gale.origin,release(gale),2400)
	var top:=highest(path)
	var drift:float=(top.x-390)*side
	check(drift>30 and drift<120,"gale bends a straight preview downwind by a modest amount (%s)" % drift)
	check(gale.snapshot().variant.text.contains("→→" if side>0 else "←←"),"gale HUD shows a strong gust")
	# The real flight follows the same bent path as the preview.
	var flown:=fly(level("gale"),release(gale),40)
	var preview:PackedVector2Array=gale.predict(gale.origin,release(gale),2400)
	check(flown.size()>30 and flown[30].distance_to(preview[30])<0.01,"gale flight matches the aiming preview")
	var plain_path:PackedVector2Array=plain.predict(plain.origin,release(plain),2400)
	check(absf(preview[30].x-plain_path[30].x)>5,"gale flight differs from a calm level")
	# The gust swings over ~10 s and only while the level is live.
	gale.phase="draft"
	var held:float=rule.data.phase;gale.variants.update(5.0)
	check(rule.data.phase==held,"gale wind holds outside live play")
	gale.phase="ready"
	for i in range(int(PI/rule.RATE*60)+2):gale.variants.update(1.0/60)
	check(signf(gale.variants.wind())==-side,"gale wind swings to the other side")
	check(gale.fx.texts.any(func(t):return String(t.text).begins_with("风向")),"gale announces the change of direction")
	var back:=round_trip(gale,"gale")
	check(is_equal_approx(back.variants.wind(),gale.variants.wind()),"restored gale resumes the same wind")
	rejects("gale",[{},{"phase":-1},{"phase":INF},{"phase":"1"}])

func _ballast(plain:RefCounted) -> void:
	var heavy:=level("ballast");heavy.obstacles.clear();plain.obstacles.clear()
	check(heavy.variants.gravity_scale()>1.0 and heavy.variants.wind()==0.0,"ballast increases gravity")
	var angle:=deg_to_rad(20)
	# Tick 25 of a 20° shot, before any wall: heavier gravity sits lower.
	var dropped:Vector2=heavy.predict(heavy.origin,release(heavy,angle),2400)[25]
	var normal:Vector2=plain.predict(plain.origin,release(plain,angle),2400)[25]
	check(dropped.y>normal.y+8,"ballast preview drops the arc (%s vs %s)" % [dropped.y,normal.y])
	var half:=highest(heavy.predict(heavy.origin,release(heavy,0.0,0.5),2400))
	check(half.y<120,"ballast half-power straight shot still reaches the core row")
	heavy.phase="flying"
	var arrow:RefCounted=heavy.launch(heavy.origin,release(heavy))
	var reference:RefCounted=plain.launch(plain.origin,release(plain))
	check(arrow.pierce==reference.pierce+1,"ballast pads launch pierce")
	plain.arrows.erase(reference)
	var start:int=arrow.pierce
	heavy.bounce(arrow)
	check(arrow.pierce==start-1,"each ballast rebound chips pierce")
	arrow.pierce=1;heavy.bounce(arrow)
	check(arrow.pierce==0 and heavy.variants.rule.data.shattered==1,"ballast arrow shatters on its last rebound")
	heavy.advance_arrow(arrow,1.0/60)
	check(not heavy.arrows.has(arrow),"shattered ballast arrow is removed")
	check(heavy.variants.summary().items.has("碎箭 1"),"ballast summary counts shattered arrows")
	var brick:RefCounted=heavy.bricks[0];brick.frozen=false;brick.hp=100.0
	heavy.active_arrow=heavy.launch(heavy.origin,release(heavy))
	heavy.hit(brick,2.0);heavy.active_arrow=null
	check(is_equal_approx(brick.hp,100.0-2.0*heavy.variants.rule.DAMAGE),"ballast arrows hit harder")
	round_trip(heavy,"ballast")
	rejects("ballast",[{},{"shattered":-1},{"shattered":1.5}])

func _carom() -> void:
	var carom:=level("carom")
	var rule:RefCounted=carom.variants.rule
	carom.phase="flying"
	var arrow:RefCounted=carom.launch(carom.origin,release(carom))
	var brick:RefCounted=carom.bricks[0]
	check(is_equal_approx(carom.variants.damage_scale(brick,arrow),0.6),"carom fresh arrow hits weak")
	check(carom.variants.damage_scale(brick,null)==1.0,"carom leaves area damage neutral")
	carom.bounce(arrow);carom.bounce(arrow)
	check(is_equal_approx(carom.variants.damage_scale(brick,arrow),1.8),"carom rebounds charge the arrow")
	check(carom.fx.texts.any(func(t):return t.text=="×1.8"),"carom shows the new multiplier")
	for i in range(5):carom.bounce(arrow)
	check(is_equal_approx(carom.variants.damage_scale(brick,arrow),3.0) and rule.data.charged==4 and rule.data.best==4,"carom charge caps at four rebounds")
	var fresh:RefCounted=carom.launch(carom.origin,release(carom))
	check(is_equal_approx(carom.variants.damage_scale(brick,fresh),0.6),"carom charge belongs to one arrow")
	# A real flight off the side wall charges the arrow.
	var sim:=level("carom")
	var points:=fly(sim,release(sim,deg_to_rad(40)),60)
	var flier:RefCounted=sim.arrows[0] if not sim.arrows.is_empty() else null
	check(flier!=null and int(flier.flags.get("carom",0))>=1 and points.size()>40,"carom wall rebound charges a flying arrow")
	check(carom.variants.summary().items.has("最高 ×3.0"),"carom summary reports the best charge")
	round_trip(carom,"carom")
	rejects("carom",[{"charged":0},{"charged":-1,"best":0},{"charged":1,"best":9},{"charged":0.5,"best":0}])

func _hover(plain:RefCounted) -> void:
	var hover:=level("hover");hover.obstacles.clear();plain.obstacles.clear()
	var rule:RefCounted=hover.variants.rule
	check(hover.variants.gravity_scale()<1.0,"hover lowers gravity")
	var angle:=deg_to_rad(20)
	var lofted:Vector2=hover.predict(hover.origin,release(hover,angle),2400)[25]
	var normal:Vector2=plain.predict(plain.origin,release(plain,angle),2400)[25]
	check(lofted.y<normal.y-8,"hover preview lifts the arc (%s vs %s)" % [lofted.y,normal.y])
	var flown:=fly(level("hover"),release(hover,angle),30)
	var preview:PackedVector2Array=hover.predict(hover.origin,release(hover,angle),2400)
	check(flown[30].distance_to(preview[30])<0.01,"hover flight matches the aiming preview")
	hover.phase="flying"
	var arrow:RefCounted=hover.launch(hover.origin,release(hover),-1,-1,false,true)
	var brick:RefCounted=hover.bricks[0]
	check(is_equal_approx(hover.variants.damage_scale(brick,arrow),0.6),"hover point-blank hit is weak")
	arrow.life=1.0
	check(is_equal_approx(hover.variants.damage_scale(brick,arrow),1.4),"hover damage grows with flight time")
	arrow.life=4.0
	check(is_equal_approx(hover.variants.damage_scale(brick,arrow),2.2) and hover.variants.damage_scale(brick,null)==1.0,"hover damage caps; area damage neutral")
	hover.variants.update(1.0/60)
	check(arrow.flags.get("hoverFull",false) and is_equal_approx(rule.data.best,2.2) and hover.fx.texts.any(func(t):return t.text=="×2.2"),"hover marks a fully charged arrow")
	check(hover.snapshot().variant.text.contains("滞空 ×2.2"),"hover HUD shows the live multiplier")
	hover.variants.update(1.0/60)
	var rings:int=hover.fx.rings.size();hover.variants.update(1.0/60)
	check(hover.fx.rings.size()==rings,"hover full-charge mark fires once per arrow")
	var back:=round_trip(hover,"hover")
	check(back.variants.summary().items.has("滞空最高 ×2.2"),"restored hover keeps its best airtime")
	rejects("hover",[{},{"best":-0.1},{"best":3.0},{"best":NAN}])
