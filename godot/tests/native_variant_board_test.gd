extends SceneTree
## Board-composition variants: collapse, domino, mimic and fusion.
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

func at(level:int,id:String="",seed_value:int=4411,progress:Dictionary={}) -> RefCounted:
	var sim:=Sim.new();sim.start(seed_value,progress);sims.append(sim)
	if progress.is_empty():
		sim.state.level=level;sim.state.skills={};sim.state.skillChosenLevel=level;sim.state.board=null
		sim.state.variantOverride={"level":level,"id":id}
		sim.generate()
	sim.phase="ready"
	return sim

func step(sim:RefCounted,seconds:float) -> void:
	for i in range(ceili(seconds*60)):sim.tick(1.0/60)

## Export, validate, restore; returns the restored sim (or null).
func round_trip(sim:RefCounted,id:String) -> RefCounted:
	var saved:Dictionary=JSON.parse_string(JSON.stringify(sim.export_progress()))
	check(Progress.valid(saved),"%s board passes validation" % id)
	var back:=at(0,"",1,saved)
	check(back.variants.id==id and back.bricks.size()==sim.bricks.size() and back.initial==sim.initial,"%s restores rule and board" % id)
	return back

func rejects(id:String,data:Dictionary,label:String) -> void:
	var saved:Dictionary=data.duplicate();saved.id=id
	check(not Progress.valid_variant(saved),label)

func lane_open(sim:RefCounted) -> bool:
	for wall in sim.obstacles:
		if absf(wall.x-390)<96:return false
	return true

