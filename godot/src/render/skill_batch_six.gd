extends RefCounted
## Snapshot-only, bounded CanvasItem geometry. No textures, nodes or gameplay RNG.
static func paint(canvas:CanvasItem, event:Dictionary, clock:float, reduced:bool, dark:bool) -> void:
	var age:float=maxf(0,clock-event.born)
	var t:float=clampf(age/event.max,0,1)
	var fade:float=1-smoothstep(0.2,1.0,t)
	if fade<0.005:return
	var p:Vector2=event.position
	var direction:Vector2=event.direction
	var side:=direction.orthogonal()
	var motion:=0.3 if reduced else 1.0
	var grow:float=1-exp(-age*30)
	var flash:float=exp(-age*36)
	var ink:=Color(event.color,fade)
	var light:=Color(event.accent,fade)
	var edge:=Color("#f2e6cb" if dark else "#34332c",fade*0.9)
	match event.id:
		"opportunist":
			# Staggered pursuing wedges compress into the existing wound, then shear away.
			for i in range(2 if reduced else 3):
				var progress:float=clampf((age-i*0.025)*14,0,1)
				var center:=p-direction*(30+i*13)*(1-progress)+side*(i-1)*9
				center+=side*(i-1)*t*12*motion
				var reach:float=(17-i*2)*(1-t*0.6)
				var points:=PackedVector2Array([center-direction*reach-side*7,center+direction*reach,center-direction*reach+side*7,center-direction*reach*0.35])
				canvas.draw_colored_polygon(points,ink)
				canvas.draw_polyline(PackedVector2Array([points[0],points[1],points[2]]),edge,3,true)
				canvas.draw_polyline(PackedVector2Array([points[0],points[1],points[2]]),light,1.3,true)
			canvas.draw_line(p-side*13,p+side*13,Color(1,1,0.9,flash),3,true)
		"bounty":
			# Reward metal is minted into rising, staggered strips rather than a static coin.
			var count:int=3 if reduced else 5
			var power:float=event.strength
			for i in range(count):
				var delay:float=i*0.025
				var local:float=maxf(0,age-delay)
				var lift:float=(1-exp(-local*9))*(22+power*22)*motion
				var center:=p+Vector2((i-(count-1)*0.5)*11,-7-lift-i%2*7)
				var length:float=(8+power*8)*(1-exp(-local*40))*(1-t*0.5)
				if length<0.1:continue
				var lean:float=sin(event.seed+i)*3*t*motion
				var strip:=PackedVector2Array([center+Vector2(-4,0),center+Vector2(-3+lean,-length),center+Vector2(4+lean,-length-3),center+Vector2(4,-2)])
				canvas.draw_colored_polygon(strip,ink)
				strip.append(strip[0]);canvas.draw_polyline(strip,edge,1.8,true)
				canvas.draw_line(center+Vector2(0,-2),center+Vector2(lean,-length+1),light,2,true)
			canvas.draw_line(p+Vector2(-18,3),p+Vector2(18,3),Color(1,0.95,0.65,flash),4,true)
		"nailburst":
			# Three clear launch lanes match the three real children, even in reduced mode.
			for offset in [-0.38,0.0,0.38]:
				var axis:=direction.rotated(offset)
				var tip:=p+axis*(12+grow*42+t*18*motion)
				var back:=tip-axis*(22*(1-t)+3)
				canvas.draw_line(back,tip,edge,5,true)
				canvas.draw_line(back,tip,light,2.2,true)
				canvas.draw_colored_polygon(PackedVector2Array([tip+axis*5,tip-axis*5+axis.orthogonal()*3,tip-axis*5-axis.orthogonal()*3]),ink)
			for i in range(2 if reduced else 6):
				var sign_value:float=-1 if i%2 else 1
				var axis:=side*sign_value
				var center:=p+axis*(9+grow*(15+i*3)*motion)+direction*(i-2)*4+Vector2(0,age*age*40*motion)
				var turn:=axis.rotated(age*4*motion)
				var shard:=PackedVector2Array([center-turn*7,center+turn.orthogonal()*4,center+turn*8,center-turn.orthogonal()*3])
				canvas.draw_colored_polygon(shard,ink)
				canvas.draw_line(shard[0],shard[2],edge,1.4,true)
			canvas.draw_circle(p,4+flash*9,Color(1,0.98,0.85,flash))
		"fusepath":
			var finish:Vector2=event.target
			var distance:float=p.distance_to(finish)
			if distance<0.1:return
			var axis:=p.direction_to(finish)
			var normal:=axis.orthogonal()
			if event.strength<0.8:
				# 0.25s arming phase: a dark unburnt wire and advancing ignition bead.
				var tip:=p.lerp(finish,t)
				canvas.draw_line(tip,finish,Color(edge,0.45),2,true)
				canvas.draw_line(p,tip,Color(ink,0.55*(1-t)),2,true)
				canvas.draw_circle(tip,4,edge)
				canvas.draw_circle(tip,2.5,light)
			else:
				# Actual delayed damage: open molten segments burn away from the source.
				var count:int=4 if reduced else 8
				for i in range(count):
					var along:float=(i+0.5)/count
					var center:=p.lerp(finish,along)
					var length:float=minf(18,distance/count*0.4)*(1-t)
					var lift:float=sin(event.seed+i*2.4)*grow*7*motion
					center+=normal*lift
					canvas.draw_line(center-axis*length,center+axis*length,edge,4*(1-t)+1,true)
					canvas.draw_line(center-axis*length,center+axis*length,light,1.8,true)
					if not reduced:
						var spark:=center+normal*(i%2*2-1)*(6+grow*13)+Vector2(0,age*age*35)
						canvas.draw_line(spark,spark-axis*3,ink,2,true)
				canvas.draw_circle(finish,3+flash*7,Color(1,0.95,0.8,flash))
