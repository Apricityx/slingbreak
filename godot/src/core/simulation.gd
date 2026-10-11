extends RefCounted
## Fixed-step native simulation. Renderers read these objects directly; UI gets
## semantic state only. No JSON or image transfer occurs in the frame loop.
const Content = preload("res://src/core/content.gd")
const Progress = preload("res://src/core/progress.gd")
const Brick = preload("res://src/core/brick.gd")
const Arrow = preload("res://src/core/projectile.gd")
const Geometry = preload("res://src/core/geometry.gd")
const Skills = preload("res://src/skills/mechanics.gd")
const Bosses = preload("res://src/bosses/director.gd")
const FX = preload("res://src/effects/effects.gd")
var content := Content.new()
var state := Progress.defaults()
var rng := RandomNumberGenerator.new()
var visual_rng := RandomNumberGenerator.new()
var skills: RefCounted
var bosses: RefCounted
var fx: RefCounted
var bricks: Array = []
var obstacles: Array = []
var arrows: Array = []
var core: Variant = null
var origin := Vector2(390,970)
var phase := "ready"
var paused := false
var intro_active := false
var time := 0.0
var clock := 0.0
var accumulator := 0.0
var next_shot_at := 0.0
var board_entrance: Variant = null
var entrance_held:=false
var drag: Variant = null
var pointer: Variant = null
var keyboard_angle := 0.0
var keyboard_power := 0.85
var initial := 0
var killed := 0
var shots := 0
var level_money := 0.0
var shot_money := 0.0
var round_uses: Dictionary = {}
var active_arrow: RefCounted
var latest_achievement: Variant = null
var sounds: Array = []
var events: Array = []
var serial := 0
var revision := 0
var theme_mode := "system"
var theme := "light"
var clear_at := 0.0
var clear_shown_at := 0.0
var report: Variant = null
var wipe: Variant = null
var locked_until := 0.0
var freeze_until := 0.0
var settled_bonus := 0.0
var stats: Dictionary = {}
var chances: Dictionary = {}
var chance_key := ""
var last_sounds: Dictionary = {}
var reduced: bool:
	get:return state.performanceMode
var slots: int:
	get:return 1+mini(3,int(state.up.slots))
var threshold: int:
	get:return ceili(initial*(0.6-0.15*rank("resonance")))

func _init() -> void:
	skills=Skills.new(self)
	bosses=Bosses.new(self)
	fx=FX.new(self)

func dispose() -> void:
	# Delayed Callables retain their skill/Boss owner. Break these cycles even
	# when a run is replaced with jobs still pending (reset, import or shutdown).
	skills.reset();bosses.reset();fx.reset();arrows.clear();active_arrow=null

func start(seed_value: int, progress: Dictionary={}, preferences: Dictionary={}) -> void:
	rng.seed=seed_value
	visual_rng.seed=seed_value^0x4f7314
	state=Progress.defaults()
	if Progress.valid(progress):
		var imported:Dictionary=progress.state.duplicate(true)
		for key in imported:state[key]=imported[key]
		for key in Progress.UPGRADES:
			if not state.up.has(key):state.up[key]=0
	if state.comboRulesVersion!=2:
		state.legacyBest=state.best;state.best=0;state.comboRulesVersion=2
	state.skills=_normalize_skills(state.skills)
	if state.skills.is_empty():state.skillChosenLevel=0
	state.volume=clampi(int(state.volume),0,100)
	state.sound=state.volume>0
	state.rerolls=clampi(int(state.rerolls),0,reroll_cap())
	if not state.achievements is Dictionary:state.achievements={}
	for key in ["level","total","best","skillChosenLevel","rerollGrantLevel"]:state[key]=int(state[key])
	for key in Progress.UPGRADES:state.up[key]=int(state.up[key])
	theme_mode=preferences.get("theme","system")
	resolve_theme()
	generate(true)

func _normalize_skills(value: Dictionary) -> Dictionary:
	var result:Dictionary={}
	for id in value:
		if content.by_id.has(id) and value[id]==1 and state.level>=content.by_id[id].minLevel:result[id]=1
	while result.size()>slots:result.erase(result.keys()[0])
	return result

func resolve_theme() -> void:
	theme="dark" if theme_mode=="dark" or theme_mode=="system" and DisplayServer.is_dark_mode_supported() and DisplayServer.is_dark_mode() else "light"

func rank(id: String) -> int:
	return 1 if state.skills.has(id) else 0

func base_damage() -> float:
	return 2+0.65*log(float(state.up.arrow)+1)/log(2.0)

func damage() -> float:
	return base_damage()*(1+rank("titan")+0.35*rank("rapid")+0.8*rank("heavy")+0.5*rank("supernova")+0.6*rank("reaper")+3*rank("railgun")+mini(10,int(state.skillRuntime.shots))*0.2*rank("growing"))

func speed() -> float:
	return 24+11*(1-exp(-float(state.up.power)/9))

func penetration() -> int:
	return mini(6,2+int(state.up.arrow)/4)+4*rank("piercer")+2*rank("heavy")+12*rank("railgun")+2*rank("opportunist")

