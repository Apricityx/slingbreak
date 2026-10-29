extends Node2D
## Native GPU-facing CanvasItem display list. The board never passes through a
## CPU raster surface or an ImageTexture upload.
const Signatures=preload("res://src/render/signatures.gd")
const BossArt=preload("res://src/render/boss_art.gd")
const CoreGlow=preload("res://src/render/core_glow.gd")
const Retained=preload("res://src/render/retained_board.gd")
var simulation: RefCounted
var signatures:=Signatures.new()
var font: Font
var icon_cache: Dictionary={}
var palette: Dictionary={}
var last_theme:=""
var prediction:=PackedVector2Array()
var boss_art:=BossArt.new()
var boxes:Dictionary={}
var core_glow:=CoreGlow.new()
var shake_offset:=Vector2.ZERO
var shake_velocity:=Vector2.ZERO
var arrow_trails:Dictionary={}
var sling_pull:=Vector2.ZERO
var sling_velocity:=Vector2.ZERO
var draw_on:CanvasItem
var background_layer:Node2D
var masonry:Node2D
var retained:Dictionary={}
var retained_simulation:RefCounted
var prepared_key:=""
const GLYPHS={"bomb":"blast","lightning":"storm","frost":"ice","prism":"prism","gold":"mint","void":"starforge","hydra":"infection","anchor":"contract","shard":"piercer","plate":"heavy","magma":"rage","scale":"boomerang","star":"nova","hour":"timeslip"}

func _ready() -> void:
	add_child(core_glow)
	font=preload("res://src/ui/presentation.gd").load_font("bold")
	font.fallbacks=[preload("res://src/ui/presentation.gd").load_font("cjk")]
	draw_on=self
	signatures.attach(self,get_global_transform().get_scale().x)
	signatures.prepare(["blast","storm","ice","prism","mint","pulse","supernova","timeslip","starforge","infection","contract","piercer","heavy","rage","nova"])
	background_layer=Retained.new();background_layer.board=self;background_layer.background=true;background_layer.show_behind_parent=true;add_child(background_layer)
	masonry=Node2D.new();masonry.show_behind_parent=true;add_child(masonry)

func _exit_tree() -> void:
	signatures.finish_loading()

func _process(delta: float) -> void:
	core_glow.present(simulation)
	if simulation!=null:
		var g=simulation
		var offers:Array=g.state.draft.options if g.state.draft is Dictionary else[]
		if g.state.swapOffer is Dictionary:offers=offers+g.state.swapOffer.options
		var key:=str(g.state.skills.keys())+str(offers)
		if key!=prepared_key:
			prepared_key=key;signatures.prepare(g.state.skills.keys()+offers)
		signatures.collect()
		var target:=Vector2.ZERO
		if not g.reduced:
			# Continuous, band-limited shake; impulses blend into the existing
			# displacement instead of replacing the board transform in one frame.
			target=Vector2(sin(g.fx.visual_time*47)+sin(g.fx.visual_time*71)*.3,sin(g.fx.visual_time*53)+sin(g.fx.visual_time*83)*.3)*g.fx.shake*.4
		var step:float=0.0 if g.paused or g.intro_active else minf(delta,0.05)
		var decay:=exp(-32*step)
		var offset:=shake_offset-target
		var impulse:Vector2=(shake_velocity+offset*32)*step
		shake_offset=target+(offset+impulse)*decay
		shake_velocity=(shake_velocity-impulse*32)*decay
		position=Vector2(3.2,0)+shake_offset
		if g.drag!=null:
			sling_pull=Vector2(g.drag.dx,g.drag.dy);sling_velocity=Vector2.ZERO
		elif g.reduced:sling_pull=Vector2.ZERO;sling_velocity=Vector2.ZERO
		elif step>0:
			# Release from the last visible pull. The damped analytic spring is
			# independent of the collision/aim coordinates and display rate.
			var damping:=15.0
			var frequency:=31.0
			var decay_pull:=exp(-damping*step)
			var cosine:=cos(frequency*step)
			var sine:=sin(frequency*step)
			var a:=sling_pull
			var b:Vector2=(sling_velocity+damping*a)/frequency
			sling_pull=(a*cosine+b*sine)*decay_pull
			sling_velocity=((-a*frequency*sine+b*frequency*cosine)-damping*(a*cosine+b*sine))*decay_pull
			if sling_pull.length_squared()<.0001 and sling_velocity.length_squared()<.01:sling_pull=Vector2.ZERO;sling_velocity=Vector2.ZERO
		if g.drag!=null and g.drag.dy>5 and not g.paused and g.phase in ["ready","flying"]:
			var pull:=Vector2(g.drag.dx,g.drag.dy)
			# Once per rendered frame, using the latest pull and live colliders.
			# No 33 ms gate or visual interpolation across collision paths.
			prediction=g.predict(g.origin,-pull.normalized()*g.speed()*(0.56+0.44*minf(1,pull.length()/100)))
		else:prediction.clear()
		_sync_retained()
		queue_redraw()

