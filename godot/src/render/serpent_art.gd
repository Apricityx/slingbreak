extends RefCounted
## 星渊巨蟒 vector layer. Behind the masonry: the star river the serpent swims
## in. In front: gates, weak scales, the tether, sparks, the aim line and the
## head, each painted from its collider; envelopes come from SerpentSurface.pose().
const Surface=preload("res://src/render/serpent_surface.gd")
const Serpent=preload("res://src/bosses/serpent.gd")
var a:RefCounted
var m:RefCounted
var t:float
var motion:float

func paint(art:RefCounted,front:bool) -> void:
	a=art;m=a.m;t=a.t;motion=0.0 if a.g.reduced else t
	if front:layer(Surface.pose(a.g))
	else:river()
	# boss_art owns this painter; holding it back would form a leaking cycle.
	a=null;m=null

## Starfield and a soft nebula band along the track the serpent swims in.
func river() -> void:
	for index in range(70):
		var at:=Vector2(390+sin(index*127.1)*375,480+sin(index*311.7)*430)
		a.circle(at,1.0+absf(sin(index*3.1))*1.3,"sky",0.25+absf(sin(motion*0.8+index))*0.35)
	var line:=PackedVector2Array()
	for index in range(121):line.append(Serpent.at(Serpent.track_length()*index/120.0))
	for spec in [[96,"nebula",0.07],[64,"nebula2",0.06],[34,"nebula",0.1],[3,"glow",0.18]]:
		a.canvas.draw_polyline(line,a.color(spec[1],spec[2]),spec[0],true)
	for index in range(48):
		var s:float=fposmod(index*Serpent.track_length()/48.0+motion*22,Serpent.track_length())
		var at:Vector2=Serpent.at(s)+Serpent.normal_at(s)*sin(index*7.3)*30
		a.circle(at,1.2+absf(sin(index*1.7))*1.2,"star",0.25+0.3*absf(sin(motion*1.6+index)))

func layer(pose:Dictionary) -> void:
	var fade:float=1-smoothstep(0.6,1.0,pose.dissolve)
	if fade<=0.01:return
	for snake in m.ghosts:gates(snake,true)
	for snake in m.snakes:gates(snake,false)
	scales(pose,fade)
	tether()
	for item in m.swallowed:
		var k:float=clampf((a.g.time-item.at)/0.5,0,1)
		var mouth:Vector2=m.focus()
		var at:Vector2=item.from.lerp(mouth,k*k)
		a.circle(at,9*(1-k)+2,"star",1-k);a.glow(at,24,"star",0.5*(1-k))
	for spark in m.sparks:
		var tail:Vector2=spark.position-spark.velocity.normalized()*22
		a.canvas.draw_line(tail,spark.position,a.color("spark",0.6),4,true)
		a.circle(spark.position,4,"spark");a.glow(spark.position,14,"spark",0.4)
	aim(pose)
	for snake in m.snakes:head(snake,pose,fade*snake.fade)

## Entry gates drink the body; exit gates pulse and count down to emergence.
func gates(snake:Dictionary,ghost:bool) -> void:
	var gate:Dictionary=snake.gate
	if gate.is_empty():return
	var age:float=a.g.time-gate.born
	if gate.entry and m.tail_v(snake)<gate.a:
		var close:float=clampf((m.tail_v(snake)-(gate.a-160))/160,0,1) if not ghost else clampf((age-1.6)/0.5,0,1)
		disc(Serpent.at(gate.a*snake.dir),clampf(age/0.3,0,1)*(1-close),false)
	if gate.exit:
		var exit:float=gate.a+gate.u
		var open:float=clampf(age/0.4,0,1)
		if m.tail_v(snake)>=exit-80:open*=clampf((exit-m.tail_v(snake))/80,0,1)
		var point:=Serpent.at((gate.a+gate.j)*snake.dir)
		disc(point,open,true)
		if snake.s<exit and gate.kind=="dive":
			var eta:float=(exit-snake.s)/maxf(1,m.base_speed()*snake.speed)
			a.canvas.draw_arc(point,46,-PI/2,-PI/2+TAU*clampf(eta/2.2,0,1),48,a.color("weak"),3,true)

func disc(point:Vector2,k:float,exit:bool) -> void:
	if k<=0.01:return
	var r:float=34*k
	a.glow(point,r*2.2,"glow" if exit else "nebula2",0.5)
	a.circle(point,r,"portal",0.95)
	var spin:float=motion*(3.0 if exit else -2.2)
	for index in range(3):
		var start:float=spin+index*TAU/3
		a.canvas.draw_arc(point,r*0.72,start,start+1.6,16,a.color("glow",0.75),2,true)
		a.canvas.draw_arc(point,r*0.42,start+0.8,start+2.0,12,a.color("star",0.6),1.5,true)
	a.ring(point,r,"glow",2.5)
	if exit:a.ring(point,r+6+3*sin(motion*7),"star",1.2,0.6)

