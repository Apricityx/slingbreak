extends RefCounted
## Ranks remain in state.up: old saves retain every purchased rank. The graph is
## a view and purchase policy over those ranks, never a second source of stats.
const CAPS := {"power":16,"arrow":24,"brick":20,"draw":10,"comboCap":12,"slots":3,"rerollCap":4}
const NODES := [
	{"id":"power_1","key":"power","name":"韧木弓臂","start":0,"end":4,"tier":1,"col":0,"row":0,"parents":[]},
	{"id":"arrow_1","key":"arrow","name":"淬锋箭头","start":0,"end":4,"tier":1,"col":1,"row":0,"parents":[]},
	{"id":"brick_1","key":"brick","name":"点金矿脉","start":0,"end":5,"tier":1,"col":2,"row":0,"parents":[]},
	{"id":"draw_1","key":"draw","name":"轻盈回弦","start":0,"end":3,"tier":1,"col":0,"row":1,"parents":["power_1"]},
	{"id":"combo_1","key":"comboCap","name":"连锁赏金","start":0,"end":4,"tier":1,"col":2,"row":1,"parents":["brick_1"]},
	{"id":"slots_1","key":"slots","name":"双星共鸣","start":0,"end":1,"tier":1,"col":1,"row":2,"parents":["arrow_1"]},
	{"id":"reroll_1","key":"rerollCap","name":"灵感火种","start":0,"end":1,"tier":1,"col":2,"row":2,"parents":["combo_1"]},
	{"id":"power_2","key":"power","name":"银翼弓臂","start":4,"end":10,"tier":2,"col":0,"row":3,"parents":["draw_1"]},
	{"id":"arrow_2","key":"arrow","name":"碎甲锋刃","start":4,"end":12,"tier":2,"col":1,"row":3,"parents":["slots_1"]},
	{"id":"brick_2","key":"brick","name":"辉金矿脉","start":5,"end":12,"tier":2,"col":2,"row":3,"parents":["combo_1"]},
	{"id":"draw_2","key":"draw","name":"疾风回弦","start":3,"end":6,"tier":2,"col":0,"row":4,"parents":["power_2"]},
	{"id":"combo_2","key":"comboCap","name":"连胜金契","start":4,"end":8,"tier":2,"col":2,"row":4,"parents":["brick_2"]},
	{"id":"slots_2","key":"slots","name":"三星协奏","start":1,"end":2,"tier":2,"col":1,"row":5,"parents":["arrow_2"]},
	{"id":"reroll_2","key":"rerollCap","name":"命运罗盘","start":1,"end":2,"tier":2,"col":2,"row":5,"parents":["reroll_1","combo_2"]},
	{"id":"power_3","key":"power","name":"逐日弓臂","start":10,"end":16,"tier":3,"col":0,"row":6,"parents":["draw_2"]},
	{"id":"arrow_3","key":"arrow","name":"星陨锋刃","start":12,"end":24,"tier":3,"col":1,"row":6,"parents":["slots_2"]},
	{"id":"brick_3","key":"brick","name":"黄金国度","start":12,"end":20,"tier":3,"col":2,"row":6,"parents":["combo_2"]},
	{"id":"draw_3","key":"draw","name":"流光回弦","start":6,"end":10,"tier":3,"col":0,"row":7,"parents":["power_3"]},
	{"id":"combo_3","key":"comboCap","name":"不朽盛宴","start":8,"end":12,"tier":3,"col":2,"row":7,"parents":["brick_3"]},
	{"id":"slots_3","key":"slots","name":"四象星阵","start":2,"end":3,"tier":3,"col":1,"row":8,"parents":["arrow_3"]},
	{"id":"reroll_3","key":"rerollCap","name":"命运织机","start":2,"end":4,"tier":3,"col":2,"row":8,"parents":["reroll_2","combo_3"]}
]
const MASTERY := [
	{"id":"mastery_arrow","key":"arrow","name":"恒星锋芒","tier":4,"col":1,"parents":[],"infinite":true},
	{"id":"mastery_brick","key":"brick","name":"丰饶星海","tier":4,"col":2,"parents":[],"infinite":true},
	{"id":"mastery_combo","key":"comboCap","name":"永恒连锁","tier":4,"col":0,"parents":[],"infinite":true}
]
const MASTERY_KEYS := ["arrow","brick","comboCap"]
const BARGAIN_PRICE := 0.8
const FORGE_BONUS := 1
const MASTERY_PRICES := {"arrow":240000.0,"brick":180000.0,"comboCap":50000.0}

## Both combat and the tree preview consume these curves. Logarithmic economy
## gains avoid multiplying two linear infinite ranks into quadratic income.
static func mastery_growth(rank:int) -> float:
	return 12.0*log(1.0+float(maxi(0,rank))/12.0)

static func arrow_damage(rank:int,mastery:int=0) -> float:
	var n:=log(1.0+float(maxi(0,mastery))/12.0)/log(2.0)
	return 2+.65*log(float(rank)+1)/log(2.0)+.08*clampi(rank-12,0,12)+.65*n+.13*n*n