func _sync_retained() -> void:
	var g=simulation
	palette=g.content.palette(g.theme)
	var active:bool=g.phase not in ["draft","clearing"]
	masonry.visible=active
	background_layer.queue_redraw()
	if retained_simulation!=g:
		for node in retained.values():node.queue_free()
		retained.clear();retained_simulation=g
	if not active:return
	var wanted:Dictionary={}
	var entrance:float=g.presentation_time if g.board_entrance!=null else -1.0
	var entrance_start:float=g.board_entrance.start if g.board_entrance!=null else -1.0
	var order:=0
	for wall in g.obstacles:
		var key:Array=[g.theme,wall.bounds,wall.flash,g.rank("spectral")]
		_retain(wall,true,key,wanted,order);order+=1
	for brick in g.bricks:
		if brick.type=="scale":continue
		var key:Array=[g.theme,brick.bounds,brick.type,brick.hp,brick.max_hp,brick.flash,brick.frozen,entrance,entrance_start,
			brick.flags.get("markUntil",0)>g.time,brick.flags.get("ward",false),
			brick.type=="hour" and g.bosses.boss_id=="clock" and g.bosses.model.lit(brick),
			brick.type!="normal" and signatures.meshes.has(GLYPHS.get(brick.type,"pulse"))]
		_retain(brick,false,key,wanted,order);order+=1
	for entity in retained.keys():
		if not wanted.has(entity):retained[entity].queue_free();retained.erase(entity)

func _retain(entity:RefCounted,is_wall:bool,key:Array,wanted:Dictionary,order:int) -> void:
	wanted[entity]=true
	if not retained.has(entity):
		var node:=Retained.new();node.board=self;node.entity=entity;node.wall=is_wall;node.material=material;masonry.add_child(node);retained[entity]=node
	# Keep the original obstacles-then-bricks order during Boss mutations.
	if retained[entity].get_index()!=order:masonry.move_child(retained[entity],order)
	retained[entity].refresh(key)

func color(section: String,key: String) -> Color:
	return Color(palette.get(section,{}).get(key,"#48652c"))

func brick_ink(type: String) -> Color:
	return Color(palette.get("brickInk",{}).get(type,"#4c5a3d"))

func ink(key: String) -> Color:return Color(palette.get(key,"#48652c"))

func alpha(color_value: Color,opacity: float) -> Color:
	color_value.a*=clampf(opacity,0,1);return color_value

