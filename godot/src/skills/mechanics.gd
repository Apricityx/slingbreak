extends RefCounted
## Skill hooks have explicit owners and bounded delayed work. Jobs retain the
## source arrow, never a mutable global source from a later volley.
const Geometry = preload("res://src/core/geometry.gd")
var owner: WeakRef
var g: RefCounted:
	get:return owner.get_ref()
var jobs: Array = []
var fields: Array = []
var records: Array = []
var budget := 120

func _init(simulation: RefCounted) -> void:owner=weakref(simulation)
func rank(id: String) -> bool:return g.rank(id)>0
func reset() -> void:jobs.clear();fields.clear();records.clear();budget=120
func pending() -> bool:return not jobs.is_empty() or not fields.is_empty()

func later(delay: float, source: RefCounted, callback: Callable, limited: bool=false) -> void:
	if jobs.size()>=512 or limited and budget<=0:return
	if limited:budget-=1
	jobs.append({"at":g.time+delay,"level":g.state.level,"source":source,"callback":callback})

func with_source(source: RefCounted, callback: Callable) -> void:
	var previous=g.active_arrow
	g.active_arrow=source;callback.call();g.active_arrow=previous

func effect(id: String, point: Vector2, radius: float=75) -> void:
	g.fx.signature(id,point,radius)

func fan(angle: float, speed: float, extras: int) -> void:
	for index in range(extras):
		var offset=(int(index/2)+1)*0.1*(-1 if index%2 else 1)
		g.launch(g.origin,Vector2.from_angle(angle+offset)*speed)

func arc(point: Vector2, count: int, amount: float, id: String) -> void:
	var previous=point
	for target in g.nearest(point,count):
		g.fx.bolt(previous,target.position);previous=target.position;g.hit(target,amount,1)
	effect(id,point,115);g.cue("lightning",1,point.x)

func global_damage(amount: float, id: String) -> void:
	effect(id,Vector2(390,440),650)
	g.fx.ring(Vector2(390,440),Color(g.content.by_id[id].color),650)
	for brick in g.bricks.duplicate():g.hit(brick,amount,1)
	g.cue("core")

