extends RefCounted
## 熔炉巨像 vector layer above the shader body. Every interactive shape (door,
## fists, bellows nozzles, globs, spout, palm socket) is painted from its collider
## in world space; envelopes come from ForgeSurface.pose().
const Surface=preload("res://src/render/forge_surface.gd")
const Forge=preload("res://src/bosses/forge.gd")
var a:RefCounted
var m:RefCounted
var t:float
var motion:float

func paint(art:RefCounted,front:bool) -> void:
	a=art;m=a.m;t=a.t;motion=0.0 if a.g.reduced else t
	layer(front)
	# boss_art owns this painter; holding it back would form a leaking cycle.
	a=null;m=null

func layer(front:bool) -> void:
	var pose:=Surface.pose(a.g)
	var ink:float=pose.rise*(1-smoothstep(0.55,1.0,pose.crack))
	if ink<=0.01:return
	if not front:back(pose,ink);return
	fists(pose,ink)
	nozzles(pose,ink)
	door(pose,ink)
	var id:String=m.move.get("id","")
	if id=="magma":pour(ink)
	if id=="palm":palm(ink)
	for glob in m.globs:glob_art(glob,ink)

## Under the masonry: telegraphs on the floor (landing marks, hammer shadow,
## palm track, bellows wind).
func back(pose:Dictionary,ink:float) -> void:
	var id:String=m.move.get("id","")
	if id=="slam":
		var ground:Vector2=Forge.FISTS[m.move.side]+Vector2(0,40)
		var k:=clampf((t-m.move.start)/maxf(0.01,m.move.live-m.move.start),0,1)
		a.glow(ground,190,"ember",0.25*k*ink);a.ring(ground,190*k,"ember",2,0.5*ink)
	for glob in m.globs:
		if t<glob.born-0.5:continue
		var k:=clampf((t-glob.born)/glob.flight,0,1)
		a.ring(glob.to,30-k*12,"ember",2,(0.35+0.5*k)*ink);a.glow(glob.to,40,"ember",0.3*k*ink)
	if id=="palm":a.line(Vector2(210,Forge.PALM_Y+16),Vector2(570,Forge.PALM_Y+16),"ember",2,0.3*ink)
	if id=="bellows" and t>=m.move.live:
		var dir:float=1.0 if m.move.side==0 else -1.0
		for index in range(12):
			var x:float=fposmod(motion*260*dir+index*131,780)
			a.line(Vector2(x,190+index*55),Vector2(x+dir*52,190+index*55),"wind",2,0.4*ink)
	if pose.heat>0.05 and not m.exposed():a.glow(m.center,140,"glow",0.25*pose.heat*ink)

## Fists: iron knuckle plates over the collider circle. An armed fist glows and
## runs its countdown; the palm-side fist is drawn by palm().
func fists(pose:Dictionary,ink:float) -> void:
	for side in range(2):
		if m.palm_live() and m.move.side==side:continue
		var at:Vector2=pose.fist_l if side==0 else pose.fist_r
		var armed:bool=m.fist_armed(side)
		if armed:a.glow(at,90,"ember",0.55*ink);a.countdown(at,Forge.FIST_RADIUS+10,"weak",m.move.start,m.move.live)
		knuckles(at,ink,armed)

func knuckles(at:Vector2,ink:float,hot:bool) -> void:
	var r:=Forge.FIST_RADIUS
	a.circle(at+Vector2(4,6),r,"soot",0.45*ink)
	a.circle(at,r,"iron",ink);a.circle(at+Vector2(-5,-6),r*0.72,"ironEdge",0.35*ink)
	for index in range(4):
		var x:float=at.x-r*0.6+index*r*0.4
		a.line(Vector2(x,at.y-r*0.62),Vector2(x,at.y-r*0.1),"soot",3,0.7*ink)
	a.ring(at,r,"crack" if hot else "ironEdge",3 if hot else 2,ink)
	if hot:a.ring(at,r*0.55,"molten",2,(0.6+0.4*sin(motion*14))*ink)

## Shoulder nozzles: bellows colliders. During bellows the open side flares.
func nozzles(pose:Dictionary,ink:float) -> void:
	for side in range(2):
		var at:Vector2=Forge.SHOULDERS[side]
		var target:bool=m.move.get("id")=="bellows" and m.move.side==side
		var draw:float=pose.bellows.x if side==0 else pose.bellows.y
		if target:
			a.glow(at,80,"molten",0.5*ink);a.countdown(at,Forge.BELLOWS_RADIUS+10,"weak",m.move.start,m.move.end)
		a.ring(at,Forge.BELLOWS_RADIUS,"crack" if target else "ironEdge",3 if target else 1.6,(1.0 if target else 0.55)*ink)
		if draw>0:a.circle(at,Forge.BELLOWS_RADIUS*0.45*draw,"core",0.7*draw*ink)

