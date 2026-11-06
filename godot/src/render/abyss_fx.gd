extends Node2D
## Fixed native VFX pool. Real event lifetimes survive move cancellation / death.
const SHADER=preload("res://src/render/abyss_fx.gdshader")
const Rig=preload("res://src/render/abyss_rig.gd")
const CAPACITY:=12
var volumes:Array[Polygon2D]=[]
var beam:Polygon2D
var simulation:RefCounted
var used:=0
var echo_box:=StyleBoxFlat.new()

func make_volume(points:PackedVector2Array) -> Polygon2D:
	var node:=Polygon2D.new();node.polygon=points
	var mat:=ShaderMaterial.new();mat.shader=SHADER;node.material=mat
	add_child(node);node.visible=false;return node
func _ready() -> void:
	echo_box.set_corner_radius_all(3);echo_box.set_border_width_all(1)
	for i in range(CAPACITY):volumes.append(make_volume(PackedVector2Array([Vector2(-160,-160),Vector2(160,-160),Vector2(160,160),Vector2(-160,160)])))
	beam=make_volume(PackedVector2Array([Vector2(0,-70),Vector2(1100,-70),Vector2(1100,70),Vector2(0,70)]))
	beam.material.set_shader_parameter("mode",2)
func configure(node:Polygon2D,age:float,duration:float,ink:Color,core:Color,mode:int,strength:float,seed:float=0) -> void:
	node.visible=true
	var mat:ShaderMaterial=node.material
	mat.set_shader_parameter("age",age);mat.set_shader_parameter("duration",duration);mat.set_shader_parameter("ink",ink);mat.set_shader_parameter("core",core)
	mat.set_shader_parameter("mode",mode);mat.set_shader_parameter("strength",strength);mat.set_shader_parameter("seed",seed);mat.set_shader_parameter("reduced",simulation.reduced)
func present(g:RefCounted) -> void:
	simulation=g;used=0
	visible=g!=null and g.bosses.boss_id=="eye" and g.phase not in ["draft","clearing"]
	for node in volumes:node.visible=false
	beam.visible=false
	if not visible:return
	var m:RefCounted=g.bosses.model
	var p:Dictionary=g.bosses.palette()
	var ink:=Color(p.weak if g.bosses.rage else p.shield);var core:=Color(p.sclera)
	# New impacts take priority over older tails when the GPU pool is full.
	for index in range(m.visuals.events.size()-1,-1,-1):
		var event:Dictionary=m.visuals.events[index]
		var age:float=g.presentation_time-event.born
		var duration:float=event.duration
		var mode:=0;var strength:=1.0;var size:=Vector2.ONE
		match event.kind:
			"intro":age-=1.1;duration=1.0;size=Vector2(1.15,0.52)
			"phase":
				if age<Rig.REVEAL_AT:mode=1;duration=Rig.REVEAL_AT;size=Vector2(1.0,0.48)
				else:age-=Rig.REVEAL_AT;duration=0.9;size=Vector2(1.25,0.5)
			"cast":
				mode=1;size=Vector2(0.65,0.4);strength=0.85
			"ward":size=Vector2.ONE*0.24;strength=0.75
			"hit":size=Vector2.ONE*0.38
			"seal_hit":size=Vector2.ONE*0.55
			"break":size=Vector2.ONE;mode=5
			"release":size=Vector2(0.8,0.55) if event.ability=="gaze" else Vector2(0.65,0.5)
			"inscribe":mode=5;size=Vector2(0.5,0.36)
			"infect":mode=7;size=Vector2(0.65,0.48)
			"resolve":
				if event.ability=="gaze":continue
				size=Vector2(0.75,0.65) if event.ability!="tear" else Vector2(0.4,0.34)
				if event.ability in ["summon","tear"]:mode=3
			"death":age-=1.22;duration=1.1;size=Vector2(1.25,0.6)
		if age<0 or age>=duration:continue
		if used>=CAPACITY:break
		var node:=volumes[used];used+=1;node.position=event.position;node.scale=size
		node.rotation=event.direction.angle() if mode==5 else 0.0
		configure(node,age,duration,ink,core,mode,strength,event.seed)
	if m.sweeping() or m.move.get("id")=="gaze" and g.time>=m.move.live and g.presentation_time<m.move.active_end+0.25:
		# One crimson sweep: real angle, real endpoint, fading out after the arc.
		beam.position=m.center;beam.rotation=m.beam_angle()
		var tail:float=clampf((m.move.active_end+0.22-g.presentation_time)/0.22,0,1)
		configure(beam,g.presentation_time-m.move.live,10,Color("#ff2343"),Color("#fff2df"),6,tail)
		beam.material.set_shader_parameter("beam_length",m.center.distance_to(m.beam_endpoint()))
	queue_redraw()