func on_shoot(main: RefCounted, pull: Vector2) -> void:
	budget=120
	var speed=main.velocity.length()
	var angle=main.velocity.angle()
	var shots=int(g.state.skillRuntime.shots)
	if rank("trident"):fan(angle,speed,5)
	if rank("rapid"):g.next_shot_at=minf(g.next_shot_at,g.time+0.18)
	if rank("timeslip"):g.next_shot_at=minf(g.next_shot_at,g.time+0.25)
	if rank("swarmqueen"):
		for index in range(8):g.launch(g.origin,Vector2.from_angle(angle+(index-3.5)*0.12)*speed,g.damage()*1.5,3,true)
	if rank("hunters"):
		for index in range(4):g.launch(g.origin+Vector2(36 if index%2 else -36,0),Vector2.from_angle(angle+(0.25 if index%2 else -0.25))*speed,-1,-1,true)
	if rank("snowburst"):
		var selected=g.shuffle(g.bricks).slice(0,5)
		for index in range(selected.size()):
			var brick=selected[index]
			later(0.06*index,main,func():
				if brick in g.bricks:brick.frozen=true;g.fx.ring(brick.position,Color("#9fc9d9"),45);g.hit(brick,g.damage()*1.5,1)
			,true)
	if rank("supernova") and shots%4==0:later(0.18,main,func():global_damage(g.damage()*5,"supernova"),true)
	if rank("pulse") and shots%3==0:later(0.18,main,func():global_damage(g.damage()*1.2,"pulse"),true)
	if rank("sharpshooter") and pull.length()>=95:
		main.damage*=3;main.pierce+=6;main.color=Color("#d4af47");effect("sharpshooter",g.origin,180)
	if rank("mirror"):
		for x in [36,744]:
			for index in range(2):g.launch(Vector2(x,820-index*90),Vector2(sin(0.65 if x<390 else -0.65),-cos(0.65))*speed,g.damage()*1.5,3,true)
	if rank("reaper") and shots%3==0:later(0.15,main,func():
		var selected=g.bricks.duplicate();selected.sort_custom(func(a,b):return a.hp<b.hp)
		for brick in selected.slice(0,4):g.fx.bolt(Vector2(brick.x,100),brick.position);effect("reaper",brick.position);g.hit(brick,brick.hp,1)
		g.cue("lightning")
	,true)
	if rank("orbital") and not g.bricks.is_empty():
		var point=g.bricks[0].position
		var density=0
		for brick in g.bricks:
			var count=g.near(brick.position,160).size()
			if count>density:point=brick.position;density=count
		effect("orbital",point,160)
		for index in range(3):later(0.12+index*0.18,main,func():g.area(point,160,g.damage()*3,"orbital"),true)
	if rank("roulette"):
		var mode=g.rng.randi_range(0,2);main.flags.roulette=mode;effect("roulette",g.origin,150)
		match mode:
			0:main.damage*=5;main.pierce+=10;main.color=Color("#d4af47")
			1:
				for index in range(8):g.launch(g.origin,Vector2.from_angle(angle+(index-3.5)*0.14)*speed,g.damage()*2,3,true)
			2:later(0.16,main,func():global_damage(g.damage()*2.5,"roulette"),true)
	if rank("stormfront"):
		var rows:Dictionary={}
		for brick in g.bricks:rows[brick.y]=true
		var selected=g.shuffle(rows.keys()).slice(0,3)
		for index in range(selected.size()):
			var y=selected[index]
			later(0.1+index*0.14,main,func():
				g.fx.beam("stormfront",Vector2(35,y),Vector2(745,y),10)
				for brick in g.bricks.duplicate():
					if brick.y==y:g.hit(brick,g.damage()*3,1)
				g.cue("lightning")
			,true)
	if rank("echo"):later(0.24,main,func():
		g.launch(g.origin,Vector2.from_angle(angle)*speed)
		if rank("trident"):fan(angle,speed,5)
		effect("echo",g.origin,110);g.cue("shoot")
	,true)
	if rank("meteor"):
		var selected=g.shuffle(g.bricks).slice(0,6)
		for index in range(selected.size()):
			var point=Vector2(selected[index].x,142)
			later(index*0.04,main,func():
				var arrow=g.launch(point,Vector2(g.rng.randf_range(-9,9),18),g.damage()*2,2)
				if arrow!=null:arrow.color=Color("#d38b63")
			,true)
	if rank("legion") and shots%3==0:fan(angle,speed,6);effect("legion",g.origin,190)
	if rank("transmute"):
		var selected=g.shuffle(g.bricks.filter(func(b):return b.type=="normal")).slice(0,4)
		for index in range(selected.size()):
			var brick=selected[index];brick.type=["bomb","lightning","frost","prism"][(shots+index)%4];brick.hp=maxf(0.25,brick.hp*0.5);brick.flash=0.25;effect("transmute",brick.position,65)
		g.cue("upgrade")
	if rank("buzzsaw") and not g.bricks.is_empty():
		var rows:Dictionary={}
		for brick in g.bricks:rows[brick.y]=rows.get(brick.y,0)+1
		var sorted=rows.keys();sorted.sort_custom(func(a,b):return rows[a]>rows[b] or rows[a]==rows[b] and a>b)
		var direction=1 if shots%2 else -1
		fields.append({"id":"buzzsaw","position":Vector2(30 if direction>0 else 750,sorted[0]),"from":Vector2(30 if direction>0 else 750,sorted[0]),"direction":direction,"born":g.time,"duration":1.4,"next":g.time,"hits":{},"damage":g.damage()*1.5,"source":main})
	if rank("pendulum"):
		if shots%2:
			for side in [-1,1]:child(main,g.origin,angle+side*0.19,g.damage()*1.2,2)
		else:main.damage*=3;main.pierce+=3;effect("pendulum",g.origin,130)
	if rank("teslanet"):
		var vertices=net_targets()
		if not vertices.is_empty():
			fields.append({"id":"teslanet","vertices":vertices,"born":g.time,"duration":0.95,"source":main})
			for index in range(3):later(0.18+index*0.26,main,func():
				for brick in g.bricks.duplicate():
					var edge=false
					for at in range(vertices.size()):
						if not Geometry.sweep(brick.bounds,vertices[at],vertices[(at+1)%vertices.size()],12).is_empty():edge=true
					if edge or Geometry.triangle(brick.position,vertices):g.hit(brick,g.damage()*1.5,1)
				for point in vertices:effect("teslanet",point,45)
				g.cue("lightning")
			)
	if rank("chronicle"):
		var record={"source":main,"damage":g.damage(),"until":g.time+1,"hits":{}}
		records.append(record)
		later(1,main,func():
			records.erase(record)
			for brick in record.hits:
				if brick in g.bricks:effect("chronicle",brick.position,65);g.hit(brick,minf(record.damage*4,record.hits[brick])/(2 if brick.frozen else 1),1)
			g.cue("prism")
		)
	if rank("firewheel"):main.flags.firewheel={"next":g.time,"hits":{}}
	if rank("worldfold"):
		var x=clampf(g.origin.x+main.velocity.x/maxf(1,-main.velocity.y)*(g.origin.y-430),90,690)
		fields.append({"id":"worldfold","x":x,"source":main,"damage":g.damage(),"born":g.time,"duration":1.15,"previous":0.0,"hits":{}});g.cue("core")
	if rank("starforge") and not g.bricks.is_empty():
		var point=Vector2.ZERO
		for brick in g.bricks:point+=brick.position/g.bricks.size()
		fields.append({"id":"starforge","position":point,"source":main,"damage":g.damage(),"born":g.time,"duration":1.2,"stacks":0});effect("starforge",point,110);g.cue("prism")
	ensure_contract()