func scales(pose:Dictionary,fade:float) -> void:
	for brick in m.scales():
		if brick.position.x<-100:continue
		var snake:Dictionary=m.snakes[0]
		var tangent:=Vector2.RIGHT
		for each in m.snakes:
			var k:int=(int(brick.flags.segment)-each.first)*each.step
			var n:int=each.points.size()
			if k>=0 and k<n:
				snake=each;tangent=(each.points[maxi(k-1,0)]-each.points[mini(k+1,n-1)]).normalized();break
		var pulse:float=0.7+0.3*sin(motion*5+brick.flags.segment)
		a.glow(brick.position,30,"weak",0.45*pulse*fade)
		a.canvas.draw_set_transform(brick.position,tangent.angle())
		var w:=16.0;var h:=12.0
		var shape:=PackedVector2Array([Vector2(w,0),Vector2(0,-h),Vector2(-w*0.8,0),Vector2(0,h)])
		a.polygon(shape,"weak","dark",2,fade)
		a.polygon(PackedVector2Array([Vector2(w-4,0),Vector2(0,-h+3),Vector2(-3,-1)]),"spark","",1,0.55*fade)
		var lost:float=1-brick.hp/maxf(1,brick.max_hp)
		if lost>0.05:
			a.line(Vector2(-7,-3),Vector2(1,2),"dark",1.6,fade);a.line(Vector2(1,2),Vector2(6,-5),"dark",1.6,fade)
		if lost>0.45:a.line(Vector2(1,2),Vector2(3,9),"dark",1.6,fade);a.line(Vector2(-7,-3),Vector2(-10,4),"dark",1.4,fade)
		if brick.flash>0:a.polygon(shape,"spark","",1,brick.flash*2)
		a.canvas.draw_set_transform(Vector2.ZERO)
		if pose.stun>0:a.ring(brick.position,20,"weak",1.5,0.4*fade)

## Twin tether: a shimmering filament through the knot, the cut target.
func tether() -> void:
	var knot:Vector2=m.knot()
	if is_nan(knot.x):return
	for snake in m.snakes:
		var from:Vector2=snake.points[0]
		var side:Vector2=(knot-from).orthogonal().normalized()
		var line:=PackedVector2Array()
		for index in range(21):
			var k:float=index/20.0
			line.append(from.lerp(knot,k)+side*sin(k*PI*3-motion*9)*5*sin(k*PI))
		a.canvas.draw_polyline(line,a.color("tether",0.35),8,true)
		a.canvas.draw_polyline(line,a.color("tether",0.9),2.5,true)
	a.glow(knot,30,"tether",0.5)
	a.canvas.draw_set_transform(knot,motion*2)
	a.polygon(PackedVector2Array([Vector2(9,0),Vector2(0,-9),Vector2(-9,0),Vector2(0,9)]),"star","tether",2)
	a.canvas.draw_set_transform(Vector2.ZERO)
	# A head hit opens the 0.8 s window for the other head.
	for index in range(2):
		var hit:float=a.g.time-m.snakes[index].hit_at
		if hit<0.8:
			var other:Vector2=m.snakes[1-index].points[0]
			a.canvas.draw_arc(other,m.head_radius(m.snakes[1-index])+14,-PI/2,-PI/2+TAU*(1-hit/0.8),40,a.color("weak"),3,true)

## Coil: a dashed strike line from the reared head to the launcher.
func aim(pose:Dictionary) -> void:
	if m.move.get("stage","")!="aim" or m.snakes.is_empty() or m.snakes[0].hidden[0]==1:return
	var head:Vector2=m.snakes[0].points[0]
	var target:Vector2=m.move.target
	var k:float=clampf((a.g.time-m.move.at)/(1.1 if a.g.bosses.rage else 1.4),0,1)
	var tip:Vector2=head.lerp(target,0.15+0.85*k)
	a.canvas.draw_dashed_line(head,tip,a.color("weak",0.35+0.5*k),3,10,true,true)
	var direction:=(target-head).normalized()
	var wing:=direction.orthogonal()*10
	a.polygon(PackedVector2Array([tip+direction*12,tip-direction*6+wing,tip-direction*6-wing]),"weak","",1,0.4+0.6*k)
	a.ring(target,26-10*k,"weak",2,0.4+0.5*k)
	a.canvas.draw_arc(head,m.head_radius(m.snakes[0])+16,-PI/2,-PI/2+TAU*(1-k),48,a.color("weak"),3,true)
	a.glow(head,80,"weak",0.5*pose.heat)

