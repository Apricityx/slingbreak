extends SceneTree
const Income=preload("res://src/effects/income_tallies.gd")
const Sim=preload("res://src/core/simulation.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize() -> void:
	var tally:=Income.new()
	tally.record(Vector2(200,300),3,1,1,9)
	tally.advance(0.1)
	var before:Vector2=tally.items[0].position
	tally.record(Vector2(400,300),7,1,2,9)
	check(tally.items.size()==1 and tally.items[0].total==10 and tally.items[0].sub=="2 块","same arrow merges exact awards and block count")
	check(tally.items[0].position==before and tally.items[0].target==Vector2(400,274),"new kill changes target without teleporting")
	tally.advance(1.0/120)
	check(tally.items[0].position.x>before.x and tally.items[0].position.x<400,"continuous follow")
	check(Income.tier(1,9)==0 and Income.tier(4,9)==1 and Income.tier(6,9)==2 and Income.tier(9,9)==3,"Web heat thresholds")
	check(Income.format_amount(12345)=="12.3k" and Income.format_amount(1234567)=="1.2m","compact large income")
	for id in range(2,65):tally.record(Vector2(300,400),10,id,1,9)
	var total:=0.0
	for item in tally.items:total+=item.total
	check(tally.items.size()==8 and total==640,"overload bounded at eight without losing sums")
	tally.advance(1.3);check(tally.items.is_empty(),"complete fade retires all entries")
	tally.record(Vector2.ZERO,5,1,1,9);tally.advance(0.95)
	tally.record(Vector2.ONE,7,1,2,9)
	check(tally.items.size()==2 and tally.items[0].total==5 and tally.items[1].total==7,"fading tally is not revived")
	var a:=Income.new();var b:=Income.new()
	a.record(Vector2.ZERO,1,1,1,9);b.record(Vector2.ZERO,1,1,1,9)
	a.record(Vector2(400,200),1,1,2,9);b.record(Vector2(400,200),1,1,2,9)
	for i in range(12):a.advance(1.0/30)
	for i in range(48):b.advance(1.0/120)
	check(a.items[0].position.distance_to(b.items[0].position)<0.1,"follow independent of rendering frame rate before rise")
	var g:=Sim.new();g.start(123);g.bricks.clear();g.fx.reset();g.phase="flying";g.threshold=1000;g.stats.previousBest=1000
	var arrow:RefCounted=g.launch(Vector2(300,400),Vector2.UP*20);g.active_arrow=arrow
	var balance:float=g.state.coins
	for i in range(12):g.hit(g.make_brick({"x":300+i*5,"y":400,"hp":1,"max":1,"type":"normal"}),100)
	check(g.fx.income.items.size()==1 and g.fx.income.items[0].count==12,"real gameplay kills use dedicated income")
	check(g.fx.income.items[0].total==g.state.coins-balance and g.shot_money==g.state.coins-balance,"display matches paid rewards including achievement bonuses")
	g.fx.floating(Vector2.ZERO,"+500",Color.RED,20)
	check(g.fx.income.items[0].count==12 and g.fx.texts.back().text=="+500","unrelated numeric skill messages are not merged")
	var started:=Time.get_ticks_usec()
	for i in range(10000):g.fx.income.record(Vector2(300,400),3,i%64,i%30,9)
	print("Native income stress: 10000 awards in %.2f ms; %d active tallies" % [(Time.get_ticks_usec()-started)/1000.0,g.fx.income.items.size()])
	check(g.fx.income.items.size()==8,"stress stays bounded")
	g.fx.reset();check(g.fx.income.items.is_empty(),"level/reset clears income")
	g.active_arrow=null;g.dispose()
	print("Native income: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