func _draw() -> void:
	set_meta("stroke_meshes",[])
	if simulation==null:return
	var g=simulation
	draw_on=self
	arrow_trails.clear()
	palette=g.content.palette(g.theme)
	draw_set_transform(Vector2.ZERO)
	if g.phase!="draft" and g.phase!="clearing":
		_core()
		_fields()
		_bounty_markers()
	for ring in g.fx.rings:
		var t:float=ring.life/ring.max
		var energy:float=ring.display_energy
		draw_arc(ring.position,maxf(0.01,ring.radius*(1-t)),0,TAU,64,alpha(ring.color,t*0.65*energy),2+0.8*clampf(energy-1,0,1),true)
	for beam in g.fx.beams:
		var t:float=(g.time-beam.born)/beam.duration
		for width in [beam.width,3.0]:draw_line(beam.start,beam.finish,alpha(beam.color,(1-t)*(0.16 if width>3 else 0.85)),width,true)
	for bolt in g.fx.bolts:
		var points:=PackedVector2Array([bolt.start])
		var phase:float=g.fx.visual_time*24
		var pose:=floori(phase)
		var blend:float=phase-pose
		blend=blend*blend*(3-2*blend)
		for index in range(1,6):
			# Retain the electric 24 Hz rhythm, interpolating the deformation
			# between deterministic poses rather than snapping whole segments.
			var a:=sin((pose+bolt.phase+index*7)*2.17)*9
			var b:=sin((pose+1+bolt.phase+index*7)*2.17)*9
			var wave:=lerpf(a,b,blend)
			points.append(bolt.start.lerp(bolt.finish,index/6.0)+Vector2(wave,-wave*0.7))
		points.append(bolt.finish)
		draw_polyline(points,alpha(ink("bolt"),minf(1,bolt.life*4)),2.5,true)
	for arrow in g.arrows:_arrow(arrow)
	_sling()
	for item in g.fx.signatures:
		var t:float=(g.time-item.born)/item.duration
		var opacity:=pow(1-t,0.7)
		var radius:float=minf(item.radius,190 if item.kind=="nova" else 115)
		if item.radius>=110:
			draw_arc(item.position,maxf(0.01,item.radius*(1-pow(1-t,3))),0,TAU,64,alpha(item.color,opacity*0.32),4 if item.kind=="nova" else 1.5,true)
			draw_arc(item.position,maxf(0.01,item.radius*0.85*(1-pow(1-t,3))),0,TAU,64,alpha(item.accent,opacity*0.45),1.5,true)
		signatures.paint(self,item.id,item.position-Vector2(0,t*35 if item.kind=="coin" else 0),0.55 if g.reduced else t,radius,item.color,item.accent,opacity*0.9)
	for particle in g.fx.particles:
		draw_set_transform(particle.position,particle.rotation);draw_rect(Rect2(-particle.size/2,-particle.size/2,particle.size,particle.size*0.7),alpha(particle.color,minf(1,particle.life*2)));draw_set_transform(Vector2.ZERO)
	for text in g.fx.texts:
		var pop:float=0 if g.reduced else text.display_pop*5
		var growth:float=minf(16,log(text.display_count+1)/log(2.0)*3.5) if text.arrow>=0 else 0.0
		draw_set_transform(text.position,0,Vector2.ONE*(1+(growth+pop)/text.size))
		_text(text.text,Vector2.ZERO,text.size,alpha(text.color,text.life*2))
		draw_set_transform(Vector2.ZERO)
	if g.phase not in ["draft","clearing"]:_draw_boss(true)
	if g.fx.flash>0:draw_rect(Rect2(0,0,780,1100),Color(0.65,0.84,0.37,g.fx.flash*0.13))
	if g.pointer!=null:
		for direction in [Vector2.RIGHT,Vector2.DOWN]:
			draw_line(g.pointer-direction*9,g.pointer-direction*3,ink("pointer"),2,true);draw_line(g.pointer+direction*3,g.pointer+direction*9,ink("pointer"),2,true)
	draw_set_transform(Vector2.ZERO)

func _text(value: String,point: Vector2,size: int,color_value: Color) -> void:
	var width:=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	draw_on.draw_string(font,point-Vector2(width/2,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color_value)

func _rounded(rect: Rect2,face: Color,edge: Color=Color.TRANSPARENT,radius: int=5) -> void:
	var key:=str(face.to_rgba32())+":"+str(edge.to_rgba32())+":"+str(radius)
	if not boxes.has(key):
		var box:=StyleBoxFlat.new();box.bg_color=face;box.border_color=edge;box.set_border_width_all(1);box.set_corner_radius_all(radius);boxes[key]=box
		if boxes.size()>512:boxes.erase(boxes.keys()[0])
	draw_on.draw_style_box(boxes[key],rect)

func _entrance(brick: RefCounted) -> void:
	var g=simulation
	if g.board_entrance==null:return
	var delay:float=maxf(0,(brick.y-170)/60)*0.035+brick.x/780*0.045
	var progress:=clampf((g.presentation_time-g.board_entrance.start-delay)/0.42,0,1)
	var eased:=1-pow(1-progress,3)
	var scale_value:=0.88+0.12*eased
	draw_on.draw_set_transform(brick.position+Vector2(0,-26*(1-eased)),0,Vector2.ONE*scale_value)

func _brick(brick: RefCounted) -> void:
	var rect:Rect2=brick.bounds
	var face:=color("brick",brick.type)
	var edge:=color("brickEdge",brick.type)
	var opacity:=1.0
	if simulation.board_entrance!=null:
		_entrance(brick);rect=Rect2(-brick.w/2,-brick.h/2,brick.w,brick.h)
		opacity=clampf((simulation.presentation_time-simulation.board_entrance.start-(brick.y-170)/60*0.035)/0.42,0,1)
	_rounded(rect,alpha(face,opacity),alpha(edge,opacity),5)
	if brick.flash>0:_rounded(rect,Color(1,1,1,brick.flash*3))
	if brick.frozen:_rounded(rect.grow(2),Color.TRANSPARENT,ink("frozenEdge"),6)
	var point:Vector2=brick.position if simulation.board_entrance==null else Vector2.ZERO
	if brick.type!="normal":_glyph(brick.type,point-Vector2(22,0),alpha(brick_ink(brick.type),opacity))
	var value:=str(ceili(brick.hp))
	var font_size:=minf(22,brick.h*0.65)
	if brick.type!="normal":
		var measured:=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(font_size)).x
		font_size*=minf(1,(brick.w/2-6)/maxf(1,measured))
	_text(value,point+Vector2(12 if brick.type!="normal" else 0,6),roundi(font_size),alpha(brick_ink(brick.type),opacity))
	if brick.hp<brick.max_hp:
		var ratio:=1-clampf(brick.hp/brick.max_hp,0,1)
		var points:=PackedVector2Array([point+Vector2(-brick.w*0.25,-brick.h/2+3),point+Vector2(-4,-3),point+Vector2(-12,4),point+Vector2(brick.w*0.26,brick.h/2-3)])
		draw_on.draw_polyline(points,alpha(ink("crack"),ratio*0.4),1,true)
	if brick.flags.get("markUntil",0)>simulation.time:draw_on.draw_arc(point,brick.w*0.42,0,TAU,32,alpha(Color("#91b646"),0.6),1.5,true)
	if brick.flags.get("ward",false):draw_on.draw_rect(rect.grow(3),color("clock","ward"),false,2)
	if brick.type=="hour" and simulation.bosses.boss_id=="clock" and simulation.bosses.model.lit(brick):draw_on.draw_rect(rect.grow(3),color("clock","gem"),false,2)
	if simulation.board_entrance!=null:draw_on.draw_set_transform(Vector2.ZERO)