func child(source: RefCounted, point: Vector2, angle: float, amount: float, pierce: int) -> RefCounted:
	var previous=g.active_arrow;g.active_arrow=source
	var arrow=g.launch(point,Vector2.from_angle(angle)*25,amount,pierce)
	g.active_arrow=previous
	if arrow!=null:arrow.flags.child=true
	return arrow

func projectile_hit(brick: RefCounted, arrow: RefCounted) -> void:
	if not brick in g.bricks:return
	var point=brick.position
	var hp=brick.hp
	var frozen=2 if brick.frozen else 1
	var base=arrow.damage
	var amount=base
	if rank("overkill"):amount+=arrow.flags.get("storedForce",0);arrow.flags.storedForce=0
	if rank("rhythm"):
		arrow.flags.beats=arrow.flags.get("beats",0)+1
		if arrow.flags.beats%3==0:amount*=4;arrow.pierce+=2;effect("rhythm",point,100);later(0.04,arrow,func():g.area(point,100,g.damage(),"rhythm"))
	if contracted(brick):amount*=2
	if rank("infection") and not arrow.flags.has("infection"):
		arrow.flags.infection={"visited":{},"damage":g.damage()*3}
		infect(brick,arrow,arrow.flags.infection)
	for id in g.state.skills:
		if id not in ["critical","execute","ambush","opportunist","specialist","siphon","sharpshooter","bargain","forge","treasury","alchemist","mint","jackpot","bounty","reaper","orbital","stormfront","storm","blizzard","prism","aftershock","pulse","supernova","legion","resonance","sweep","lance","crossfire"]:effect(id,point,95 if id=="ice" else 70)
	if rank("ice"):
		for target in g.near(point,95):target.frozen=true;target.flash=0.18
	amount*=1+(minf(1.2,floor(arrow.kills/3.0)*0.2) if rank("rage") else 0)
	if rank("ambush") and brick.hp>=brick.max_hp:amount*=3;effect("ambush",point,80)
	if rank("opportunist") and brick.hp<brick.max_hp:amount*=3;effect("opportunist",point,80)
	if rank("specialist") and brick.type!="normal":amount*=4;effect("specialist",point,85)
	if rank("critical") and g.rng.randf()<0.5:amount*=3;g.fx.floating(point-Vector2(0,13),"暴击",Color("#ce805c"),13);effect("critical",point,100)
	if rank("execute") and brick.hp-amount*(2 if brick.frozen else 1)<=brick.max_hp*0.25:amount=maxf(amount,brick.hp);effect("execute",point,95)
	g.hit(brick,amount)
	if rank("siphon") and not brick in g.bricks and arrow.take("siphon",8):arrow.pierce+=1;arrow.damage+=arrow.base_damage*0.25;effect("siphon",point,75)
	if rank("minefield") and arrow.take("minefield"):
		for index in range(3):later(0.12+index*0.18,arrow,func():g.area(point,135,g.damage()*2,"minefield"),true)
	if rank("frostfire"):
		for target in g.near(point,100):target.frozen=true;target.flash=0.2
		later(0.09,arrow,func():g.area(point,100,g.damage()*1.5,"frostfire"),true)
	if rank("thunderlottery") and g.rng.randf()<0.35:later(0.07,arrow,func():arc(point,6,g.damage()*3,"thunderlottery"),true)
	if rank("poison"):
		brick.flags.markUntil=g.time+0.55
		for index in range(1,4):later(index*0.15,arrow,func():
			if brick in g.bricks:g.fx.ring(brick.position,Color("#91b646"),25);g.hit(brick,g.damage()*0.8,1)
		,true)
	if rank("doubletap"):later(0.2,arrow,func():g.area(point,115,g.damage()*2,"doubletap"),true)
	if rank("crossfire") and arrow.take("crossfire"):later(0.08,arrow,func():line_damage(point,3,"crossfire",true,true),true)
	if rank("blast") and not brick in g.bricks:later(0.055,arrow,func():g.area(point,125,g.damage()*1.5,"blast"),true)
	if rank("lightning"):later(0.065,arrow,func():arc(point,3,g.damage()*1.2,"lightning"),true)
	if rank("sweep") and arrow.take("sweep"):later(0.08,arrow,func():line_damage(point,2,"sweep",true,false),true)
	if rank("lance") and arrow.take("lance"):later(0.08,arrow,func():line_damage(point,2,"lance",false,true),true)
	if rank("wormhole") and arrow.take("wormhole",3):
		arrow.pierce+=2
		later(0.035,arrow,func():
			if not arrow in g.arrows:return
			var selected=g.bricks.filter(func(b):return not arrow.hit.has(b.id) and b.position.distance_to(point)>80)
			selected.sort_custom(func(a,b):return a.position.distance_squared_to(point)>b.position.distance_squared_to(point))
			if selected.is_empty():return
			var target=selected[0];var entry=arrow.position
			arrow.damage+=arrow.base_damage*0.5;arrow.position=target.position+Vector2(0,target.h/2+9);arrow.velocity=Vector2(0,-maxf(22,arrow.velocity.length()));arrow.overlap.clear();arrow.trail.clear()
			g.fx.beam("wormhole",entry,arrow.position,2,0.8);effect("wormhole",entry,65);effect("wormhole",arrow.position,65);g.cue("prism")
		)
	if rank("threadweaver"):
		if not arrow.flags.has("thread"):arrow.flags.thread={"points":[],"seen":{}}
		var chain=arrow.flags.thread
		if chain.points.size()<5 and not chain.seen.has(brick.id):
			chain.seen[brick.id]=true
			if not chain.points.is_empty():
				var previous=chain.points.back()
				later(0.045,arrow,func():segment_damage(previous,point,14,g.damage()*3,"threadweaver"))
			chain.points.append(point);arrow.pierce=maxi(arrow.pierce,6-chain.points.size())
	if rank("overkill") and not brick in g.bricks:
		arrow.flags.storedForce=minf(g.damage()*4,maxf(0,amount*frozen-hp)+g.damage()*0.5);arrow.pierce=maxi(arrow.pierce,2);effect("overkill",point)
	if rank("nailburst") and arrow.flags.get("main",false) and arrow.take("nailburst"):
		for offset in [-0.38,0,0.38]:
			var fragment=child(arrow,point,arrow.velocity.angle()+offset,g.damage()*0.9,2)
			if fragment!=null:fragment.overlap[brick.id]=true;fragment.hit[brick.id]=true
		effect("nailburst",point,95);g.cue("prism")
	if rank("fusepath"):
		if not arrow.flags.has("fuse"):arrow.flags.fuse=[]
		var chain=arrow.flags.fuse
		var seen=false
		for item in chain:
			if item.id==brick.id:seen=true
		if chain.size()<4 and not seen:
			if not chain.is_empty():
				var previous=chain.back().point
				g.fx.beam("fusepath",previous,point,2,0.8)
				later(0.25,arrow,func():segment_damage(previous,point,12,g.damage()*1.5,"fusepath"))
			chain.append({"point":point,"id":brick.id})
	if rank("undertow") and arrow.take("undertow"):
		fields.append({"id":"undertow","position":point,"born":g.time,"duration":0.85,"source":arrow})
		for index in range(3):
			var outer=240-index*80
			var inner=outer-80
			later(0.12+index*0.2,arrow,func():
				for target in g.bricks.duplicate():
					var distance=target.position.distance_to(point)
					if distance<=outer and (inner==0 or distance>inner):g.hit(target,g.damage()*2,1)
				g.fx.ring(point,Color("#419eab"),outer);g.cue("frost")
			)
		later(0.75,arrow,func():g.area(point,110,g.damage()*3,"undertow"))

