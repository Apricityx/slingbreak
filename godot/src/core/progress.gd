extends RefCounted
## Validate external progress before changing a live session or either save file.
const UPGRADES := ["power","arrow","brick","draw","comboCap","slots","rerollCap"]
const BOSSES := ["eye","clock","serpent","forge"]
static var known_skills:Dictionary={}

static func skill_ids() -> Dictionary:
	if known_skills.is_empty():
		for item in JSON.parse_string(FileAccess.get_file_as_string("res://assets/skills.json")):known_skills[item.id]=true
	return known_skills

static func defaults() -> Dictionary:
	return {"level":1,"coins":0.0,"total":0,"best":0,"comboRulesVersion":2,"legacyBest":0,"up":{"power":0,"arrow":0,"brick":0,"draw":0,"comboCap":0,"slots":0,"rerollCap":0},"rerolls":0,"rerollGrantLevel":0,"sound":true,"volume":100,"performanceMode":false,"board":null,"skills":{},"skillScopeVersion":3,"skillGateVersion":1,"skillChosenLevel":0,"draft":null,"swapOffer":null,"skillRuntime":null,"milestone":null,"bossOverride":null,"achievements":{}}

static func finite_number(value: Variant, low: float, high: float, integer: bool=false) -> bool:
	if not (value is int or value is float):return false
	var number:=float(value)
	return is_finite(number) and number>=low and number<=high and (not integer or number==floor(number))

static func valid(payload: Dictionary) -> bool:
	if payload.get("format")!="slingbreak-progress" or payload.get("version")!=1 or not payload.get("state") is Dictionary:return false
	var candidate:Dictionary=payload.state
	for key in ["level","coins","total","best"]:
		if not finite_number(candidate.get(key),1 if key=="level" else 0,100000 if key=="level" else 1e18,key!="coins"):return false
	if not candidate.get("up") is Dictionary:return false
	for key in UPGRADES:
		if not finite_number(candidate.up.get(key,0),0,{"draw":10,"slots":3,"rerollCap":4}.get(key,10000),true):return false
	if candidate.has("skills") and not candidate.skills is Dictionary:return false
	if candidate.get("skills",{}).size()>81:return false
	var ids:=skill_ids()
	for id in candidate.get("skills",{}):
		if not id is String or not ids.has(id) or not finite_number(candidate.skills[id],0,1,true):return false
	if candidate.has("volume") and not finite_number(candidate.volume,0,100,true):return false
	for key in ["sound","performanceMode"]:
		if candidate.has(key) and not candidate[key] is bool:return false
	for key in ["rerolls","rerollGrantLevel","skillChosenLevel","legacyBest","comboRulesVersion","skillScopeVersion","skillGateVersion"]:
		if candidate.has(key) and not finite_number(candidate[key],0,1e18,true):return false
	if candidate.get("achievements",{}) is not Dictionary or candidate.get("achievements",{}).size()>32:return false
	for count in candidate.get("achievements",{}).values():
		if not finite_number(count,0,1e18,true):return false
	var runtime:Variant=candidate.get("skillRuntime")
	if runtime!=null:
		if not runtime is Dictionary:return false
		for key in ["level","shots"]:
			if not finite_number(runtime.get(key,0),0,1e18,true):return false
		for key in ["forge","decay"]:
			if runtime.has(key) and not runtime[key] is bool:return false
		if runtime.has("contract"):
			var contract:Variant=runtime.contract
			if not contract is Dictionary or not finite_number(contract.get("rounds"),0,3,true) or not finite_number(contract.get("size"),0,3,true):return false
			if not contract.get("targets") is Array or contract.targets.size()>3:return false
			for point in contract.targets:
				if not point is Dictionary or not finite_number(point.get("x"),-2000,2000) or not finite_number(point.get("y"),-2000,2000):return false
	for key in ["draft","swapOffer"]:
		var offer:Variant=candidate.get(key)
		if offer==null:continue
		if not offer is Dictionary or not finite_number(offer.get("level"),1,100000,true) or not offer.get("options") is Array or offer.options.size()!=3:return false
		for id in offer.options:
			if not id is String or not ids.has(id) or offer.options.count(id)!=1:return false
		if key=="draft" and offer.has("rerolled") and not finite_number(offer.rerolled,0,1e18,true):return false
		if key=="swapOffer" and (not offer.get("target") is String or not ids.has(offer.target)):return false
	var override:Variant=candidate.get("bossOverride")
	if override!=null and (not override is Dictionary or not finite_number(override.get("level"),1,100000,true) or not override.get("boss") in BOSSES):return false
	if candidate.has("bossDeck"):
		if not candidate.bossDeck is Array or candidate.bossDeck.size()>4:return false
		for id in candidate.bossDeck:
			if not id in BOSSES:return false
	if candidate.get("board")!=null and not valid_board(candidate.board):return false
	if candidate.get("nativeBoss")!=null and not valid_boss(candidate.nativeBoss,candidate.level):return false
	return true

