extends RefCounted
## Explicit, validated debug surface; never accepts arbitrary object properties.
const Progress=preload("res://src/core/progress.gd")
const FIELDS={
	"damage":["最终伤害",0.001,1e9,0.1],"speed":["箭速",1,200,0.1],
	"penetration":["穿透次数",1,10000,1],"drawInterval":["射击间隔（秒）",0.01,100,0.01],
	"baseHp":["砖块基础生命",0.001,1e9,0.1],"specialRate":["特殊砖比例",0,1,0.01],
	"bonus":["过关奖励",0,1e15,1],"comboStep":["连击增幅",0.001,1000,0.01],
	"comboCap":["连击倍率上限",1,100000,0.1],"rewardScale":["砖块收益倍率",0,100000,0.1],
	"costScale":["商店价格倍率",0,100000,0.1],"thresholdRate":["核心解锁击破比例",0,1,0.01]}
var unlocked:=false
var enabled:=false
var overrides:Dictionary={}
var counts:Dictionary={}
var taps:=0
var last_tap:=-10000

func tap(now:int) -> bool:
	taps=taps+1 if now-last_tap<=450 else 1;last_tap=now
	if taps>=7:unlocked=true
	return unlocked

func value(key:String,fallback:float) -> float:
	return float(overrides.get(key,fallback)) if enabled else fallback

func load_config(config:Dictionary) -> void:
	unlocked=config.get("unlocked",false)==true;enabled=unlocked and config.get("enabled",false)==true
	for key in config.get("overrides",{}):
		if FIELDS.has(key) and Progress.finite_number(config.overrides[key],FIELDS[key][1],FIELDS[key][2]):overrides[key]=config.overrides[key]
	for key in config.get("counts",{}):
		if str(key).is_valid_int() and int(key)>=1 and int(key)<=100000 and Progress.finite_number(config.counts[key],1,77,true):counts[str(int(key))]=int(config.counts[key])

func config() -> Dictionary:
	return {"unlocked":unlocked,"enabled":enabled,"overrides":overrides.duplicate(),"counts":counts.duplicate()}

func apply(s:RefCounted,input:Dictionary) -> bool:
	if not unlocked:return false
	match input.get("operation",""):
		"enable":
			if not input.get("value") is bool:return false
			enabled=input.value
		"reset":enabled=false;overrides.clear();counts.clear()
		"override":
			var key:String=input.get("key","")
			if not FIELDS.has(key):return false
			if input.get("value")==null:overrides.erase(key)
			elif Progress.finite_number(input.value,FIELDS[key][1],FIELDS[key][2],FIELDS[key][3]==1):overrides[key]=input.value
			else:return false
		"count":
			if not Progress.finite_number(input.get("level"),1,100000,true):return false
			if input.get("value")==null:counts.erase(str(int(input.level)))
			elif Progress.finite_number(input.value,1,77,true):counts[str(int(input.level))]=int(input.value)
			else:return false
		"state":
			if not enabled:return false
			var key:String=input.get("key","")
			if key in Progress.UPGRADES:
				if not Progress.finite_number(input.get("value"),0,{"draw":10,"slots":3,"rerollCap":4}.get(key,10000),true):return false
				s.state.up[key]=int(input.value)
				while s.state.skills.size()>s.slots:s.state.skills.erase(s.state.skills.keys()[-1])
			elif key in ["coins","total","best","rerolls"]:
				if not Progress.finite_number(input.get("value"),0,s.reroll_cap() if key=="rerolls" else 1e18,key!="coins"):return false
				s.state[key]=input.value
			else:return false
		"skills":
			if not enabled or not input.get("ids") is Array or input.ids.size()>s.slots:return false
			var chosen:Dictionary={}
			for id in input.ids:
				if not id is String or not s.content.by_id.has(id) or chosen.has(id):return false
				chosen[id]=1
			s.state.skills=chosen;s.state.swapOffer=null
			# Regenerate to remove old passive/contract effects, including pending jobs.
			s.state.skillChosenLevel=s.state.level;s.state.board=null;s.generate()
		"level":
			if not enabled or not Progress.finite_number(input.get("value"),1,100000,true):return false
			s.state.level=int(input.value);s.state.board=null;s.state.bossOverride=null
			s.state.skillChosenLevel=s.state.level;s.generate()
		"boss":
			if not enabled or not input.get("id") is String or not input.id in Progress.BOSSES:return false
			s.state.bossOverride={"level":s.state.level,"boss":input.id};s.state.board=null
			s.state.skillChosenLevel=s.state.level;s.state.swapOffer=null;s.generate()
		_:return false
	s.revision+=1
	return true
