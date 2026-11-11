extends SceneTree
## Integration regressions: real overlapping flights, delayed descendants,
## independent metronome beats, upgrade-normalised heat and persistent guidance.
const Sim=preload("res://src/core/simulation.gd")
const Session=preload("res://src/core/session.gd")
const Progress=preload("res://src/core/progress.gd")
var sims:Array=[]
var failures:=0
var checks:=0

func _initialize() -> void:call_deferred("_run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func make(id:String) -> RefCounted:
	var g:=Sim.new();g.start(4411,{});sims.append(g)
	g.state.level=30;g.state.skillChosenLevel=30;g.state.skills={};g.state.board=null
	g.state.variantOverride={"level":30,"id":id};g.generate();g.phase="ready"
	for brick in g.bricks:brick.type="normal"
	return g

func live(g:RefCounted,seconds:float) -> void:
	for i in range(roundi(seconds*60)):g.update(1.0/60)

func fire(g:RefCounted) -> RefCounted:
	g.next_shot_at=0
	check(g.shoot(70,70),"shot accepted")
	return g.arrows.back()

func kill(g:RefCounted,arrow:RefCounted,count:int) -> void:
	g.active_arrow=arrow
	for brick in g.bricks.slice(0,count):g.hit(brick,1e9)
	g.active_arrow=null

func _run() -> void:
	_cadence();_economy();_heat();_guidance()
	for g in sims:g.dispose()
	print("Native variant design: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func _cadence() -> void:
	var g:=make("cadence");g.bricks.clear();g.obstacles.clear()
	var rule:RefCounted=g.variants.rule
	fire(g);live(g,1.2)
	var phase:float=rule.data.phase
	fire(g)
	check(rule.data.streak==1 and is_equal_approx(rule.data.phase,phase),"early beat scores without moving the metronome")
	fire(g)
	check(rule.data.streak==1 and g.arrows.back().flags.beatScale==1.0,"a second shot on the same beat earns no charge")
	live(g,0.15);fire(g)
	check(rule.data.streak==1,"late side of the same beat cannot score twice")
	check(g.sounds.any(func(s):return s.type=="cadence_tick"),"independent beat emits a sampled tick")
	var spam:=make("cadence");spam.bricks.clear();spam.obstacles.clear()
	for i in range(60):
		spam.next_shot_at=0;spam.shoot(70,70);live(spam,1.0/60)
	check(spam.variants.rule.data.best==0,"even unlimited fast shots cannot farm eight beats within one second")
	var saved:Dictionary=g.export_progress()
	check(Progress.valid(saved),"metronome state survives save validation")
	var back:=Sim.new();sims.append(back);back.start(1,saved)
	check(back.variants.rule.data.claimed==rule.data.claimed and back.variants.rule.data.beat==rule.data.beat,"restore cannot reclaim a scored beat")

func _economy() -> void:
	var g:=make("escrow");var rule:RefCounted=g.variants.rule
	rule.data.pot=1000.0
	var blank:=fire(g);var scoring:=fire(g)
	kill(g,scoring,1)
	g.arrows.erase(blank);rule.update(0)
	check(rule.data.lost==300 and rule.rounds.has(scoring.id),"blank shot settles while another scoring arrow still flies")
	var delayed:=fire(g)
	g.skills.later(0.1,delayed,func():kill(g,delayed,1))
	g.arrows.erase(delayed);rule.update(0)
	check(rule.rounds.has(delayed.id),"pending source-owned skill keeps only its own shot open")
	g.time+=0.11;g.skills.update(0.11);rule.update(0)
	check(not rule.rounds.has(delayed.id) and rule.data.lost==300,"delayed kill credits its original shot before settlement")
	var parent:=fire(g)
	g.active_arrow=parent;var fragment:RefCounted=g.launch(Vector2(390,500),Vector2.UP);g.active_arrow=null
	g.arrows.erase(parent);rule.update(0)
	check(rule.rounds.has(parent.id),"a child projectile keeps its own launch alive")
	kill(g,fragment,1);g.arrows.erase(fragment);rule.update(0)
	check(not rule.rounds.has(parent.id) and rule.data.lost==300,"fragment kill protects its parent from blank penalty")
	var wager:=make("wager");wager.spawn_core(true)
	var a:=fire(wager);var b:=fire(wager)
	kill(wager,a,3)
	check(wager.variants.rule.data.stake==1.5 and wager.arrows.has(a) and wager.arrows.has(b),"quota pays immediately during overlapping flight")
	wager.arrows.erase(b);wager.variants.update(0)
	check(wager.variants.rule.data.stake==1.0 and wager.variants.rule.data.busts==1,"another blank shot independently busts the stake")
	kill(wager,a,3)
	check(wager.variants.rule.data.stake==1.0,"one shot cannot raise twice")
	var c:=fire(wager);kill(wager,c,3)
	var d:=fire(wager)
	check(wager.variants.core_hit(d),"cash-out accepts an unfinished shot")
	wager.clear()
	check(wager.settled_bonus==round(wager.bonus(30)*1.5),"cash-out keeps earned stake without penalising final shot")

func _heat() -> void:
	var timings:Array=[]
	for rank in [0,5,10]:
		var g:=make("overheat");g.state.up.draw=rank;g.bricks.clear();g.obstacles.clear()
		var rule:RefCounted=g.variants.rule
		for i in range(60*25):
			g.shoot(70,70);live(g,1.0/60)
			if rule.data.vents>0:break
		check(rule.data.vents==1,"fastest firing reaches overheat at draw rank %d" % rank)
		timings.append(g.time/g.draw_interval())
		live(g,g.draw_interval()*4.0)
		check(not rule.data.vented,"withholding fire cools the bow at draw rank %d" % rank)
	check(float(timings.max())-float(timings.min())<2.0,"heat pacing remains comparable across upgrade tiers")
	var glass:=make("hourglass");glass.bricks.clear();glass.obstacles.clear();fire(glass)
	live(glass,1.5)
	check(glass.variants.bonus_scale()==2.5,"draw plus aiming grace leaves time for a deliberate shot")
	live(glass,1.0)
	check(glass.variants.bonus_scale()<2.5,"long-lived arrow cannot freeze the decision timer")

func _guidance() -> void:
	for id in ["seal","banked","bulwark"]:
		var g:=make(id);g.events.clear();g.spawn_core()
		check(g.events.any(func(e):return e.get("text","").contains(g.variants.core_note())),"core announcement uses "+id+" condition")
		check(not g.events.any(func(e):return e.get("text","")=="核心已显现 · 命中即可清场"),"restricted core never promises a direct clear")
	var session:=Session.new();session.start(4411,{})
	session.command("seenVariant")
	var saved:Dictionary=session.runtime.export_progress()
	check(Progress.valid(saved) and saved.state.variantSeen.has(session.runtime.variants.id),"acknowledged rule is persisted in validated progress")
	var id:String=session.runtime.variants.id
	session.start(1,saved)
	check(session.frame.variant.id==id and session.frame.variant.seen,"restored rule remembers its introduction")
	var before:String=session.frame.variant.status
	session.runtime.phase="ready";session.runtime.paused=false;session.runtime.variants.rule.on_shoot()
	for i in range(15):session.update(1.0/60)
	check(session.frame.variant.status!=before and session.frame.variant.status.contains("剩余"),"countdown publishes without a hit or pointer event")
	session.runtime.dispose()
