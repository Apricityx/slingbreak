extends RefCounted
## Purchase/reward model, never an autoplay or wall-clock claim. The fixed kill
## distributions deliberately isolate economy; strong combos are stress cases.
const Sim=preload("res://src/core/simulation.gd")
const Upgrades=preload("res://src/core/upgrade_tree.gd")
const CHECKPOINTS:=[50,100,200,500,1000,2000,5000,10000]

static func income(g:RefCounted,kills:int,achievements:bool,core_only:bool=false) -> float:
	var amount:float=g.bonus()
	if core_only:return amount
	for start in range(0,40,kills):
		var arrow:RefCounted=g.launch(g.origin,Vector2.UP*30)
		for index in range(mini(kills,40-start)):
			var value:float=g.reward("normal",index+1)
			if achievements:
				arrow.kills=index+1;arrow.achievement.base+=value
				amount+=g.evaluate_achievements(arrow)
			else:amount+=value
		g.arrows.clear()
	return amount

static func run(config:Dictionary={}) -> Dictionary:
	var g:=Sim.new();g.start(int(config.get("seed",431)))
	g.state.skills={};g.state.draft=null;g.phase="ready";g.variants.reset()
	var marks:Dictionary={};var rows:Array=[];var total:=0.0;var bought:=0;var window:=0
	var strategy:String=config.get("strategy","balanced")
	for level in range(1,int(config.get("levels",10000))+1):
		g.state.level=level;g.state.skillRuntime={"level":level,"shots":0,"forge":false,"decay":false}
		if config.get("draft",false):
			var options:Array=g.roll();var choice:String=options[0]
			for id in ["forge","bargain","treasury","mint","jackpot","bounty"]:
				if id in options:choice=id;break
			if g.state.skills.size()>=g.slots:g.state.skills.erase(g.state.skills.keys()[0])
			g.state.skills[choice]=1
		if config.get("economic_envelope",false) and marks.has("complete"):
			g.state.skills={"mint":1,"treasury":1,"jackpot":1,"bounty":1}
		var earned:=income(g,int(config.get("kills",3)),config.get("achievements",false),config.get("core_only",false))
		g.state.coins+=earned;total+=earned
		if not marks.has("complete"):
			while true:
				var options:Array=g.upgrade_nodes().filter(func(n):return not n.infinite and n.available and n.affordable)
				if options.is_empty():break
				options.sort_custom(func(a,b):
					var col:int=1 if strategy=="arsenal" else 2 if strategy=="wealth" else -1
					return a.cost*(.35 if a.col==col else 1.0)<b.cost*(.35 if b.col==col else 1.0))
				g.buy(options[0].key,options[0].id)
				for target in ["slots_1","slots_2","slots_3","draw_3"]:
					var node:Dictionary=Upgrades.find(target)
					if g.state.up[node.key]>=node.end and not marks.has(target):marks[target]=level
			if Upgrades.complete(g.state.up):marks.complete=level
		else:
			while true:
				var key:="arrow";var price:float=g.mastery_cost(key)
				if strategy!="damage_only":
					for candidate in ["brick","comboCap"]:
						var cost:float=g.mastery_cost(candidate)
						if cost<price:key=candidate;price=cost
				if g.state.coins<price:break
				var before:int=g.state.mastery[key]
				if not g.buy(key,"mastery_"+{"comboCap":"combo"}.get(key,key)):
					push_error("Economy model purchase rejected");break
				bought+=int(g.state.mastery[key])-before
				if not marks.has("endless"):marks.endless=level
		if level in CHECKPOINTS:
			rows.append({"level":level,"income":earned,"coins":g.state.coins,"up":g.state.up.duplicate(),"mastery":g.state.mastery.duplicate(),"baseDamage":g.base_damage(),"baseHp":g.base_hp(),"hits":ceili(g.base_hp()/g.base_damage()),"hpPerDamage":g.base_hp()/g.base_damage(),"masteryRanks":bought,"ranksLast100":bought-window})
		if level%100==0:window=bought
		g.events.clear();g.sounds.clear();g.fx.reset()
	var result:Dictionary={"config":config,"milestones":marks,"income":total,"checkpoints":rows}
	g.dispose();return result
