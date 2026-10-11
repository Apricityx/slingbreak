extends RefCounted
## Boss art reads the real targets, deadlines, hands, segments and portals. Every
## interactive shape is painted from the collider's state in world coordinates.
var c:Node2D
var g:RefCounted
var d:RefCounted
var m:RefCounted
var p:Dictionary
var t:float

func paint(canvas:Node2D,front:bool) -> void:
	var director:RefCounted=canvas.simulation.bosses
	if director.model==null or director.exploded:return
	c=canvas;g=c.simulation;d=director;m=d.model;p=d.palette();t=g.time
	match d.boss_id:
		"eye":eye(front)
		"clock":clock(front)
		"serpent":serpent(front)
		"forge":forge(front)
	c.draw_set_transform(Vector2.ZERO)

func color(key:String,opacity:float=1) -> Color:return c.alpha(Color(p[key]),opacity)
func line(a:Vector2,b:Vector2,key:String,width:float=2,opacity:float=1) -> void:c.draw_line(a,b,color(key,opacity),width,true)
func ring(at:Vector2,r:float,key:String,width:float=2,opacity:float=1) -> void:
	if r>0:c.draw_arc(at,r,0,TAU,64,color(key,opacity),width,true)
func circle(at:Vector2,r:float,key:String,opacity:float=1) -> void:c.draw_circle(at,maxf(0.01,r),color(key,opacity))
func ellipse(at:Vector2,r:Vector2,key:String,fill:bool=false,width:float=2,opacity:float=1) -> void:
	var points:=PackedVector2Array()
	for index in range(65):points.append(at+Vector2(cos(index*TAU/64),sin(index*TAU/64))*r)
	if fill:c.draw_colored_polygon(points,color(key,opacity))
	else:c.draw_polyline(points,color(key,opacity),width,true)
func polygon(points:PackedVector2Array,key:String,edge:String="",width:float=2,opacity:float=1) -> void:
	c.draw_colored_polygon(points,color(key,opacity))
	if edge!="":points.append(points[0]);c.draw_polyline(points,color(edge,opacity),width,true)
func glow(at:Vector2,r:float,key:String,opacity:float=0.25) -> void:
	for index in range(16,0,-1):circle(at,r*index/16,key,opacity*(1-index/17.0)/6)
func countdown(at:Vector2,r:float,key:String,start:float,end:float) -> void:
	var remaining:=clampf((end-t)/maxf(0.001,end-start),0,1)
	if remaining>0:c.draw_arc(at,r,-PI/2,-PI/2+TAU*remaining,64,color(key),3,true)
func text(value:String,at:Vector2,size:int,key:String) -> void:c._text(value,at,size,color(key))
func bezier(a:Vector2,b:Vector2,end:Vector2) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for index in range(25):
		var k:float=index/24.0
		points.append(a*pow(1-k,2)+2*b*(1-k)*k+end*k*k)
	return points
func cog(at:Vector2,r:float,teeth:int,angle:float,fill:bool=false) -> void:
	var points:=PackedVector2Array()
	for index in range(teeth*2):points.append(at+Vector2.from_angle(angle+index*PI/teeth)*r*(0.82 if index%2 else 1))
	if fill:polygon(points,"brass","rim")
	else:points.append(points[0]);c.draw_polyline(points,color("brassDeep"),2,true);ring(at,r*0.3,"brassDeep")

