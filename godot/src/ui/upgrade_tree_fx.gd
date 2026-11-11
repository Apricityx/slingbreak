extends Control
## Bounded local bursts: faceted shards, a fast glint and directional unlock
## energy. No gameplay RNG, no Tween callbacks, no full-screen flash.
var bursts:Array=[]
var paths:Array=[]
var clock:=0.0
var reduced:=false
const LIFE:=.85

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE

func fire(point:Vector2,ink:Color,tier:int) -> void:
	if bursts.size()>=8:bursts.pop_front()
	bursts.append({"point":point,"ink":ink,"tier":tier,"born":clock})
	queue_redraw()

func connect_path(a:Vector2,b:Vector2,ink:Color) -> void:
	if paths.size()>=12:paths.pop_front()
	paths.append({"a":a,"b":b,"ink":ink,"born":clock})

func _process(delta:float) -> void:
	advance(delta)

func advance(delta:float) -> void:
	clock+=maxf(0,delta)
	bursts=bursts.filter(func(event):return clock-event.born<LIFE)
	paths=paths.filter(func(event):return clock-event.born<.7)
	queue_redraw()

func reset() -> void:
	bursts.clear();paths.clear();clock=0;queue_redraw()

func _draw() -> void:
	for event in paths:
		var age:float=clock-event.born
		var t:=clampf(age/.45,0,1)
		var head:Vector2=event.a.lerp(event.b,t)
		var tail:Vector2=event.a.lerp(event.b,maxf(0,t-.16))
		var ink:Color=event.ink;ink.a=clampf((.7-age)/.25,0,1)
		if not reduced:
			draw_line(tail,head,Color(ink,ink.a*.16),9,true);draw_line(tail,head,ink,3,true)
			draw_circle(head,3,Color(1,.98,.87,ink.a))
	for event in bursts:
		var age:float=clock-event.born
		var strength:float=1+event.tier*.3
		var point:Vector2=event.point
		var ink:Color=event.ink
		if event.tier==2:ink=ink.lerp(Color("#f9d589"),.65)
		var flash:=exp(-age*19)*.7
		for i in range(5):
			draw_circle(point,20+i*5,Color(ink,flash*(.14 if reduced else .28)))
		if age<.3:
			var radius:float=(12+age*180)*strength
			var alpha:=pow(1-age/.3,2)
			for axis in range(4):
				var direction:=Vector2.from_angle(axis*PI/2+.2)
				var side:=direction.orthogonal()*4*alpha
				draw_colored_polygon(PackedVector2Array([point+side,point+direction*radius,point-side,point-direction*6]),Color(1,.98,.85,alpha))
		var count:int=4 if reduced else 10+event.tier*4
		for i in range(count):
			var angle:float=i*TAU/count+event.born*.7
			var direction:=Vector2.from_angle(angle)
			var distance:float=(18+(1-exp(-age*6))*(27+fmod(i*13.0,23)))*strength*(.45 if reduced else 1)
			var center:Vector2=point+direction*distance+Vector2(0,age*age*39)
			var alpha:=pow(maxf(0,1-age/LIFE),1.8)
			var length:float=(3+fmod(i*7.0,5))*alpha*strength
			# Skip subpixel diamonds before precision collapses the vertices at
			# deep graph coordinates (legendary tier is ~900 design pixels down).
			if length<.3:continue
			var side:=direction.orthogonal()*length*.45
			draw_colored_polygon(PackedVector2Array([center+direction*length,center+side,center-direction*length,center-side]),Color(ink.lightened(.4 if i%3==0 else .05),alpha))