func _glyph(type: String,point: Vector2,color_value: Color) -> void:
	var id:String=GLYPHS.get(type,"pulse")
	signatures.paint(draw_on,id,point,0.5,11,color_value,color_value,1)

func _wall(wall: RefCounted) -> void:
	_rounded(Rect2(wall.bounds.position+Vector2(0,4),wall.bounds.size),color("obstacle","shadow"),Color.TRANSPARENT,5)
	_rounded(wall.bounds,color("obstacle","face"),color("obstacle","rim"),5)
	var rect:Rect2=wall.bounds
	for index in range(5):
		var x:float=rect.position.x+7+index*14
		draw_on.draw_line(Vector2(x,rect.position.y+6),Vector2(x+10,rect.end.y-6),color("obstacle","stripe"),4,true)
	_rounded(Rect2(wall.x-17,wall.y-10,34,20),color("obstacle","plate"),Color.TRANSPARENT,3)
	for index in range(3):draw_on.draw_line(Vector2(wall.x-9+index*9,wall.y-5),Vector2(wall.x-9+index*9,wall.y+5),color("obstacle","slot"),2,true)
	for index in range(4):
		var point:Vector2=wall.position+Vector2(-31 if index%2==0 else 31,-12 if index<2 else 12)
		draw_on.draw_circle(point,2.5,color("obstacle","rivet"))
	if wall.flash>0:draw_on.draw_rect(wall.bounds,Color(1,1,1,wall.flash*2))
	if simulation.rank("spectral"):draw_on.draw_rect(wall.bounds.grow(3),alpha(Color("#779eb0"),0.7),false,1.5)

func _srgb_mix(start: Color, finish: Color, amount: float) -> Color:
	# HTML palette colours hold sRGB channel values; Color does not convert them.
	return start.lerp(finish, clampf(amount, 0, 1))

func _aim_ink(key: String) -> Color:
	# After a shot the line eases from the charging colour back to its ready colour.
	var g = simulation
	var amount := clampf(1.0-(g.next_shot_at-g.presentation_time)/0.5, 0, 1)
	return _srgb_mix(color("aim", "charging"), color("aim", key), amount*amount*amount)

func _dashed_circle(center: Vector2, radius: float, pattern: Array, ink: Color, width: float) -> void:
	var length := TAU*radius
	var drawn := 0.0
	var slot := 0
	while drawn < length-0.01:
		var span := minf(float(pattern[slot]), length-drawn)
		if slot%2 == 0:
			draw_arc(center, radius, drawn/radius, (drawn+span)/radius, maxi(2, ceili(span/3.0)), ink, width, true)
		drawn += span
		slot = (slot+1)%pattern.size()

