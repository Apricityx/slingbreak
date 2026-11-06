extends SceneTree
## Level variants: deck draw, board shaping, timers, settlement and save restore.
const Sim=preload("res://src/core/simulation.gd")
const Variants=preload("res://src/core/variants.gd")
const Progress=preload("res://src/core/progress.gd")
var failures:=0
var checks:=0
var sims:Array=[]

func _initialize() -> void:call_deferred("_run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

## Fresh level forced to rule `id`; "" forces a plain level, null draws from the deck.
func at(level:int,id:Variant="",seed_value:int=4411,progress:Dictionary={}) -> RefCounted:
	var sim:=Sim.new();sim.start(seed_value,progress);sims.append(sim)
	if progress.is_empty():
		sim.state.level=level;sim.state.skills={};sim.state.skillChosenLevel=level;sim.state.board=null
		if id!=null:sim.state.variantOverride={"level":level,"id":id}
		sim.generate()
	sim.phase="ready"
	return sim

func _run() -> void:
	for id in Variants.ORDER:check(Variants.script_for(id)!=null,"rule file exists: "+id)
	var dealt:=at(7,null)
	check(dealt.variants.id in Variants.ORDER and dealt.snapshot().variant is Dictionary,"every ordinary level draws a rule")
	var info:Dictionary=dealt.snapshot().variant
	check(info.note!="" and Color.html_is_valid(info.color),"status carries the note and colour for the pre-draft card")
	dealt.state.variantDeck=[]
	var drawn:Array=[]
	for i in range(Variants.ORDER.size()*6):drawn.append(dealt.variants.draw_next())
	var first:Dictionary={}
	for id in drawn.slice(0,Variants.ORDER.size()):first[id]=true
	check(first.size()==Variants.ORDER.size(),"one deck deals every rule once")
	var repeats:=0
	for i in range(1,drawn.size()):if drawn[i]==drawn[i-1]:repeats+=1
	check(repeats==0,"reshuffles never repeat the previous rule")
	check(Progress.valid(dealt.export_progress()),"saved variant deck passes validation")
	var bad:Dictionary=dealt.export_progress();bad.state.variantDeck=[1]
	check(not Progress.valid(bad),"malformed variant deck is rejected")
	var boss:=at(100,null)
	check(boss.variants.id=="" and not boss.bosses.fight.is_empty(),"boss levels play without a rule")
	var plain:=at(14)
	check(plain.variants.id=="" and plain.snapshot().variant==null,"empty override plays a plain level")

	var fort:=at(15,"fortress")
	check(fort.variants.id=="fortress","fortress level selected")
	check(fort.obstacles.size()>plain.obstacles.size() and fort.obstacles.size()<=12,"fortress adds bounded walls")
	for wall in fort.obstacles:check(absf(wall.x-390)>=192,"fortress keeps the central route open")
	check(fort.bricks.size()<plain.bricks.size() and fort.initial==fort.bricks.size(),"fortress thins the board and recounts it")
	check(fort.bricks[0].hp>=fort.base_hp()*2.5,"fortress bricks are armoured")
	check(fort.variants.bonus_scale()==2.0,"fortress doubles the core bonus")

	var rush:=at(10,"rush")
	var golds:int=rush.bricks.filter(func(b):return b.type=="gold").size()
	check(rush.variants.id=="rush" and golds>=rush.bricks.size()*0.3,"rush seeds a gold field")
	rush.variants.update(30)
	check(rush.variants.rule.data.clock==0.0,"rush timer waits for the first shot")
	check(rush.shoot(0,100) and rush.variants.rule.data.started,"first shot starts the rush")
	rush.variants.update(rush.variants.rule.RUSH_SECONDS+0.1)
	check(rush.variants.rule.data.expired and rush.bricks.filter(func(b):return b.type=="gold").is_empty(),"expired rush fades the remaining gold")

	var drift:=at(5,"drift")
	check(drift.variants.id=="drift","drift level selected")
	drift.spawn_core(true)
	var before:float=drift.core.x
	for i in range(30):drift.variants.update(1.0/60)
	check(absf(drift.core.x-before)>20 and drift.core.x>=140 and drift.core.x<=640,"drifting core moves within the board")
	var expected:float=round(drift.bonus()*2)
	drift.clear()
	check(drift.settled_bonus==expected,"drift doubles the settled core bonus")
	check(drift.report.get("variant") is Dictionary and drift.report.variant.title.contains("游移核心"),"report names the variant")

	var quiver:=at(20,"quiver")
	check(quiver.variants.id=="quiver" and quiver.variants.rule.data.par==8,"quiver defaults to par 8 without pace history")
	quiver.state.skillRuntime.shots=5
	check(is_equal_approx(quiver.variants.bonus_scale(),2.75),"spare arrows raise the quiver bonus")
	quiver.state.skillRuntime.shots=9
	check(is_equal_approx(quiver.variants.bonus_scale(),0.6) and quiver.snapshot().variant.text.contains("超出 1 箭"),"overshooting par softens the bonus")

	plain.shots=15;plain.clear()
	check(plain.state.paceShots==15.0,"ordinary clear records shot pace")
	plain.state.level=20;plain.state.skillChosenLevel=20;plain.state.board=null;plain.state.variantOverride={"level":20,"id":"quiver"};plain.generate()
	check(plain.variants.rule.data.par==12,"later quiver par follows recorded pace")

	# Restore keeps the rule and its counters; old boards without a variant still load.
	rush=at(10,"rush");rush.shoot(0,100);rush.variants.rule.data.clock=4.0
	var saved:Dictionary=rush.export_progress()
	check(Progress.valid(saved),"variant board passes validation")
	var back:=at(0,"",1,saved)
	check(back.variants.id=="rush" and back.variants.rule.data.clock==4.0 and back.variants.rule.data.started,"restore keeps rush state")
	saved.state.board.variant={"id":"rush","clock":-1}
	check(not Progress.valid(saved),"malformed variant data is rejected")
	saved.state.board.erase("variant")
	back=at(0,"",1,saved)
	check(back.variants.id=="","legacy board without variant plays as ordinary")
	# Host: rules load by id from src/core/variants/, never from arbitrary paths.
	check(Variants.script_for("rule")==null and Variants.script_for("../simulation")==null and Variants.script_for("nope")==null,"host rejects unknown or unsafe rule ids")
	check(not Progress.valid_variant({"id":"rule"}) and not Progress.valid_variant({"id":"drift","phase":-1}),"saved rule ids and data are validated")
	var forced:=Sim.new();sims.append(forced);forced.start(4411,{})
	forced.state.level=7;forced.state.skills={};forced.state.skillChosenLevel=7;forced.state.board=null
	forced.state.variantOverride={"level":7,"id":"fortress"};forced.generate()
	check(forced.variants.id=="fortress","variant override forces a rule on any level")
	for sim in sims:sim.dispose()
	print("Native variants: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