func draw_interval() -> float:
	return (100-9*mini(10,int(state.up.draw)))/100.0

func special_rate() -> float:
	return minf(0.22,0.10+0.12*(1-exp(-float(state.up.brick)/12)))

func base_hp() -> float:
	var n:=log(float(state.level))/log(2.0)
	return floor(3+0.8*n+0.2*n*n)

func bonus(level: int=-1) -> float:
	# The reference rounds the base payout, then rounds again after Treasury.
	var scaled: int = int(state.level) if level<0 else level
	return round(round(240*pow(scaled,1.15))*(1+2*rank("treasury")))

func combo_step() -> float:return 0.25+0.025*state.up.comboCap
func combo_cap() -> float:return 3+0.5*state.up.comboCap
func cap_kills() -> int:return 1+ceili((combo_cap()-1)/combo_step()-0.000000001)
func multiplier(kills: int) -> float:return minf(combo_cap(),1+maxi(0,kills-1)*combo_step())
func reroll_cap() -> int:return 1+mini(4,int(state.up.rerollCap))

func reward(type: String, kills: int) -> float:
	var value:=maxf(1,round(3*pow(state.level,1.1)*(1+0.16*state.up.brick)*multiplier(kills)*(3 if type=="gold" else 1)))
	value*=1+rank("mint")
	if type=="gold":value*=(3+5*rank("alchemist"))/3.0
	if rank("jackpot"):value*=10 if rng.randf()<0.25 else 1.5
	value*=1+rank("bounty")*mini(8,maxi(0,kills-1))*0.25
	if type!="normal" and rank("specialist"):value*=3
	return round(value)

func cost(key: String) -> float:
	var value:=0.0
	match key:
		"slots":value=[1e5,1e7,1e9][mini(2,int(state.up.slots))]
		"rerollCap":value=[2e4,4e5,8e6,1.6e8][mini(3,int(state.up.rerollCap))]
		"comboCap":value=ceil(1500*pow(1.65,state.up.comboCap))
		_:value=ceil({"power":75,"arrow":100,"brick":120,"draw":50}.get(key,0)*pow({"power":1.4,"arrow":1.46,"brick":1.5,"draw":1.35}.get(key,1),state.up.get(key,0)))
	return maxf(1,ceil(value*pow(0.6,rank("bargain"))))

func generate(restore: bool=false) -> void:
	var handoff:=phase=="clearing" and not reduced
	if not restore:state.erase("nativeBoss")
	bricks.clear();obstacles.clear();arrows.clear();core=null
	skills.reset();fx.reset();bosses.reset()
	initial=0;killed=0;shots=0;level_money=0;shot_money=0;next_shot_at=0
	latest_achievement=null;board_entrance=null;entrance_held=false;report=null;phase="ready"
	round_uses={};drag=null
	if not state.skillRuntime is Dictionary or state.skillRuntime.get("level")!=state.level:
		state.skillRuntime={"level":state.level,"shots":0,"forge":false,"decay":false}
	var board:Variant=state.board
	if restore and Progress.valid_board(board) and board.get("level")==state.level:
		for item in board.bricks:make_brick(item)
		for item in board.get("obstacles",[]):make_obstacle(item)
		initial=int(board.initial);killed=int(board.killed);level_money=float(board.get("levelMoney",0))
		if board.get("core",false) and not state.level%100==0:spawn_core(true)
	else:layout()
	stats={"brick":0.0,"mult":0.0,"carried":level_money,"bestKills":0,"bestMoney":0.0,"skills":{},"record":false,"previousBest":state.best}
	bosses.start(restore)
	if state.skillChosenLevel==state.level:
		state.draft=null;apply_passives()
	else:
		var valid:bool=state.draft is Dictionary and state.draft.get("level")==state.level and state.draft.get("options") is Array and state.draft.options.size()==3
		if valid:
			var unique:Dictionary={}
			for id in state.draft.options:
				if not content.by_id.has(id) or rank(id) or content.by_id[id].minLevel>state.level:valid=false
				unique[id]=true
			valid=valid and unique.size()==3
		if not valid:state.draft={"level":state.level,"options":roll()}
		phase="draft"
	if handoff:
		wipe={"at":clock*1000,"from":state.level-1,"to":state.level,"eyebrow":"NEXT LEVEL","note":"新的局面"}
		locked_until=clock+1.12
	revision+=1

func shuffle(items: Array) -> Array:
	var result:=items.duplicate()
	for i in range(result.size()-1,0,-1):
		var j:=rng.randi_range(0,i)
		var temp:Variant=result[i];result[i]=result[j];result[j]=temp
	return result