func _core() -> void:
	var g=simulation
	if g.core==null:return
	var point:Vector2=g.core_display_position()
	var motion:=CoreGlow.pose(g.presentation_time,g.core.born)
	var size:float=motion.scale
	var age:float=maxf(0,g.presentation_time-g.core.born)
	if age<1.2:
		var sweep:=minf(1,age/0.45)
		var fade:=1-maxf(0,(age-0.6)/0.6)
		draw_line(point-Vector2(330*sweep,0),point-Vector2(60,0),alpha(color("core","line"),fade*0.8),2,true)
		draw_line(point+Vector2(60,0),point+Vector2(330*sweep,0),alpha(color("core","line"),fade*0.8),2,true)
		var gap:=58-38*pow(minf(1,age/0.5),2)
		for side in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			draw_polyline(PackedVector2Array([point+side*Vector2(gap,gap-12),point+side*gap,point+side*Vector2(gap-12,gap)]),alpha(color("core","line"),fade*0.8),2,true)
	var spin:float=motion.spin
	var pulse:float=motion.pulse
	for index in 2:
		draw_set_transform(point, spin+g.presentation_time*(-0.5 if index else 0.4), Vector2.ONE*size)
		_dashed_circle(Vector2.ZERO, 40+index*10+pulse*2, [12, 8, 3, 8], alpha(color("core", "ring"), 0.5), 1)
	draw_set_transform(point, spin+PI/4, Vector2.ONE*size)
	_rounded(Rect2(-21,-21,42,42),color("core","face"),Color.TRANSPARENT,4)
	draw_rect(Rect2(-14,-14,28,28),color("core","frame"),false,1.5)
	draw_rect(Rect2(-4,-4,8,8),color("core","heart"))
	draw_set_transform(Vector2.ZERO);_text("THE CORE",point-Vector2(0,31),9,color("core","label"))

func _arrow(arrow: RefCounted) -> void:
	var point:Vector2=arrow.display_position(simulation.presentation_fraction)
	var trail:PackedVector2Array=arrow.display_trail(simulation.presentation_fraction)
	arrow_trails[arrow.id]=trail
	var arrow_color:Color=arrow.color if arrow.color.a>0 else color("arrow","shaft")
	if arrow.visual!="" and trail.size()>1:_styled_trail(arrow)
	else:
		for index in range(trail.size()):draw_circle(trail[index],2.2,alpha(color("arrow","trail"),float(index+1)/maxi(1,trail.size())*0.45))
	_arrow_shape(point,arrow.display_angle(simulation.presentation_fraction),arrow_color)
	if arrow.flags.has("firewheel"):
		draw_arc(point,90,0,TAU,48,alpha(Color("#cd8150"),0.25),2,true)
		for side in [0,PI]:signatures.paint(self,"firewheel",point+Vector2.from_angle(simulation.time*7+side)*90,0.5,20,Color("#cd8150"),Color("#dec773"))

func _trace(arrow:RefCounted,ink_color:Color,width:float,opacity:float,offset:float=0,wave:bool=false,jagged:bool=false,dash:bool=false) -> void:
	var points:=PackedVector2Array()
	var trail:PackedVector2Array=arrow_trails.get(arrow.id,arrow.trail)
	for index in range(trail.size()):
		var point:Vector2=trail[index]
		if offset!=0:
			var tangent:Vector2=(trail[mini(index+1,trail.size()-1)]-trail[maxi(0,index-1)]).normalized()
			point+=tangent.orthogonal()*offset*(sin(index*0.85-simulation.time*9) if wave else 1)*index/trail.size()
		elif jagged:point+=Vector2(4,-3) if index%2 else Vector2(-4,3)
		points.append(point)
	points.append(arrow.display_position(simulation.presentation_fraction))
	if dash:
		for index in range(1,points.size(),2):draw_line(points[index-1],points[index],alpha(ink_color,opacity),width,true)
	else:draw_polyline(points,alpha(ink_color,opacity),width,true)

