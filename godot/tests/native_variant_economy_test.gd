extends SceneTree
## Economy variants (wanted/escrow/streak/wager): payouts against a plain level,
## settled bonus, HUD/report text, save round-trip and malformed-data rejection.
const Sim=preload("res://src/core/simulation.gd")
const Variants=preload("res://src/core/variants.gd")
const Progress=preload("res://src/core/progress.gd")
const LEVEL:=7
const SEED:=4411
var failures:=0
var checks:=0
var sims:Array=[]

func _initialize() -> void:call_deferred("_run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func make(variant_id:String,level:int=LEVEL,seed_value:int=SEED) -> RefCounted:
	var sim:=Sim.new();sim.start(seed_value,{});sims.append(sim)
	sim.state.level=level;sim.state.skills={};sim.state.skillChosenLevel=level;sim.state.board=null
	sim.state.variantOverride={"level":level,"id":variant_id}
	sim.generate();sim.phase="ready"
	return sim

func restore(saved:Dictionary) -> RefCounted:
	var sim:=Sim.new();sim.start(1,saved);sims.append(sim);sim.phase="ready"
	return sim

func normals(sim:RefCounted) -> Array:
	return sim.bricks.filter(func(b):return b.type=="normal" and not b.flags.get("wanted",false))

## Coin delta of destroying one brick with passive damage (no scoring arrow).
func pay(sim:RefCounted,brick:RefCounted) -> float:
	var before:float=sim.state.coins
	sim.hit(brick,1e9)
	return sim.state.coins-before

## Coin deltas of one arrow killing `count` normal bricks in a row (no achievement fires below 4).
func run(sim:RefCounted,count:int,arrow:RefCounted=null) -> Array:
	if arrow==null:arrow=sim.launch(sim.origin,Vector2(0,-20))
	var deltas:Array=[]
	var targets:Array=normals(sim).slice(0,count)
	sim.active_arrow=arrow
	for brick in targets:deltas.append(pay(sim,brick))
	sim.active_arrow=null
	return deltas

## Fire a real shot; `kills` bricks fall to its main arrow, then every arrow ends.
func shot(sim:RefCounted,kills:int) -> void:
	sim.next_shot_at=0
	check(sim.shoot(0,100),"shot fires")
	if kills>0:run(sim,kills,sim.arrows[0])
	sim.arrows.clear()
	for i in range(2):sim.tick(1.0/60)

func rejects(sim:RefCounted,bad:Dictionary,label:String) -> void:
	var saved:Dictionary=sim.export_progress()
	var variant:Dictionary=saved.state.board.variant.duplicate(true)
	for key in bad:variant[key]=bad[key]
	saved.state.board.variant=variant
	check(not Progress.valid(saved),label)

func round_trip(sim:RefCounted,label:String) -> RefCounted:
	var saved:Dictionary=sim.export_progress()
	check(Progress.valid(saved),label+" board passes validation")
	var back:=restore(saved)
	check(back.variants.id==sim.variants.id and back.variants.rule.data==sim.variants.rule.data,label+" restore keeps rule data")
	return back

func _run() -> void:
	for id in ["wanted","escrow","streak","wager"]:
		check(Variants.script_for(id)!=null and id in Variants.ORDER,"%s loads by id and is in the level deck" % id)
		var title:String=make(id).variants.rule.title()
		check(title.length()>=2 and title.length()<=4,"%s has a short title" % id)
	var plain:=make("")
	check(plain.variants.id=="","plain comparison level has no rule")
	var base:float=pay(plain,normals(plain)[0])
	check(base==plain.reward("normal",1),"plain passive kill pays the base reward")
	var plain_run:Array=run(make(""),3)
	_wanted(base);_escrow(base);_streak(base,plain_run);_wager()
	for sim in sims:sim.dispose()
	print("Native variants economy: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func _wanted(base:float) -> void:
	var g:=make("wanted")
	var marked:Array=g.bricks.filter(func(b):return b.flags.get("wanted",false))
	check(g.variants.id=="wanted" and marked.size()==3 and g.variants.rule.data.total==3,"wanted marks three bounty bricks")
	for a in marked:
		check(a.type=="normal" and a.hp>=g.base_hp()*2.5,"bounty bricks are armoured normals")
		for b in marked:check(a==b or a.position.distance_to(b.position)>=200,"bounty bricks are spread out")
	check(pay(g,normals(g)[0])==base,"ordinary bricks pay as usual on a wanted level")
	check(pay(g,marked[0])==round(base*10),"first-shot bounty pays ×10")
	g.state.skillRuntime.shots=4
	check(pay(g,marked[1])==round(base*7),"bounty decays 0.75 per shot")
	check(g.variants.rule.data.claimed==2 and g.snapshot().variant.text.contains("×7 · 剩 1"),"wanted HUD shows the bounty and targets left")
	var back:=round_trip(g,"wanted")
	check(back.bricks.filter(func(b):return b.flags.get("wanted",false)).size()==1,"restore keeps the remaining bounty flag")
	back.state.skillRuntime.shots=40
	check(pay(back,back.bricks.filter(func(b):return b.flags.get("wanted",false))[0])==round(base*3),"bounty never drops below ×3")
	check(back.snapshot().variant.text.contains("悬赏已清"),"cleared bounties are reported")
	var expected:float=round(back.bonus())
	back.spawn_core(true);back.clear()
	check(back.settled_bonus==expected and back.report.variant.items==["缉拿 3 / 3"],"wanted keeps the core bonus and reports captures")
	rejects(g,{"claimed":4},"wanted rejects claimed above total")
	rejects(g,{"total":-1},"wanted rejects negative totals")
	rejects(g,{"claimed":"2"},"wanted rejects non-numeric counters")

func _escrow(base:float) -> void:
	var g:=make("escrow")
	var rule:RefCounted=g.variants.rule
	var paid:float=pay(g,normals(g)[0])
	check(paid==round(base*0.5),"escrow pays bricks half up front")
	check(rule.data.pot==paid*2,"escrow banks twice the payment in the pot")
	shot(g,0)
	var lost:float=round(paid*2*0.3)
	check(rule.data.pot==paid*2-lost and rule.data.lost==lost and not rule.data.open,"a blank shot loses 30% of the pot")
	shot(g,2)
	check(rule.data.pot>paid*2-lost and rule.data.lost==lost,"a scoring shot keeps and grows the pot")
	g.next_shot_at=0;g.shoot(0,100);g.next_shot_at=0;g.shoot(0,100)
	run(g,1,g.arrows[1])
	check(g.arrows.size()==2 and rule.data.open and rule.data.kills==1,"a follow-up shot in the air joins the open shot")
	g.arrows.clear()
	for i in range(2):g.tick(1.0/60)
	check(rule.data.lost==lost,"follow-up kill saves the shot")
	check(g.snapshot().variant.text.begins_with("奖池 · 奖池 "),"escrow HUD shows the pot")
	var back:=round_trip(g,"escrow")
	var pot:float=back.variants.rule.data.pot
	check(back.variants.rule.seen==0.0 and pay(back,normals(back)[0])==round(base*0.5) and back.variants.rule.data.pot==pot+round(base*0.5)*2,"restored pot keeps accruing from fresh stats")
	pot=back.variants.rule.data.pot
	var expected:float=back.bonus()+pot
	back.spawn_core(true)
	check(back.variants.core_hit(null),"escrow lets the core clear")
	back.clear()
	check(absf(back.settled_bonus-expected)<=1,"core cashes out the pot with the bonus")
	var items:Array=back.report.variant.items
	check(items.size()==3 and items[0].begins_with("奖池") and items[1].begins_with("流失") and items[2].begins_with("奖金 ×"),"escrow report shows pot, loss and bonus badges")
	back.variants.update(1.0/60)
	check(back.variants.rule.data.lost==lost,"no settlement runs during clearing")
	var capped:=make("escrow")
	capped.variants.rule.data.pot=1e12;pay(capped,normals(capped)[0])
	check(capped.variants.rule.data.pot==capped.bonus()*3 and is_equal_approx(capped.variants.bonus_scale(),4.0),"pot is capped at 3× bonus (×4 total)")
	rejects(g,{"pot":-1},"escrow rejects a negative pot")
	rejects(g,{"open":1},"escrow rejects a non-bool open flag")
	rejects(g,{"kills":0.5},"escrow rejects fractional kills")

func _streak(base:float,plain_run:Array) -> void:
	var g:=make("streak")
	check(pay(g,normals(g)[0])==round(base*0.5),"passive streak kills pay half")
	var deltas:Array=run(g,3)
	check(deltas.size()==3 and plain_run.size()==3,"three arrow kills scored")
	check(deltas[0]==round(plain_run[0]*0.5) and deltas[1]==round(plain_run[1]*0.5),"first two arrow kills pay half")
	check(deltas[2]==round(plain_run[2]*2),"third arrow kill pays double")
	var data:Dictionary=g.variants.rule.data
	check(data.boosted==1 and data.best==3 and g.snapshot().variant.text.contains("已赏 1 块"),"streak tracks boosted bricks")
	round_trip(g,"streak")
	var expected:float=round(g.bonus())
	g.spawn_core(true);g.clear()
	check(g.settled_bonus==expected and g.report.variant.items==["连杀砖 1 块","最长 3 连"],"streak keeps the bonus and reports the run")
	var bad:=make("streak")
	rejects(bad,{"boosted":-3},"streak rejects negative counts")
	rejects(bad,{"best":null},"streak rejects missing best")

func _wager() -> void:
	var g:=make("wager")
	var rule:RefCounted=g.variants.rule
	check(g.snapshot().variant.text.contains("核心现身后开局"),"wager waits for the core")
	shot(g,3)
	check(rule.data.stake==1.0 and not rule.data.armed,"shots before the core never raise")
	g.spawn_core(true)
	shot(g,3)
	check(rule.data.stake==1.5 and rule.data.best==1.5,"three kills with the core up raise the stake")
	check(g.snapshot().variant.text.contains("赌注 ×1.5"),"wager HUD shows the stake")
	shot(g,1)
	check(rule.data.stake==1.0 and rule.data.busts==1,"a short shot busts the stake to ×1")
	shot(g,0)
	check(rule.data.busts==1,"a blank at ×1 is not a bust")
	shot(g,3)
	g.next_shot_at=0;g.shoot(0,100)
	var back:=round_trip(g,"wager")
	check(back.variants.rule.data.open and back.variants.rule.data.armed,"wager restores an open shot")
	back.variants.update(1.0/60)
	check(back.variants.rule.data.busts==2 and back.variants.rule.data.stake==1.0,"restored shot that scored nothing busts")
	g.active_arrow=g.arrows[0]
	check(g.variants.core_hit(g.arrows[0]) and not rule.data.open,"core hit cashes out without settling")
	g.active_arrow=null
	var expected:float=round(g.bonus()*1.5)
	g.clear()
	check(g.settled_bonus==expected,"settled bonus uses the stake")
	check(g.report.variant.items==["最高 ×1.5","失手 1 次","奖金 ×1.5"],"wager report shows best stake, busts and bonus")
	var top:=make("wager")
	top.variants.rule.data.stake=3.75;top.variants.rule._raise(Vector2.ZERO)
	check(top.variants.rule.data.stake==4.0,"stake reaches ×4")
	top.variants.rule._raise(Vector2.ZERO)
	check(top.variants.rule.data.stake==4.0 and top.variants.bonus_scale()==4.0,"stake is capped at ×4")
	top.bricks=top.bricks.slice(0,2)
	check(top.variants.rule.quota()==2,"quota shrinks to the bricks left")
	rejects(top,{"stake":0.5},"wager rejects a stake below ×1")
	rejects(top,{"stake":9.0},"wager rejects a stake above the cap")
	rejects(top,{"armed":"yes"},"wager rejects a non-bool armed flag")