func layout() -> void:
	var rows:=10+mini(1,int(state.level-1)/8)
	var cells:Array=[]
	for row in range(rows):
		for column in range(7):cells.append({"row":row,"col":column,"x":102+column*96,"y":170+row*60})
	var blocked:Dictionary={}
	var count:=5+rng.randi_range(0,2)+mini(1,int(state.level)/10)
	for cell in shuffle(cells):
		if cell.row==0 or cell.row==rows-1 or absi(cell.col-3)<2:continue
		var adjacent:=false
		for wall in obstacles:
			if wall.position.distance_to(Vector2(cell.x,cell.y))<104:adjacent=true
		if adjacent:continue
		make_obstacle(cell);blocked[Vector2(cell.x,cell.y)]=true
		if obstacles.size()>=count:break
	var gaps:=4+rng.randi_range(0,3)
	for cell in shuffle(cells):
		var point:=Vector2(cell.x,cell.y)
		if cell.col!=3 and not blocked.has(point) and gaps>0:blocked[point]=true;gaps-=1
	for cell in cells:
		if blocked.has(Vector2(cell.x,cell.y)):continue
		var hp:=base_hp()+(1 if rng.randf()<0.12 else 0)
		make_brick({"x":cell.x,"y":cell.y,"hp":hp,"max":hp})
	var types:=["bomb","lightning","frost","prism","gold"]
	var candidates:=shuffle(bricks)
	for index in range(floori(bricks.size()*special_rate())):
		candidates[index].type=types[index] if index<5 else types[rng.randi_range(0,4)]
		candidates[index].hp=base_hp();candidates[index].max_hp=base_hp()
	initial=bricks.size()

func make_brick(data: Dictionary) -> RefCounted:
	var brick:=Brick.new()
	serial+=1;brick.id=serial
	brick.x=float(data.x);brick.y=float(data.y)
	brick.w=float(data.get("w",84));brick.h=float(data.get("h",44))
	brick.hp=float(data.get("hp",base_hp()));brick.max_hp=float(data.get("max",brick.hp))
	brick.type=data.get("type","normal");brick.frozen=data.get("frozen",false)
	brick.flags=data.get("nativeFlags",{}).duplicate(true)
	bricks.append(brick)
	return brick

func make_obstacle(data: Dictionary) -> RefCounted:
	var wall:=Brick.new();serial+=1;wall.id=serial
	wall.x=float(data.x);wall.y=float(data.y);wall.w=float(data.get("w",84));wall.h=float(data.get("h",44));wall.type="obstacle"
	obstacles.append(wall)
	return wall

func apply_passives() -> void:
	if rank("decay") and not state.skillRuntime.get("decay",false):
		for brick in bricks:brick.hp*=0.65;brick.flash=0.2
		state.skillRuntime.decay=true;fx.signature("decay",Vector2(390,320),340)
	if killed>=threshold and core==null and bosses.fight.is_empty():spawn_core()
	skills.ensure_contract()

func _weights() -> Array:
	var pool:Array=[]
	var pressure:=0
	for id in state.skills:pressure+={"white":0,"blue":1,"gold":2}[content.by_id[id].tier]
	for skill in content.catalog:
		if rank(skill.id) or state.level<skill.minLevel:continue
		pool.append({"id":skill.id,"weight":skill.weight/(1+{"white":0.0,"blue":0.2,"gold":0.4}[skill.tier]*pressure)})
	return pool

func roll(exclude: Array=[]) -> Array:
	var pool:=_weights()
	var avoided:Array=pool.filter(func(item):return not item.id in exclude)
	if avoided.size()>=3:pool=avoided
	var result:Array=[]
	while result.size()<3 and not pool.is_empty():
		var total:=0.0
		for item in pool:total+=item.weight
		var ticket:=rng.randf()*total
		var chosen:=pool.size()-1
		for index in range(pool.size()):
			ticket-=pool[index].weight
			if ticket<0:chosen=index;break
		result.append(pool[chosen].id);pool.remove_at(chosen)
	return result

func draft_chances() -> Dictionary:
	var key:=str(state.skills.keys())+str(state.level)
	if key==chance_key:return chances
	chance_key=key;chances={}
	var pool:=_weights()
	var total:=0.0
	for item in pool:total+=item.weight
	for item in content.catalog:chances[item.id]=0.0
	for item in pool:chances[item.id]=item.weight/total
	for a in pool:
		var remaining:float=total-a.weight
		var third:=0.0
		for b in pool:
			if b.id!=a.id:third+=b.weight/remaining/(remaining-b.weight)
		for item in pool:
			if item.id==a.id:continue
			chances[item.id]+=a.weight/total*item.weight/remaining+a.weight/total*item.weight*(third-item.weight/remaining/(remaining-item.weight))
	return chances

func choose(id: String) -> bool:
	if paused or phase!="draft" or not id in state.draft.options or state.skillChosenLevel==state.level:return false
	if state.skills.size()>=slots:state.skills.erase(state.skills.keys()[0])
	state.skills[id]=1;state.skillChosenLevel=state.level;state.draft=null
	board_entrance=null if reduced else {"start":time,"end":time+0.85}
	phase="ready" if reduced else "entering"
	apply_passives();cue("upgrade");revision+=1
	fx.signature(id,origin,190)
	return true