func line_damage(point: Vector2, scale: float, id: String, row: bool, column: bool) -> void:
	if row:g.fx.beam(id,Vector2(50,point.y),Vector2(730,point.y),14)
	if column:g.fx.beam(id,Vector2(point.x,145),Vector2(point.x,850),14)
	for brick in g.bricks.duplicate():
		if row and absf(brick.y-point.y)<12 or column and absf(brick.x-point.x)<16:g.hit(brick,g.damage()*scale,1)
	g.cue("lightning")

func segment_damage(start: Vector2, finish: Vector2, width: float, amount: float, id: String) -> void:
	g.fx.beam(id,start,finish,width,0.75);effect(id,finish,55)
	for brick in g.bricks.duplicate():
		if not Geometry.sweep(brick.bounds,start,finish,width).is_empty():g.hit(brick,amount,1)
	g.cue("prism")

func record_damage(brick: RefCounted, amount: float) -> void:
	for record in records:
		if record.source==g.active_arrow and g.time<record.until:
			record.hits[brick]=record.hits.get(brick,0)+amount;brick.flags.markUntil=record.until

func destroyed(brick: RefCounted, _depth: int) -> void:
	var source=g.active_arrow
	var point=brick.position
	if rank("cascade") and take_round("cascade",16):later(0.09,source,func():g.area(point,145,g.damage()*2.5,"cascade"),true)
	if rank("nova") and take_round("nova",8):later(0.08,source,func():
		for index in range(3):g.launch(point,Vector2(sin((index-1)*0.8),-cos((index-1)*0.8))*22,g.damage()*1.5,3,true)
	,true)
	if brick.frozen and rank("shatter") and source!=null and source.take("shatter",6):later(0.09,source,func():g.area(point,65,g.damage()*1.5,"shatter"),true)
	if brick.type=="bomb" and rank("aftershock"):later(0.16,source,func():g.area(point,112,g.damage()*2,"aftershock"),true)
	for field in fields:
		if field.id=="starforge" and field.stacks<16:
			field.stacks+=1;g.fx.beam("starforge",point,field.position,2,0.45)
	if contracted(brick):
		var contract=g.state.skillRuntime.contract
		contract.targets=contract.targets.filter(func(p):return p.x!=brick.x or p.y!=brick.y)
		effect("contract",point,75)
		g.fx.ring(point,Color("#e0c46a"),74);g.fx.burst(point,Color("#f0d98a"),10,1.4)
		if contract.targets.is_empty():
			contract.rounds+=1
			var money=round(g.bonus()*0.4)
			g.state.coins+=money;g.level_money+=money;g.shot_money+=money
			for arrow in g.arrows:arrow.pierce+=4
			g.fx.floating(Vector2(390,860),"契约完成 +%d" % int(money),Color("#b69a48"),24);g.cue("upgrade")
			g.fx.ring(Vector2(390,840),Color("#e0c46a"),190);g.fx.burst(Vector2(390,840),Color("#f0d98a"),20,2)
			later(0.12,source,ensure_contract)

