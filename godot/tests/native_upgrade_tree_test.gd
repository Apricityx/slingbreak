extends SceneTree
const Sim=preload("res://src/core/simulation.gd")
const Upgrades=preload("res://src/core/upgrade_tree.gd")
const Progress=preload("res://src/core/progress.gd")
const FX=preload("res://src/ui/upgrade_tree_fx.gd")
var failures:=0
var checks:=0

func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)

func fresh() -> RefCounted:
	var g:=Sim.new();g.start(1234);g.phase="ready";g.state.draft=null;g.state.skills={};g.state.coins=1e9
	return g

func run() -> void:
	var g:=fresh()
	var rng_state:int=g.rng.state
	check(g.upgrade_nodes().size()==24,"21 foundation nodes and three endless nodes in live snapshot")
	check(not g.buy("arrow","mastery_arrow"),"endless purchase cannot bypass the full-tree gate")
	check(not g.buy("draw","draw_1"),"locked node rejects direct command")
	check(not g.buy("power","arrow_1"),"mismatched family rejects direct command")
	check(not g.buy("power","missing"),"unknown node rejects direct command")
	g.state.coins=74;check(not g.buy("power") and g.state.coins==74,"insufficient balance never partially deducts")
	g.state.coins=75;check(g.buy("power") and g.state.coins==0,"exact balance buys once")
	check(not g.buy("power") and g.state.up.power==1,"double click cannot overdraw")
	g.state.coins=1e9;g.paused=true;check(not g.buy("power"),"paused transaction rejected")
	g.paused=false;g.phase="flying";check(not g.buy("power"),"flying transaction rejected")
	g.phase="ready"
	var purchases:=1
	var spent:=75.0
	var made_progress:=true
	while made_progress:
		made_progress=false
		for node in Upgrades.NODES:
			if not Upgrades.available(g.state.up,node):continue
			var before:float=g.state.coins;var price:float=g.cost(node.key)
			check(price>0 and is_finite(price),"finite positive price: "+node.id)
			check(g.buy(node.key,node.id),"reachable purchase: "+node.id)
			check(is_equal_approx(before-g.state.coins,price),"exactly one price charged: "+node.id)
			made_progress=true;purchases+=1;spent+=price
	check(purchases==89,"all 89 ranks reachable without deadlocks")
	for key in Upgrades.CAPS:
		check(g.state.up[key]==Upgrades.CAPS[key] and not g.buy(key),"cap enforced for "+key)
	check(g.rng.state==rng_state,"buying never consumes gameplay RNG")
	check(g.upgrade_nodes().filter(func(n):return not n.infinite).all(func(n):return n.complete),"every foundation node completes")
	check(g.snapshot().masteryUnlocked,"completing all foundations unlocks the endless orbit")
	check(spent>1e6 and spent<2e6,"whole-tree cost stays within model budget")
	check(is_equal_approx(g.draw_interval(),.4) and g.penetration()==6,"bounded fire rate and penetration")
	check(g.damage()>4.9 and g.damage()<5.1 and g.speed()<34,"bounded damage and arrow speed")
	var exported:Dictionary=g.export_progress();check(Progress.valid(exported),"completed tree exports valid progress")
	var restored:=Sim.new();restored.start(9,JSON.parse_string(JSON.stringify(exported)))
	check(restored.state.up==g.state.up,"ranks survive JSON reload")
	restored.dispose();g.dispose()
	g=fresh();g.state.up=Upgrades.CAPS.duplicate();g.state.coins=1e15;g.state.level=100
	var base:float=g.base_damage();var income:float=g.reward("normal",1);var cap:float=g.combo_cap()
	var original:Dictionary=g.state.up.duplicate();rng_state=g.rng.state
	for node in Upgrades.MASTERY:
		var last_price:=0.0
		for rank_index in range(125):
			var price:float=g.mastery_cost(node.key);var coins:float=g.state.coins
			check(is_finite(price) and price>last_price,"endless prices rise without exponential overflow")
			check(g.buy(node.key,node.id),"endless ranks remain purchasable beyond 100")
			check(g.state.mastery[node.key]==rank_index+1 and is_equal_approx(coins-g.state.coins,price),"endless transaction charges exactly once")
			last_price=price
	check(is_equal_approx(g.base_damage(),base+10),"endless damage reaches the real combat stat")
	var arrow:RefCounted=g.launch(g.origin,Vector2.UP*30)
	check(is_equal_approx(arrow.damage,g.damage()),"new arrows use the ascended damage")
	check(g.reward("normal",1)>income*4,"endless income reaches real brick rewards")
	check(is_equal_approx(g.combo_cap(),cap+31.25) and g.multiplier(10000)==g.combo_cap(),"endless cap reaches the real combo multiplier")
	check(is_equal_approx(g.combo_step(),1.8) and g.cap_kills()<=26,"endless combo growth remains reachable on actual boards")
	check(g.state.up==original and g.rng.state==rng_state,"endless ranks neither rewrite legacy ranks nor consume RNG")
	check(g.penetration()==6 and is_equal_approx(g.draw_interval(),.4) and g.slots==4 and g.reroll_cap()==5,"mechanical limits remain stable after ascension")
	var saved:Dictionary=g.export_progress();check(Progress.valid(saved),"endless progress validates")
	restored=Sim.new();restored.start(47,JSON.parse_string(JSON.stringify(saved)));restored.phase="ready"
	check(restored.state.mastery==g.state.mastery and is_equal_approx(restored.base_damage(),g.base_damage()),"endless ranks and combat gains survive JSON reload")
	var price:float=restored.mastery_cost("arrow");restored.state.coins=price-1
	check(not restored.buy("arrow","mastery_arrow") and restored.state.coins==price-1,"unaffordable endless purchase is atomic")
	restored.state.coins=price;check(restored.buy("arrow","mastery_arrow") and restored.state.coins==0,"exact endless balance succeeds")
	check(not restored.buy("arrow","mastery_arrow"),"repeated endless click cannot overdraw")
	restored.state.coins=1e9;restored.paused=true;check(not restored.buy("brick","mastery_brick"),"paused endless purchase rejected")
	restored.paused=false;restored.phase="flying";check(not restored.buy("brick","mastery_brick"),"flying endless purchase rejected")
	restored.dispose()
	for invalid in [-1,1.5,INF,"3"]:
		var bad:Dictionary=saved.duplicate(true);bad.state.mastery.arrow=invalid;check(not Progress.valid(bad),"invalid endless rank rejected")
	var bad:Dictionary=saved.duplicate(true);bad.state.up.draw=9;check(not Progress.valid(bad),"import cannot grant endless ranks before completing foundations")
	bad=saved.duplicate(true);bad.state.mastery.power=1;check(not Progress.valid(bad),"unknown endless family rejected")
	for key in Upgrades.MASTERY_KEYS:
		g.state.coins=1e18
		g.state.mastery[key]=1000000000
		check(is_finite(g.mastery_cost(key)) and g.mastery_cost(key)<=1e15,"extreme endless costs remain finite and payable")
		check(g.buy(key,Upgrades.MASTERY.filter(func(n):return n.key==key)[0].id),"large endless ranks do not hit a gameplay cap")
	check(Progress.valid(g.export_progress()),"large endless ranks remain saveable")
	check(g.cap_kills()<=26,"extreme endless combo still gives useful per-kill gains")
	g.dispose()
	g=fresh();g.state.skills={"forge":1};g.state.up.power=2
	price=g.cost("power");var coins:float=g.state.coins
	check(g.buy("power") and g.state.up.power==4,"forge caps bonus at purchased stage")
	check(g.state.skillRuntime.forge and is_equal_approx(coins-g.state.coins,price),"forge is one transaction and consumed once")
	check(not g.buy("power"),"forge cannot bypass next stage requirements")
	g.state.skills={"bargain":1};g.state.up.arrow=0
	check(g.cost("arrow")==60 and g.buy("arrow"),"bargain applies 40 percent discount")
	g.state.up=Upgrades.CAPS.duplicate();g.state.skills={"bargain":1,"forge":1};g.state.skillRuntime.forge=false
	check(g.mastery_cost("arrow")==192000,"bargain discounts endless price")
	coins=g.state.coins
	check(g.buy("arrow","mastery_arrow") and g.state.mastery.arrow==3 and g.state.coins==coins-192000,"forge grants three endless ranks in one paid transaction")
	check(g.buy("arrow","mastery_arrow") and g.state.mastery.arrow==4,"endless forge consumes only one charge per level")
	g.dispose()
	g=fresh();g.state.up={"power":10000,"arrow":10000,"brick":10000,"draw":9,"comboCap":10000,"slots":3,"rerollCap":4}
	var legacy:Dictionary=g.export_progress();check(Progress.valid(legacy),"legacy over-cap ranks remain importable")
	legacy.state.erase("mastery")
	restored=Sim.new();restored.start(9,legacy);restored.phase="ready"
	check(restored.state.up.power==10000 and restored.cost("power")==0 and not restored.buy("power"),"legacy ranks preserved without infinite prices")
	check(restored.buy("draw") and restored.state.up.draw==10,"partly bought legacy stage remains finishable")
	check(restored.state.mastery=={"arrow":0,"brick":0,"comboCap":0} and restored.buy("arrow","mastery_arrow"),"old saves gain the endless orbit only after the last foundation rank")
	restored.dispose();g.dispose()
	var fx:=FX.new();root.add_child(fx);fx.set_process(false)
	for i in range(40):fx.fire(Vector2.ZERO,Color.GOLD,2);fx.connect_path(Vector2.ZERO,Vector2.ONE,Color.GOLD)
	check(fx.bursts.size()==8 and fx.paths.size()==12,"FX queues bounded under rapid purchases")
	fx.advance(1.2);check(fx.bursts.is_empty() and fx.paths.is_empty(),"FX tails expire completely")
	fx.reduced=true;fx.fire(Vector2.ZERO,Color.GOLD,2);check(fx.bursts.size()==1,"reduced motion preserves confirmation")
	fx.reset();check(fx.bursts.is_empty() and fx.clock==0,"FX reset clears transient state")
	fx.queue_free();await process_frame
	print("Upgrade tree: %d checks, %d failures; %d ranks, total cost %.0f" % [checks,failures,purchases,spent]);quit(1 if failures else 0)
