extends SceneTree
## Tempo & pressure variants: siege, hourglass, overheat and cadence.
const Sim=preload("res://src/core/simulation.gd")
const Progress=preload("res://src/core/progress.gd")
var failures:=0
var checks:=0
var sims:Array=[]

func _initialize() -> void:call_deferred("_run")

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func forced(id:String,level:int=7) -> RefCounted:
	var sim:=Sim.new();sim.start(4411,{});sims.append(sim)
	sim.state.level=level;sim.state.skills={};sim.state.skillChosenLevel=level;sim.state.board=null
	sim.state.variantOverride={"level":level,"id":id};sim.generate();sim.phase="ready"
	return sim

func restored(saved:Dictionary) -> RefCounted:
	var sim:=Sim.new();sim.start(1,saved);sims.append(sim);sim.phase="ready"
	return sim

## Fire again as soon as the draw allows, and settle back to aiming.
func fire(sim:RefCounted) -> bool:
	sim.time=maxf(sim.time,sim.next_shot_at);sim.phase="ready"
	return sim.shoot(0,100)

func live(sim:RefCounted,seconds:float) -> void:
	for i in range(roundi(seconds*60)):sim.variants.update(1.0/60)

func round_trip(sim:RefCounted,label:String) -> RefCounted:
	var saved:Dictionary=sim.export_progress()
	check(Progress.valid(saved),label+" board passes validation")
	var back:=restored(saved)
	check(back.variants.id==sim.variants.id and back.variants.rule.data==sim.variants.rule.data,label+" restores its rule data")
	return back

func rejects(id:String,data:Dictionary,label:String) -> void:
	var variant:=data.duplicate();variant.id=id
	check(not Progress.valid_variant(variant),label)