func eye(front:bool) -> void:
	var center:Vector2=m.center
	var age:float=t-d.intro_at
	var rise:=clampf((age-0.6)/1.2,0,1)
	var dim:=0.5 if m.exposed() else 1.0
	var red:bool=d.rage
	if not front:
		glow(center,300,"irisRage" if red else "crack",0.3*rise*dim)
		for index in range(2+d.fight.phase*2):
			var side:float=1 if index%2 else -1
			var k:=int(index/2)
			var start:=Vector2(390+side*(150+k*30),98)
			var sway:float=sin(t*(0.8+k*0.2)+index)*30 if not g.reduced else 0
			var length:float=(170+k*60)*rise
			var points:=bezier(start,start+Vector2(side*length*0.5,length*0.45+sway),start+Vector2(side*length*0.3+sway,length))
			for at in range(1,points.size()):line(points[at-1],points[at],"crackEdge" if k%2 else "crack",maxf(1.5,(12-k*2)*(1-at/24.0)+1.5),0.35*dim)
			if red:circle(points[24],3,"weak",0.6*dim)
		for side in [-1,1]:
			for index in range(3+d.fight.phase):
				var angle:float=-0.15-index*0.32 if side>0 else PI+0.15+index*0.32
				var at:=Vector2(390+side*(236-index*16),88+index*2)
				var tip:Vector2=at+Vector2.from_angle(angle)*(64-index*6)*rise
				var normal:=Vector2.from_angle(angle).orthogonal()*7
				polygon(PackedVector2Array([at+normal,tip,at-normal]),"crack","weak" if red else "crackEdge",1.4,0.8*dim)
		return
	var tear:=clampf((age-0.25)/0.8,0,1)
	var points:=PackedVector2Array()
	for sign_value in [-1,1]:
		for index in range(19):
			var i:int=index if sign_value<0 else 18-index
			var u:float=i/18.0
			var width:=pow(sin(u*PI),0.8)
			points.append(Vector2(390-250*tear+u*500*tear,92+sign_value*48*tear*width+sin(i*127.1)*6*width))
	if tear>0:polygon(points,"crack","irisRage" if red else "crackEdge",2.2)
	for brick in g.bricks:
		if brick.type=="anchor":
			var chain:=bezier(brick.position,(brick.position+center)/2+Vector2(sin(t*1.3+brick.x)*14,60 if m.exposed() else 36),center)
			for i in range(1,chain.size(),2):line(chain[i-1],chain[i],"chain",2.4,0.4 if m.exposed() else 1)
	var opened:=clampf((age-1.1)/0.7,0,1)
	var blink:=pow(maxf(0,cos(fposmod(t,4.8)*TAU/4.8)),40)*0.85
	var lid:=opened*(0.55 if m.exposed() else 1.2 if m.move.get("id")=="doom" else 1-blink)
	var eyes:Array=[center]
	if m.move.get("id")=="mirage":eyes=[Vector2(170,92),Vector2(610,92)]
	for at in eyes:
		if lid>0:
			ellipse(at,Vector2(45,25*lid),"sclera",true)
			var look:Vector2=(g.pointer-at).limit_length(8) if g.pointer!=null else Vector2(sin(t)*3,0)
			ellipse(at+look,Vector2(23,23*lid),"irisRage" if red else "iris",true)
			ellipse(at+look,Vector2(10,16*lid),"pupil",true);circle(at+look+Vector2(-6,-7*lid),4,"sclera")
		if not m.exposed():ring(at,57,"shield",3,float(d.fight.data.ward)/100)
	for watcher in m.watchers:
		var open:bool=not watcher.blind and fposmod(t-watcher.born,2.6)<2.6*0.45
		ellipse(watcher.position,Vector2(25,13 if open else 2),"scleraShade",true)
		if open:circle(watcher.position,8,"iris");circle(watcher.position,4,"pupil")
	for well in m.wells:
		circle(well.position,80,"well",0.7);ring(well.position,88,"wellRim",2,0.8)
		for index in range(3):c.draw_arc(well.position,30+index*16,t*3+index,t*3+index+PI*1.5,40,color("wellRim",0.4),2,true)
	var move:Dictionary=m.move
	if move.is_empty():return
	match move.id:
		"summon":
			ring(move.target,38,"iris",2);countdown(move.target,46,"weak",move.start,move.end)
			for index in range(6):line(move.target+Vector2.from_angle(t+index*TAU/6)*25,move.target+Vector2.from_angle(t+(index+2)*TAU/6)*25,"shield",1.5)
		"tear":
			var point:Vector2=m.tear_point();polygon(PackedVector2Array([point-Vector2(0,26),point+Vector2(15,2),point+Vector2(0,18),point+Vector2(-15,2)]),"scleraShade","shield");countdown(point,28,"weak",move.live,move.end)
		"gaze":
			var end:Vector2=center+Vector2.from_angle(m.beam_angle())*1100
			for width in [80,18,3]:line(center,end,"beam",width,0.08 if width>3 else 0.9)
		"mirage":
			for at in eyes:ring(at,65,"shield",1,0.3)
		"doom":glow(center,180,"weak",0.5);countdown(center,100,"weak",move.live,move.end);text("%d / 3" % move.hits,center+Vector2(0,85),15,"weak")