func take_round(id: String, limit: int) -> bool:
	var count=int(g.round_uses.get(id,0))
	if count>=limit:return false
	g.round_uses[id]=count+1;return true

func ensure_contract() -> void:
	if not rank("contract") or g.state.skillChosenLevel!=g.state.level:return
	if not g.state.skillRuntime.has("contract"):g.state.skillRuntime.contract={"rounds":0,"targets":[],"size":0}
	var contract=g.state.skillRuntime.contract
	if contract.rounds>=3 or not contract.targets.is_empty() or g.bricks.is_empty():return
	# Random each round: draw from a private pool so no brick is marked twice
	# and no board layout or HP ordering is assumed.
	var pool:=g.bricks.duplicate()
	var targets:Array=[]
	while targets.size()<3 and not pool.is_empty():
		var index:=g.rng.randi_range(0,pool.size()-1)
		var brick:RefCounted=pool[index]
		pool.remove_at(index)
		targets.append({"x":brick.x,"y":brick.y})
	contract.targets=targets;contract.size=targets.size()

func contracted(brick: RefCounted) -> bool:
	if not rank("contract") or not g.state.skillRuntime.has("contract"):return false
	for point in g.state.skillRuntime.contract.targets:
		if point.x==brick.x and point.y==brick.y:return true
	return false

