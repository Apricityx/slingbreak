extends RefCounted
## 时之君主 vector layer above the shader dial. Every interactive shape (hands,
## core, gears, key, bell, pendulum) is painted from its collider in world space;
## envelopes come from ClockSurface.pose() so dial and vectors never disagree.
const Surface=preload("res://src/render/clock_surface.gd")
var a:RefCounted
var m:RefCounted
var t:float
var motion:float

func paint(art:RefCounted,front:bool) -> void:
	a=art;m=a.m;t=a.t;motion=0.0 if a.g.reduced else t
	layer(front)
	# boss_art owns this painter; holding it back would form a leaking cycle.
	a=null;m=null

func layer(front:bool) -> void:
	var pose:=Surface.pose(a.g)
	var ink:float=pose.rise*(1-smoothstep(0.55,1.0,pose.crack))
	if ink<=0.01:return
	if not front:back(pose,ink);return
	for gear in m.gears:gear_art(gear,ink)
	props(pose,ink)
	hands(pose,ink)
	core(pose,ink)
	if not m.wave.is_empty():a.ring(m.center,m.wave.radius,"ward",4,0.6);a.ring(m.center,m.wave.radius-10,"ward",1.5,0.25)
	for arrow in m.frozen:a.glow(arrow.position,18,"stop",0.4);a.c._arrow_shape(arrow.position,arrow.velocity.angle(),a.color("ghost"))

## Under the masonry: the hour-hand light falling on the lit numeral, midnight
## plaque glows and rewind ghosts.
func back(pose:Dictionary,ink:float) -> void:
	var lit:RefCounted=m.lit_plaque()
	var id:String=m.move.get("id","")
	if lit!=null and not m.exposed() and id!="midnight" and not pose.dying:
		var pulse:float=0.75+0.25*sin(motion*4)
		var to:Vector2=lit.position;var from:Vector2=m.center
		var side:=(to-from).normalized().orthogonal()
		var shade:Color=a.color("gem",0.0);var bright:Color=a.color("gem",0.2*pulse*ink)
		a.canvas.draw_polygon(PackedVector2Array([from+side*6,to+side*34,to-side*34,from-side*6]),PackedColorArray([shade,bright,bright,shade]))
		a.glow(to,64,"gem",0.5*pulse*ink)
	if id=="midnight":
		for index in range(12):
			var lit_index:bool=index<int(m.move.rung)
			a.glow(m.hour_point(index),46,"weak" if lit_index else "ghost",(0.5 if lit_index else 0.12)*ink)
	if id=="rewind":
		for ghost in m.move.ghosts:
			var rect:=Rect2(ghost.x-ghost.w/2,ghost.y-ghost.h/2,ghost.w,ghost.h)
			var flicker:float=0.6+0.4*sin(motion*9+ghost.x*0.05)
			a.canvas.draw_rect(rect,a.color("ghost",0.18*flicker),true)
			a.canvas.draw_rect(rect,a.color("ghost",0.55*flicker),false,1.2)

## Breguet hand in local space (+x toward the tip). Collider: a 7 px bar from 36
## to the hand length, so the visible blade matches the deflecting shape.
func hand_shape(length:float,width:float) -> Array:
	var blade:=PackedVector2Array([Vector2(-38,-width*0.45),Vector2(length*0.62,-width),Vector2(length-6,-width*0.45),Vector2(length,0),Vector2(length-6,width*0.45),Vector2(length*0.62,width),Vector2(-38,width*0.45)])
	return [blade,Vector2(length*0.72,0),width*1.55]

func hand(angle:float,length:float,width:float,opacity:float,shadow:bool) -> void:
	var shape:Array=hand_shape(length,width)
	var offset:=Vector2(5,7) if shadow else Vector2.ZERO
	a.canvas.draw_set_transform(m.center+offset,angle)
	if shadow:
		a.canvas.draw_colored_polygon(shape[0],a.color("face",0.45*opacity))
		a.canvas.draw_arc(shape[1],shape[2],0,TAU,24,a.color("face",0.45*opacity),4,true)
	else:
		a.polygon(shape[0],"brass","brassDeep",1.6,opacity)
		a.canvas.draw_line(Vector2(-30,0),Vector2(length-12,0),a.color("handEdge",0.55*opacity),1.2,true)
		a.canvas.draw_arc(shape[1],shape[2],0,TAU,24,a.color("brassDeep",opacity),5.5,true)
		a.canvas.draw_arc(shape[1],shape[2],0,TAU,24,a.color("brass",opacity),3,true)
		a.circle(Vector2(-38,0),width*1.25,"brass",opacity);a.ring(Vector2(-38,0),width*1.25,"brassDeep",1.4,opacity)
	a.canvas.draw_set_transform(Vector2.ZERO)