func clock(front:bool) -> void:
	var center:Vector2=m.center
	var rise:=clampf((t-d.intro_at)/1.4,0,1)
	if not front:
		for index in range(24):
			var angle:float=t*0.05+index*PI/12
			line(center+Vector2(cos(angle),sin(angle)*0.95)*306,center+Vector2(cos(angle),sin(angle)*0.95)*(346 if index%2 else 390),"brassDeep",2 if index%2 else 4,0.3*rise)
		ellipse(center,Vector2(350,332.5),"brassDeep",false,1.5,0.35*rise)
		ellipse(center,Vector2(300,285),"face",true,2,0.55*rise)
		if d.rage:glow(center,250,"weak",0.25)
		ellipse(center,Vector2(300,285),"ward" if m.exposed() else "rim",false,4,0.8*rise)
		ellipse(center,Vector2(288,273.6),"rim",false,1.2,0.8*rise)
		for index in range(60):
			var angle:float=-PI/2+index*PI/30
			line(center+Vector2(cos(angle),sin(angle)*0.95)*(280 if index%5 else 272),center+Vector2(cos(angle),sin(angle)*0.95)*288,"tick",1 if index%5 else 2.4,0.4*rise if index%5 else 0.8*rise)
		for spec in [[Vector2(-150,-40),70,14,0.4],[Vector2(120,90),54,11,-0.52],[Vector2(40,-150),40,9,0.7]]:cog(center+spec[0],spec[1],spec[2],m.turn*spec[3])
		var crown:=Vector2(390,142-(1-rise)*120)
		var points:=PackedVector2Array([crown+Vector2(-64,22),crown+Vector2(-64,-13)])
		for index in range(5):
			var x:float=-64+index*32
			var tip:float=-61 if index==2 else -35 if index%2 else -48
			points.append(crown+Vector2(x+16,tip));points.append(crown+Vector2(x+32,-13));circle(crown+Vector2(x+16,tip),7 if index==2 else 5,"weak" if d.rage else "gem")
		points.append(crown+Vector2(64,22));polygon(points,"brass","rim",2.5,rise)
		c.draw_rect(Rect2(crown+Vector2(-64,3),Vector2(128,19)),color("face",rise))
		for i in range(-2,3):circle(crown+Vector2(i*23,13),4,"weak" if d.rage else "gem")
		return
	for pair in [[m.minute,235,7.0],[m.hour,155,11.0]]:
		c.draw_set_transform(center,pair[0])
		var length:float=pair[1];var w:float=pair[2]
		polygon(PackedVector2Array([Vector2(-30,-w*0.6),Vector2(length-18,-w),Vector2(length,0),Vector2(length-18,w),Vector2(-30,w*0.6)]),"hand","handEdge")
		circle(Vector2(-34,0),w*1.3,"hand");c.draw_set_transform(Vector2.ZERO)
	for gear in m.gears:
		cog(gear.position,34,10,gear.angle,true);circle(gear.position,18,"face");c.draw_arc(gear.position,38,gear.angle-0.6,gear.angle+0.6,16,color("weak" if gear.jammed else "gem"),4,true)
	circle(center,32,"gemDeep");circle(center,24,"gem");ring(center,35,"weak" if m.exposed() else "rim",2)
	var move:Dictionary=m.move
	if not m.wave.is_empty():ring(center,m.wave.radius,"ward",4,0.6)
	for arrow in m.frozen:glow(arrow.position,18,"stop",0.4);c._arrow_shape(arrow.position,arrow.velocity.angle(),color("ghost"))
	if move.is_empty():return
	match move.id:
		"stop":cog(move.target,18,8,t*2,true);c.draw_rect(Rect2(move.target-Vector2(4,4),Vector2(8,8)),color("face"));countdown(move.target,27,"stop",move.start,move.end)
		"toll":
			var at:Vector2=m.bell_point()
			polygon(PackedVector2Array([at+Vector2(-25,18),at+Vector2(-16,-12),at+Vector2(-10,-24),at+Vector2(10,-24),at+Vector2(16,-12),at+Vector2(25,18)]),"brass","rim");line(at+Vector2(-26,18),at+Vector2(26,18),"handEdge",5);circle(at+Vector2(0,27),5,"brassDeep");countdown(at,40,"stop",move.start,move.end)
		"pendulum":
			var at:Vector2=m.bob_point();line(center,at,"brass",3);circle(at,30,"brass");circle(at,18,"face");text("%d / %d" % [move.hits,4 if d.rage else 3],at+Vector2(0,50),13,"text")
		"rewind":
			for ghost in move.ghosts:c.draw_rect(Rect2(ghost.x-ghost.w/2,ghost.y-ghost.h/2,ghost.w,ghost.h),color("ghost",0.22));c.draw_rect(Rect2(ghost.x-ghost.w/2,ghost.y-ghost.h/2,ghost.w,ghost.h),color("ghost",0.6),false,1)
			countdown(center,62,"ghost",move.start,move.end)
		"haste":ring(center,210,"gem",2,0.25)
		"midnight":countdown(center,76,"weak",move.start,move.end);text("%d / 3" % move.hits,center+Vector2(0,60),15,"weak")

