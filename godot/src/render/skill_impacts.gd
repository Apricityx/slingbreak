extends RefCounted
## Local, one-shot material silhouettes. All coordinates are visual snapshots;
## no entity references, gameplay RNG, textures or per-impact nodes are needed.
static func paint(canvas:CanvasItem, event:Dictionary, clock:float, reduced:bool, dark:bool) -> void:
	var age:float=maxf(0,clock-event.born)
	var t:float=clampf(age/event.max,0,1)
	var fade:float=1-smoothstep(0.18,1.0,t)
	if fade<0.005:return
	var flash:float=exp(-age*38)
	var grow:float=1-exp(-age*24)
	var p:Vector2=event.position
	var ink:=Color(event.color,fade)
	var light:=Color(event.accent,fade)
	var edge:=Color("#e4f4ff" if dark else "#263546",fade*0.85)
	var motion:=0.3 if reduced else 1.0
	match event.id:
		"shatter":
			# Split crystal crown: faceted shards, never a large icy fireball.
			canvas.draw_circle(p,12+flash*9,Color(0.9,0.98,1,flash*0.85))
			for i in range(4 if reduced else 8):
				var angle:float=event.seed+i*2.39996
				var axis:=Vector2.from_angle(angle+age*2.0*motion)
				var travel:float=(12+i%3*6)*(1-exp(-age*10))*motion
				var center:=p+Vector2.from_angle(angle)*(10+travel)+Vector2(0,35*age*age*motion)
				var length:float=(9+i%3*3)*(0.7+grow*0.3)*(1-t*0.45)
				var tip:=center+axis*length
				var base:=center-axis*length*0.6
				var side:=axis.orthogonal()*length*0.35
				var shell:=PackedVector2Array([tip,center+side,base,center-side])
				canvas.draw_colored_polygon(shell,ink)
				canvas.draw_colored_polygon(PackedVector2Array([tip,center+side,base]),Color(0.75,0.94,1,fade*0.9))
				shell.append(tip);canvas.draw_polyline(shell,edge,1.4,true)
				canvas.draw_line(base,tip,Color(0.95,1,1,fade),1.3,true)
		"execute":
			# Two opposed blades close, cross, then separate into short cut edges.
			var direction:Vector2=event.direction
			for sign_value in [-1.0,1.0]:
				var axis:=direction.rotated(sign_value*(0.9-grow*0.4))
				var normal:=axis.orthogonal()
				var center:Vector2=p+normal*sign_value*(8*(1-grow)+t*13*motion)
				var reach:float=(22+grow*23)*(1-smoothstep(0.3,1.0,t)*0.65)
				var blade:=PackedVector2Array([center-axis*reach,center-normal*5,center+axis*reach,center+normal*5])
				canvas.draw_colored_polygon(blade,ink)
				canvas.draw_line(center-axis*reach,center+axis*reach,edge,4,true)
				canvas.draw_line(center-axis*reach,center+axis*reach,light,2,true)
			canvas.draw_circle(p,4+flash*8,Color(1,0.94,0.98,flash))
		"rage":
			# Three rising tongues are the three-kill beat; strength grows by tier.
			var size:float=event.strength
			canvas.draw_circle(p,8+flash*10,Color(1,0.91,0.62,flash*0.8))
			for i in range(3):
				var x:float=(i-1)*13
				var base:=p+Vector2(x,9-t*8*motion)
				var height:float=(28+(12 if i==1 else 0))*size*(0.7+grow*0.3)
				var tip:=base+Vector2((i-1)*5+sin(age*19+i*2)*5*motion,-height-t*14*motion)
				var flame:=PackedVector2Array([base+Vector2(-6,0),base+Vector2(-9,-height*0.4),tip,base+Vector2(7,-height*0.35),base+Vector2(6,0)])
				canvas.draw_colored_polygon(flame,ink)
				flame.append(flame[0]);canvas.draw_polyline(flame,edge,1.4,true)
				canvas.draw_colored_polygon(PackedVector2Array([base+Vector2(-3,0),tip.lerp(base,0.32),base+Vector2(3,0)]),light)
			if not reduced:
				for i in range(4):
					var ember:=p+Vector2(sin(event.seed+i*3.1)*25,-12-age*(45+i*12))
					canvas.draw_line(ember,ember+Vector2(0,4),light,2,true)
		"aftershock":
			# Jagged radial fault branches leave open gaps instead of a closed ring.
			canvas.draw_circle(p,9+flash*15,Color(1,0.88,0.6,flash*0.7))
			for i in range(4 if reduced else 6):
				var axis:=Vector2.from_angle(event.seed+i*TAU/(4 if reduced else 6))
				var normal:=axis.orthogonal()
				var reach:float=(65+i%3*15)*(0.18+0.82*grow)
				var points:=PackedVector2Array()
				var fault:=PackedVector2Array([p+axis*9,p+axis*reach*0.32+normal*7,p+axis*reach*0.55-normal*5,p+axis*reach])
				# Burn away the inner crack while the tip advances; no static spokes.
				var erase:float=smoothstep(0.12,0.9,t)*2.8
				var segment:int=mini(2,int(erase))
				points.append(fault[segment].lerp(fault[segment+1],erase-segment))
				for at in range(segment+1,4):points.append(fault[at])
				canvas.draw_polyline(points,edge,5*(1-t*0.6),true)
				canvas.draw_polyline(points,ink,3*(1-t*0.6),true)
				canvas.draw_polyline(points,light,1.2,true)
				var chip:=p+axis*(reach*0.65+age*12*motion)+Vector2(0,25*age*age*motion)
				canvas.draw_colored_polygon(PackedVector2Array([chip-axis*4,chip+normal*3,chip+axis*5,chip-normal*3]),ink)
		"blizzard":
			# Short branching ice veins break apart into facets, never a circular rim.
			var radius:float=lerpf(10,76,grow)
			canvas.draw_circle(p,8+flash*12,Color(0.88,0.98,1,flash*0.8))
			for i in range(3 if reduced else 6):
				var angle:float=event.seed+i*TAU/(3 if reduced else 6)
				var axis:=Vector2.from_angle(angle)
				var side:=axis.orthogonal()
				var facet:=p+axis*(radius+sin(event.seed+i)*7)+Vector2(0,age*age*20*motion)
				var stem:=p+axis*(8+smoothstep(0.1,0.8,t)*radius*0.85)
				var tip:=p+axis*radius
				canvas.draw_line(stem,tip,edge,3,true)
				canvas.draw_line(stem,tip,light,1.5,true)
				if t<0.45:
					for sign_value in [-1.0,1.0]:
						var fork:Vector2=tip-axis*17+side*sign_value*14
						canvas.draw_line(tip-axis*30,fork,light,1.5,true)
				axis=axis.rotated(age*2*motion)
				var shard:=PackedVector2Array([facet+axis*9,facet+axis.orthogonal()*3,facet-axis*7,facet-axis.orthogonal()*3])
				canvas.draw_colored_polygon(shard,light)
				canvas.draw_polyline(PackedVector2Array([shard[0],shard[1],shard[2],shard[3],shard[0]]),edge,1.2,true)
		"prism":
			# A splitting faceted lens turns the special-brick burst into arrow lanes.
			var radius:float=lerpf(8,48,grow)*(1-smoothstep(0.55,1,t)*0.55)
			var center:=p+Vector2(0,-radius*0.2)
			var points:=PackedVector2Array()
			for i in range(6):points.append(center+Vector2.from_angle(-PI/2+i*TAU/6+age*motion)*radius)
			canvas.draw_colored_polygon(points,Color(0.55,0.78,0.86,fade*0.22))
			points.append(points[0]);canvas.draw_polyline(points,light,2.1,true)
			for i in range(3 if reduced else 6):
				var axis:=Vector2.from_angle(-PI/2+(i-(1 if reduced else 2.5))*0.36)
				var tip:=p+axis*(35+grow*24+age*45*motion)
				canvas.draw_line(p+axis*7,tip,edge,4,true)
				canvas.draw_line(p+axis*7,tip,light,1.5,true)
				canvas.draw_colored_polygon(PackedVector2Array([tip,tip-axis*9+axis.orthogonal()*4,tip-axis*9-axis.orthogonal()*4]),ink)
			canvas.draw_circle(p,4+flash*7,Color(1,1,1,flash))
		"alchemist":
			# Procedural coin face and rising minted fragments; no image asset.
			var radius:float=lerpf(5,18,grow)*(1-t*0.35)
			canvas.draw_circle(p,radius+3,Color(0.2,0.14,0.04,fade*0.85))
			canvas.draw_circle(p,radius,Color(0.95,0.72,0.18,fade))
			canvas.draw_arc(p,radius,0,TAU,24,light,2,true)
			canvas.draw_line(p-Vector2(radius*0.35,radius*0.55),p+Vector2(radius*0.35,radius*0.55),Color(0.45,0.28,0.05,fade),1.4,true)
			for i in range(3 if reduced else 7):
				var angle:float=event.seed+i*TAU/7
				var shard:=p+Vector2.from_angle(angle)*(18+grow*34)+Vector2(0,-age*(24+i*5))
				var size:float=(2.5+i%3)*fade
				if size<0.15:continue
				canvas.draw_colored_polygon(PackedVector2Array([shard+Vector2.UP*size,shard+Vector2.RIGHT*size,shard+Vector2.DOWN*size,shard+Vector2.LEFT*size]),light)
