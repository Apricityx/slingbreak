extends RefCounted
## World-space telegraphs and aftermath. Never advances gameplay or random state.
const Rig=preload("res://src/render/abyss_rig.gd")
const Pattern=preload("res://src/bosses/eye_pattern.gd")

func trace(a:RefCounted,points:PackedVector2Array,key:String,opacity:float=1,width:float=1.5) -> void:
	if points.size()<2:return
	a.canvas.draw_polyline(points,a.color(key,opacity*0.12),width+4,true)
	a.canvas.draw_polyline(points,a.color(key,opacity),width,true)

func rune(a:RefCounted,at:Vector2,angle:float,size:float,opacity:float,key:String="shield") -> void:
	var dir:=Vector2.from_angle(angle);var n:=dir.orthogonal()
	trace(a,PackedVector2Array([at-dir*size,at+n*size*0.6,at+dir*size,at-n*size*0.6,at-dir*size]),key,opacity)
	a.line(at-dir*size*0.4,at+dir*size*0.4,"sclera",1,opacity*0.8)

func paint(a:RefCounted,front:bool) -> void:
	var m:RefCounted=a.m;var g:RefCounted=a.g;var d:RefCounted=a.d
	var t:float=a.t;var at:Vector2=m.center
	var pose:=Rig.pose(g)
	var motion:float=0 if g.reduced else t
	if not front:return
	var eyes:Array=[at]
	if m.move.get("id")=="mirage":eyes=[Vector2(170,Rig.CENTER.y),Vector2(610,Rig.CENTER.y)]
	if d.dying_at>=0:
		var collapse:float=t-d.dying_at
		for i in range(12 if g.reduced else 24):
			var k:float=clampf(collapse/1.3,0,1)
			var dir:=Vector2.from_angle(i*2.399+k*0.3)
			var p:Vector2=at+Vector2(dir.x*150,dir.y*65)*lerpf(1,0.1,k*k)
			a.line(p,p-dir*8,"shield",1.5,sin(k*PI)*0.6)
	for brick in g.bricks:
		if brick.type!="anchor" or d.busy:continue
		var socket:=at+Vector2(-110 if brick.x<390 else 110,62)
		var chain:PackedVector2Array=a.bezier(brick.position,(brick.position+socket)/2+Vector2(0,35),socket)
		for i in range(1,chain.size()):
			a.line(chain[i-1],chain[i],"chain",1.2,(0.12 if m.exposed() else 0.32)*pose.opening)
		if not m.exposed():
			var travel:float=fposmod(motion*0.35+brick.x/780,1)
			a.circle(chain[int(travel*24)],3,"shield",0.9)
	for watcher in m.watchers:
		if d.busy or not m.watchers_active():continue
		var open:bool=not watcher.blind and fposmod(g.time-watcher.born,2.6)<2.6*0.45
		a.ellipse(watcher.position,Vector2(25,13 if open else 3),"crack",true)
		a.ellipse(watcher.position,Vector2(25,13 if open else 3),"shield",false,1.5)
		if open:a.ellipse(watcher.position,Vector2(4,10),"weak",true)
	for well in m.wells:
		a.circle(well.position,65,"well",0.7)
		for i in range(3):
			a.canvas.draw_arc(well.position,26+i*15,motion+i,motion+i+PI*1.4,32,a.color("wellRim",0.6),2,true)
	var move:Dictionary=m.move
	if move.is_empty():return
	var progress:float=clampf((g.time-move.start)/(move.end-move.start),0,1)
	match move.id:
		"orbit":
			for b in g.bricks:
				if b.flags.get("orbit",false):
					var angle:float=(g.time-move.start)*(1.2 if d.rage else 0.8)+b.flags.slot*TAU/b.flags.count
					var trail:=PackedVector2Array()
					for i in range(9):trail.append(at+Vector2(cos(angle-i*0.045)*132,sin(angle-i*0.045)*38+14))
					trace(a,trail,"weak" if b.flags.get("heart",false) else "shield",0.7,2)
				if b.flags.get("heart",false):
					rune(a,b.position,PI/2,24,0.95,"weak")
		"summon":
			var p:Vector2=move.target
			var assemble:float=smoothstep(0,0.65,g.time-move.start)
			a.glow(p,68,"iris",0.25);a.countdown(p,46,"weak",move.start,move.end)
			for i in range(6):
				var angle:float=i*TAU/6+motion*0.16
				var v:=Vector2.from_angle(angle)
				var radius:float=lerpf(78,36,assemble)
				rune(a,p+v*radius,angle,7,assemble)
				trace(a,PackedVector2Array([p+v*29,p+v.rotated(TAU/3)*29]),"shield",assemble*0.85,2)
				var k:float=fposmod((g.time-move.start)*0.7+i/6.0,1)
				a.line(p+v*lerpf(70,15,k),p+v*lerpf(78,23,k),"sclera",1.5,sin(k*PI)*0.8)
			rune(a,p,-PI/2,12,0.9)
			a.text("击破法阵",p+Vector2(0,68),14,"text")
		"tear":
			for tear in move.tears:
				if tear.state!="fall":continue
				var lane:float=smoothstep(move.start,move.live,g.time)
				a.line(Vector2(tear.x,230),Vector2(tear.x,850),"shield",1,0.16*lane)
				a.line(Vector2(tear.x-14,846),Vector2(tear.x+14,846),"weak",2,0.6*lane)
				if g.time<tear.at:
					# Gathering at the lower lid: a bead swells before it drops.
					var k:float=clampf((g.time-move.start)/maxf(0.01,tear.at-move.start),0,1)
					var bead:Vector2=at+Vector2(float(tear.side)*34,40+k*6)
					a.glow(bead,14+k*10,"iris",0.3*k);a.circle(bead,2+k*4,"sclera",0.5+k*0.4)
					continue
				var p:Vector2=m.tear_point(tear)
				var fall:float=g.time-tear.at
				for side in [-1,1]:
					var wake:=PackedVector2Array()
					for i in range(10):
						var k:float=i/9.0
						wake.append(p+Vector2(side*(6+k*8)+sin(motion*6+k*4)*2,-k*minf(80,fall*150)))
					trace(a,wake,"shield",0.55,1.5)
				a.glow(p,36,"iris",0.42)
				a.polygon(PackedVector2Array([p-Vector2(0,24),p+Vector2(13,3),p+Vector2(0,16),p+Vector2(-13,3)]),"iris","shield",2)
				a.line(p-Vector2(0,15),p+Vector2(0,9),"sclera",2)
				a.countdown(p,22,"weak",tear.at,tear.at+Pattern.TEAR_FALL)
		"gaze":
			gaze(a,move)
		"mirage":
			var emerge:float=1-smoothstep(0.15,0.9,g.time-move.start)
			for p in eyes:
				a.countdown(p,70,"shield",move.start,move.end)
				for i in range(5):
					var y:float=-32+i*16
					var side:float=-1 if p.x<390 else 1
					a.line(p+Vector2(side*80,y),p+Vector2(side*(80+emerge*65),y),"shield",1.5,emerge*0.7)
			if emerge>0:
				for i in range(5):
					var k:float=(g.time-move.start)*1.6+i*0.1
					if k<1:rune(a,Vector2(390,92).lerp(eyes[i%2],k),0,6,emerge)
		"doom":
			a.glow(at,170,"weak",0.3+progress*0.3)
			a.countdown(at,76,"weak",move.live,move.end)
			# A compact accretion silhouette gives the final spell a readable centre
			# of gravity. It is drawn as a few arcs, not a large persistent ring.
			var charge_k:float=smoothstep(0.0,0.7,progress)
			var hole_radius:float=18.0+charge_k*13.0
			a.canvas.draw_circle(at,hole_radius+7,Color("#241038",0.55+charge_k*0.2))
			a.canvas.draw_circle(at,hole_radius,Color("#070512",0.92))
			for ring in range(3):
				var radius:float=31.0+ring*17.0-charge_k*ring*4.0
				var start:float=motion*(1.4+ring*0.35)+ring*2.1
				a.canvas.draw_arc(at,radius,start,start+PI*(1.15+charge_k*0.35),18,Color("#ff5b91",0.72-charge_k*ring*0.12),2.2,true)
				a.canvas.draw_arc(at,radius,start+PI,start+PI+PI*(0.72+charge_k*0.2),14,Color("#b38cff",0.55),1.4,true)
			for i in range(5 if g.reduced else 9):
				var orbit:float=motion*(1.8+i*0.08)+i*0.9
				var radius:float=55.0+fposmod(i*19.0-progress*70.0,58.0)
				var p:Vector2=at+Vector2(cos(orbit),sin(orbit)*0.56)*radius
				a.line(p,p-Vector2.from_angle(orbit)*lerpf(4,13,charge_k),"sclera",1.5,(0.25+charge_k*0.65))
			for i in range(18 if not g.reduced else 6):
				var angle:float=i*2.399
				var distance:float=80+fposmod(i*23-motion*90,180)
				var dir:=Vector2.from_angle(angle)
				a.line(at+dir*distance,at+dir*(distance+12),"weak",2,progress*0.8)
			for i in range(3):
				var p:=at+Vector2((i-1)*23,103)
				a.polygon(PackedVector2Array([p+Vector2(0,-6),p+Vector2(6,0),p+Vector2(0,6),p+Vector2(-6,0)]),"sclera" if i<move.hits else "crack","weak")
			for i in range(6):
				var angle:float=i*TAU/6
				var radius:float=90-progress*35
				rune(a,at+Vector2(cos(angle)*radius,sin(angle)*radius*0.6),angle,5+progress*3,0.4+progress*0.5,"weak")
			a.text("终焉 · 三击打断",at+Vector2(0,135),15,"text")