func buy(key: String) -> bool:
	if phase!="ready" or paused or not state.up.has(key):return false
	if key=="comboCap" and state.up.brick<5 and state.up.comboCap==0:return false
	if key=="draw" and state.up.draw>=10 or key=="slots" and state.up.slots>=3 or key=="rerollCap" and state.up.rerollCap>=4:return false
	var price:=cost(key)
	if state.coins<price:return false
	state.coins-=price;state.up[key]+=1
	if rank("forge") and key not in ["slots","rerollCap"] and not state.skillRuntime.get("forge",false):
		state.skillRuntime.forge=true;state.up[key]+=mini(2,10-int(state.up.draw)) if key=="draw" else 2
	cue("upgrade");events.append({"type":"toast","text":"升级成功"});revision+=1
	return true

func launch(position: Vector2, velocity: Vector2, amount: float=-1, pierce: int=-1, homing: bool=false, main: bool=false) -> RefCounted:
	if arrows.size()>=64:return null
	var arrow:=Arrow.new();serial+=1;arrow.id=serial
	arrow.position=position;arrow.previous=position;arrow.velocity=velocity
	arrow.scale=pow(2,rank("siegebreaker")+rank("spectral")+rank("timeslip"))
	arrow.damage=(damage() if amount<0 else amount)*arrow.scale;arrow.base_damage=arrow.damage
	arrow.pierce=(penetration() if pierce<0 else pierce)+6*(rank("boomerang")+rank("spectral"))+3*(rank("fusepath")+rank("rhythm"))
	arrow.flags={"homing":homing,"main":main};arrow.source=active_arrow
	if not state.skills.is_empty():arrow.visual=state.skills.keys().back()
	arrow.achievement={"id":arrow.id,"kills":0,"chain":0,"frozen":0,"gold":0,"types":{},"unlocked":{},"bounces":0,"base":0.0,"paid":0.0,"mult":1.0,"baseMult":1.0,"bountyMult":1.0,"capKills":cap_kills(),"bankKill":false,"trickKill":false,"airKill":false,"core":false}
	arrows.append(arrow)
	return arrow

func shoot(dx: float, dy: float) -> bool:
	var pull:=Vector2(dx,dy)
	if paused or intro_active or clock<locked_until or phase not in ["ready","flying"] or time<next_shot_at or arrows.size()>=64 or pull.length()<10 or dy<5:return false
	if phase=="ready":round_uses={};latest_achievement=null;shot_money=0
	state.skillRuntime.shots+=1;shots+=1;phase="flying"
	next_shot_at=time+draw_interval()
	var main:=launch(origin,-pull.normalized()*speed()*(0.56+0.44*minf(1,pull.length()/100)), -1,-1,false,true)
	active_arrow=main;skills.on_shoot(main,pull);active_arrow=null
	cue("shoot");revision+=1
	return true

func near(point: Vector2, radius: float) -> Array:
	return bricks.filter(func(b):return b.position.distance_squared_to(point)<=radius*radius)

func nearest(point: Vector2, count: int, accept: Callable=Callable()) -> Array:
	var result:Array=[]
	for brick in bricks:
		if accept.is_valid() and not accept.call(brick):continue
		var at:=0
		var distance:float=brick.position.distance_squared_to(point)
		while at<result.size() and result[at].position.distance_squared_to(point)<=distance:at+=1
		if at>=count:continue
		result.insert(at,brick)
		if result.size()>count:result.pop_back()
	return result

func area(point: Vector2, radius: float, amount: float, id: String="", depth: int=1) -> void:
	fx.ring(point,Color(content.by_id[id].color) if content.by_id.has(id) else Color("#df7035"),radius)
	if id!="":fx.signature(id,point,radius)
	for brick in near(point,radius):hit(brick,amount,depth)
	cue("boom",1,point.x)

func hit(brick: RefCounted, amount: float, depth: int=0) -> void:
	if phase=="clearing" or not brick in bricks or not is_finite(amount) or amount<=0:return
	if not bosses.before_hit(brick,depth):return
	var dealt:=amount*(2 if brick.frozen else 1)
	skills.record_damage(brick,minf(brick.hp,dealt))
	brick.hp-=dealt;brick.flash=0.16
	if brick.hp>0:fx.burst(brick.position,fx.brick_color(brick.type),4,0.5);cue("tap",1,brick.x);return
	bricks.erase(brick);killed+=1;state.total+=1
	if active_arrow!=null:
		active_arrow.kills+=1;state.best=maxi(state.best,active_arrow.kills)
	var money:=_award(brick,depth)
	state.coins+=money;shot_money+=money;level_money+=money
	fx.burst(brick.position,fx.brick_color(brick.type),16);fx.floating(brick.position,"+%d" % int(money));fx.shake=minf(8,fx.shake+1.5)
	if brick.type!="normal":cue("boom" if brick.type=="bomb" else brick.type,1,brick.x,true)
	cue("break",active_arrow.kills if active_arrow!=null else 0,brick.x)
	if killed>=threshold and core==null and bosses.fight.is_empty():spawn_core()
	if depth<70:
		match brick.type:
			"bomb":area(brick.position,132,damage()*2,"",depth+1)
			"lightning":
				var from:Vector2=brick.position
				for target in nearest(brick.position,7 if rank("storm") else 5):
					fx.bolt(from,target.position);from=target.position;hit(target,damage()*(2 if rank("storm") else 1.6),depth+1)
			"frost":
				var radius:=190 if rank("blizzard") else 140
				fx.ring(brick.position,Color("#81bece"),radius+4)
				for target in near(brick.position,radius):target.frozen=true;hit(target,damage()*(1 if rank("blizzard") else 0.5),depth+1)
			"prism":
				var count:=6 if rank("prism") else 3
				for i in range(count):
					var angle:float=-0.9+i*1.8/(count-1)
					launch(brick.position,Vector2(sin(angle),-cos(angle))*18,-1,3 if rank("prism") else 2)
	skills.destroyed(brick,depth);bosses.destroyed(brick,depth)
	revision+=1