static func brick_value(rank:int,mastery:int=0) -> float:
	return 1+.16*rank+.12*mastery_growth(mastery)

static func combo_step(rank:int,mastery:int=0) -> float:
	return .25+.025*rank+.01*mastery_growth(mastery)

static func combo_cap(rank:int,mastery:int=0) -> float:
	return 3+.5*rank+.25*mastery_growth(mastery)

static func reroll_interval(rank:int) -> int:
	return [5,5,4,4,3][clampi(rank,0,4)]

static func metric_number(value:float,mastery:int) -> String:
	# Small late-game gains must remain visible in the before/after comparison.
	return String.num(value,2 if mastery==0 else 4 if mastery<10000 else 6)

static func complete(up:Dictionary) -> bool:
	for key in CAPS:
		if int(up.get(key,0))<CAPS[key]:return false
	return true

static func mastery_cost(key:String,rank:int) -> float:
	if key not in MASTERY_KEYS or rank<0:return 0
	# Near-linear prices track level income (L^1.1 / L^1.15). With diminishing
	# gains, purchases per cleared chapter stay close instead of accelerating.
	return ceil(minf(1e15,MASTERY_PRICES[key]*pow(1+float(rank)/12,1.15)))

static func mastery_description(key:String) -> String:
	return {"arrow":"永久提升基础伤害，享受战斗技能加成；阶位越高，单阶增益越小。","brick":"永久提高所有碎砖收益；单阶增益递减，持续积累财富。","comboCap":"永久提高连击增幅与倍率上限；单阶增益递减，长连锁收益更高。"}.get(key,"")

static func find(id:String) -> Dictionary:
	for node in NODES+MASTERY:
		if node.id==id:return node
	return {}

static func current(up:Dictionary,key:String) -> Dictionary:
	for node in NODES:
		if node.key==key and int(up.get(key,0))<node.end:return node
	return {}

static func available(up:Dictionary,node:Dictionary) -> bool:
	if node.is_empty():return false
	if node.get("infinite",false):return complete(up)
	var rank:int=up.get(node.key,0)
	if rank<node.start or rank>=node.end:return false
	# Purchased legacy ranks grandfather their own stage, without granting free
	# prerequisites, currency or extra skill slots.
	if rank>node.start:return true
	for id in node.parents:
		var parent:=find(id)
		if int(up.get(parent.key,0))<parent.end:return false
	return true

static func base_cost(key:String,rank:int) -> float:
	if not CAPS.has(key) or rank>=CAPS[key]:return 0
	match key:
		"slots":return [2500.0,30000.0,220000.0][rank]
		"rerollCap":return [800.0,4000.0,12000.0,32000.0][rank]
		"comboCap":return ceil(750*pow(1.55,rank))
		"arrow":return ceil(100*pow(1.4,mini(rank,12))*pow(1.32,maxi(0,rank-12)))
		_:return ceil({"power":75,"brick":120,"draw":90}[key]*pow({"power":1.4,"brick":1.45,"draw":1.6}[key],rank))

static func metrics(key:String,rank:int,mastery:int=0) -> Array:
	match key:
		"power":return [["弹速","%.2f" % (24+11*(1-exp(-float(rank)/9)))]]
		"arrow":return [["基础伤害",metric_number(arrow_damage(rank,mastery),mastery)],["基础穿透",str(mini(6,2+rank/4))]]
		"brick":return [["碎砖收益","×"+metric_number(brick_value(rank,mastery),mastery)],["特殊砖率","%.1f%%" % (100*minf(.22,.1+.12*(1-exp(-float(rank)/12))))]]
		"draw":return [["发射间隔","%.2f 秒" % (1.0-.06*mini(10,rank))]]
		"comboCap":return [["连击增幅","+"+String.num(combo_step(rank,mastery),3 if mastery==0 else 6)],["倍率上限","×"+metric_number(combo_cap(rank,mastery),mastery)]]
		"slots":return [["技能槽",str(1+mini(3,rank))]]
		"rerollCap":return [["刷新容量",str(1+mini(4,rank))],["补充周期","每 %d 关" % reroll_interval(rank)]]
	return []

static func descriptions(key:String) -> String:
	return {"power":"更快的箭速，让反弹与贯穿更加利落。","arrow":"提升基础伤害，13～24 级每级额外 +0.08；每 4 级穿透 +1，上限 6。","brick":"增加碎砖收益与特殊砖数量；特殊砖率在下关生成时生效。","draw":"缩短两次发射的等待时间，满级为 0.40 秒。","comboCap":"每次连续击碎带来更高收益，并提升单箭倍率上限。","slots":"增加一个跨关技能槽，让更多战斗技能同时生效。","rerollCap":"容量 +1 并立即获得 1 次刷新；第 2、4 级将补充周期缩短至 4、3 关。"}.get(key,"")