## Furnace door: sealed ring with the heat gauge; exposed it blooms and counts down.
func door(pose:Dictionary,ink:float) -> void:
	var at:Vector2=m.center
	var gauge:float=clampf(pose.heat,0,1)
	if not m.exposed() and not pose.dying:
		var r:=Forge.DOOR_RADIUS+14
		a.canvas.draw_arc(at,r,-PI/2,-PI/2+TAU,64,a.color("soot",0.55*ink),7,true)
		if gauge>0:a.canvas.draw_arc(at,r,-PI/2,-PI/2+TAU*gauge,64,a.color("molten" if a.g.time>=m.refill_until else "smoke",0.95*ink),4,true)
		a.ring(at,Forge.DOOR_RADIUS,"ironEdge",2.5,ink)
	if m.exposed():
		a.glow(at,130+14*sin(motion*7),"molten",0.6*pose.vent*ink)
		a.circle(at,Forge.OPEN_RADIUS*0.6,"core",0.7*pose.vent*ink)
		a.ring(at,Forge.OPEN_RADIUS,"weak",3,ink);a.countdown(at,Forge.OPEN_RADIUS+16,"core",m.vented_at,m.stunned_until)
	if m.move.get("id")=="meltdown":
		a.ring(at,Forge.DOOR_RADIUS+4+pose.beat*10,"weak",3,(0.3+0.7*pose.beat)*ink)
		for index in range(3):a.circle(at+Vector2(-24+index*24,-Forge.DOOR_RADIUS-30),6,"weak" if index<m.move.hits else "soot",ink)
	var strike:float=1-clampf((t-m.struck_at)/0.3,0,1)
	if strike>0:a.glow(at,80,"core",strike*0.8);a.ring(at,40+(1-strike)*40,"core",3,strike)
	var ping:float=1-clampf((t-m.pinged_at)/0.25,0,1)
	if ping>0:a.ring(m.center,Forge.DOOR_RADIUS+(1-ping)*14,"ironEdge",2,ping*ink)
	var burst:float=1-clampf((t-m.vented_at)/0.7,0,1)
	if burst>0 and m.exposed():a.ring(m.vent_point,20+(1-burst)*80,"molten",3,burst);a.ring(at,50+(1-burst)*260,"ember",4,burst*0.7)
	var ignite:float=smoothstep(0.75,0.9,pose.rise)*(1-smoothstep(0.9,1.0,pose.rise))
	if ignite>0:a.glow(at,180,"molten",ignite*0.8);a.ring(at,50+ignite*90,"molten",2,ignite)

## Crucible pour: the spout collider and the stream to where slag is landing.
func pour(ink:float) -> void:
	var spout:Vector2=m.spout()
	var live:bool=t>=m.move.live
	a.glow(spout,60,"molten",0.5*ink);a.ring(spout,26,"crack",3,ink);a.countdown(spout,36,"weak",m.move.start,m.move.end)
	if not live:return
	var land:=Vector2(m.pour_x(),700)
	var bend:=Vector2(spout.x+(land.x-spout.x)*0.2,spout.y-60)
	var stream:PackedVector2Array=a.bezier(spout,bend,land)
	var wobble:float=2*sin(motion*20)
	a.canvas.draw_polyline(stream,a.color("ember",0.55*ink),14+wobble,true)
	a.canvas.draw_polyline(stream,a.color("molten",0.9*ink),7,true)
	a.canvas.draw_polyline(stream,a.color("core",0.7*ink),2.5,true)
	a.glow(land,50,"molten",0.5*ink)

## Iron palm: the reaching fist with a molten socket between two deflecting knuckle bars.
func palm(ink:float) -> void:
	if not m.palm_live():return
	var x:float=m.palm_x();var y:=Forge.PALM_Y
	for span in [[-78,-22],[22,78]]:
		var rect:=Rect2(x+span[0]-4,y+4-13,span[1]-span[0]+8,26)
		a.c._rounded(rect,a.color("iron",ink),a.color("ironEdge",ink),12)
	a.glow(Vector2(x,y),60,"molten",0.5*ink)
	a.circle(Vector2(x,y),22,"soot",ink);a.circle(Vector2(x,y),15,"molten",(0.7+0.3*sin(motion*10))*ink)
	a.ring(Vector2(x,y),22,"crack",3,ink)
	var need:int=4 if a.d.rage else 3
	for index in range(need):a.circle(Vector2(x-(need-1)*9+index*18,y-30),4.5,"molten" if index<m.move.hits else "soot",ink)
	a.countdown(Vector2(x,y),32,"weak",m.move.live,m.move.end)

func glob_art(glob:Dictionary,ink:float) -> void:
	if t<glob.born:return
	var at:Vector2=m.glob_point(glob)
	var back:Vector2=m.glob_point({"from":glob.from,"to":glob.to,"born":glob.born+0.08,"flight":glob.flight,"arc":glob.arc})
	a.line(back,at,"ember",12,0.35*ink)
	a.glow(at,46,"ember",0.4*ink);a.circle(at,Forge.GLOB_RADIUS*0.75,"molten",ink);a.circle(at+Vector2(-4,-4),7,"core",ink)
	a.ring(at,Forge.GLOB_RADIUS,"crack",2,0.8*ink)
