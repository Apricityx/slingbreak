extends RefCounted
## Short launch/impact snapshots; no per-arrow render nodes, texture uploads or RNG.
const IDS=["trident","meteor","hunters","rapid"]

static func paint(canvas:CanvasItem,event:Dictionary,clock:float,reduced:bool,dark:bool) -> void:
	var age:float=maxf(0,clock-event.born)
	var t:float=clampf(age/event.max,0,1)
	var fade:float=1-smoothstep(0.18,1.0,t)
	if fade<0.005:return
	var p:Vector2=event.position
	var d:Vector2=event.direction
	var n:=d.orthogonal()
	var motion:=0.3 if reduced else 1.0
	var grow:float=1-exp(-age*28)
	var flash:float=exp(-age*38)
	var ink:=Color(event.color,fade)
	var light:=Color(event.accent,fade)
	var edge:=Color("#e7dfc3" if dark else "#4a3527",fade*0.9)
	var white:=Color(1,0.98,0.87,flash)
	match event.id:
		"trident":
			# A foil splits from each REAL additional launch lane; asymmetry is gameplay's.
			var tip:=p+d*(18+grow*76+t*22*motion)
			var heel:=tip-d*(46*(1-t)+5)
			var width:float=4.5*(1-t*0.7)
			var blade:=PackedVector2Array([heel-n*width,tip,heel+n*width,heel-d*5])
			canvas.draw_colored_polygon(blade,ink)
			canvas.draw_polyline(PackedVector2Array([heel-n*width,tip,heel+n*width]),edge,2.7,true)
			canvas.draw_line(heel,tip,light,1.5,true)
			# Paired pressure slices open across the launch throat and dissolve, never a ring.
			for sign_value in [-1,1]:
				var base:Vector2=p+d*(14+grow*24)+n*sign_value*(4+grow*7*motion)
				canvas.draw_line(base-d*8,base+d*9+n*sign_value*3,Color(ink,fade*0.65),2,true)
			canvas.draw_line(p-n*5,p+d*14,white,3,true)
		"meteor":
			if event.strength<0.8:
				# Entry heat grows into a directional molten body, then erodes into short embers.
				var center:=p+d*(8+grow*55+t*30*motion)
				var width:float=9*(1-t*0.65)
				var tail:=center-d*(44*(1-t)+9)
				canvas.draw_colored_polygon(PackedVector2Array([tail,center-n*width,center+d*12,center+n*width]),Color(ink,fade*0.5))
				canvas.draw_colored_polygon(PackedVector2Array([tail+d*8,center-n*width*0.65,center+d*9,center+n*width*0.65]),ink)
				canvas.draw_polyline(PackedVector2Array([center-n*width,center+d*12,center+n*width]),edge,2,true)
				canvas.draw_line(center-d*18,center+d*7,light,3,true)
				canvas.draw_circle(center+d*4,3+flash*3,Color(1,0.96,0.78,fade))
				for i in range(2 if reduced else 5):
					var sign_value:float=-1 if i%2 else 1
					var spark:=center-d*(14+i*7)+n*sign_value*(7+grow*(5+i)*motion)
					canvas.draw_line(spark,spark-d*(4+5*(1-t)),light,1.6,true)
			else:
				# Impact stays on the actual brick and splashes sideways from the incoming vector.
				canvas.draw_colored_polygon(PackedVector2Array([p-d*24*(1-t),p-n*(1+13*grow),p+d*7,p+n*(1+13*grow)]),ink)
				canvas.draw_line(p-n*16,p+n*16,white,4,true)
				for i in range(3 if reduced else 7):
					var axis:=(-d).rotated((i/float(2 if reduced else 6)-0.5)*2.4)
					var chip:=p+axis*(7+grow*(16+i%3*6)*motion)+Vector2(0,age*age*35*motion)
					canvas.draw_line(chip,chip+axis*(7*(1-t)+1),edge,3.8,true)
					canvas.draw_line(chip,chip+axis*(6*(1-t)+1),light,1.8,true)
		"hunters":
			if event.strength<0.8:
				# Two staggered wing pairs peel away from the launch; no continuous fake orbit.
				var center:Vector2=p+d*(8+grow*50+t*14*motion)+n*sin(event.seed)*4
				var span:float=(6+grow*13)*(1-t*0.75)
				for sign_value in [-1,1]:
					for i in range(1 if reduced else 2):
						var root:=center-d*i*10
						var wing:=PackedVector2Array([root+d*5,root+n*sign_value*span-d*(8+grow*8*motion),root+n*sign_value*span*0.65-d*19,root-d*6])
						canvas.draw_colored_polygon(wing,Color(ink,fade*(0.9-i*0.25)))
						canvas.draw_polyline(PackedVector2Array([wing[0],wing[1],wing[2]]),edge,1.8,true)
						canvas.draw_line(wing[0],wing[2],light,1.1,true)
				canvas.draw_line(center-d*12,center+d*9,edge,5,true)
				canvas.draw_line(center-d*10,center+d*12,light,2,true)
				canvas.draw_circle(p,3+flash*4,white)
			else:
				# Real contact pinches into a stinger wound; the two open brackets recoil locally.
				canvas.draw_line(p-d*19*(1-t),p+d*8,edge,4,true)
				canvas.draw_line(p-d*19*(1-t),p+d*8,light,2,true)
				for sign_value in [-1,1]:
					var center:Vector2=p+n*sign_value*(7+grow*11*motion)
					canvas.draw_polyline(PackedVector2Array([center-d*9,center+n*sign_value*4,center+d*8]),ink,3,true)
				canvas.draw_line(p-n*9,p+n*9,white,3,true)
		"rapid":
			# The string traverses its release in 0.18s (the actual cooldown), then sheds wind.
			var snap:float=1-pow(1-clampf(age/0.18,0,1),3)
			var flex:float=lerpf(-20,8,snap)
			var bow:=PackedVector2Array()
			for i in range(13):
				var along:float=i/12.0*2-1
				bow.append(p+n*along*35+d*(7+(1-along*along)*flex))
			canvas.draw_polyline(bow,edge,5,true)
			canvas.draw_polyline(bow,ink,3,true)
			var string:=PackedVector2Array([p-n*35+d*7,p+d*lerpf(-25,7,snap),p+n*35+d*7])
			canvas.draw_polyline(string,light,1.7,true)
			canvas.draw_line(p-d*6,p+d*18,white,4,true)
			for i in range(2 if reduced else 4):
				var sign_value:float=-1 if i%2 else 1
				var tip:=p+d*(25+grow*(28+i*7))+n*sign_value*(16+i*4)
				canvas.draw_polyline(PackedVector2Array([tip-d*(24*(1-t)+2)-n*sign_value*5,tip-d*8,tip]),Color(ink,fade*0.8),2,true)
