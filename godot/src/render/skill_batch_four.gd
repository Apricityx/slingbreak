extends RefCounted
## Four semantic one-shots, rendered from immutable event snapshots. No textures,
## gameplay queries, node allocation or RNG; bounded geometry on the visual clock.
static func paint(canvas:CanvasItem,event:Dictionary,clock:float,reduced:bool,dark:bool) -> void:
	var age:float=maxf(0,clock-event.born)
	var t:float=clampf(age/event.max,0,1)
	var fade:float=1-smoothstep(0.22,1.0,t)
	if fade<0.005:return
	var p:Vector2=event.position
	var grow:float=1-exp(-age*25)
	var flash:float=exp(-age*35)
	var motion:=0.3 if reduced else 1.0
	var ink:=Color(event.color,fade)
	var light:=Color(event.accent,fade)
	var edge:=Color("#dce7cf" if dark else "#35432f",fade*0.92)
	match event.id:
		"treasury":
			# A rupturing faceted vault: opposed walls open, ingots fan down from
			# the real core payout, then disperse rather than scaling a coin icon.
			for sign_value in [-1.0,1.0]:
				var x:float=sign_value*(8+grow*16*motion)
				var panel:=PackedVector2Array([p+Vector2(x,-20),p+Vector2(x+sign_value*13,-9),p+Vector2(x+sign_value*10,17),p+Vector2(x,25)])
				canvas.draw_colored_polygon(panel,Color(ink,fade*0.3))
				canvas.draw_polyline(panel,edge,3,true)
				canvas.draw_line(panel[0],panel[3],light,2,true)
			for i in range(4 if reduced else 9):
				var n:float=i/float(3 if reduced else 8)
				var axis:=Vector2.from_angle(PI*0.16+n*PI*0.68)
				var q:=p+axis*(12+grow*(32+n*11)*motion)+Vector2(0,age*age*75*motion)
				var size:float=(4+i%3)*(1-t*0.45)
				var facet:=PackedVector2Array([q+Vector2(0,-size),q+Vector2(size*1.3,0),q+Vector2(0,size),q-Vector2(size*1.3,0)])
				canvas.draw_colored_polygon(facet,ink)
				canvas.draw_polyline(PackedVector2Array([facet[3],facet[0],facet[1]]),light,2,true)
				canvas.draw_line(facet[1],facet[2],edge,1.5,true)
			canvas.draw_line(p+Vector2(0,-16),p+Vector2(0,24+grow*10),Color(1,0.97,0.7,flash),7,true)
		"bargain":
			# Twin compression rails converge into a forging seam, which sheds
			# short upward chips. Sequential teeth make the discount feel earned.
			for sign_value in [-1.0,1.0]:
				var x:float=sign_value*(28-grow*20+t*12*motion)
				var rail:=PackedVector2Array([p+Vector2(x,-31),p+Vector2(x+sign_value*12,-22),p+Vector2(x+sign_value*12,19),p+Vector2(x,27)])
				canvas.draw_polyline(rail,edge,4,true);canvas.draw_polyline(rail,ink,2,true)
				for j in range(3):
					var y:float=-17+j*15
					canvas.draw_line(p+Vector2(x,y),p+Vector2(x-sign_value*(4+grow*4),y-4),light,2,true)
			var height:float=(12+grow*29)*(1-smoothstep(0.35,1,t))
			canvas.draw_line(p+Vector2(0,height*0.5),p-Vector2(0,height),edge,6,true)
			canvas.draw_line(p+Vector2(0,height*0.5),p-Vector2(0,height),light,3,true)
			for i in range(3 if reduced else 6):
				var axis:=Vector2.from_angle(-PI*0.88+i*PI*0.76/float(2 if reduced else 5))
				var q:=p+axis*(12+grow*37*motion)+Vector2(0,age*age*30*motion)
				canvas.draw_line(q,q+axis*(5*(1-t)),light,2.4,true)
			canvas.draw_circle(p,4+flash*8,Color(1,1,0.85,flash))
		"resonance":
			# Four open harmonic petals contract onto the newly revealed core;
			# they never become a fixed-radius ring or cover the core silhouette.
			for i in range(4):
				var axis:=Vector2.from_angle(PI/4+i*PI/2)
				var side:=axis.orthogonal()
				var reach:float=lerpf(68,29,grow*motion+(1-motion)*0.6)
				var points:=PackedVector2Array()
				for j in range(9):
					var u:float=j/8.0
					points.append(p+axis*(reach+sin(u*PI)*14*(1-t))+side*((u-0.5)*38*(1-t*0.5)))
				canvas.draw_polyline(points,edge,4,true);canvas.draw_polyline(points,ink,2.4,true)
				if not reduced:
					var q:Vector2=p+axis*(78-grow*49)+side*(8*sin(i+event.seed))
					canvas.draw_line(q,q+axis*6,light,2,true)
				canvas.draw_line(p+axis*23,p+axis*(27+flash*14),light,2,true)
			canvas.draw_circle(p,4+flash*10,Color(0.94,1,0.8,flash*0.8))
		"corehunter":
			# Local curved streamlets indicate the true captured target without
			# a 320px beam. The target gets separate inward-moving brackets.
			var target:Vector2=event.target
			var axis:Vector2=p.direction_to(target)
			var side:=axis.orthogonal()
			var reach:float=minf(78,p.distance_to(target)*0.48)
			for i in range(2 if reduced else 3):
				var points:=PackedVector2Array()
				for j in range(9):
					var u:float=lerpf(t*0.65,0.25+grow*0.75,j/8.0)
					points.append(p+axis*(u*reach)+side*((i-1)*13*(1-u)+sin(u*PI)*16*motion))
				canvas.draw_polyline(points,edge,3.5,true);canvas.draw_polyline(points,light,1.7,true)
			for sign_value in [-1.0,1.0]:
				var q:Vector2=target+side*sign_value*(29+(1-grow)*12*motion)
				canvas.draw_polyline(PackedVector2Array([q-axis*9+side*sign_value*5,q,q+axis*9+side*sign_value*5]),ink,2.5,true)
			canvas.draw_circle(p,3+flash*6,Color(0.95,1,0.85,flash))
