extends RefCounted
## Actual brick kills at staged times; no synthetic income values.
static func step(entry:Dictionary,time:float) -> void:
	var g:RefCounted=entry.g
	if time<0:return
	if not entry.has("income_arrow"):
		entry.income_arrow=g.launch(Vector2(240,440),Vector2.UP*20)
		g.initial=1000;g.threshold=1000
		g.stats.previousBest=1000
		entry.next_kill=0
		g.bricks.clear();entry.income_bricks=[]
		for index in range(12):
			entry.income_bricks.append(g.make_brick({"x":260+(index%4)*80,"y":440+(index/4)*48,"hp":1,"max":1,"w":72,"h":34,"type":"gold" if index==7 else "normal"}))
	var schedule:Array=[0.0,0.16,0.30,0.42,0.53,0.63,0.72,0.80,0.87,0.94,1.01,1.08]
	while entry.next_kill<schedule.size() and time>=schedule[entry.next_kill]:
		g.fx.advance_visual(maxf(0,schedule[entry.next_kill]-g.fx.visual_time))
		var index:int=entry.next_kill
		var brick:RefCounted=entry.income_bricks[index]
		entry.income_arrow.position=brick.position;g.active_arrow=entry.income_arrow
		g.hit(brick,100);g.active_arrow=null
		entry.next_kill+=1
