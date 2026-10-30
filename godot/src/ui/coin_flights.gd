extends Control
const Easing=preload("res://src/ui/easing.gd")
## Bounded, deterministic coin/spark paths, independent of simulation RNG.
var paths:Array=[]
var age:=0.0
var duration:=.9
var spark:=false
var ink:=Color("#e8c34a")

func setup(from:Vector2,to:Vector2,count:int=16,is_spark:bool=false,color:Color=Color("#e8c34a")) -> void:
	paths.clear();age=0.0
	spark=is_spark;ink=color;duration=.52 if spark else .9
	for i in range(mini(count,24)):
		var start:Vector2=from+Vector2(sin(i*2.4)*32,cos(i*2.4)*18) if not spark else from
		paths.append({"from":start,"to":to,"bend":(start+to)/2+Vector2(sin(i*1.7)*70,-75),"delay":i*.022})

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=30

func _process(delta:float) -> void:
	age+=delta;queue_redraw()
	if age>duration+paths.size()*.022+.1:queue_free()

func _draw() -> void:
	for path in paths:
		var p:=clampf((age-path.delay)/duration,0,1)
		if p<=0 or p>=1:continue
		var q:=Easing.bezier(p,.45,0,.35,1);var u:=1-q
		var at:Vector2=u*u*path.from+2*u*q*path.bend+q*q*path.to
		var color:=ink;color.a=minf(1,p*8)*minf(1,(1-p)*7)
		if spark:
			draw_set_transform(at,p*TAU)
			draw_rect(Rect2(-5,-5,10,10),color);draw_set_transform(Vector2.ZERO)
		else:
			draw_circle(at,7,color);draw_arc(at,4.5,0,TAU,16,Color("#fff6c2",color.a),1,true)
