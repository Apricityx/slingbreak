extends Control
## Continuous fill across banked and partially earned charge slots.
var visuals: RefCounted
var count:=0
var capacity:=1
var ghost:=0
var progress:=0.0
var pip:=12.0
var gap:=6.0
var display_amount:=0.0
var reduced:=false
var flashes:Array=[]
var snapshot:=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2((capacity+ghost)*(pip+gap)-gap,pip+6)
	if snapshot:set_process(false)
	else:display_amount=count+progress

func motion_copy() -> Control:
	var result:Control=get_script().new()
	result.set("visuals",visuals);result.set("count",count);result.set("capacity",capacity);result.set("ghost",ghost);result.set("progress",progress);result.set("pip",pip);result.set("gap",gap);result.set("display_amount",display_amount);result.set("flashes",flashes.duplicate(true));result.set("snapshot",true);result.set_process(false)
	return result

func set_amount(value:int,fraction:float,still:bool=false) -> void:
	if value>count and not still:
		for i in range(count,value):flashes.append({"index":i,"age":-.14*float(i-count),"spent":false})
	elif value<count and not still:
		for i in range(value,count):
			var pending:bool=flashes.any(func(flash):return int(flash.index)==i and flash.spent and flash.age<.6)
			if not pending:flashes.append({"index":i,"age":0.0,"spent":true})
	count=value;progress=fraction
	reduced=still
	if reduced:display_amount=count+progress;queue_redraw()

func spend() -> Vector2:
	var index:=maxi(0,count-1)
	if not reduced:flashes.append({"index":index,"age":0.0,"spent":true})
	return Vector2(pip/2+index*(pip+gap),size.y/2)

func _process(delta:float) -> void:
	var had_flashes:=not flashes.is_empty()
	for flash in flashes:flash.age+=delta
	if reduced:flashes.clear()
	else:flashes=flashes.filter(func(flash):return flash.age<.7)
	var target:=float(count)+progress
	if is_equal_approx(display_amount,target) and flashes.is_empty() and not had_flashes:return
	display_amount=target if reduced else lerpf(display_amount,target,1-exp(-delta*16))
	if absf(display_amount-target)<.001:display_amount=target
	queue_redraw()

func _draw() -> void:
	for i in range(capacity+ghost):
		var fill_amount:=clampf(display_amount-i,0,1) if i<capacity else 0.0
		var center:=Vector2(pip/2+i*(pip+gap),size.y/2)
		var radius:=pip*.4
		var points:=PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0)])
		var edge: Color=visuals.color("text-3") if i>=capacity else visuals.color("line-2").lerp(visuals.color("accent-ink"),fill_amount)
		var face: Color=visuals.color("surface")
		if i>=capacity:face.a=0;edge.a=.6
		draw_colored_polygon(points,face)
		if fill_amount>0:
			var cut:=center.y+radius-2*radius*fill_amount
			var left:=center.x-radius+absf(cut-center.y)
			var right:=center.x+radius-absf(cut-center.y)
			var fill:=PackedVector2Array([Vector2(left,cut),Vector2(right,cut)])
			if cut<center.y:fill.append(center+Vector2(radius,0))
			fill.append(center+Vector2(0,radius))
			if cut<center.y:fill.append(center+Vector2(-radius,0))
			draw_colored_polygon(fill,visuals.color("accent-bar"))
		for flash in flashes:
			if int(flash.index)!=i or float(flash.age)<0:continue
			var pulse:=clampf(float(flash.age)/.42,0,1)
			var ring:Color=visuals.color("accent-bar");ring.a=(1.0-pulse)*(.85 if not flash.spent else .65)
			draw_arc(center,radius*(1.0+.85*pulse),0,TAU,24,ring,1.4,true)
		points.append(points[0]);draw_polyline(points,edge,1.2,true)