func _award(brick: RefCounted, depth: int) -> float:
	if active_arrow==null:
		var money:=reward(brick.type,1);stats.brick+=money;return money
	var arrow:RefCounted=active_arrow
	var tally:Dictionary=arrow.achievement
	tally.kills=arrow.kills;tally.chain+=1 if depth>0 else 0;tally.frozen+=1 if brick.frozen else 0;tally.gold+=1 if brick.type=="gold" else 0
	if brick.type!="normal":tally.types[brick.type]=true
	tally.bankKill=tally.bankKill or tally.bounces>0;tally.trickKill=tally.trickKill or tally.bounces>=3;tally.airKill=tally.airKill or arrow.life>=2
	tally.baseMult=multiplier(arrow.kills);tally.bountyMult=1+rank("bounty")*mini(8,maxi(0,arrow.kills-1))*0.25
	var base:=reward(brick.type,arrow.kills);tally.base+=base
	var value:=evaluate_achievements(arrow)
	stats.brick+=minf(value,base);stats.mult+=value-minf(value,base)
	stats.bestKills=maxi(stats.bestKills,arrow.kills);stats.bestMoney=maxf(stats.bestMoney,tally.paid)
	if arrow.kills>stats.previousBest and stats.previousBest>=4 and not stats.record:
		stats.record=true;fx.floating(brick.position,"新纪录 · %d 连" % arrow.kills,Color("#e0ad2c"),24);fx.ring(brick.position,Color("#e0ad2c"),260);hitstop(0.09)
	if arrow.kills in [4,8,12]:
		fx.signature("supernova",brick.position,100+arrow.kills*5);fx.floating(brick.position-Vector2(0,30),{4:"势如破竹",8:"火力全开",12:"超载"}[arrow.kills],Color("#e0ad2c"),20)
		if arrow.kills==12:hitstop(0.045)
	return value

func evaluate_achievements(arrow: RefCounted) -> float:
	var tally:Dictionary=arrow.achievement
	var tests:Dictionary={"double":arrow.kills>=4,"five":arrow.kills>=8,"ten":arrow.kills>=12,"twenty":arrow.kills>=20,"bank":tally.bankKill,"trick":tally.trickKill,"chain":tally.chain>=3,"ice":tally.frozen>=2,"mix":tally.types.size()>=3,"gold":tally.gold>=2,"air":tally.airKill,"core":tally.core and arrow.kills>=3}
	for item in content.achievements:
		if tally.unlocked.has(item.id) or not tests[item.id]:continue
		tally.unlocked[item.id]=true;tally.mult+=item.bonus
		state.achievements[item.id]=state.achievements.get(item.id,0)+1
		events.append({"type":"achievement","id":item.id,"name":item.name,"bonus":item.bonus,"arrow":arrow.id});cue("upgrade")
	var total:float=round(tally.base*tally.mult)
	var delta:float=total-tally.paid;tally.paid=total;latest_achievement=tally
	return delta

func spawn_core(quiet: bool=false) -> void:
	if core!=null or phase=="clearing":return
	core={"x":390.0,"y":80.0,"born":time-(2 if quiet else 0)}
	if not quiet:
		fx.flash=1;fx.ring(Vector2(390,80),Color("#a4d65e"),220);fx.burst(Vector2(390,80),Color("#a4d65e"),45,2);cue("core");events.append({"type":"toast","text":"核心已显现 · 命中即可清场"})
	revision+=1