func serpent(front:bool) -> void:
	if not front:
		for index in range(72):
			var at:=Vector2(390+sin(index*127.1)*375,480+sin(index*311.7)*430)
			circle(at,1.2+absf(sin(index))*1.2,"sky",0.3+absf(sin(t+index))*0.4)
		return
	for snake in m.snakes:
		if snake.mode in ["under","sink"]:continue
		var run:Array=[snake.head]
		for segment in snake.segments:run.append(segment.position)
		for index in range(1,run.size()):
			var width:float=44-18*index/maxf(1,run.size())
			for spec in [[8,"dark",0.55],[0,"body",1],[-14,"twin" if m.snakes.size()==2 else "bodyLight",0.9],[-30,"belly",0.6]]:line(run[index-1],run[index],spec[1],maxf(2,width+spec[0]),spec[2])
			line(run[index-1],run[index],"weak" if snake.mode in ["coil","maw","rend","lunge"] else "glow",3,0.25+0.5*(0.5+0.5*sin(t*6-index*0.7)))
		for index in range(snake.segments.size()):
			var segment:RefCounted=snake.segments[index]
			var angle:float=(run[index]-segment.position).angle()
			var width:float=(44-18*(index+1)/maxf(1,run.size()))*0.5
			c.draw_set_transform(segment.position,angle)
			polygon(PackedVector2Array([Vector2(width+2,0),Vector2(0,-width),Vector2(-width-2,0),Vector2(0,width)]),"twin" if m.snakes.size()==2 else "bodyLight","dark")
			polygon(PackedVector2Array([Vector2(width-2,0),Vector2(0,-width+5),Vector2(-4,-width*0.3)]),"belly","",1,0.5)
			if segment.hp<segment.max_hp:line(Vector2(-width*0.6,-width*0.3),Vector2(0,width*0.1),"glow",1.5);line(Vector2(0,width*0.1),Vector2(width*0.4,-width*0.4),"glow",1.5)
			c.draw_set_transform(Vector2.ZERO);c._text(str(ceili(segment.hp)),segment.position+Vector2(0,4),12,c.brick_ink("scale"))
		var head:Vector2=snake.head
		var hot:bool=snake.mode in ["coil","rend","lunge","maw"]
		if hot:glow(head,70+20*sin(t*20),"star" if snake.mode=="maw" else "weak",0.5)
		c.draw_set_transform(head,snake.angle)
		polygon(PackedVector2Array([Vector2(34,0),Vector2(12,-27),Vector2(-27,-20),Vector2(-35,0),Vector2(-27,20),Vector2(12,27)]),"head","dark",3)
		for side in [-1,1]:
			polygon(PackedVector2Array([Vector2(-18,side*18),Vector2(-46,side*33),Vector2(-25,side*5)]),"horn","dark",1)
			polygon(PackedVector2Array([Vector2(13,side*17),Vector2(45,side*(6+snake.jaw*18)),Vector2(24,side*4)]),"bodyLight","dark",2)
			ellipse(Vector2(2,side*15),Vector2(7,4),"eye",true);line(Vector2(3,side*12),Vector2(3,side*18),"dark",2)
		if snake.mode=="maw":ellipse(Vector2(26,0),Vector2(12,12),"maw",true)
		c.draw_set_transform(Vector2.ZERO)
	for gate in m.portals:
		var k:=clampf((t-gate.born)/0.5,0,1)
		ellipse(gate.position,Vector2(48,22)*k,"portal",true);ellipse(gate.position,Vector2(48,22)*k,"glow",false,3);ellipse(gate.position,Vector2(60,28)*k,"star",false,1,0.45)
		if gate.exit:countdown(gate.position,64,"weak",gate.born,gate.end)
	for spark in m.sparks:circle(spark.position,4,"spark");glow(spark.position,12,"spark",0.3)
	if m.snakes.size()==2:
		var start:Vector2=m.snakes[0].head;var finish:Vector2=m.snakes[1].head
		line(start,finish,"tether",3,0.8);glow((start+finish)/2,22,"tether",0.3)
	if not m.eclipse.is_empty():
		var k:=clampf(minf((t-m.eclipse.at)/0.8,(m.eclipse.end-t)/0.5),0,1)
		c.draw_rect(Rect2(0,0,780,1100),color("dark",0.75*k))
		for snake in m.snakes:ring(snake.head,48,"weak",2,k)

