extends RefCounted
## Presentation only: bounded, source-ID based, no retained projectiles or Tweens.
const LIMIT:=8
const LIFETIME:=1.25
var items:Array=[]

static func format_amount(value:float) -> String:
	if value>=1000000:return "%.1fm" % (value/1000000)
	if value>=10000:return "%.1fk" % (value/1000)
	return str(int(value))

static func tier(kills:int,cap:int) -> int:
	if kills>=cap:return 3
	if kills>=maxi(5,ceili(cap*0.66)):return 2
	return 1 if kills>=4 else 0

func record(point:Vector2,amount:float,source:int,kills:int,cap:int) -> void:
	var entry:Dictionary={}
	for item in items:
		if item.source==source and item.life>0.35:entry=item;break
	# Match the Web overload policy: fold excess arrows into the latest tally,
	# preserving the displayed sum instead of creating unbounded floating text.
	if entry.is_empty() and items.size()>=LIMIT:entry=items.back()
	var anchor:=point-Vector2(0,26)
	if entry.is_empty():
		entry={"source":source,"position":anchor,"target":anchor,"total":0.0,"count":0,"kills":0,"life":LIFETIME,"pop":0.0,"rise":0.0,"growth":0.0,"tier":0,"text":"","sub":""}
		items.append(entry)
	entry.total+=amount;entry.count+=1;entry.kills=maxi(kills,entry.count)
	entry.text="+"+format_amount(entry.total);entry.sub="%d 块" % entry.count
	entry.tier=tier(entry.kills,cap);entry.target=anchor
	entry.life=LIFETIME;entry.pop=1.0;entry.rise=0.0

func advance(delta:float) -> void:
	var alive:=0
	var follow:=1-exp(-delta*12)
	var grow:=1-exp(-delta*18)
	for item in items:
		item.life-=delta
		item.pop=maxf(0,item.pop-delta*5)
		item.growth=lerpf(item.growth,minf(20,log(item.count+1)/log(2.0)*4.2),grow)
		if item.life<0.5:item.rise+=delta*40
		item.position=item.position.lerp(item.target-Vector2(0,item.rise),follow)
		if item.life>0:items[alive]=item;alive+=1
	items.resize(alive)
