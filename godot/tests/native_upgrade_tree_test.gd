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
	check(g.upgrade_nodes().size()==21,"21 nodes in the live snapshot")
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
	check(g.upgrade_nodes().all(func(n):return n.complete),"every node completes")
	check(spent>1e6 and spent<2e6,"whole-tree cost stays within model budget")
	check(is_equal_approx(g.draw_interval(),.4) and g.penetration()==6,"bounded fire rate and penetration")
	check(g.damage()>4.9 and g.damage()<5.1 and g.speed()<34,"bounded damage and arrow speed")
	var exported:Dictionary=g.export_progress();check(Progress.valid(exported),"completed tree exports valid progress")
	var restored:=Sim.new();restored.start(9,JSON.parse_string(JSON.stringify(exported)))
	check(restored.state.up==g.state.up,"ranks survive JSON reload")
	restored.dispose();g.dispose()
	g=fresh();g.state.skills={"forge":1};g.state.up.power=2
	var price:float=g.cost("power");var coins:float=g.state.coins
	check(g.buy("power") and g.state.up.power==4,"forge caps bonus at purchased stage")
	check(g.state.skillRuntime.forge and is_equal_approx(coins-g.state.coins,price),"forge is one transaction and consumed once")
	check(not g.buy("power"),"forge cannot bypass next stage requirements")
	g.state.skills={"bargain":1};g.state.up.arrow=0
	check(g.cost("arrow")==60 and g.buy("arrow"),"bargain applies 40 percent discount")
	g.dispose()
	g=fresh();g.state.up={"power":10000,"arrow":10000,"brick":10000,"draw":9,"comboCap":10000,"slots":3,"rerollCap":4}
	var legacy:Dictionary=g.export_progress();check(Progress.valid(legacy),"legacy over-cap ranks remain importable")
	restored=Sim.new();restored.start(9,legacy);restored.phase="ready"
	check(restored.state.up.power==10000 and restored.cost("power")==0 and not restored.buy("power"),"legacy ranks preserved without infinite prices")
	check(restored.buy("draw") and restored.state.up.draw==10,"partly bought legacy stage remains finishable")
	restored.dispose();g.dispose()
	var fx:=FX.new();root.add_child(fx);fx.set_process(false)
	for i in range(40):fx.fire(Vector2.ZERO,Color.GOLD,2);fx.connect_path(Vector2.ZERO,Vector2.ONE,Color.GOLD)
	check(fx.bursts.size()==8 and fx.paths.size()==12,"FX queues bounded under rapid purchases")
	fx.advance(1.2);check(fx.bursts.is_empty() and fx.paths.is_empty(),"FX tails expire completely")
	fx.reduced=true;fx.fire(Vector2.ZERO,Color.GOLD,2);check(fx.bursts.size()==1,"reduced motion preserves confirmation")
	fx.reset();check(fx.bursts.is_empty() and fx.clock==0,"FX reset clears transient state")
	fx.queue_free();await process_frame
	print("Upgrade tree: %d checks, %d failures; %d ranks, total cost %.0f" % [checks,failures,purchases,spent]);quit(1 if failures else 0)