func hands(pose:Dictionary,ink:float) -> void:
	# Intro: the hands sweep in from a full turn back; death: they unwind and fall.
	var lead:float=(1-ease(pose.rise,0.35))*TAU*1.5
	var fall:float=pose.crack*pose.crack*TAU*2.2
	var minute:float=m.minute-lead+fall;var hour:float=m.hour-lead*0.5-fall*0.6
	var opacity:float=ink*clampf(pose.rise*1.6,0,1)
	var rate:float=0.0 if a.g.reduced else 1.6 if a.g.time<a.d.shift_until else 0.5 if pose.haste>0 else -0.4 if pose.rewind>0 else 0.0
	for pass_shadow in [true,false]:
		if rate!=0 and not pass_shadow:
			for step in range(1,4):
				hand(minute-rate*step*0.09,235,7,opacity*0.22/step,false)
		hand(hour,155,10,opacity,pass_shadow)
		hand(minute,235,7,opacity,pass_shadow)

## Crystal core under six brass petals. Shielded: petals closed, spring arc;
## stalled: petals fold back, the gem blooms and a countdown ring runs.
func core(pose:Dictionary,ink:float) -> void:
	var at:Vector2=m.center;var open:float=pose.open
	var spring:float=clampf(a.d.fight.data.get("spring",100.0)/100.0,0,1)
	if not m.exposed() and not pose.dying:
		a.canvas.draw_arc(at,46,-PI/2,-PI/2+TAU*spring,48,a.color("brassDeep",0.5*ink),5,true)
		a.canvas.draw_arc(at,46,-PI/2,-PI/2+TAU*spring,48,a.color("gem" if a.g.time>=m.refill_until else "ward",0.85*ink),2.5,true)
	if m.exposed():
		a.glow(at,90+12*sin(motion*6),"gem",0.55*open*ink)
		a.countdown(at,52,"weak",m.jammed_at,m.stunned_until)
	a.circle(at+Vector2(3,5),37,"face",0.5*ink)
	a.circle(at,36,"gemDeep",ink);a.circle(at,28+open*4,"gem",ink)
	for facet in range(6):
		var angle:float=facet*TAU/6+motion*0.3
		a.line(at+Vector2.from_angle(angle)*6,at+Vector2.from_angle(angle)*(26+open*4),"gemDeep",1.2,0.55*ink)
	a.circle(at+Vector2(-9,-10),7,"stop",0.5*ink)
	for petal in range(6):
		var angle:float=petal*TAU/6+PI/6+(motion*0.2 if not m.exposed() else 0.0)
		var dir:=Vector2.from_angle(angle);var side:=dir.orthogonal()
		var reach:float=lerpf(10,40,open)
		var base:=at+dir*reach
		a.polygon(PackedVector2Array([base-side*11,base+dir*(30-open*12),base+side*11,base-dir*4]),"brass","brassDeep",1.4,ink*(1-open*0.25))
	a.ring(at,36,"weak" if m.exposed() else "rim",2,ink)
	var strike:float=1-clampf((t-m.struck_at)/0.3,0,1)
	if strike>0:a.glow(at,70,"stop",strike*0.8);a.ring(at,40+(1-strike)*40,"stop",3,strike)
	var ping:float=1-clampf((t-m.pinged_at)/0.25,0,1)
	if ping>0:a.ring(at,36+(1-ping)*14,"rim",2,ping*ink)
	var ignite:float=smoothstep(0.75,0.9,pose.rise)*(1-smoothstep(0.9,1.0,pose.rise))
	if ignite>0:a.glow(at,160,"gem",ignite*0.8);a.ring(at,40+ignite*80,"gem",2,ignite)
	var burst:float=1-clampf((t-m.jammed_at)/0.6,0,1)
	if burst>0 and m.exposed():a.ring(m.jam_point,20+(1-burst)*70,"gem",3,burst);a.ring(at,40+(1-burst)*240,"gem",4,burst*0.7)

func gear_art(gear:Dictionary,ink:float) -> void:
	var at:Vector2=gear.position
	a.circle(at+Vector2(4,6),36,"face",0.4*ink)
	a.cog(at,34,10,gear.angle,true)
	a.circle(at,20,"face",ink)
	for spoke in range(3):a.line(at,at+Vector2.from_angle(gear.angle+spoke*TAU/3+PI/3)*20,"brassDeep",3,ink)
	a.circle(at,5,"brass",ink)
	var key:String="weak" if gear.jammed else "gem"
	var pulse:float=1.0 if gear.jammed else 0.65+0.35*sin(motion*5)
	a.canvas.draw_arc(at,42,gear.angle-0.6,gear.angle+0.6,16,a.color(key,0.25*pulse*ink),10,true)
	a.canvas.draw_arc(at,42,gear.angle-0.6,gear.angle+0.6,16,a.color(key,pulse*ink),3,true)
	var dir:=Vector2.from_angle(gear.angle)
	if gear.jammed:
		for sign in [-1,1]:a.line(at+dir.rotated(sign*0.6)*12,at-dir.rotated(sign*0.6)*12,"weak",3,ink)
	else:a.polygon(PackedVector2Array([at+dir*48,at+dir*58+dir.orthogonal()*7,at+dir*58-dir.orthogonal()*7]),"gem","",1,pulse*ink)