func _run() -> void:
	_siege();_hourglass();_overheat();_cadence()
	for sim in sims:sim.dispose()
	print("Native variants tempo: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func _lowest(sim:RefCounted) -> float:
	var lowest:=0.0
	for item in sim.bricks+sim.obstacles:lowest=maxf(lowest,item.y+item.h/2)
	return lowest

func _siege() -> void:
	var sim:=forced("siege")
	var rule:RefCounted=sim.variants.rule
	check(sim.variants.id=="siege" and float(rule.data.room)>0 and float(rule.data.room)<=rule.MAX_ROOM,"siege measures its room to the floor")
	var top:float=sim.bricks[0].y
	live(sim,10)
	check(rule.data.offset==0.0 and sim.bricks[0].y==top,"siege waits for the first shot")
	check(rule.bonus_scale()==2.0 and sim.snapshot().variant.text.contains("首箭"),"siege starts at ×2 and says so")
	check(fire(sim) and rule.data.started,"first shot starts the siege")
	live(sim,5)
	check(is_equal_approx(sim.bricks[0].y-top,float(rule.data.offset)) and float(rule.data.offset)>15,"formation creeps toward the bow")
	check(rule.bonus_scale()<2.0 and rule.bonus_scale()>1.0,"advancing shrinks the bonus")
	var before:float=float(rule.data.offset)
	for brick in sim.bricks.slice(0,6):sim.hit(brick,1e9)
	live(sim,0.5)
	check(float(rule.data.offset)<before,"destroyed bricks push the formation back")
	var mid:RefCounted=round_trip(sim,"siege")
	check(is_equal_approx(mid.bricks[0].y,sim.bricks[0].y),"siege restore keeps the shifted bricks")
	live(sim,120)
	check(float(rule.data.offset)==float(rule.data.room) and _lowest(sim)<=rule.FLOOR+0.01,"advance stops at the floor, well above the bow")
	check(rule.bonus_scale()==1.0 and sim.snapshot().variant.text.contains("底线"),"a breached floor leaves the bonus at ×1")
	check(rule.summary().size()==1 and sim.variants.summary().items.size()==1,"siege summary at ×1 has no bonus badge")
	for i in range(100):rule.destroyed(sim.bricks[0])
	live(sim,10)
	check(float(rule.data.offset)>=0 and sim.bricks[0].y>=top-0.01,"recoil never lifts bricks above their start")
	sim.paused=true;var held:float=float(rule.data.offset);live(sim,5)
	check(float(rule.data.offset)==held,"pausing freezes the siege")
	rejects("siege",{"started":true,"offset":200.0,"recoil":0.0,"room":96.0,"front":0},"siege rejects offset past its room")
	rejects("siege",{"started":"yes","offset":0.0,"recoil":0.0,"room":96.0,"front":0},"siege rejects a non-bool start")
	rejects("siege",{"started":true,"offset":0.0,"recoil":-1.0,"room":96.0,"front":0},"siege rejects negative recoil")

func _hourglass() -> void:
	var sim:=forced("hourglass")
	var rule:RefCounted=sim.variants.rule
	live(sim,10)
	check(rule.data.bonus==2.5 and not rule.draining(),"hourglass waits for the first shot")
	check(fire(sim),"hourglass first shot")
	check(rule.draining()==false,"flight and the draw cooldown are free")
	live(sim,3)
	check(rule.data.bonus==2.5,"no sand falls while arrows fly")
	sim.phase="ready";sim.time=sim.next_shot_at
	check(rule.draining() and sim.snapshot().variant.text.contains("流失"),"idle ready bow drains the sand")
	live(sim,4)
	check(is_equal_approx(rule.bonus_scale(),2.1) and is_equal_approx(float(rule.data.idle),4.0),"sand drains 0.1 per idle second")
	round_trip(sim,"hourglass")
	live(sim,60)
	check(rule.bonus_scale()==1.0 and sim.snapshot().variant.text.contains("已尽"),"hourglass bottoms out at ×1")
	check(rule.summary()[0].contains("犹豫"),"hourglass reports hesitation")
	var expected:float=round(sim.bonus()*1.0)
	sim.clear()
	check(sim.settled_bonus==expected and sim.report.variant.title.contains("沙漏"),"hourglass settles at its floor")
	var fresh:=forced("hourglass")
	fire(fresh);fresh.phase="ready";fresh.time=fresh.next_shot_at;fresh.paused=true;live(fresh,5)
	check(fresh.variants.rule.data.bonus==2.5,"pausing stops the hourglass")
	rejects("hourglass",{"started":true,"bonus":3.0,"idle":0.0},"hourglass rejects a bonus above its start")
	rejects("hourglass",{"started":true,"bonus":0.5,"idle":0.0},"hourglass rejects a bonus below its floor")
	rejects("hourglass",{"started":true,"bonus":2.0},"hourglass rejects missing fields")

func _overheat() -> void:
	var sim:=forced("overheat")
	var rule:RefCounted=sim.variants.rule
	var normal:float=sim.draw_interval()
	check(is_equal_approx(sim.snapshot().drawInterval,normal*0.4),"a cold bow draws at ×0.4")
	check(fire(sim) and is_equal_approx(sim.next_shot_at-sim.time,normal*0.4),"first shot uses the cold interval")
	var main:RefCounted=sim.arrows[0]
	check(main.flags.heatScale==1.0 and rule.damage_scale(sim.bricks[0],main)==1.0,"cold arrows hit at full strength")
	check(is_equal_approx(float(rule.data.heat),0.2),"each shot adds heat")
	for i in range(3):fire(sim)
	var hot:RefCounted=sim.arrows.back()
	check(hot.flags.heatScale<1.0 and hot.flags.heatScale>=0.65,"hot arrows hit softer")
	check(rule.interval_scale()>0.4 and rule.interval_scale()<=0.8,"heat slows the draw toward ×0.8")
	check(fire(sim) and rule.data.vented and is_equal_approx(rule.bonus_scale(),1.5),"full heat vents and costs bonus")
	check(rule.interval_scale()==1.6 and sim.snapshot().variant.text.contains("冷却"),"a venting bow draws slowly")
	fire(sim)
	check(float(rule.data.heat)==1.0 and int(rule.data.vents)==1,"venting shots add no heat")
	round_trip(sim,"overheat")
	live(sim,1.0)
	check(rule.data.vented,"vent lasts until the bow cools")
	live(sim,2.0)
	check(not rule.data.vented and float(rule.data.heat)<rule.RESUME,"cooled bow resumes rapid fire")
	for vent in range(6):
		for i in range(6):fire(sim)
		live(sim,4)
	check(rule.bonus_scale()==1.0 and int(rule.data.vents)>=4,"repeated vents floor the bonus at ×1")
	check(rule.summary()[0].contains("过热"),"overheat reports vents")
	sim.paused=true;var held:float=float(rule.data.heat);fire(sim);live(sim,3)
	check(float(rule.data.heat)==held,"pausing freezes the heat")
	rejects("overheat",{"heat":1.5,"vented":false,"bonus":1.8,"vents":0},"overheat rejects heat above 1")
	rejects("overheat",{"heat":0.5,"vented":0,"bonus":1.8,"vents":0},"overheat rejects a non-bool vent")
	rejects("overheat",{"heat":0.5,"vented":false,"bonus":2.5,"vents":0},"overheat rejects a bonus above its start")

func _cadence() -> void:
	var sim:=forced("cadence")
	var rule:RefCounted=sim.variants.rule
	live(sim,5)
	check(rule.data.phase==0.0 and not rule.data.started and sim.snapshot().variant.text.contains("首箭"),"metronome waits for the first shot")
	check(fire(sim) and rule.data.started and int(rule.data.streak)==0,"first shot sets the downbeat")
	check(sim.arrows[0].flags.beatScale==1.0,"the downbeat shot is unscaled")
	live(sim,1.25)
	check(rule.offset()<=rule.WINDOW,"metronome reaches the next beat window")
	check(fire(sim) and int(rule.data.streak)==1 and is_equal_approx(sim.arrows.back().flags.beatScale,1.15),"on-beat shot starts a streak and hits harder")
	check(is_equal_approx(rule.damage_scale(sim.bricks[0],sim.arrows.back()),1.15) and rule.damage_scale(sim.bricks[0],null)==1.0,"beat damage applies to that shot only")
	check(is_equal_approx(rule.period(),1.25) and float(rule.data.phase)==0.0,"streak quickens and re-anchors the beat")
	live(sim,1.20)
	check(fire(sim) and int(rule.data.streak)==2,"streak builds on the faster beat")
	round_trip(sim,"cadence")
	live(sim,0.55)
	check(rule.offset()>rule.WINDOW,"mid-beat is off the window")
	check(fire(sim) and int(rule.data.streak)==0 and sim.arrows.back().flags.beatScale==1.0,"off-beat shot breaks the streak")
	check(int(rule.data.best)==2 and is_equal_approx(rule.bonus_scale(),1.2),"best streak lifts the bonus")
	rule.data.streak=8;rule.data.phase=rule.period()-0.05
	check(fire(sim) and int(rule.data.streak)==8 and is_equal_approx(sim.arrows.back().flags.beatScale,1.85),"streak and damage are capped")
	check(is_equal_approx(rule.period(),0.9) and rule.bonus_scale()<=1.8,"tempo and bonus are bounded")
	check(rule.summary().size()==2 and sim.variants.summary().items.size()==3,"cadence summary adds a bonus badge")
	sim.paused=true;var held:float=float(rule.data.phase);live(sim,1)
	check(float(rule.data.phase)==held,"pausing freezes the metronome")
	rejects("cadence",{"started":true,"phase":0.0,"streak":9,"best":9,"beats":0},"cadence rejects a streak over the cap")
	rejects("cadence",{"started":true,"phase":-1.0,"streak":0,"best":0,"beats":0},"cadence rejects a negative phase")
	rejects("cadence",{"started":true,"phase":0.0,"streak":1.5,"best":2,"beats":0},"cadence rejects fractional streaks")