func clear() -> void:
	if phase=="clearing":return
	var level:=int(state.level)
	settled_bonus=bonus();state.coins+=settled_bonus;level_money+=settled_bonus
	phase="clearing";clear_shown_at=clock;clear_at=time+3.4
	hitstop(0.13)
	fx.flash=1.6;fx.shake=14;fx.ring(Vector2(390,80),Color("#a4d65e"),850);fx.burst(Vector2(390,80),Color("#93c446"),80,3)
	for brick in bricks:fx.burst(brick.position,fx.brick_color(brick.type),6)
	bricks.clear();obstacles.clear();arrows.clear();core=null;skills.reset();cue("win",1,390,true)
	var parts:Array=[]
	for entry in [["基础砖块",stats.brick,"#9bcc5d"],["倍率加成",stats.mult,"#e0ad2c"],["核心奖金",settled_bonus,"#5f8a2f"],["技能与其他",maxf(0,level_money-stats.brick-stats.mult-settled_bonus-stats.carried),"#8d78b9"],["此前进度",stats.carried,"#b9c2ad"]]:
		if entry[1]>0:parts.append({"label":entry[0],"value":entry[1],"color":entry[2]})
	var highlights:Array=stats.skills.keys()
	highlights.sort_custom(func(a,b):return stats.skills[a]>stats.skills[b])
	var top:Array=[]
	for id in highlights.slice(0,3):top.append({"name":content.by_id[id].name,"icon":content.by_id[id].icon,"count":stats.skills[id]})
	report={"level":level,"total":level_money,"parts":parts,"bestKills":stats.bestKills,"bestMoney":stats.bestMoney,"shots":shots,"bricks":killed,"skills":top,"record":stats.record}
	if level%5==0 and level>state.rerollGrantLevel:
		state.rerollGrantLevel=level
		if state.rerolls<reroll_cap():state.rerolls+=1;report.reroll={"count":state.rerolls,"capacity":reroll_cap()}
	if not bosses.fight.is_empty():report.rift={"title":bosses.fight.name,"items":["%d 相" % bosses.fight.phases,"弱点 %d 次" % bosses.fight.hits]}
	state.level+=1;state.board=null;state.swapOffer=null;revision+=1

func hitstop(seconds: float) -> void:
	if not reduced:freeze_until=maxf(freeze_until,clock+seconds)

func update(delta: float) -> void:
	if not is_finite(delta) or delta<0:return
	clock+=minf(delta,0.05)
	if wipe!=null and clock*1000-wipe.at>=1120:wipe=null;revision+=1
	if paused or intro_active:return
	accumulator+=minf(delta,0.05)
	var steps:=0
	while accumulator>=1.0/60 and steps<4:
		accumulator-=1.0/60;steps+=1
		if clock>=freeze_until and phase!="draft":tick(1.0/60)
	if steps==4:accumulator=0

func tick(delta: float) -> void:
	time+=delta
	if phase=="entering" and not entrance_held and board_entrance!=null and time>=board_entrance.end:board_entrance=null;phase="ready";revision+=1
	if phase=="clearing" and time>=clear_at:generate();return
	bosses.update(delta)
	if phase=="flying":
		skills.update(delta)
		var scaled:float=delta*(0.2 if rank("timeslip") and drag!=null and drag.dy>5 else 1)
		for arrow in arrows.duplicate():
			if phase!="flying":break
			advance_arrow(arrow,scaled)
		if phase=="flying" and arrows.is_empty() and not skills.pending():phase="ready";revision+=1
	for brick in bricks:brick.flash=maxf(0,brick.flash-delta)
	for wall in obstacles:wall.flash=maxf(0,wall.flash-delta)
	fx.update(delta)

func guide(arrow: RefCounted, delta: float) -> void:
	if rank("boomerang") and arrow.life>=0.55 and not arrow.flags.get("returned",false):
		arrow.flags.returned=true;arrow.damage*=3;arrow.pierce+=6;arrow.velocity=-arrow.velocity;arrow.hit.clear();arrow.overlap.clear();fx.signature("boomerang",arrow.position,100)
	if core!=null and rank("corehunter") and not arrow.flags.get("coreBoost",false):arrow.flags.coreBoost=true;arrow.pierce+=4
	var homing:bool=arrow.flags.get("homing",false)
	var reach:=350.0 if homing else 250.0
	var target:Variant=null
	if core!=null and (homing or rank("seeking") or rank("corehunter")) and arrow.position.distance_to(Vector2(core.x,core.y))<(320 if rank("corehunter") else reach):target=Vector2(core.x,core.y)
	elif homing or rank("seeking"):
		var best:=INF
		for brick in bricks:
			var difference:Vector2=brick.position-arrow.position
			if arrow.hit.has(brick.id) or difference.dot(arrow.velocity)<=0 or difference.length()>=reach:continue
			var score:float=difference.length()*(1 if brick.type=="normal" else 0.7)
			if score<best:best=score;target=brick.position
	if target!=null:
		arrow.velocity=arrow.velocity.rotated(clampf(arrow.velocity.angle_to(target-arrow.position),-delta*4,delta*4))
		arrow.color=Color("#91b646" if core!=null else "#8873b1")

func integrate(arrow: RefCounted, delta: float) -> void:
	# Matter's velocity is distance per 60 Hz tick. Gravity .48 becomes
	# .48*(1000/60)^2/1000. Integrate in 64-bit so a long flight does not
	# accumulate Vector2 rounding.
	var ratio:=delta*60
	# Velocity is normalised to a 60 Hz tick, so acceleration is scaled once
	# here and once more in the position update (Matter's deltaTime squared).
	# Air friction scales linearly, including Timeslip and the release tick.
	var drag:=1.0-0.0005*ratio
	arrow.vx*=drag;arrow.vy*=drag
	arrow.vx+=bosses.wind*ratio
	arrow.vy+=0.48*pow(1000.0/60.0,2)*0.001*ratio
	arrow.px+=arrow.vx*ratio;arrow.py+=arrow.vy*ratio