func _styled_trail(arrow:RefCounted) -> void:
	var profile:Dictionary=simulation.content.effect_profiles[arrow.visual]
	var primary:=Color(profile.color)
	var accent:=Color(profile.accent)
	var style:String=profile.trail
	var index:int=simulation.arrows.find(arrow)
	var crowded:bool=simulation.arrows.size()>24
	var detailed:bool=not simulation.reduced and (not crowded or index<6 or index>=simulation.arrows.size()-2)
	_trace(arrow,primary,10 if style=="heavy" else 8,0.16)
	if not detailed:_trace(arrow,primary,3,0.7);_trace(arrow,accent,1.2,0.9)
	else:
		match style:
			"rail":_trace(arrow,primary,2,0.6,-3);_trace(arrow,primary,2,0.6,3);_trace(arrow,accent,1.5,0.9)
			"helix":_trace(arrow,primary,2,0.65,6,true);_trace(arrow,accent,2,0.8,-6,true)
			"echo":_trace(arrow,primary,2,0.4,-5);_trace(arrow,accent,2,0.5,5);_trace(arrow,primary,1.5,0.8,0,false,false,true)
			"fork":_trace(arrow,primary,1.5,0.5,-6);_trace(arrow,accent,1.5,0.7,6);_trace(arrow,primary,2,0.7)
			"electric","zigzag":_trace(arrow,primary,2,0.8,0,false,true);_trace(arrow,accent,1,0.75)
			"dash","scan":_trace(arrow,primary,2.5,0.8,0,false,false,true)
			"ribbon","flame":_trace(arrow,primary,4,0.55,4,true);_trace(arrow,accent,2,0.8,-3,true)
			"comet","heavy":_trace(arrow,primary,5 if style=="heavy" else 4,0.65);_trace(arrow,accent,1.5,0.95)
			_:_trace(arrow,primary,1.5,0.65)
	if detailed and style in ["beads","spark","crystal","slash"]:
		var trail:PackedVector2Array=arrow_trails.get(arrow.id,arrow.trail)
		for at in range(2,trail.size(),3):
			var point:Vector2=trail[at]
			var size_value:float=1+at/float(trail.size())*2.5
			match style:
				"beads":draw_arc(point,size_value,0,TAU,16,alpha(accent,0.65),1.5,true)
				"spark":draw_line(point-Vector2(size_value,0),point+Vector2(size_value,0),alpha(accent,0.65),1.5,true);draw_line(point-Vector2(0,size_value),point+Vector2(0,size_value),alpha(accent,0.65),1.5,true)
				"crystal":
					var corners:=PackedVector2Array([point+Vector2(0,-size_value*1.4),point+Vector2(size_value*1.4,0),point+Vector2(0,size_value*1.4),point+Vector2(-size_value*1.4,0),point+Vector2(0,-size_value*1.4)]);draw_polyline(corners,alpha(accent,0.65),1.5,true)
				"slash":draw_line(point+Vector2(-4,4),point+Vector2(4,-4),alpha(accent,0.65),1.5,true)
	if index<(6 if crowded else 12):signatures.paint(self,arrow.visual,arrow.display_position(simulation.presentation_fraction),0.5,16 if style=="heavy" else 12,primary,accent,0.85)

func _arrow_shape(point: Vector2,angle: float,arrow_color: Color) -> void:
	draw_on.draw_set_transform(point,angle)
	draw_on.draw_line(Vector2(-29,0),Vector2(4,0),arrow_color,2.3,true)
	draw_on.draw_colored_polygon(PackedVector2Array([Vector2(10,0),Vector2(0,-4),Vector2(0,4)]),arrow_color)
	for side in [-1,1]:draw_on.draw_line(Vector2(-23,0),Vector2(-29,side*4),color("arrow","fletch"),2,true)
	draw_on.draw_set_transform(Vector2.ZERO)

func _sling() -> void:
	var g=simulation
	var point:Vector2=g.origin
	var pull:=Vector2(g.drag.dx,g.drag.dy) if g.drag!=null else Vector2.ZERO
	var pouch:=point+sling_pull
	_charge_aura(point, pull)
	_dashed_circle(point, 79, [4, 6], alpha(color("sling", "range"), 0.72), 1.5)
	draw_circle(point,48,color("sling","pad"))
	draw_line(point+Vector2(0,53),point+Vector2(0,16),color("sling","frame"),12,true)
	for side in [-1,1]:
		var tip:=point+Vector2(side*23,-14)
		draw_line(point+Vector2(0,16),tip,color("sling","frame"),10,true)
		draw_line(tip,pouch,color("sling","band"),3,true);draw_circle(tip,3,color("sling","knob"))
	draw_line(pouch-Vector2(5,0),pouch+Vector2(5,0),color("sling","pouch"),5,true)
	if g.phase in ["ready","flying"]:
		_arrow_shape(pouch-Vector2(0,4),(-pull).angle() if pull.y>5 else -PI/2+g.keyboard_angle,color("arrow","shaft"))
		if pull.y>5 and prediction.size()>1:
			var ink_color:Color=_aim_ink("line")
			var glow:Color=_aim_ink("glow")
			_draw_prediction(glow,ink_color)
		else:draw_dashed_line(point-Vector2(0,65),point+Vector2(sin(g.keyboard_angle)*40,-110),_aim_ink("keyboard"),1.7,7)
	for index in range(5):_rounded(Rect2(point.x-22+index*10,point.y+75,5,4),color("sling","meterOn" if pull.length()>index*20 else "meterOff"),Color.TRANSPARENT,1)