func props(pose:Dictionary,ink:float) -> void:
	var move:Dictionary=m.move
	if move.is_empty():return
	var live:float=clampf((t-move.start)/maxf(0.01,move.live-move.start),0,1)
	match move.id:
		"stop":
			var at:Vector2=move.target;var dir:Vector2=(m.center-at).normalized()
			a.canvas.draw_dashed_line(at,m.center,a.color("stop",0.4*ink),1.5,8)
			a.glow(at,46,"stop",0.4*ink)
			a.line(at,at+dir*26,"brassDeep",6,ink);a.line(at,at+dir*26,"brass",3,ink)
			var spin:float=motion*2.5
			for lobe in range(3):a.circle(at-dir*4+Vector2.from_angle(spin+lobe*TAU/3)*9,8,"brass",ink)
			a.circle(at-dir*4,6,"face",ink);a.ring(at-dir*4,17,"brassDeep",1.5,ink)
			a.countdown(at,28,"stop",move.start,move.end)
		"toll":
			var at:Vector2=a.d.model.bell_point()
			var sway:float=0.0 if a.g.reduced else sin((t-move.start)*(1.7 if a.d.rage else 1.3))*0.25
			a.line(Vector2(at.x,at.y-60),at+Vector2(0,-26),"brassDeep",2,0.6*ink)
			a.canvas.draw_set_transform(at,sway)
			var body:=PackedVector2Array([Vector2(-29,20),Vector2(-21,4),Vector2(-18,-14),Vector2(-10,-25),Vector2(10,-25),Vector2(18,-14),Vector2(21,4),Vector2(29,20)])
			a.circle(Vector2(4,6),28,"face",0.35*ink)
			a.polygon(body,"brass","brassDeep",2,ink)
			a.line(Vector2(-30,20),Vector2(30,20),"brassDeep",5,ink);a.line(Vector2(-14,-12),Vector2(-18,10),"handEdge",2,0.5*ink)
			a.circle(Vector2(sin(motion*7)*6,27),5,"brassDeep",ink)
			a.canvas.draw_set_transform(Vector2.ZERO)
			for rung in range(3):a.circle(at+Vector2(-16+rung*16,-44),4.5,"weak" if rung<int(move.rung) else "brassDeep",ink)
			a.countdown(at,42,"stop",move.start,move.end)
		"pendulum":
			var at:Vector2=a.d.model.bob_point();var dir:Vector2=(at-m.center).normalized()
			var needed:int=4 if a.d.rage else 3
			a.line(m.center+dir*48,at-dir*34,"brassDeep",8,ink*live);a.line(m.center+dir*48,at-dir*34,"brass",4,ink*live)
			a.circle(at+Vector2(4,6),33,"face",0.4*ink)
			a.circle(at,33,"brass",ink*live);a.ring(at,33,"brassDeep",2,ink*live)
			a.circle(at,20,"gemDeep",ink*live);a.circle(at,14,"gem",ink*live);a.circle(at+Vector2(-5,-6),4,"stop",0.6*ink)
			for pip in range(needed):
				var angle:float=-PI/2+(pip-(needed-1)/2.0)*0.45
				a.canvas.draw_arc(at,41,angle-0.16,angle+0.16,8,a.color("weak" if pip<int(move.hits) else "brassDeep",ink),4,true)
			a.countdown(at,48,"stop",move.start,move.end)
		"rewind":
			for arc in range(3):
				var start:float=-motion*2.4+arc*TAU/3
				a.canvas.draw_arc(m.center,70,start,start+1.4,20,a.color("ghost",0.7*ink),3,true)
				var tip:Vector2=m.center+Vector2.from_angle(start)*70;var back:Vector2=Vector2.from_angle(start).orthogonal()
				a.polygon(PackedVector2Array([tip+back*9,tip+Vector2.from_angle(start)*7,tip-Vector2.from_angle(start)*7]),"ghost","",1,0.8*ink)
			a.countdown(m.center,62,"ghost",move.start,move.end)
		"haste":
			if pose.haste<=0:return
			for dash in range(24):
				var angle:float=motion*3.2+dash*TAU/24
				a.canvas.draw_arc(m.center,212,angle,angle+0.12,4,a.color("gem",0.45*ink),2.5,true)
		"midnight":
			for seal in range(3):
				var at:Vector2=m.center+Vector2.from_angle(-PI/2+(seal-1)*0.5)*-96
				var hit:bool=seal<int(move.hits)
				a.circle(at,10,"weak" if hit else "face",ink);a.ring(at,10,"weak",2,ink)
			a.countdown(m.center,76,"weak",move.start,move.end)
			a.text("%d / 12" % int(move.rung),m.center+Vector2(0,-118),14,"weak")