func advance_arrow(arrow: RefCounted, delta: float) -> void:
	arrow.previous=arrow.position
	guide(arrow,delta)
	bosses.contact(arrow)
	integrate(arrow,delta)
	arrow.life+=delta
	arrow.trail.append(arrow.position)
	if arrow.trail.size()>14:arrow.trail.remove_at(0)
	var contacts:Array=[]
	for wall in obstacles:
		var contact:=Geometry.sweep(wall.bounds,arrow.previous,arrow.position)
		if not contact.is_empty():contacts.append({"kind":"wall","object":wall,"contact":contact})
	for brick in bricks:
		var contact:=Geometry.sweep(brick.bounds,arrow.previous,arrow.position)
		if not contact.is_empty():contacts.append({"kind":"brick","object":brick,"contact":contact})
	if core!=null:
		var contact:=Geometry.sweep(Rect2(core.x-33,core.y-33,66,66),arrow.previous,arrow.position)
		if not contact.is_empty():contacts.append({"kind":"core","contact":contact})
	contacts.sort_custom(func(a,b):return a.contact.t<b.contact.t)
	active_arrow=arrow
	for item in contacts:
		if phase!="flying":break
		if item.kind=="wall":
			if skills.wall(arrow,item.object):continue
			if reflect(arrow,item.contact):
				item.object.flash=0.2;bounce(arrow);break
		elif item.kind=="core":
			arrow.achievement.core=true
			var extra:=evaluate_achievements(arrow);state.coins+=extra;level_money+=extra;shot_money+=extra;clear();break
		elif item.object in bricks and not arrow.overlap.has(item.object.id):
			arrow.hit[item.object.id]=true;arrow.overlap[item.object.id]=true
			skills.projectile_hit(item.object,arrow)
			arrow.pierce-=0 if item.object.type=="frost" else 1
			if arrow.pierce<=0:break
	active_arrow=null
	reflect_walls(arrow,true)
	for id in arrow.overlap.keys():
		var present:=false
		for brick in bricks:
			if brick.id==id and brick.bounds.grow(2.5).has_point(arrow.position):present=true;break
		if not present:arrow.overlap.erase(id)
	if arrow.pierce<=0 or arrow.position.y>1080 or arrow.life>4.5:arrows.erase(arrow)

func reflect(arrow: RefCounted, contact: Dictionary) -> bool:
	var normal:Vector2=contact.normal
	if arrow.velocity.dot(normal)>=0:return false
	arrow.position=arrow.previous.lerp(arrow.position,contact.t)+normal*0.8
	arrow.velocity=arrow.velocity.bounce(normal)*0.94;arrow.trail.clear()
	return true

func reflect_walls(arrow: RefCounted, live: bool) -> void:
	var bounced:=false
	if arrow.px<20 or arrow.px>760:
		arrow.px=clampf(arrow.px,20,760);arrow.vx=-arrow.vx*0.86;bounced=true
	if arrow.py<22:
		arrow.py=22;arrow.vy=absf(arrow.vy)*0.85;bounced=true
	if bounced and live:bounce(arrow)

func bounce(arrow: RefCounted) -> void:
	arrow.achievement.bounces+=1
	fx.ring(arrow.position,Color("#8a9480"),27);fx.burst(arrow.position,Color("#ced9a4"),9,0.7);cue("ricochet",1,arrow.position.x)
	skills.bounce(arrow)

func predict(position: Vector2, velocity: Vector2, distance: float=720) -> PackedVector2Array:
	var arrow:=Arrow.new();arrow.position=position;arrow.velocity=velocity
	var path:=PackedVector2Array([position])
	var traveled:=0.0
	# Only seeking reads preview hit attribution. Plain/core-hunting arrows
	# pass through bricks here, so their brick sweeps cannot affect the path.
	var seeking:=rank("seeking")>0
	var spectral:=rank("spectral")>0
	var hit_ids:Array=[]
	var hit_bounds:Array[Rect2]=[]
	if seeking:
		for brick in bricks:hit_ids.append(brick.id);hit_bounds.append(brick.bounds.grow(2.5))
	for step in range(270):
		var from:Vector2=arrow.position
		arrow.previous=from
		# Prediction omits side effects while using the same integration/colliders.
		skills.guide_prediction(arrow,1.0/60)
		bosses.contact(arrow,false)
		integrate(arrow,1.0/60)
		if not spectral:
			var contacts:Array=[]
			for wall in obstacles:
				var contact:=Geometry.sweep(wall.bounds,from,arrow.position)
				if not contact.is_empty():contacts.append(contact)
			contacts.sort_custom(func(a,b):return a.t<b.t)
			for contact in contacts:
				if reflect(arrow,contact):break
		reflect_walls(arrow,false)
		if seeking:
			var finish:Vector2=arrow.position
			var left:=minf(from.x,finish.x);var right:=maxf(from.x,finish.x)
			var top:=minf(from.y,finish.y);var bottom:=maxf(from.y,finish.y)
			for index in range(hit_ids.size()):
				if arrow.hit.has(hit_ids[index]):continue
				var bounds:Rect2=hit_bounds[index]
				if right<bounds.position.x or left>bounds.end.x or bottom<bounds.position.y or top>bounds.end.y:continue
				if not Geometry.sweep(bounds,from,finish,0).is_empty():arrow.hit[hit_ids[index]]=true
		traveled+=from.distance_to(arrow.position);path.append(arrow.position)
		if traveled>=distance or arrow.position.y>1380:break
	return path