func _charge_aura(point: Vector2, pull: Vector2) -> void:
	var g = simulation
	var keys: Array = g.state.skills.keys()
	if keys.is_empty() or g.phase not in ["ready", "flying"]:
		return
	var id: String = keys.back()
	var profile: Dictionary = g.content.effect_profiles.get(id, {})
	var charge := clampf(pull.length()/95.0, 0, 1)
	var ink := Color(str(profile.get("color", g.content.by_id[id].color)))
	var accent := Color(str(profile.get("accent", "#ffffff")))
	var phase := 0.5 if g.reduced else 0.5+sin(g.time*1.5)*0.08
	signatures.paint(self, id, point, phase, 80.0+charge*14.0, ink, accent, 0.2+charge*0.25)

func _draw_prediction(glow: Color,ink_color: Color) -> void:
	# Submit both continuous strokes in two calls, retaining every collision
	# sample and a smooth per-vertex fade. No corner simplification is needed.
	var glow_colors:=PackedColorArray()
	var line_colors:=PackedColorArray()
	var traveled:=0.0
	for index in range(prediction.size()):
		if index>0:traveled+=prediction[index-1].distance_to(prediction[index])
		var fade:=clampf((720-traveled)/220,0,1)
		glow_colors.append(alpha(glow,fade*0.45))
		line_colors.append(alpha(ink_color,fade*0.9))
	draw_polyline_colors(prediction,glow_colors,9,true)
	draw_polyline_colors(prediction,line_colors,2.6,true)
	for index in range(6,prediction.size(),6):
		draw_circle(prediction[index],3,alpha(_aim_ink("dot"),line_colors[index].a/maxf(ink_color.a,0.00001)))

func _fields() -> void:
	var g=simulation
	for field in g.skills.fields:
		var t:=clampf((g.time-field.born)/field.duration,0,1)
		var ink_color:=Color(g.content.by_id[field.id].color)
		match field.id:
			"buzzsaw":signatures.paint(self,"buzzsaw",field.position,fmod(g.time*2,1),53,ink_color,Color("#d4bb79"))
			"teslanet":
				var points:=PackedVector2Array(field.vertices)
				if points.size()==3:draw_colored_polygon(points,alpha(ink_color,0.06+pow(sin(t*PI*6),2)*0.12))
				points.append(points[0]);draw_polyline(points,alpha(ink_color,0.75),2,true)
				for point in field.vertices:draw_arc(point,12,0,TAU,24,ink_color,2,true)
			"undertow":
				for index in range(3):draw_arc(field.position,maxf(4,240*(1-t)-index*30),0,TAU,64,alpha(ink_color,(1-t)*(0.6-index*0.12)),2,true)
			"worldfold":
				for x in [20+(field.x-20)*t,760-(760-field.x)*t]:
					for width in [24,7,2]:draw_line(Vector2(x,125),Vector2(x,870),alpha(ink_color,0.9 if width==2 else 0.14),width,true)
			"starforge":
				draw_arc(field.position,170+field.stacks*12,0,TAU,64,alpha(ink_color,0.12),2,true)
				signatures.paint(self,field.id,field.position,t,47+field.stacks*2,ink_color,Color("#71aaa2"));_text(str(field.stacks),field.position+Vector2(0,6),16,ink_color)

func _bounty_markers() -> void:
	var g=simulation
	if not g.rank("contract") or not g.state.skillRuntime.has("contract"):return
	var targets:Array=g.state.skillRuntime.contract.get("targets",[])
	for index in range(targets.size()):
		var point:Dictionary=targets[index]
		var brick:RefCounted=null
		for candidate in g.bricks:
			if candidate.x==point.get("x") and candidate.y==point.get("y"):brick=candidate;break
		if brick!=null:_bounty_marker(brick,index)

