extends SceneTree
## Reproducible pacing MODEL, not an autoplay win-rate claim. Uses production
## rewards/prices/purchases and a conservative 40 ordinary-brick clear at 3 kills
## per arrow. No skills, gold bricks, achievement payouts or variant bonuses.
const Sim=preload("res://src/core/simulation.gd")
const Upgrades=preload("res://src/core/upgrade_tree.gd")

func _initialize() -> void:
	var results:Array=[]
	for strategy in ["balanced","arsenal","wealth"]:
		var g:=Sim.new();g.start(431);g.state.skills={};g.state.draft=null;g.phase="ready";g.state.coins=0
		var milestones:Dictionary={};var rows:Array=[];var total:=0.0
		for level in range(1,201):
			g.state.level=level
			var income:float=g.bonus()
			for kill in range(40):income+=g.reward("normal",1+kill%3)
			g.state.coins+=income;total+=income
			while true:
				var options:Array=g.upgrade_nodes().filter(func(n):return n.available and n.affordable)
				if options.is_empty():break
				options.sort_custom(func(a,b):
					var wa:float=1.0;var wb:float=1.0
					if strategy=="arsenal":wa=.35 if a.col==1 else 1;wb=.35 if b.col==1 else 1
					if strategy=="wealth":wa=.35 if a.col==2 else 1;wb=.35 if b.col==2 else 1
					return a.cost*wa<b.cost*wb)
				g.buy(options[0].key,options[0].id)
				for target in ["slots_1","slots_2","slots_3","draw_3"]:
					var node:Dictionary=Upgrades.find(target)
					if g.state.up[node.key]>=node.end and not milestones.has(target):milestones[target]=level
			if level in [1,5,10,20,40,60,100,200]:rows.append({"level":level,"income":income,"coins":g.state.coins,"ranks":g.state.up.duplicate()})
			if g.upgrade_nodes().all(func(n):return n.complete):milestones["complete"]=level;break
		results.append({"strategy":strategy,"milestones":milestones,"income":total,"checkpoints":rows});g.dispose()
	var path:="res://../agent-tmp/godot/upgrade-economy.json"
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(results,"  "));file.close()
	print(JSON.stringify(results));quit()