func forge(front:bool) -> void:
	var center:Vector2=m.center
	if not front:
		c._rounded(Rect2(80,140,620,680),color("iron",0.32),color("ironEdge"),80)
		c._rounded(Rect2(300,16,180,140),color("iron"),color("ironEdge"),60)
		for side in [-1,1]:
			c._rounded(Rect2(35 if side<0 else 630,230,115,425),color("iron",0.5),color("ironEdge"),40)
			line(Vector2(390+side*17,80),Vector2(390+side*45,86),"molten",6)
		for index in range(9):line(Vector2(180+index*55,160),Vector2(150+index*60,800),"ironEdge",2,0.2)
		if not m.slam.is_empty():
			c.draw_rect(Rect2(m.slam.x-46,145,92,730),color("ember",0.12));line(Vector2(m.slam.x,140),Vector2(m.slam.x,865),"ember",3,0.4)
		if not m.wind.is_empty():
			for index in range(14):
				var x:float=fposmod(t*120*m.wind.direction+index*113,780)
				line(Vector2(x,170+index*47),Vector2(x+m.wind.direction*45,170+index*47),"wind",2,0.45)
		return
	glow(center,95,"glow",0.4);circle(center,33,"glow");circle(center,16,"core");ring(center,38,"molten",2)
	for meteor in m.meteors:
		if t<meteor.born:continue
		glow(meteor.position,40,"ember",0.3);circle(meteor.position,16,"molten");circle(meteor.position,8,"core")
	if not m.palm.is_empty():
		var rect:=Rect2(m.palm.x-64,821,128,28)
		if t<m.palm.down:c.draw_rect(rect,color("ironEdge",0.25),false,1.5)
		else:
			c._rounded(rect,color("iron"),color("ironEdge"),14)
			for index in range(-2,3):line(Vector2(m.palm.x+index*20,824),Vector2(m.palm.x+index*20,846),"ironEdge",1.4)
			for index in range(m.palm.hits):line(Vector2(m.palm.x-28+index*18,823),Vector2(m.palm.x-20+index*18,846),"crack",2)