func infect(brick: RefCounted, source: RefCounted, chain: Dictionary) -> void:
	if not brick in g.bricks or chain.visited.has(brick.id) or chain.visited.size()>=15:return
	chain.visited[brick.id]=true
	var point=brick.position
	effect("infection",point,24)
	later(0.3,source,func():
		effect("infection",point,65)
		if brick in g.bricks:g.hit(brick,chain.damage,1)
		for target in g.nearest(point,2,func(b):return not chain.visited.has(b.id) and b.position.distance_to(point)<=230):
			if chain.visited.size()>=15:break
			g.fx.beam("infection",point,target.position,3,0.5);infect(target,source,chain)
	)

func wall(arrow: RefCounted, obstacle: RefCounted) -> bool:
	if rank("spectral"):
		if not arrow.flags.has("phased"):arrow.flags.phased={}
		if not arrow.flags.phased.has(obstacle.id):arrow.flags.phased[obstacle.id]=true;arrow.damage+=arrow.base_damage*0.5;effect("spectral",obstacle.position,60)
		return true
	if rank("siegebreaker"):
		g.obstacles.erase(obstacle);effect("siegebreaker",obstacle.position,155);g.fx.burst(obstacle.position,Color("#87917f"),22,1.5)
		var point=obstacle.position
		later(0.035,arrow,func():g.area(point,155,g.damage()*4,"siegebreaker"))
		g.state.skillRuntime.wallsBroken=g.state.skillRuntime.get("wallsBroken",0)+1
		return true
	return false

func bounce(arrow: RefCounted) -> void:
	if rank("bankshot") and not arrow.flags.get("bankEcho",false) and arrow.take("bankshot",3):
		with_source(arrow,func():
			for offset in [-0.5,0.5]:
				var fragment=g.launch(arrow.position,Vector2(sin(offset),-cos(offset))*24,g.damage()*2,2,true)
				if fragment!=null:fragment.flags.bankEcho=true
		)
	if rank("ricochet") and arrow.take("ricochet",4):arrow.pierce+=2;arrow.damage+=arrow.base_damage*0.15
	if rank("reboundaim") and int(arrow.flags.get("smartBounces",0))<3:
		var selected=g.nearest(arrow.position,1,func(b):return not arrow.hit.has(b.id))
		if not selected.is_empty():
			arrow.flags.smartBounces=arrow.flags.get("smartBounces",0)+1;arrow.pierce+=1;arrow.damage+=arrow.base_damage*0.5;arrow.velocity=(selected[0].position-arrow.position).normalized()*maxf(22,arrow.velocity.length());g.fx.beam("reboundaim",arrow.position,selected[0].position,2);effect("reboundaim",arrow.position)