func _run() -> void:
	for id in ["collapse","domino","mimic","fusion"]:check(Variants.script_for(id)!=null,"%s rule loads" % id)
	var plain:=at(14)
	_collapse(plain);_domino(plain);_mimic();_fusion(plain)
	for sim in sims:sim.dispose()
	print("Native variants board: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func _collapse(_plain:RefCounted) -> void:
	var sim:=at(14,"collapse")
	var rule:RefCounted=sim.variants.rule
	check(sim.variants.id=="collapse" and sim.initial==sim.bricks.size() and lane_open(sim),"collapse keeps the board and lane")
	# Settled: nothing sits above an empty cell in its column.
	var targets:Dictionary=rule._targets()
	var settled:=true
	for brick in targets:settled=settled and is_equal_approx(brick.y,targets[brick])
	check(settled and not rule.settling,"collapse starts settled")
	# Break the lowest brick of a column with something above it.
	var victim:RefCounted=null
	for brick in sim.bricks:
		# Directly stacked (no wall between), so the upper brick must fall.
		var above:Array=sim.bricks.filter(func(b):return b.x==brick.x and is_equal_approx(b.y,brick.y-60))
		var below:Array=sim.bricks.filter(func(b):return b.x==brick.x and b.y>brick.y)
		if not above.is_empty() and below.is_empty() and (victim==null or brick.y>victim.y):victim=brick
	check(victim!=null,"collapse finds a stacked column")
	var column_x:float=victim.x
	var drop_y:float=victim.y
	var upper:RefCounted=sim.bricks.filter(func(b):return b.x==column_x and b.y<drop_y).reduce(func(a,b):return a if a.y>b.y else b)
	var upper_y:float=upper.y
	sim.hit(victim,victim.hp+1)
	check(rule.settling,"breaking a brick wakes the column")
	step(sim,0.05)
	check(upper.y>upper_y and upper.y<drop_y,"bricks above fall gradually")
	step(sim,2.0)
	check(is_equal_approx(upper.y,drop_y) and not rule.settling and int(rule.data.fallen)>0,"the stack lands in the gap")
	var column:Array=sim.bricks.filter(func(b):return b.x==column_x)
	var ys:Dictionary={}
	for brick in column:ys[roundi(brick.y)]=true
	check(ys.size()==column.size(),"falling bricks never overlap")
	var sunk:=false
	for wall in sim.obstacles:
		for brick in sim.bricks:sunk=sunk or brick.bounds.intersects(wall.bounds)
	check(not sunk,"collapsed bricks never sink into walls")
	check(sim.variants.bonus_scale()==1.5 and sim.snapshot().variant.text.contains("已塌落"),"collapse pays ×1.5 and reports falls")
	check(sim.variants.summary().items.size()==2,"collapse summary lists falls and bonus")
	var back:=round_trip(sim,"collapse")
	check(int(back.variants.rule.data.fallen)==int(rule.data.fallen),"collapse restore keeps the fall count")
	rejects("collapse",{"floor":20,"fallen":0},"collapse rejects an off-board floor")
	rejects("collapse",{"floor":710,"fallen":-1},"collapse rejects a negative count")

func _domino(plain:RefCounted) -> void:
	var sim:=at(14,"domino")
	check(sim.variants.id=="domino" and sim.initial==sim.bricks.size() and sim.bricks.size()==plain.bricks.size(),"domino keeps the layout")
	check(sim.bricks.all(func(b):return b.hp>=ceil(plain.base_hp()*1.5)),"domino bricks are sturdier")
	var rule:RefCounted=sim.variants.rule
	var origin:RefCounted=null
	for brick in sim.bricks:
		if rule.neighbours(brick.x,brick.y).size()==2 and brick.type=="normal":origin=brick;break
	check(origin!=null,"domino finds a brick with two row neighbours")
	var sides:Array=rule.neighbours(origin.x,origin.y)
	var before:Array=sides.map(func(b):return b.hp)
	var far:Array=sim.bricks.filter(func(b):return absf(b.y-origin.y)>50)
	var far_hp:float=far.reduce(func(total,b):return total+b.hp,0.0)
	sim.hit(origin,origin.hp+1)
	check(sides[0].hp==before[0] and rule.pending.size()==1,"the push waits a beat")
	step(sim,rule.DELAY+0.05)
	var pushed:=true
	for i in sides.size():
		var expected:float=before[i]-sim.damage()*rule.PUSH
		pushed=pushed and (not sides[i] in sim.bricks or is_equal_approx(sides[i].hp,expected))
	check(pushed,"neighbours take PUSH × damage")
	check(far.reduce(func(total,b):return total+b.hp,0.0)==far_hp,"pushes stay on the same row")
	# Weakened bricks topple in turn: the ripple travels along the row.
	var first:RefCounted=null
	var second:RefCounted=null
	for brick in sim.bricks:
		for side in rule.neighbours(brick.x,brick.y):
			if rule.neighbours(side.x,side.y).size()==2:first=brick;second=side;break
		if first!=null:break
	check(first!=null,"domino finds three bricks in a row")
	var third:RefCounted=rule.neighbours(second.x,second.y).filter(func(b):return b!=first)[0]
	second.hp=0.1;third.hp=0.1
	var toppled:int=int(rule.data.toppled)
	sim.hit(first,first.hp+1)
	step(sim,rule.DELAY+0.02)
	check(not second in sim.bricks and third in sim.bricks,"the first neighbour topples a beat later")
	step(sim,rule.DELAY+0.02)
	check(not third in sim.bricks and int(rule.data.toppled)>=toppled+2,"the ripple carries on and is counted")
	check(sim.variants.bonus_scale()==1.3 and sim.snapshot().variant.text.contains("已推倒"),"domino pays ×1.3 and reports topples")
	var back:=round_trip(sim,"domino")
	check(int(back.variants.rule.data.toppled)==int(rule.data.toppled) and back.variants.rule.pending.is_empty(),"domino restore keeps the count, drops transient ripples")
	rejects("domino",{"toppled":1.5},"domino rejects a fractional count")
	rejects("domino",{},"domino rejects missing data")

func _mimic() -> void:
	var sim:=at(14,"mimic")
	var rule:RefCounted=sim.variants.rule
	var hidden:Array=sim.bricks.filter(func(b):return b.flags.get("mimic",false))
	var normals:int=sim.bricks.filter(func(b):return b.type=="normal").size()
	check(sim.variants.id=="mimic" and hidden.size()==ceili(normals*rule.SHARE) and hidden.all(func(b):return b.type=="normal"),"mimic hides inside normal bricks")
	check(rule.unrevealed()==hidden.size() and sim.snapshot().variant.text.contains("未揭晓 %d" % hidden.size()),"mimic reports hidden bricks")
	# The first hit reveals before damage; a second hit does not re-roll.
	var brick:RefCounted=hidden[0]
	brick.hp=1000;brick.max_hp=1000
	sim.hit(brick,1)
	check(not brick.flags.has("mimic") and (brick.type!="normal" or brick.max_hp==3000),"first hit reveals a special or armour")
	var revealed_type:String=brick.type
	var max_after:float=brick.max_hp
	sim.hit(brick,1)
	check(brick.type==revealed_type and brick.max_hp==max_after,"a revealed brick stays revealed")
	check(int(rule.data.revealed)+int(rule.data.armored)==1 and rule.unrevealed()==hidden.size()-1,"mimic counts reveals")
	# A lethal reveal fires as its new type in the same hit.
	var fired:=false
	for i in range(1,hidden.size()):
		var item:RefCounted=hidden[i]
		if not item in sim.bricks or not item.flags.get("mimic",false):continue
		sim.hit(item,item.hp*0.5+0.001)
		if item.type!="normal":fired=true;break
	check(fired,"some reveal yields a special brick")
	var revealed:int=int(rule.data.revealed)+int(rule.data.armored)
	check(revealed>=2 and rule.unrevealed()<=hidden.size()-revealed,"mimic tallies every reveal")
	check(sim.variants.bonus_scale()==1.0 and sim.variants.summary().items.size()==2,"mimic is neutral and lists reveals")
	var back:=round_trip(sim,"mimic")
	check(back.variants.rule.unrevealed()==rule.unrevealed(),"mimic flags survive restore")
	rejects("mimic",{"revealed":1,"armored":-2},"mimic rejects negative counts")
	rejects("mimic",{"revealed":"1","armored":0},"mimic rejects non-numeric counts")

func _fusion(plain:RefCounted) -> void:
	var sim:=at(14,"fusion")
	var rule:RefCounted=sim.variants.rule
	var fused:Array=sim.bricks.filter(func(b):return b.flags.get("fused",false))
	check(sim.variants.id=="fusion" and fused.size()==int(rule.data.fused) and fused.size()>=8,"fusion welds many pairs")
	check(sim.bricks.size()==plain.bricks.size()-fused.size() and sim.initial==sim.bricks.size(),"fusion recounts the board")
	check(fused.all(func(b):return b.w==180 and b.type=="normal" and b.hp>=plain.base_hp()*2),"fused bricks are double width and health")
	var overlap:=false
	for i in sim.bricks.size():
		for j in range(i+1,sim.bricks.size()):
			if sim.bricks[i].bounds.intersects(sim.bricks[j].bounds):overlap=true
		for wall in sim.obstacles:
			if sim.bricks[i].bounds.intersects(wall.bounds):overlap=true
	check(not overlap and lane_open(sim),"fused bricks fit their cells")
	var normal:RefCounted=sim.bricks.filter(func(b):return b.type=="normal" and not b.flags.get("fused",false))[0]
	check(sim.reward("normal",1,null,fused[0])==round(sim.reward("normal",1,null,normal)*rule.REWARD),"fused bricks pay ×REWARD")
	var killed:int=sim.killed
	sim.hit(fused[0],fused[0].hp+1)
	check(sim.killed==killed+1 and int(rule.data.broken)==1,"a fused break counts once")
	check(sim.snapshot().variant.text.contains("巨砖 1 / %d" % fused.size()) and sim.variants.bonus_scale()==1.0,"fusion reports broken giants")
	# Clearing still reaches the core threshold.
	for brick in sim.bricks.duplicate():
		if sim.core!=null:break
		sim.hit(brick,brick.hp+1)
	check(sim.core!=null,"fusion board still reveals the core")
	var back:=round_trip(sim,"fusion")
	check(back.bricks.filter(func(b):return b.flags.get("fused",false)).size()==sim.bricks.filter(func(b):return b.flags.get("fused",false)).size(),"fused flags survive restore")
	rejects("fusion",{"fused":3,"broken":-1},"fusion rejects negative counts")
	rejects("fusion",{"fused":3},"fusion rejects missing fields")
