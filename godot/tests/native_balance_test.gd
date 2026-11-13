extends SceneTree
## Long-horizon design regressions, real transaction/clear/save integration,
## and boss scaling. Deliberately independent bounds, not copied formulas.
const Sim=preload("res://src/core/simulation.gd")
const Upgrades=preload("res://src/core/upgrade_tree.gd")
const Progress=preload("res://src/core/progress.gd")
const Model=preload("res://tools/upgrade_economy_model.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func fresh() -> RefCounted:
	var g:=Sim.new();g.start(431);g.state.skills={};g.state.draft=null;g.phase="ready";g.variants.reset();g.state.coins=1e9
	return g

func run() -> void:
	var g:=fresh();g.state.up=Upgrades.CAPS.duplicate()
	# Diminishing growth remains positive, and the preview reports the stat the
	# next real arrow/reward will use, including small late-game increments.
	var previous_damage_gain:=INF;var previous_income_gain:=INF
	for rank_value in [0,1,10,100,1000,10000]:
		g.state.mastery={"arrow":rank_value,"brick":rank_value,"comboCap":rank_value}
		var damage:float=g.base_damage();var brick_value:float=Upgrades.brick_value(20,rank_value)
		var preview:Array=g.upgrade_nodes()
		for id in ["mastery_arrow","mastery_brick","mastery_combo"]:
			var node:Dictionary=preview.filter(func(n):return n.id==id)[0]
			check(node.before[0][1]!=node.after[0][1],"late marginal gain remains readable: "+id)
		g.state.mastery.arrow+=1;g.state.mastery.brick+=1
		var damage_gain:float=g.base_damage()-damage
		var income_gain:float=Upgrades.brick_value(20,rank_value+1)-brick_value
		check(damage_gain>0 and damage_gain<previous_damage_gain,"damage gains diminish without stopping")
		check(income_gain>0 and income_gain<previous_income_gain,"income gains diminish without stopping")
		previous_damage_gain=damage_gain;previous_income_gain=income_gain
		check(g.cap_kills()<=26,"higher combo caps remain attainable")
	var total:=0.0
	for key in Upgrades.CAPS:
		for rank_value in range(Upgrades.CAPS[key]):total+=Upgrades.base_cost(key,rank_value)
	var core_budget:=0.0
	for level in range(1,91):core_budget+=g.bonus(level)
	check(total<core_budget,"core bonuses alone cover foundations before the first natural boss")
	g.dispose()
	_rerolls();_forge();_bosses();_income()
	var baseline:Dictionary=Model.run()
	check(baseline.milestones.complete>=40 and baseline.milestones.complete<=60,"ordinary three-kill progression completes foundations in the intended band")
	var early_rate:=0.0;var late_rate:=0.0
	for row in baseline.checkpoints:
		if row.level>=100:check(row.hpPerDamage>=2 and row.hpPerDamage<=3.5,"ordinary durability tracks damage through level %d" % row.level)
		if row.level==1000:early_rate=row.ranksLast100
		if row.level==10000:late_rate=row.ranksLast100
	check(early_rate>0 and late_rate/early_rate>.75 and late_rate/early_rate<1.5,"late purchases per hundred levels stay near the level-1000 cadence")
	var conservative:Dictionary=Model.run({"strategy":"damage_only","core_only":true})
	check(conservative.milestones.complete<=90,"core-only income retains foundation affordability")
	for row in conservative.checkpoints:
		if row.level>=1000:check(row.hpPerDamage>2 and row.hpPerDamage<5,"core-only damage neither trivializes nor loses pace with ordinary durability")
	var rich:Dictionary=Model.run({"kills":12,"achievements":true,"economic_envelope":true})
	for row in rich.checkpoints:
		if row.level>=500:check(row.hpPerDamage>1.25 and row.hpPerDamage<3.5,"rich high-combo envelope does not reach permanent one-hit damage")
	print("Native balance: %d checks, %d failures; 30,000 model levels" % [checks,failures]);quit(1 if failures else 0)

func _rerolls() -> void:
	var g:=fresh();g.state.up=Upgrades.CAPS.duplicate();g.state.up.rerollCap=0;g.state.rerolls=0
	for rank_value in range(4):
		check(g.buy("rerollCap") and g.state.rerolls==rank_value+1,"capacity purchase grants exactly one usable charge")
	check(g.reroll_cap()==5 and g.reroll_interval()==3,"max refresh rank improves both capacity and refill pace")
	g.state.rerolls=0;g.state.level=1;g.state.rerollGrantLevel=0
	for level in range(1,7):
		g.phase="ready";g.clear()
		check(g.state.rerolls==level/3,"refills follow completed levels, not frame updates")
		var count:int=g.state.rerolls;g.clear();check(g.state.rerolls==count,"clear retry cannot duplicate a refill")
		if level==2:check(is_equal_approx(g.snapshot().rerollProgress,2.0/3.0),"HUD progress uses the upgraded interval")
		if level==3:
			var saved:Dictionary=g.export_progress();var back:=Sim.new();back.start(43,saved);back.phase="ready";back.variants.reset()
			check(back.state.rerolls==1 and back.state.rerollGrantLevel==3,"reload preserves the charge and refill clock")
			back.clear();check(back.state.rerolls==1,"reload cannot immediately duplicate a refill");back.dispose()
	g.state.rerolls=5;g.state.level=9;g.phase="ready";g.clear()
	check(g.state.rerolls==5 and g.state.rerollGrantLevel==9,"full storage consumes the elapsed refill, without banking hidden charges")
	g.state.rerolls=4;g.phase="ready";g.clear();check(g.state.rerolls==4,"spending after full storage waits for the next refill")
	g.dispose()

func _forge() -> void:
	var g:=fresh();g.state.skills={"forge":1,"bargain":1}
	var node:Dictionary=g.upgrade_nodes().filter(func(n):return n.id=="power_1")[0]
	check(node.gain==2 and node.forge and node.cost==60,"preview prices one paid rank and one free rank")
	var coins:float=g.state.coins
	check(g.buy("power") and g.state.up.power==2 and g.state.coins==coins-60,"bounded discount/forge benefit reaches the real transaction")
	check(g.buy("power") and g.state.up.power==3,"forge cannot repeat before the next level")
	g.state.up=Upgrades.CAPS.duplicate();g.state.mastery={"arrow":10000,"brick":10000,"comboCap":10000};g.state.level=10000
	var saved:Dictionary=g.export_progress();check(Progress.valid(saved),"high-rank balance state remains saveable")
	var back:=Sim.new();back.start(9,JSON.parse_string(JSON.stringify(saved)))
	check(back.state.up==g.state.up and back.state.mastery==g.state.mastery and back.state.coins==g.state.coins,"balance update retains purchased ranks and wallet on reload")
	check(is_equal_approx(back.base_damage(),g.base_damage()),"shared runtime/preview curve survives reload")
	back.dispose();g.dispose()

func _bosses() -> void:
	for id in ["eye","clock","serpent","forge"]:
		var low:=fresh();var high:=fresh()
		for g in [low,high]:
			g.state.level=100;g.state.up=Upgrades.CAPS.duplicate();g.state.bossOverride={"level":100,"boss":id}
		high.state.mastery.arrow=125;high.state.skills={"railgun":1}
		low.bosses.start(false);high.bosses.start(false)
		check(low.bosses.fight.max==high.bosses.fight.max,"permanent damage and draft no longer inflate boss HP: "+id)
		check(high.damage()/high.bosses.fight.max>low.damage()/low.bosses.fight.max,"damage investment improves relative boss output: "+id)
		for g in [low,high]:g.bosses.fight.hp=0;g.bosses.update(1.0/60)
		check(low.bosses.fight.phase==2 and high.bosses.fight.phase==2 and low.bosses.fight.max==high.bosses.fight.max,"phase changes retain content-based HP: "+id)
		low.dispose();high.dispose()

func _income() -> void:
	var g:=fresh();g.state.up=Upgrades.CAPS.duplicate();g.state.level=54
	var base:float=Model.income(g,3,false)
	g.state.mastery.brick=1;var wealth_gain:float=Model.income(g,3,false)-base;g.state.mastery.brick=0
	g.state.mastery.comboCap=1;var combo_gain:float=Model.income(g,3,false)-base;g.state.mastery.comboCap=0
	var efficiency:float=(wealth_gain/g.mastery_cost("brick"))/(combo_gain/g.mastery_cost("comboCap"))
	check(efficiency>.8 and efficiency<1.5,"first endless economy choices compete at ordinary three-kill combos")
	var high:float=Model.income(g,12,true)
	check(high/base>2 and high/base<4,"long combos remain rewarding without the old fivefold level payout")
	var cap:=1.0
	for item in g.content.achievements:cap+=item.bonus
	check(is_equal_approx(cap,4.0),"all achievement rewards together are bounded at x4")
	g.dispose()