func net_targets() -> Array:
	if g.bricks.is_empty():return []
	var sorted=g.bricks.duplicate();sorted.sort_custom(func(a,b):return a.y>b.y)
	var first=sorted.pop_front()
	if sorted.is_empty():return [first.position]
	sorted.sort_custom(func(a,b):return a.position.distance_squared_to(first.position)>b.position.distance_squared_to(first.position))
	var second=sorted.pop_front()
	if sorted.is_empty():return [first.position,second.position]
	sorted.sort_custom(func(a,b):return absf((second.position-first.position).cross(a.position-first.position))>absf((second.position-first.position).cross(b.position-first.position)))
	return [first.position,second.position,sorted[0].position]

func guide_prediction(arrow: RefCounted, delta: float) -> void:
	# The live guide's return/core bonuses must not fire for preview arrows.
	if not rank("seeking") and not rank("corehunter"):return
	var target=null
	if g.core!=null and arrow.position.distance_to(Vector2(g.core.x,g.core.y))<(320 if rank("corehunter") else 250):target=Vector2(g.core.x,g.core.y)
	elif rank("seeking"):
		# Retain nearest-target order (first brick wins ties) without creating
		# a predicate closure and sorted result array for each prediction step.
		var best:=INF
		for brick in g.bricks:
			if arrow.hit.has(brick.id):continue
			var difference:Vector2=brick.position-arrow.position
			if difference.dot(arrow.velocity)<=0 or difference.length()>=250:continue
			var distance:=difference.length_squared()
			if distance<best:best=distance;target=brick.position
	if target!=null:arrow.velocity=arrow.velocity.rotated(clampf(arrow.velocity.angle_to(target-arrow.position),-delta*4,delta*4))

func update(delta: float) -> void:
	var due:Array=[]
	var keep:Array=[]
	for job in jobs:
		if job.at<=g.time:due.append(job)
		else:keep.append(job)
	jobs=keep
	for job in due:
		if g.phase!="flying":break
		if job.level==g.state.level:with_source(job.source,job.callback)
	for arrow in g.arrows.duplicate():
		if arrow.flags.has("firewheel") and g.time>=arrow.flags.firewheel.next:
			var wheel=arrow.flags.firewheel;wheel.next=g.time+0.18
			with_source(arrow,func():
				for brick in g.bricks.duplicate():
					var distance=brick.position.distance_to(arrow.position)
					if distance>=45 and distance<=115 and wheel.hits.get(brick.id,0)<4:wheel.hits[brick.id]=wheel.hits.get(brick.id,0)+1;g.hit(brick,g.damage(),1)
			)
	for field in fields.duplicate():
		if g.phase!="flying":break
		var t=clampf((g.time-field.born)/field.duration,0,1)
		with_source(field.source,func():
			match field.id:
				"buzzsaw":
					field.position.x=30+t*720 if field.direction>0 else 750-t*720
					if g.time>=field.next:
						field.next=g.time+0.075
						for brick in g.bricks.duplicate():
							if field.hits.get(brick.id,0)<3 and not Geometry.sweep(brick.bounds,field.from,field.position,43).is_empty():field.hits[brick.id]=field.hits.get(brick.id,0)+1;g.hit(brick,field.damage,1)
						field.from=field.position
				"worldfold":
					var left=20+(field.x-20)*t
					var right=760-(760-field.x)*t
					var old_left=20+(field.x-20)*field.previous
					var old_right=760-(760-field.x)*field.previous
					for brick in g.bricks.duplicate():
						if not field.hits.has(brick.id) and (brick.x+brick.w/2>=old_left and brick.x-brick.w/2<=left or brick.x-brick.w/2<=old_right and brick.x+brick.w/2>=right):field.hits[brick.id]=true;g.hit(brick,field.damage*3,1)
					field.previous=t
					if t>=1:
						g.fx.beam("worldfold",Vector2(field.x,125),Vector2(field.x,850),150,0.65)
						for brick in g.bricks.duplicate():
							if absf(brick.x-field.x)<=75+brick.w/2:g.hit(brick,field.damage*6,1)
						effect("worldfold",Vector2(field.x,430),180);g.cue("boom")
				"starforge":
					if t>=1:
						var radius=170+field.stacks*12
						g.area(field.position,radius,field.damage*(4+field.stacks*0.4),"starforge");g.fx.floating(field.position-Vector2(0,35),"熔炉释放 · %d 层" % field.stacks,Color("#bd9141"),22)
		)
		if t>=1:fields.erase(field)
