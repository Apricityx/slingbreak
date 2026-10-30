extends RefCounted
## Bounded, snapshot-only CanvasItem material bursts. No textures or entity nodes.
static func paint(canvas:CanvasItem,event:Dictionary,clock:float,reduced:bool,dark:bool) -> void:
	var age:float=maxf(0,clock-event.born)
	var t:float=clampf(age/event.max,0,1)
	var fade:float=1-smoothstep(0.22,1,t)
	if fade<0.005:return
	var p:Vector2=event.position
	var axis:Vector2=event.direction
	var side:=axis.orthogonal()
	var grow:float=1-exp(-age*25)
	var flash:float=exp(-age*40)
	var motion:float=0.3 if reduced else 1.0
	var ink:=Color(event.color,fade)
	var light:=Color(event.accent,fade)
	var edge:=Color("#e2f2e0" if dark else "#25352e",fade*0.9)
	match event.id:
		"legion":
			# Exactly six launch lanes, matching the six extra arrows' angular offsets.
			canvas.draw_circle(p,4+flash*10,Color(1,1,0.9,flash))
			for i in range(6):
				var offset:float=(int(i/2)+1)*0.1*(-1 if i%2 else 1)
				var lane:=axis.rotated(offset)
				var normal:=lane.orthogonal()
				var travel:float=16+grow*(35+i%2*6)+age*90*motion
				var tip:=p+lane*travel
				var length:float=(23+i%3*4)*(1-t*0.65)
				canvas.draw_line(tip-lane*length,tip,edge,4.4,true)
				canvas.draw_line(tip-lane*length,tip,light,2,true)
				var blade:=PackedVector2Array([tip+lane*8,tip-lane*5+normal*3.8,tip-lane*2,tip-lane*5-normal*3.8])
				canvas.draw_colored_polygon(blade,ink)
				canvas.draw_line(tip-lane*2,tip+lane*8,light,1.3,true)
				if not reduced:
					canvas.draw_line(tip-lane*(length+8),tip-lane*(length+15),Color(ink,fade*0.4),1.4,true)
		"poison":
			# Three real damage ticks each etch and dissolve a new set of edge pits.
			# The empty centre keeps HP and special-brick markings readable.
			for i in range(3 if reduced else 6):
				var angle:float=event.seed+i*2.39996
				var outward:=Vector2.from_angle(angle)
				var normal:=outward.orthogonal()
				var center:=p+Vector2(outward.x*29,outward.y*15)
				var radius:float=(4+i%3)*(0.6+grow*0.4)*(1-t*0.7)
				var points:=PackedVector2Array()
				for j in range(5):
					var ray:=Vector2.from_angle(j*TAU/5+angle)
					points.append(center+ray*radius*(1+sin(j*4.7+event.seed)*0.2))
				canvas.draw_colored_polygon(points,Color(ink,fade*0.38))
				points.append(points[0]);canvas.draw_polyline(points,edge,2.8,true)
				canvas.draw_polyline(points,ink,1.6,true)
				var drip:=center+outward*(4+grow*11*motion)+Vector2(0,age*age*75*motion)
				canvas.draw_line(center,drip,Color(ink,fade*0.55),1.5,true)
				canvas.draw_colored_polygon(PackedVector2Array([drip-outward*4,drip+normal*2.5,drip+outward*3,drip-normal*2.5]),light)
				canvas.draw_circle(center,1.5+flash*2,Color(light,flash*0.85))
		"ambush":
			# A spear cleaves a closed defence into two moving, fractured plates.
			canvas.draw_circle(p,4+flash*11,Color(1,0.97,0.85,flash))
			for sign_value in [-1.0,1.0]:
				var center:Vector2=p+side*sign_value*(7+grow*18*motion)
				var plate:=PackedVector2Array([center-axis*19,center+side*sign_value*13-axis*10,center+side*sign_value*17+axis*7,center+axis*18,center-axis*2+side*sign_value*4])
				canvas.draw_colored_polygon(plate,Color(ink,fade*0.5))
				plate.append(plate[0]);canvas.draw_polyline(plate,edge,2.2,true)
				canvas.draw_polyline(PackedVector2Array([center-axis*19,center-axis*2+side*sign_value*4,center+axis*18]),light,2,true)
				if not reduced:
					var chip:Vector2=center+side*sign_value*(10+grow*14)+axis*(t*10)
					canvas.draw_line(chip,chip+axis*6,light,2,true)
			var tip:=p+axis*(16+grow*29)
			var heel:=tip-axis*(42*(1-t*0.7))
			canvas.draw_line(heel,tip,edge,6,true)
			canvas.draw_line(heel,tip,light,2.2,true)
			canvas.draw_colored_polygon(PackedVector2Array([tip+axis*7,tip-axis*9+side*6,tip-axis*4,tip-axis*9-side*6]),ink)
		"siphon":
			# Fragments pull inward then feed a local forward-facing arrow edge.
			# Snapshot endpoint is clamped: a remote source never draws a board-wide beam.
			var target:Vector2=p+(event.target-p).limit_length(36)+axis*18
			var gather:float=smoothstep(0.0,0.68,t)
			for i in range(3 if reduced else 6):
				var angle:float=event.seed+i*TAU/(3 if reduced else 6)
				var start:=p+Vector2.from_angle(angle)*(20+(14+i%3*5)*motion)
				var bend:=side*sin(angle)*12*motion*sin(gather*PI)
				var drop:=start.lerp(target,gather)+bend
				var direction:Vector2=start.direction_to(target)
				var normal:=direction.orthogonal()
				var size:float=(3+i%2)*(1-t*0.6)
				canvas.draw_line(drop-direction*(8*(1-gather)),drop,Color(ink,fade*0.5),2.5,true)
				var shard:=PackedVector2Array([drop+direction*size*2,drop+normal*size,drop-direction*size,drop-normal*size])
				canvas.draw_colored_polygon(shard,ink)
				canvas.draw_line(drop-direction*size,drop+direction*size*2,edge,1.2,true)
			var charge:float=sin(clampf(t/0.85,0,1)*PI)
			var tip:=target+axis*(5+grow*12)
			canvas.draw_line(target-axis*12,tip,edge,4.5*charge+0.5,true)
			canvas.draw_line(target-axis*12,tip,light,2*charge+0.5,true)
			if charge>0.04:
				canvas.draw_colored_polygon(PackedVector2Array([tip+axis*6,tip-axis*5+side*4*charge,tip-axis*5-side*4*charge]),light)