static func valid_boss(boss:Variant,level:float) -> bool:
	if not boss is Dictionary or not boss.get("boss") in BOSSES or boss.get("level")!=level:return false
	var phases:int=4 if boss.boss=="serpent" else 3
	if boss.get("phases")!=phases or not finite_number(boss.get("phase"),1,phases,true):return false
	if not finite_number(boss.get("max"),1,1e15) or not finite_number(boss.get("hp"),0,boss.max):return false
	for key in ["hits","paid","clock"]:
		if not finite_number(boss.get(key),0,1e18,key=="hits"):return false
	if not boss.get("intro") is bool or not boss.get("abilities") is Array or boss.abilities.size()!=phases or not boss.get("data") is Dictionary:return false
	for phase in boss.abilities:
		if not phase is Array or phase.is_empty() or phase.size()>5:return false
		for ability in phase:
			if not ability is String or not ability in {"eye":["orbit","summon","tear","gaze","mirage","doom"],"clock":["stop","toll","pendulum","rewind","haste","midnight"],"serpent":["coil","dive","devour","eclipse","comet","twin"],"forge":["meteor","magma","slam","bellows","palm"]}[boss.boss]:return false
	var meter:String={"eye":"ward","clock":"spring","forge":"heat"}.get(boss.boss,"")
	if meter!="" and not finite_number(boss.data.get(meter),0,100):return false
	if boss.boss=="serpent":
		if not boss.data.get("snakes") is Array or boss.data.snakes.is_empty() or boss.data.snakes.size()>2:return false
		for snake in boss.data.snakes:
			if not snake is Dictionary or not snake.get("hp") is Array or snake.hp.size()>64 or not finite_number(snake.get("max"),0,64,true):return false
			for hp in snake.hp:
				if not finite_number(hp,.001,1e15):return false
	return true

static func valid_board(board: Variant) -> bool:
	if not board is Dictionary or not board.get("bricks") is Array or board.bricks.size()>240:return false
	if not finite_number(board.get("initial"),1,10000,true) or not finite_number(board.get("killed"),0,10000,true):return false
	if not finite_number(board.get("level",1),1,100000,true) or not finite_number(board.get("levelMoney",0),0,1e18):return false
	if board.has("core") and not board.core is bool:return false
	for item in board.bricks:
		if not item is Dictionary:return false
		for key in ["x","y","w","h","hp","max"]:
			if not finite_number(item.get(key),0.001 if key in ["w","h","hp","max"] else -2000,1e12):return false
		if not item.get("type") in ["normal","bomb","lightning","frost","prism","gold","void","hydra","shard","anchor","plate","magma","scale","star","hour"]:return false
		if item.has("frozen") and not item.frozen is bool:return false
		if item.has("nativeFlags"):
			if not item.nativeFlags is Dictionary or item.nativeFlags.size()>16:return false
			for flag in item.nativeFlags:
				if flag=="markUntil":
					if not finite_number(item.nativeFlags[flag],0,1e18):return false
				elif flag in ["hourIndex","slot","count"]:
					if not finite_number(item.nativeFlags[flag],0,64,true):return false
				elif not item.nativeFlags[flag] is bool:return false
	if not board.get("obstacles",[]) is Array or board.get("obstacles",[]).size()>12:return false
	for item in board.get("obstacles",[]):
		if not item is Dictionary:return false
		for key in ["x","y","w","h"]:
			if not finite_number(item.get(key),0.001 if key in ["w","h"] else -2000,2000):return false
	return true