func _bounty_marker(brick: RefCounted,index: int) -> void:
	# Gold target diamond, top ribbon with a minted coin seal and a short sheen.
	# The seal sits inside the 16 px row gap so it never covers the row above.
	# Bounded paths only: three simultaneous targets stay cheap on the 89-era
	# renderer, and the marker repaints every frame instead of the brick.
	var g=simulation
	var time:float=0.0 if g.reduced else g.time
	var pulse:float=0.5+0.5*sin(time*3.2+index*2.1)
	var gold:=Color("#d8b85a")
	var light:=Color("#f6e6ae")
	var center:Vector2=brick.position
	var left:float=center.x-brick.w*0.5
	var top:float=center.y-brick.h*0.5
	var right:float=center.x+brick.w*0.5
	var bottom:float=center.y+brick.h*0.5
	_bounty_glow(center,brick.w*0.95,gold,0.19+pulse*0.12)
	# Warm wash keeps the brick readable while making it feel minted.
	draw_rect(Rect2(left,top,brick.w,brick.h),alpha(light,0.06+pulse*0.05))
	var out:float=7+pulse*2
	var diamond:=PackedVector2Array([Vector2(center.x,top-out),Vector2(right+out,center.y),Vector2(center.x,bottom+out),Vector2(left-out,center.y)])
	var loop:=diamond.duplicate()
	loop.append(diamond[0])
	# A dark gold underlay keeps the cord readable on pale bricks as well.
	draw_polyline(loop,alpha(Color("#806020"),0.38),3.4,true)
	draw_polyline(loop,alpha(gold,0.95),1.8,true)
	for point in [Vector2(left-out,center.y),Vector2(right+out,center.y),Vector2(center.x,bottom+out)]:
		draw_colored_polygon(PackedVector2Array([point+Vector2(0,-2.6),point+Vector2(1.6,0),point+Vector2(0,2.6),point+Vector2(-1.6,0)]),alpha(light,0.8))
	# A short sheen passes over the brick, clipped to its rectangle without a
	# canvas clip item.
	var sweep:=fposmod(time*0.52+index*0.31,1.0)
	var sx:float=left+sweep*brick.w
	var sheen:=_clip_segment(Vector2(sx,top-4),Vector2(sx+13,bottom+4),Rect2(left,top,brick.w,brick.h))
	if sheen.size()==2:draw_line(sheen[0],sheen[1],alpha(light,0.18+pulse*0.08),3,true)
	# Ribbon pinned to the top edge; the seal stays in the row gap.
	var by:float=top+2.5
	var half:float=24
	var ribbon:=PackedVector2Array([Vector2(center.x-half,by-5),Vector2(center.x+half,by-5),Vector2(center.x+half-4.5,by),Vector2(center.x+half,by+5),Vector2(center.x-half,by+5),Vector2(center.x-half+4.5,by)])
	draw_colored_polygon(ribbon,alpha(Color("#b6913c"),0.94))
	var ribbon_edge:=ribbon.duplicate()
	ribbon_edge.append(ribbon[0])
	draw_polyline(ribbon_edge,alpha(light,0.94),1.1,true)
	# Minted coin seal with a tiny bob.
	var coin:=Vector2(center.x,top-2.5+(0.0 if g.reduced else sin(time*2.4+index*1.7)*1.2))
	var radius:float=8.5+pulse*0.6
	_bounty_glow(coin,22,Color("#f0d98a"),0.38)
	draw_circle(coin,radius,Color("#e8c766"))
	draw_arc(coin,radius,0,TAU,32,Color("#fff3c9"),1.2,true)
	draw_arc(coin,radius*0.68,0,TAU,32,Color("#98742f"),1.0,true)
	_star(coin,radius*0.62,0.24,Color("#8a6829"))
	# One twinkle at the seal's shoulder, still inside the row gap.
	_star(Vector2(center.x+radius+5,coin.y-radius*0.9),2.5+pulse*2,0.24,light,0.55+pulse*0.35)

func _star(center: Vector2,radius: float,inner: float,ink: Color,opacity: float=1.0) -> void:
	var points:=PackedVector2Array()
	for index in range(8):
		points.append(center+Vector2.from_angle(-PI/2+index*PI/4)*radius*(1.0 if index%2==0 else inner))
	draw_colored_polygon(points,alpha(ink,opacity))

func _bounty_glow(center: Vector2,radius: float,ink: Color,opacity: float) -> void:
	# Six bounded circles approximate the browser's cached radial glow; no
	# gradient texture is allocated per target or per frame.
	for step in range(6,0,-1):
		draw_circle(center,radius*step/6.0,alpha(ink,opacity*(1.0-step/7.0)*0.33))

func _clip_segment(start: Vector2,finish: Vector2,rect: Rect2) -> PackedVector2Array:
	# Liang-Barsky clip, so the sheen never spills over the brick's rectangle.
	var delta:=finish-start
	var directions:=[-delta.x,delta.x,-delta.y,delta.y]
	var distances:=[start.x-rect.position.x,rect.end.x-start.x,start.y-rect.position.y,rect.end.y-start.y]
	var low:=0.0
	var high:=1.0
	for index in range(4):
		if absf(directions[index])<0.000001:
			if distances[index]<0:return PackedVector2Array()
		else:
			var ratio:float=distances[index]/directions[index]
			if directions[index]<0:low=maxf(low,ratio)
			else:high=minf(high,ratio)
	if low>high:return PackedVector2Array()
	return PackedVector2Array([start+delta*low,start+delta*high])

func _draw_boss(front: bool) -> void:
	boss_art.paint(self,front)
