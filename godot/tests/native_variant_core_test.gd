extends SceneTree
## Core-behaviour variants (banked, bulwark, blink, seal): mechanic, HUD text,
## settlement, save round-trip and malformed-data rejection.
const Sim=preload("res://src/core/simulation.gd")
const Progress=preload("res://src/core/progress.gd")
var failures:=0
var checks:=0
var sims:Array=[]

func _initialize() -> void:call_deferred("_run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func forced(id:String,level:int=7,seed_value:int=4411) -> RefCounted:
	var sim:=Sim.new();sims.append(sim);sim.start(seed_value,{})
	sim.state.level=level;sim.state.skills={};sim.state.skillChosenLevel=level;sim.state.board=null
	sim.state.variantOverride={"level":level,"id":id};sim.generate();sim.phase="ready"
	return sim

func plain(level:int=7,seed_value:int=4411) -> RefCounted:
	var sim:=Sim.new();sims.append(sim);sim.start(seed_value,{})
	sim.state.level=level;sim.state.skills={};sim.state.skillChosenLevel=level;sim.state.board=null
	sim.state.variantOverride={"level":level,"id":""};sim.generate();sim.phase="ready"
	return sim

## Export, push through JSON (ints may come back as floats) and restore.
func reload(sim:RefCounted) -> RefCounted:
	var saved:Variant=JSON.parse_string(JSON.stringify(sim.export_progress()))
	check(saved is Dictionary and Progress.valid(saved),"%s save passes validation" % sim.variants.id)
	var back:=Sim.new();sims.append(back);back.start(1,saved if saved is Dictionary else {});back.phase="ready"
	return back

## Clear the threshold with plain kills so the core spawns normally.
func reach_core(sim:RefCounted) -> void:
	var guard:=0
	while sim.core==null and not sim.bricks.is_empty() and guard<200:
		var pick:RefCounted=null
		for brick in sim.bricks:
			if brick.type=="normal" and not brick.flags.get("seal",false):pick=brick;break
		if pick==null:pick=sim.bricks[0]
		sim.hit(pick,1e6);guard+=1

func common(sim:RefCounted,id:String,title:String,bonus:float) -> void:
	check(sim.variants.id==id,"%s forced by override" % id)
	check(sim.variants.rule.title()==title and sim.variants.rule.note()!="","%s names itself" % id)
	check(is_equal_approx(sim.variants.bonus_scale(),bonus),"%s bonus ×%s" % [id,bonus])
	var status:Variant=sim.snapshot().variant
	check(status is Dictionary and status.text.begins_with(title),"%s HUD status" % id)
	check(sim.variants.summary().items.size()>=1,"%s settlement badges" % id)
	check(sim.initial==sim.bricks.size(),"%s keeps initial in sync" % id)

func fly(sim:RefCounted,seconds:float) -> void:
	for i in range(int(seconds*60)):
		if sim.phase!="flying":break
		sim.tick(1.0/60)

func _run() -> void:
	_banked();_bulwark();_blink();_seal()
	for sim in sims:sim.dispose()
	print("Native variants core: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func _banked() -> void:
	var sim:=forced("banked")
	common(sim,"banked","折射核心",1.5)
	sim.spawn_core(true);sim.bricks.clear();sim.obstacles.clear();sim.phase="flying"
	# Straight up from below: a direct hit glances off the core.
	var direct:RefCounted=sim.launch(Vector2(390,300),Vector2(0,-22))
	fly(sim,1.5)
	check(sim.phase!="clearing" and int(sim.variants.rule.data.denied)>=1,"direct core hit is denied")
	check(not direct.flags.get("bankedReady",false),"core rebound does not arm the arrow")
	# The denied arrow bounced away from the core: that rebound is ignored.
	var arrow:RefCounted=sim.launch(Vector2(390,300),Vector2(0,-1))
	sim.time=12.0;check(not sim.variants.rule.core_hit(arrow),"unarmed arrow denied")
	arrow.position=Vector2(390,100);sim.variants.rule.bounced(arrow)
	check(not arrow.flags.get("bankedReady",false),"same-tick core reflection is not a bank")
	arrow.position=Vector2(25,400);sim.variants.rule.bounced(arrow)
	check(arrow.flags.get("bankedReady",false) and sim.variants.rule.core_hit(arrow),"wall rebound arms the arrow")
	# Real bank shot: off the left wall into the core.
	var banked:=forced("banked")
	banked.spawn_core(true);banked.bricks.clear();banked.obstacles.clear();banked.phase="flying"
	var expected:float=round(banked.bonus()*1.5)
	banked.launch(Vector2(390,40),Vector2(0,-6))
	fly(banked,1.0)
	check(banked.phase=="clearing","ceiling bank shot clears the level")
	check(banked.settled_bonus==expected,"banked pays ×1.5")
	check(banked.report.variant.title.contains("折射核心"),"report names banked")
	var saved:=forced("banked");saved.variants.rule.data.denied=4
	var back:=reload(saved)
	check(back.variants.id=="banked" and int(back.variants.rule.data.denied)==4,"restore keeps banked data")
	check(not Progress.valid_variant({"id":"banked","denied":-1}) and not Progress.valid_variant({"id":"banked","denied":1.5}) and not Progress.valid_variant({"id":"banked"}),"malformed banked data rejected")

func _bulwark() -> void:
	var sim:=forced("bulwark")
	common(sim,"bulwark","坚壁核心",1.8)
	check(int(sim.variants.rule.data.hp)==3 and sim.variants.rule.status()=="护甲 3","bulwark starts with 3 plates")
	sim.spawn_core(true)
	var arrow:RefCounted=sim.launch(Vector2(390,300),Vector2(0,-1))
	var rule:RefCounted=sim.variants.rule
	check(not rule.core_hit(arrow) and int(rule.data.hp)==2,"first hit strips a plate")
	check(not rule.core_hit(arrow) and int(rule.data.hp)==2,"guard window ignores an immediate re-hit")
	sim.variants.update(rule.GUARD+0.02)
	check(not rule.core_hit(arrow) and int(rule.data.hp)==1,"second hit after guard strips another plate")
	sim.variants.update(rule.GUARD+0.02)
	check(rule.core_hit(arrow),"last plate lets the core break")
	# Simulated: an arrow ping-ponging between core and ceiling cannot strip everything at once.
	var live:=forced("bulwark")
	live.spawn_core(true);live.bricks.clear();live.obstacles.clear();live.phase="flying"
	# Trapped between the core top (y 47) and the ceiling (y 22) it would re-hit every few ticks.
	live.launch(Vector2(390,36),Vector2(0,8))
	for i in range(15):live.tick(1.0/60)
	check(int(live.variants.rule.data.hp)==2 and live.phase!="clearing","one fast arrow strips one plate per guard window")
	var saved:=forced("bulwark");saved.spawn_core(true)
	saved.variants.rule.data.hp=2;saved.variants.rule.data.guard=0.1
	var back:=reload(saved)
	check(back.variants.id=="bulwark" and int(back.variants.rule.data.hp)==2 and is_equal_approx(float(back.variants.rule.data.guard),0.1) and back.core!=null,"restore keeps plates and the core")
	var finish:=forced("bulwark");finish.spawn_core(true);finish.variants.rule.data.hp=1
	finish.phase="flying";finish.bricks.clear();finish.obstacles.clear()
	var expected:float=round(finish.bonus()*1.8)
	finish.launch(Vector2(390,300),Vector2(0,-22));fly(finish,1.5)
	check(finish.phase=="clearing" and finish.settled_bonus==expected,"breaking the last plate pays ×1.8")
	for bad in [{"hp":0,"guard":0},{"hp":4,"guard":0},{"hp":2,"guard":-1},{"hp":2,"guard":1},{"hp":2}]:
		var entry:Dictionary=bad.duplicate();entry.id="bulwark"
		check(not Progress.valid_variant(entry),"malformed bulwark data rejected: %s" % str(bad))

func _blink() -> void:
	var sim:=forced("blink")
	common(sim,"blink","闪移核心",1.6)
	var rule:RefCounted=sim.variants.rule
	check(int(rule.data.slot)==2 and int(rule.data.next)!=2 and sim.variants.rule.status()=="核心未显现","blink waits in the centre slot")
	sim.variants.update(5.0)
	check(float(rule.data.clock)==0.0,"blink clock waits for the core")
	sim.spawn_core()
	check(sim.core.x==390.0 and sim.core.y==80.0,"core appears in the starting slot")
	var target:int=int(rule.data.next)
	for i in range(int(rule.PERIOD*60)+2):sim.variants.update(1.0/60)
	check(int(rule.data.blinks)==1 and int(rule.data.slot)==target,"core blinks to the telegraphed slot")
	check(is_equal_approx(sim.core.x,rule.SLOTS[target]) and is_equal_approx(sim.core.y,rule.Y),"core position follows the slot")
	check(int(rule.data.next)!=int(rule.data.slot),"next slot always differs")
	var seen:Dictionary={}
	for i in range(40):rule._blink();seen[int(rule.data.slot)]=true;check(int(rule.data.next)!=int(rule.data.slot),"next slot differs after blink %d" % i)
	check(seen.size()>=4,"blink visits most slots")
	for x in rule.SLOTS:check(x>=110 and x<=670,"slot %s stays on the board" % x)
	sim.phase="draft";var frozen_clock:float=float(rule.data.clock);sim.variants.update(1.0)
	check(float(rule.data.clock)==frozen_clock,"blink clock pauses outside play")
	sim.phase="ready";sim.variants.update(0.5)
	check(sim.variants.rule.status().ends_with("秒后闪移"),"blink HUD counts down")
	var back:=reload(sim)
	back.variants.update(1.0/60)
	check(back.variants.id=="blink" and int(back.variants.rule.data.slot)==int(rule.data.slot) and int(back.variants.rule.data.blinks)==41,"restore keeps blink data")
	check(back.core!=null and is_equal_approx(back.core.x,rule.SLOTS[int(rule.data.slot)]),"restored core snaps to its slot")
	for bad in [{"clock":0,"slot":1,"next":1,"blinks":0},{"clock":0,"slot":5,"next":1,"blinks":0},{"clock":9,"slot":1,"next":2,"blinks":0},{"clock":0,"slot":1,"next":2,"blinks":-1}]:
		var entry:Dictionary=bad.duplicate();entry.id="blink"
		check(not Progress.valid_variant(entry),"malformed blink data rejected: %s" % str(bad))

func _seal() -> void:
	var sim:=forced("seal")
	common(sim,"seal","封印核心",1.3)
	var rule:RefCounted=sim.variants.rule
	var sealed:Array=rule.seals()
	check(sealed.size()==3 and int(rule.data.total)==3,"seal marks three bricks")
	for brick in sealed:check(brick.type=="normal" and brick.y>=350,"seal bricks are normal and in the lower field")
	var base:=plain()
	check(sim.threshold<base.threshold and sim.threshold==mini(sim.initial,ceili(sim.initial*0.6*0.6)),"seal core appears earlier")
	check(rule.status()=="封印 剩 3","seal HUD counts seals")
	reach_core(sim)
	check(sim.core!=null and rule.seals().size()==3,"core appears while still sealed")
	var arrow:RefCounted=sim.launch(Vector2(390,300),Vector2(0,-1))
	check(not rule.core_hit(arrow) and int(rule.data.denied)==1,"sealed core denies hits")
	var back:=reload(sim)
	check(back.variants.id=="seal" and back.variants.rule.seals().size()==3 and back.core!=null,"restore keeps seal bricks via flags")
	for brick in rule.seals():sim.hit(brick,1e6)
	check(rule.seals().is_empty() and rule.status()=="已解封" and rule.core_hit(arrow),"breaking every seal opens the core")
	var toasts:Array=sim.events.filter(func(e):return e.get("text","").begins_with("封印解除"))
	check(toasts.size()==1,"unsealing announces once")
	# Simulated clear once unsealed.
	sim.phase="flying";sim.bricks.clear();sim.obstacles.clear()
	var expected:float=round(sim.bonus()*1.3)
	sim.launch(Vector2(390,300),Vector2(0,-22));fly(sim,1.5)
	check(sim.phase=="clearing" and sim.settled_bonus==expected,"unsealed core pays ×1.3")
	check(sim.report.variant.items.has("3 道封印"),"seal settlement badge")
	# Breaking seals before the core appears still unseals it.
	var early:=forced("seal")
	for brick in early.variants.rule.seals():early.hit(brick,1e6)
	reach_core(early)
	check(early.core!=null and early.variants.rule.core_hit(arrow),"seals broken early leave the core open")
	for bad in [{"total":4,"denied":0},{"total":-1,"denied":0},{"total":3,"denied":0.5},{"denied":0}]:
		var entry:Dictionary=bad.duplicate();entry.id="seal"
		check(not Progress.valid_variant(entry),"malformed seal data rejected: %s" % str(bad))