func gaze(a:RefCounted,move:Dictionary) -> void:
	var m:RefCounted=a.m;var g:RefCounted=a.g;var t:float=g.time;var at:Vector2=m.center
	var cool:float=1-smoothstep(move.active_end,move.end,t)
	var shown:float=smoothstep(move.start,move.start+0.4,t)*cool
	var from:float=PI/2-move.dir*Pattern.ARC;var to:float=PI/2+move.dir*Pattern.ARC
	if t<move.live:
		# The whole sweep is announced: a dashed fan with chevrons along the arc.
		var k:float=clampf((t-move.start)/(move.live-move.start),0,1)
		for i in range(13):
			var angle:float=lerpf(from,to,i/12.0);var dir:=Vector2.from_angle(angle)
			var end:Vector2=Pattern.beam_end(at,angle);var length:float=at.distance_to(end)
			for j in range(int((length-80)/46)):
				var q:Vector2=at+dir*(80+j*46)
				a.line(q,q+dir*18,"weak",1.5,shown*(0.16+0.22*float(i==0)))
		var ring:=PackedVector2Array()
		for i in range(33):ring.append(at+Vector2.from_angle(lerpf(from,to,i/32.0))*300)
		trace(a,ring,"weak",shown*0.55,2)
		for i in range(5):
			var angle:float=lerpf(from,to,fposmod(i/5.0+(0.0 if g.reduced else t*0.35),1))
			var q:Vector2=at+Vector2.from_angle(angle)*300;var tangent:=Vector2.from_angle(angle+PI/2*move.dir)
			var n:=tangent.orthogonal()
			trace(a,PackedVector2Array([q-tangent*6+n*7,q+tangent*5,q-tangent*6-n*7]),"weak",shown*0.85,2.5)
		var start_dir:=Vector2.from_angle(from)
		trace(a,PackedVector2Array([at+start_dir*70,Pattern.beam_end(at,from)]),"weak",shown*(0.4+0.4*k),2.5)
		# Counter ring tightens onto the real 43 px pupil collider.
		var pulse:float=0.6+0.4*sin(t*(8+10*k))
		var radius:float=lerpf(78,Rig.PUPIL_RADIUS+4,smoothstep(0,0.6,k))
		a.canvas.draw_arc(at,radius,0,TAU,40,a.color("text",shown*0.85*pulse),2.5,true)
		for i in range(4):
			var dir:=Vector2.from_angle(i*TAU/4+PI/4)
			a.line(at+dir*(radius+4),at+dir*(radius+14),"text",2.5,shown*pulse)
	else:
		# Scorched swept arc: what the beam has already crossed.
		var now:float=m.beam_angle()
		var swept:=PackedVector2Array([at])
		for i in range(17):
			var angle:float=lerpf(from,now,i/16.0);swept.append(Pattern.beam_end(at,angle))
		if swept.size()>=3:a.canvas.draw_colored_polygon(swept,a.color("weak",0.06*cool))
		for i in range(1,swept.size()):a.line(swept[i-1],swept[i],"weak",2,0.45*cool)
