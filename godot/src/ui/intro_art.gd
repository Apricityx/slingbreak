extends Control
## Native version of the opening 1.86 s illustration, including 60 fragments.
var visuals:RefCounted
var age:=0.0
var palette:Dictionary={}

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	palette=JSON.parse_string(FileAccess.get_file_as_string("res://assets/palettes.json"))[visuals.mode].intro

func ease_out(value:float) -> float:return 1-pow(1-clampf(value,0,1),3)
func ink(key:String,opacity:float=1) -> Color:
	var value:=Color(palette[key]);value.a*=opacity;return value
func line(points:PackedVector2Array,key:String,width:float,opacity:float=1) -> void:draw_polyline(points,ink(key,opacity),width,true)

func _draw() -> void:
	var view_scale:=size/Vector2(640,460)
	draw_set_transform(Vector2.ZERO,0,view_scale)
	var pull:=ease_out((age-0.2)/0.65)
	var flight:=clampf((age-0.92)/0.24,0,1)
	var burst:=clampf((age-1.16)/0.7,0,1)
	for x in range(136,505,23):
		for y in range(45,420,23):draw_rect(Rect2(x,y,1.5,1.5),ink("dot",0.55))
	for index in range(15):
		var point:=Vector2(192+index%5*53,68+int(index/5)*43)
		var color:=Color(palette.blocks[(index+int(index/5))%3])
		if burst>0:
			var progress:=ease_out(burst)
			color.a=1-burst
			for part in range(4):
				var velocity:=Vector2((index%5-2)*65+(20 if part%2 else -20),(int(index/5)-2)*58-(35 if part<2 else 0))
				var at:=point+Vector2(11+part%2*22,8+int(part/2)*16)+velocity*progress+Vector2(0,65*burst*burst)
				var rotation:float=(1 if index%2 else -1)*burst*(part+1)
				var points:=PackedVector2Array()
				for corner in [Vector2(-9,-6),Vector2(9,-6),Vector2(9,6),Vector2(-9,6)]:points.append(at+corner.rotated(rotation))
				draw_colored_polygon(points,color)
		else:
			var reveal:=ease_out((age-index*0.022)/0.38)
			var at:=point+Vector2(22,16+(1-reveal)*18)
			color.a=reveal
			draw_rect(Rect2(at-Vector2(22,16)*reveal,Vector2(44,32)*reveal),color)
			draw_rect(Rect2(at-Vector2(17,11)*reveal,Vector2(34,3)*reveal),ink("sheen",reveal))
	var anchor_y:float=326+(1-ease_out(flight*3) if flight>0 else 1)*pull*47
	var fade:=1-ease_out((age-1.62)/0.4)
	line(PackedVector2Array([Vector2(320,343),Vector2(320,399)]),"frame",14,fade)
	line(PackedVector2Array([Vector2(276,314),Vector2(290,348),Vector2(320,366),Vector2(350,348),Vector2(364,314)]),"frame",10,fade)
	line(PackedVector2Array([Vector2(276,314),Vector2(320,anchor_y),Vector2(364,314)]),"band",4,fade)
	if burst==0:
		var arrow_y:=326+pull*47-flight*210
		if flight>0:line(PackedVector2Array([Vector2(320,arrow_y+18),Vector2(320,arrow_y+75)]),"trail",6,fade*0.25)
		line(PackedVector2Array([Vector2(320,arrow_y),Vector2(320,arrow_y-66)]),"frame",3)
		line(PackedVector2Array([Vector2(311,arrow_y-55),Vector2(320,arrow_y-68),Vector2(329,arrow_y-55)]),"frame",3)
		draw_polyline(PackedVector2Array([Vector2(312,arrow_y-4),Vector2(320,arrow_y+3),Vector2(328,arrow_y-4)]),Color("#f67b65"),3,true)
	draw_set_transform(Vector2.ZERO)