## The skull, top-down: two jaw halves hinge open for devour and the strike.
func head(snake:Dictionary,pose:Dictionary,opacity:float) -> void:
	if opacity<=0.01 or snake.points.is_empty() or snake.hidden[0]==1:return
	var at:Vector2=snake.points[0]
	var stage:String=m.move.get("stage","")
	var forward:Vector2=Vector2.RIGHT
	if snake.points.size()>1 and snake.hidden[1]==0:forward=(at-snake.points[1]).normalized()
	if stage in ["aim","lunge"] and snake==m.snakes[0]:forward=forward.slerp((m.move.target-at).normalized(),0.6)
	if pose.dying:opacity*=0.6+0.4*absf(sin(t*31))
	var size:float=m.head_radius(snake)/27.0
	var angle:float=forward.angle()
	var jaw:=0.0
	if stage=="maw":jaw=0.55+0.25*sin(motion*7)
	elif stage=="lunge":jaw=0.8
	elif stage=="aim":jaw=0.15
	elif m.exposed():jaw=0.3
	elif pose.dying:jaw=0.6
	if stage=="dark":a.glow(at,64,"weak",0.65*pose.dark*opacity);a.ring(at,40+4*sin(motion*8),"weak",2,pose.dark*opacity)
	if stage=="maw":a.glow(at+forward*24*size,60,"star",0.5*opacity)
	var skull:=PackedVector2Array([Vector2(38,0),Vector2(30,-12),Vector2(14,-22),Vector2(-6,-26),Vector2(-24,-20),Vector2(-32,0),Vector2(-24,20),Vector2(-6,26),Vector2(14,22),Vector2(30,12)])
	var base:=Transform2D(angle,Vector2(size,size),0,at)
	a.canvas.draw_set_transform_matrix(Transform2D(angle,Vector2(size,size),0,at+Surface.SHADOW))
	a.polygon(skull,"dark","",1,0.3*opacity)
	a.canvas.draw_set_transform_matrix(base)
	if jaw>0.02:
		a.ellipse(Vector2(14,0),Vector2(10+20*jaw,4+12*jaw),"maw",true,2,opacity)
		for side in [-1,1]:
			for fang in range(2):
				var root:=Vector2(22-fang*12,side*(4+12*jaw))
				a.polygon(PackedVector2Array([root+Vector2(-3,0),root+Vector2(3,0),root+Vector2(0,-side*7)]),"belly","",1,opacity)
	for side in [-1,1]:
		var pivot:=Vector2(-18,0)
		a.canvas.draw_set_transform_matrix(base*Transform2D(side*jaw*0.42,pivot)*Transform2D(0,-pivot))
		var half:=PackedVector2Array()
		for point in [Vector2(40,side*1),Vector2(30,side*12),Vector2(14,side*22),Vector2(-6,side*26),Vector2(-24,side*20),Vector2(-32,side*1)]:half.append(point)
		a.polygon(half,"head","dark",2.5,opacity)
		# Plate seams and a pale lip along the jaw line.
		a.line(Vector2(-22,side*10),Vector2(20,side*8),"bodyLight",2,0.55*opacity)
		a.line(Vector2(30,side*11),Vector2(12,side*21),"belly",2,0.5*opacity)
		a.polygon(PackedVector2Array([Vector2(-20,side*17),Vector2(-46,side*30),Vector2(-30,side*6)]),"horn","dark",1.5,opacity)
		a.line(Vector2(-4,side*23),Vector2(16,side*17),"dark",3,opacity)
		var eye:="weak" if stage in ["aim","lunge","dark"] else "eye"
		a.ellipse(Vector2(6,side*15),Vector2(8,4.5),eye,true,2,opacity)
		if m.exposed():
			a.line(Vector2(2,side*12),Vector2(10,side*18),"dark",2,opacity);a.line(Vector2(10,side*12),Vector2(2,side*18),"dark",2,opacity)
		else:a.line(Vector2(7,side*12),Vector2(7,side*18),"dark",2,opacity)
		a.circle(Vector2(31,side*5),1.8,"dark",opacity)
	a.canvas.draw_set_transform_matrix(base)
	# Forehead gem: the stripe's light ends here and burns with the coil.
	a.polygon(PackedVector2Array([Vector2(-4,0),Vector2(-12,-5),Vector2(-22,0),Vector2(-12,5)]),"weak" if pose.heat>0.5 else "glow","dark",1.5,opacity)
	if snake.flash>0:a.polygon(skull,"belly","",1,snake.flash*0.6*opacity)
	a.canvas.draw_set_transform(Vector2.ZERO)
	if pose.stun>0 and snake==m.snakes[0]:
		for index in range(3):
			var phase:float=motion*3.6+index*TAU/3
			var star:=at+Vector2(cos(phase)*34,sin(phase)*13-44)*size
			a.canvas.draw_set_transform(star,phase)
			a.polygon(PackedVector2Array([Vector2(6,0),Vector2(1.5,-1.5),Vector2(0,-6),Vector2(-1.5,-1.5),Vector2(-6,0),Vector2(-1.5,1.5),Vector2(0,6),Vector2(1.5,1.5)]),"star","",1,pose.stun*opacity)
		a.canvas.draw_set_transform(Vector2.ZERO)