func illumination(point:Vector2) -> float:
	if simulation==null or not visible or simulation.bosses.boss_id!="eye":return 0.0
	var g:RefCounted=simulation;var m:RefCounted=g.bosses.model
	var light:=0.0
	for event in m.visuals.events:
		if event.kind not in ["break","release","resolve","phase","death"]:continue
		var age:float=g.presentation_time-event.born
		if event.kind=="phase":
			var entrance:float=age-2.25-(point.y-170)/60*0.035
			if entrance>=0 and entrance<0.6:light=maxf(light,sin(entrance/0.6*PI)*0.22)
		if event.kind=="phase":age-=Rig.REVEAL_AT
		if event.kind=="death":age-=1.22
		if age<0 or age>0.65:continue
		var distance:float=point.distance_to(event.position)
		light=maxf(light,exp(-age*9)*maxf(0,1-distance/240)*0.28)
	if m.sweeping():
		var dir:=Vector2.from_angle(m.beam_angle());var delta:Vector2=point-m.center
		if delta.dot(dir)>0 and delta.length()<m.center.distance_to(m.beam_endpoint())+40:
			light=maxf(light,maxf(0,1-absf(delta.cross(dir))/70)*0.42)
	elif m.move.get("id")=="gaze" and g.time<m.move.live:
		light=maxf(light,maxf(0,1-point.distance_to(m.center)/320)*0.2*smoothstep(m.move.start,m.move.live,g.time))
	return light*(0.5 if g.reduced else 1.0)

func _draw() -> void:
	if simulation==null or not visible:return
	# A reset can occur after present() has queued this draw for the frame.
	if simulation.bosses.boss_id!="eye" or simulation.bosses.model==null:
		visible=false;return
	var g:RefCounted=simulation;var m:RefCounted=g.bosses.model
	var p:Dictionary=g.bosses.palette();var ink:=Color(p.weak if g.bosses.rage else p.shield)
	var stone:=Color(g.content.palette(g.theme).obstacle.face);var core:=Color(p.sclera)
	for event in m.visuals.events:
		var age:float=g.presentation_time-event.born
		if age<0 or age>=event.duration:continue
		if event.kind in ["phase","intro"]:
			var peak:float=Rig.REVEAL_AT if event.kind=="phase" else 1.1
			if event.kind=="phase":stage_echo(event,age,ink,core)
			# Four broken, almond-shaped seal paths close toward the pupil. They
			# share the relic's proportions and have a discrete reveal, not a loop.
			var seal_fade:float=smoothstep(0.15,0.6,age)*(1-smoothstep(peak,peak+0.55,age))
			if seal_fade>0:
				for side in [-1,1]:
					for vertical in [-1,1]:
						var path:=PackedVector2Array()
						for j in range(17):
							var k:float=j/16.0
							path.append(event.position+Vector2(side*lerpf(154,27,k),vertical*(sin(k*PI)*38+14)))
						draw_polyline(path,Color(ink,seal_fade*0.16),7,true)
						draw_polyline(path,Color(ink,seal_fade*0.85),2,true)
						var cursor:int=clampi(int(age/peak*16),0,16)
						draw_line(path[maxi(0,cursor-2)],path[cursor],Color(core,seal_fade*0.9),2.5,true)
			if age<peak:
				var k:=age/peak
				for i in range(8 if not g.reduced else 4):
					var angle:float=i*TAU/8+0.2
					var dir:=Vector2(cos(angle),sin(angle)*0.45)
					var position:Vector2=event.position+dir*lerpf(165,54,smoothstep(0,1,k))
					glyph(position,angle,k,ink,core)
				continue
			age-=peak
		elif event.kind=="death":
			if age<1.22:continue
			age-=1.22
		if event.kind=="cast":continue
		if event.kind=="break":
			fracture(event,age,Color("#432c85"),Color("#a57bff"),Color("#bfefff"));continue
		if event.ability=="gaze" and event.kind=="resolve":continue
		var life:float=0.8 if event.kind in ["phase","intro","death","break"] else 0.4
		if age>=life:continue
		var opacity:=pow(1-age/life,1.5)
		var count:int=5 if g.reduced else 14 if event.kind in ["phase","break","death"] else 8
		for i in range(count):
			var angle:float=i*2.399+event.seed*0.7
			var dir:=Vector2.from_angle(angle)
			var origin:Vector2=event.position
			if event.kind in ["phase","intro","death","break"]:origin+=Vector2(dir.x*100,dir.y*33)
			else:dir=(dir+event.direction*1.7).normalized()
			var speed:float=(55+i%4*24)*(0.3 if g.reduced else 1.0)
			var position:Vector2=origin+dir*speed*age+Vector2(0,age*age*65)
			var axis:Vector2=dir.rotated(age*(i%3-1)*3)
			var length:float=(3+i%4)*(1-age/life*0.6)
			var vertices:=PackedVector2Array([position-axis*length,position+axis.orthogonal()*2,position+axis*length,position-axis.orthogonal()*2])
			draw_colored_polygon(vertices,Color(stone if i%3==0 else ink,opacity))
			draw_line(position-axis*length,position+axis.orthogonal()*2,Color(core,opacity*0.8),1,true)
		if event.kind in ["hit","ward","seal_hit"]:
			var normal:Vector2=event.direction.orthogonal()
			var reach:float=16+age*35
			draw_line(event.position-normal*reach,event.position+normal*reach,Color(core,exp(-age*14)),2,true)