func cue(type: String, n: int=1, x: float=390, priority: bool=false, ui: bool=false) -> void:
	if not state.sound or paused and not ui:return
	var interval:float={"draw":0.065,"break":0.018,"boom":0.055,"lightning":0.06,"tap":0.03,"ricochet":0.035,"bell":0.2,"tick":0.08}.get(type,0.05)
	if not priority and clock-last_sounds.get(type,-INF)<interval:return
	last_sounds[type]=clock;sounds.append({"type":type,"n":clampi(n,0,20),"x":x,"priority":priority,"ui":ui})

func export_progress() -> Dictionary:
	var saved:Dictionary=state.duplicate(true)
	saved.erase("nativeBoss")
	if phase!="clearing":
		saved.board={"layoutVersion":2,"balanceVersion":3,"level":state.level,"levelMoney":level_money,"initial":initial,"killed":killed,"bricks":bricks.map(func(b):return b.serialize()),"obstacles":obstacles.map(func(b):return {"x":b.x,"y":b.y,"w":b.w,"h":b.h}),"core":core!=null}
	if not bosses.fight.is_empty() and phase!="clearing":saved.nativeBoss=bosses.serialize()
	return {"format":"slingbreak-progress","version":1,"exportedAt":Time.get_datetime_string_from_system(true),"state":saved}

func snapshot() -> Dictionary:
	var shop:Array=[]
	for pair in [["power","弹弓","crosshair"],["arrow","箭矢","move-up-right"],["brick","砖块","blocks"],["comboCap","连击强化","gauge"],["slots","技能槽位","layout-grid"],["rerollCap","技能刷新","refresh-cw"],["draw","拉弦速度","timer"]]:
		var key:String=pair[0]
		var maxed:bool=key=="slots" and state.up.slots>=3 or key=="rerollCap" and state.up.rerollCap>=4 or key=="draw" and state.up.draw>=10
		var description:String={"power":"拉力 %d%% · 更远射程" % roundi(speed()/24*100),"arrow":"伤害 %.2f · 穿透 %d 块" % [damage(),penetration()],"brick":"价值 +%d%% · 特殊率 %.1f%%" % [roundi(state.up.brick*16),special_rate()*100],"comboCap":"每连增幅 +%s，%d 连达到 ×%s 上限" % [String.num(combo_step(),3),cap_kills(),String.num(combo_cap(),3)],"slots":"当前 %d 个技能槽" % slots,"rerollCap":"","draw":"拉弦间隔 %.2f 秒" % draw_interval()}[key]
		var label:String="%d / 10" % state.up.draw if key=="draw" else "+%d" % state.up.comboCap if key=="comboCap" else "%d / 4" % slots if key=="slots" else "%d / 5" % reroll_cap() if key=="rerollCap" else "LV. %d" % (state.up[key]+1)
		shop.append({"key":key,"name":pair[1],"icon":pair[2],"description":description,"level":state.up[key],"cost":cost(key),"maxed":maxed,"locked":key=="comboCap" and state.up.brick<5 and state.up.comboCap==0,"affordable":state.coins>=cost(key),"levelLabel":label})
	return {"level":state.level,"coins":state.coins,"total":state.total,"best":state.best,"phase":phase,"time":time,"origin":{"x":origin.x,"y":origin.y},"initial":initial,"killed":killed,"threshold":threshold,"shotMoney":shot_money,"levelMoney":level_money,"core":core,"skills":state.skills.keys(),"paused":paused,"draft":state.draft,"up":state.up,"rerolls":state.rerolls,"rerollCap":reroll_cap(),"drawInterval":draw_interval(),"nextShotAt":next_shot_at,"boardEntrance":board_entrance,"achievement":latest_achievement,"boss":bosses.fight if not bosses.fight.is_empty() else null,"bossStatus":bosses.status(),"notices":bosses.notices,"soundEnabled":state.sound,"volume":state.volume,"performanceMode":state.performanceMode,"reduced":reduced,"theme":theme,"themeMode":theme_mode,"slots":slots,"slotMax":4,"drag":drag,"rerollProgress":0 if state.rerolls>=reroll_cap() else (int(state.level)-1)%5/5.0,"canSwap":phase=="ready" and state.skillChosenLevel==state.level,"preview":{"damage":damage(),"speed":speed(),"penetration":penetration(),"bonus":bonus(),"comboStep":combo_step(),"comboCap":combo_cap(),"capKills":cap_kills()},"shop":shop,"chances":draft_chances(),"swapOffer":state.swapOffer,"achievementHistory":state.achievements,"achievementCatalog":content.achievements,"transition":{"report":report,"bonus":settled_bonus,"holdDraft":wipe!=null and clock*1000-wipe.at<640,"wipe":wipe,"clock":clock*1000,"clearAge":(clock-clear_shown_at)*1000}}