func fracture(event:Dictionary,age:float,stone:Color,ink:Color,core:Color) -> void:
	var normal:Vector2=event.direction;var tangent:=normal.orthogonal()
	var fade:float=1-smoothstep(0.25,0.85,age)
	# Six deliberate masonry plates peel from the hit side; staggered release
	# creates a visible crack-propagation beat before the fragments fall.
	for i in range(6):
		var delay:float=i*0.025
		var t:float=maxf(0,age-delay)
		var side:float=1 if i%2 else -1
		var distance:float=26+(i/2)*32
		var p:Vector2=event.position+tangent*side*distance+normal*(20+minf(t*140,50))
		p+=tangent*side*t*(14+i*6)+Vector2(0,t*t*85)*(0.25 if simulation.reduced else 1)
		var axis:Vector2=tangent.rotated(side*t*1.3)
		var v:=PackedVector2Array([p-axis*17-normal*5,p+axis*10-normal*7,p+axis*18+normal*3,p-axis*9+normal*8])
		draw_colored_polygon(v,Color(stone,fade))
		draw_polyline(PackedVector2Array([v[0],v[1],v[2]]),Color(core,fade*0.85),2,true)
		if age<0.22:draw_line(event.position+normal*43,p,Color(ink,exp(-age*15)),2,true)

func glyph(at:Vector2,angle:float,amount:float,ink:Color,core:Color) -> void:
	var dir:=Vector2.from_angle(angle);var normal:=dir.orthogonal()
	var size:float=7+amount*4
	var points:=PackedVector2Array([at-dir*size,at+normal*size*0.6,at+dir*size,at-normal*size*0.6,at-dir*size])
	draw_polyline(points,Color(ink,smoothstep(0,0.2,amount)*0.8),1.5,true)
	if amount>0.5:draw_line(at-dir*2,at+dir*2,Color(core,(amount-0.5)*1.5),1.5,true)

func stage_echo(event:Dictionary,age:float,ink:Color,core:Color) -> void:
	if age>1.6:return
	var g:RefCounted=simulation;var palette:Dictionary=g.content.palette(g.theme)
	var masonry:Array=event.get("masonry",[])
	for i in range(masonry.size()):
		var brick:Dictionary=masonry[i]
		var delay:float=(brick.position.y-170)/600*0.30
		var k:float=clampf((age-delay)/0.85,0,1)
		var opacity:float=pow(1-k,2)
		if opacity>0.01:
			echo_box.bg_color=Color(Color(palette.brick.get(brick.type,palette.brick.normal)),opacity*0.85)
			echo_box.border_color=Color(ink,opacity*k)
			draw_style_box(echo_box,Rect2(brick.position-brick.size*0.5,brick.size))
			if k>0.15:
				var p:Vector2=brick.position
				draw_polyline(PackedVector2Array([p+Vector2(-18,-8),p+Vector2(-3,1),p+Vector2(4,-4),p+Vector2(17,9)]),Color(ink,opacity*0.7),1.5,true)
		# Only every fifth brick sends an imprint; the dense field stays readable.
		if i%5!=0 or g.reduced and i%10!=0:continue
		var travel:float=clampf((age-delay-0.18)/0.95,0,1)
		if travel<=0 or travel>=1:continue
		var easing:float=travel*travel
		var target:Vector2=event.position+Vector2(sin(i*3.7)*80,0)
		var position:Vector2=brick.position.lerp(target,easing)
		position.x+=sin(travel*PI)*sin(i*1.7)*24
		var direction:Vector2=(target-brick.position).normalized()
		var fade:float=sin(travel*PI)*0.75
		draw_line(position-direction*14,position,Color(ink,fade*0.4),2,true)
		var n:=direction.orthogonal()
		var shape:=PackedVector2Array([position-direction*5,position+n*3,position+direction*5,position-n*3])
		draw_colored_polygon(shape,Color(ink,fade));draw_line(position-direction*3,position+direction*3,Color(core,fade),1,true)
