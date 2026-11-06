extends RefCounted
## Bounded native presentation state. Visual randomness never advances gameplay.
var owner: WeakRef
var g: RefCounted:
	get:return owner.get_ref()
var particles: Array = []
var trail_remnants: Array = []
var rings: Array = []
var bolts: Array = []
var texts: Array = []
var income:=preload("res://src/effects/income_tallies.gd").new()
var signatures: Array = []
var beams: Array = []
var skill_events: Array = []
var specials: Array = []
var explosions: Array = []
var normal_breaks: Array = []
var bombs: Array = []
var shake := 0.0
var flash := 0.0
var cooldowns: Dictionary = {}
var visual_time := 0.0
var bolt_serial := 0
var particle_cursor:=0
var special_serial:=0
var skill_event_serial:=0

# The signature/trail family is the remaining v1 skill presentation. Keep the
# simulation and audio active while the v2 skill art is being rebuilt.
const SKILL_V1_EFFECTS_VISIBLE:=false

func skill_v1_effects_visible() -> bool:return SKILL_V1_EFFECTS_VISIBLE

func _init(simulation: RefCounted) -> void:owner=weakref(simulation)
func reset() -> void:
	particles.clear();trail_remnants.clear();particle_cursor=0;rings.clear();bolts.clear();texts.clear();signatures.clear();beams.clear();skill_events.clear();specials.clear();explosions.clear();normal_breaks.clear();bombs.clear();cooldowns.clear();shake=0;flash=0;visual_time=0;bolt_serial=0;special_serial=0;skill_event_serial=0
	income.items.clear()

func brick_color(type: String) -> Color:
	return Color(g.content.palette(g.theme).brick.get(type,"#dce2d0"))

func burst(point: Vector2, ink: Color, count: int=16, force: float=1) -> void:
	count=mini(count,5) if g.reduced else ceili(count*0.55)
	for index in range(count):
		var angle=g.visual_rng.randf()*TAU
		var velocity=Vector2.from_angle(angle)*(1+g.visual_rng.randf()*5)*force
		var lifetime:float=g.visual_rng.randf_range(0.5,0.9)
		var rotation:float=g.visual_rng.randf()*TAU
		var particle:Dictionary={"position":point,"origin":point,"velocity":velocity*60-Vector2(0,60),"age":0.0,"life":lifetime,"max":lifetime,"size":g.visual_rng.randf_range(2,7),"color":ink,"rotation":rotation,"initial_rotation":rotation}
		if particles.size()<300:particles.append(particle)
		else:
			# Reuse the oldest slot without copying a full 300-entry Array for
			# every brick in a chain reaction. RNG consumption stays unchanged.
			particles[particle_cursor]=particle;particle_cursor=(particle_cursor+1)%300

func linger_trail(arrow: RefCounted) -> void:
	if arrow.trail.is_empty():return
	# Keep presentation data only, never the damage/source/achievement graph.
	var ghost:=preload("res://src/core/projectile.gd").new()
	ghost.id=arrow.id;ghost.position=arrow.position;ghost.velocity=arrow.velocity
	ghost.visual=arrow.visual;ghost.trail=arrow.trail.duplicate()
	ghost.flags={"trailIndex":g.arrows.find(arrow),"trailCrowded":g.arrows.size()>24}
	ghost.reset_display()
	trail_remnants.append({"arrow":ghost,"life":0.5,"max":0.5})
	if trail_remnants.size()>64:trail_remnants.pop_front()

func arrow_break(point: Vector2, flight: Vector2, primary: Color, accent: Color, force: float=1) -> void:
	# Reconstruct the actual shaft/head/fletching at birth, then explode those
	# pieces outwards. Random rectangles/faded particles lose the silhouette
	# immediately and still look like the arrow was simply removed.
	var direction:=flight.normalized() if flight.length_squared()>0.01 else Vector2.UP
	var angle:=direction.angle()
	var pieces:Array=[]
	var shaft_count:=3 if g.reduced else 6
	for index in range(shaft_count):
		var start:=lerpf(-29,4,index/float(shaft_count))
		var finish:=lerpf(-29,4,(index+1)/float(shaft_count))
		pieces.append({"points":PackedVector2Array([Vector2(start,-1.15),Vector2(finish,-1.15),Vector2(finish,1.15),Vector2(start,1.15)]),"color":primary})
	# Two halves of the original arrowhead, not a generic spark at its centre.
	for side in [-1,1]:
		pieces.append({"points":PackedVector2Array([Vector2(10,0),Vector2(0,side*4),Vector2.ZERO]),"color":primary})
		var start:=Vector2(-23,0)
		var finish:=Vector2(-29,side*4)
		var edge:Vector2=(finish-start).normalized().orthogonal()
		pieces.append({"points":PackedVector2Array([start-edge,finish-edge,finish+edge,start+edge]),"color":accent})
	for index in range(pieces.size()):
		var polygon:PackedVector2Array=pieces[index].points
		var center:=Vector2.ZERO
		for vertex in polygon:center+=vertex
		center/=polygon.size()
		for vertex in range(polygon.size()):polygon[vertex]-=center
		var body_point:=point+center.rotated(angle)
		var radial:=Vector2((center.x+10)*0.45,(-1 if index%2==0 else 1)*g.visual_rng.randf_range(9,18)).normalized()
		# Damage scale can be exponential; never let it fling debris offscreen.
		var velocity:Vector2=radial.rotated(angle)*g.visual_rng.randf_range(155,235)*clampf(force,1,1.4)+flight.limit_length(18)*2
		var lifetime:float=g.visual_rng.randf_range(0.65,0.85)
		var spin:float=g.visual_rng.randf_range(5,10)*(-1 if index%2==0 else 1)
		var particle:Dictionary={"position":body_point,"origin":body_point,"velocity":velocity,"age":0.0,"life":lifetime,"max":lifetime,"size":2.3,"polygon":polygon,"spin":spin,"color":pieces[index].color,"rotation":angle,"initial_rotation":angle}
		if particles.size()<300:particles.append(particle)
		else:particles[particle_cursor]=particle;particle_cursor=(particle_cursor+1)%300
	ring(point-direction*10,accent,48)

func special_break(point: Vector2, type: String, intensity: float=1.0, depth: int=0) -> void:
	# Lightning requires real hop endpoints, emitted by Simulation.hit().
	# There is no independent radial/source impact for an electric brick.
	if type=="lightning":return
	if type=="bomb":
		bomb_blast(point,132.0,intensity)
		return
	# One bounded event replaces a node/particle system for every special brick.
	# The renderer chooses a distinct silhouette while this queue stays cheap.
	if g.reduced and depth>2:return
	special_serial+=1
	var color:=brick_color(type)
	var accent:=Color(g.content.palette(g.theme).brickInk.get(type,"#ffffff"))
	var duration:float=0.56 if type=="frost" else 0.58 if type=="gold" else 0.72 if not g.reduced else 0.48
	var event:Dictionary={"position":point,"type":type,"born":visual_time,"life":duration,"max":duration,"intensity":clampf(intensity,0.65,1.5),"seed":special_serial*1.618,"color":color,"accent":accent}
	if type=="frost":event.radius=190.0 if g.rank("blizzard") else 140.0
	# Chain reactions can produce many hits in one simulation tick. Keep the
	# most recent impacts and let the draw pass remain a fixed-size workload.
	if specials.size()<48:specials.append(event)
	else:specials[special_serial%48]=event

func frozen_target(point: Vector2, radius: float=42.0) -> void:
	# A separate short beat makes each affected brick read as a target of the
	# frost wave, rather than only inheriting a static frozen flag.
	special_serial+=1
	var duration:float=0.58 if not g.reduced else 0.38
	var event:Dictionary={"position":point,"type":"ice_shards","born":visual_time,"life":duration,"max":duration,"intensity":clampf(radius/42.0,0.65,1.5),"seed":special_serial*1.618,"color":Color("#bfeefa"),"accent":Color("#ffffff")}
	if specials.size()<48:specials.append(event)
	else:specials[special_serial%48]=event

func normal_break(point: Vector2, color: Color, intensity: float=1.0, size: Vector2=Vector2(76,36), heading: Vector2=Vector2.UP) -> void:
	# One GPU instance per break (flash, grid fragments, sparks, shock arc).
	# No CPU particles or rings, so dense chains stay one batched draw.
	special_serial+=1
	var event:Dictionary={"position":point,"born":visual_time,"life":0.5,"seed":special_serial,"color":color,"intensity":clampf(intensity,0.75,1.35),"size":size,"heading":heading.normalized() if heading.length_squared()>0.01 else Vector2.UP}
	if normal_breaks.size()<72:normal_breaks.append(event)
	else:normal_breaks[special_serial%72]=event

func bomb_blast(point:Vector2,radius:float=132.0,intensity:float=1.0) -> void:
	# One GPU instance per bomb: flash, fireball, shock ring drawn at the real
	# damage radius, jets, casing chunks, embers and smoke in one batched draw.
	special_serial+=1
	var event:Dictionary={"position":point,"radius":radius,"born":visual_time,"seed":special_serial,"intensity":clampf(intensity,0.65,1.0)}
	if bombs.size()<16:bombs.append(event)
	else:bombs[special_serial%16]=event
	shake=maxf(shake,7.0*intensity)

func explosion(point:Vector2,radius:float=132.0,intensity:float=1.0) -> void:
	special_serial+=1
	explosions.append({"position":point,"radius":radius,"born":visual_time,"seed":special_serial*1.618,"intensity":clampf(intensity,0.65,1.0)})
	if explosions.size()>16:explosions.pop_front()
	shake=maxf(shake,6.0*intensity)

func skill_event(id:String, point:Vector2, direction:Vector2=Vector2.UP, target:Vector2=Vector2.ZERO, strength:float=1.0, duration:float=0.5) -> void:
	# Skill events are presentation-only; they never infer or mutate gameplay state.
	skill_event_serial+=1
	var color:=Color(g.content.by_id[id].color) if g.content.by_id.has(id) else Color("#8aa79e")
	var accent:=Color(g.content.effect_profiles[id].accent) if g.content.effect_profiles.has(id) else Color("#f4f0cf")
	var event:Dictionary={"id":id,"position":point,"direction":direction.normalized() if direction.length_squared()>0.001 else Vector2.UP,"target":target,"born":visual_time,"life":duration,"max":duration,"strength":clampf(strength,0.55,1.2),"seed":skill_event_serial*1.618,"color":color,"accent":accent}
	if skill_events.size()<64:skill_events.append(event)
	else:skill_events.pop_front();skill_events.append(event)

func skill_batch_eight(id:String, point:Vector2, targets:PackedVector2Array=PackedVector2Array(), outcome:float=1.0) -> void:
	skill_event(id,point,Vector2.UP,Vector2.ZERO,1.0,{"nova":0.62,"crossfire":0.48,"jackpot":0.72,"supernova":0.96}[id])
	# Copy positions only: deleted bricks and source arrows never stay alive for art.
	skill_events.back().targets=targets.slice(0,48)
	skill_events.back().outcome=outcome

func ring(point: Vector2, ink: Color, radius: float=90) -> void:
	for item in rings:
		if radius<260 and item.color==ink and item.life>0.48 and absf(item.radius-radius)<24 and item.position.distance_to(point)<24:item.energy=minf(2,item.energy+0.2);return
	rings.append({"position":point,"color":ink,"radius":radius,"life":0.55,"max":0.55,"energy":1.0,"display_energy":1.0})
	if rings.size()>48:rings.pop_front()

func floating(point: Vector2, text: String, ink: Color=Color("#48652c"), size: int=17) -> void:
	# Generic skill/bonus messages must never be parsed as brick income.
	texts.append({"position":point,"target":point,"text":text,"color":ink,"size":size,"life":1.05,"arrow":-1,"total":0,"count":1,"pop":1.0,"display_pop":0.0,"display_count":1.0,"rise":0.0})
	if texts.size()>48:texts.pop_front()

func brick_income(point:Vector2,amount:float) -> void:
	var arrow:RefCounted=g.active_arrow
	income.record(point,amount,arrow.id if arrow!=null else -1,arrow.kills if arrow!=null else 1,g.cap_kills())

func bolt(start: Vector2, finish: Vector2) -> void:
	bolt_serial+=1
	bolts.append({"start":start,"finish":finish,"life":0.4,"phase":bolt_serial*13.0})
	if bolts.size()>64:bolts.pop_front()

func skill_bolt(start: Vector2, finish: Vector2) -> void:
	if not SKILL_V1_EFFECTS_VISIBLE:return
	bolt(start,finish)

func signature(id: String, point: Vector2, radius: float=75, duration: float=-1) -> void:
	if not SKILL_V1_EFFECTS_VISIBLE:return
	if not g.content.by_id.has(id):return
	if g.time-cooldowns.get(id,-INF)<0.085:return
	cooldowns[id]=g.time
	var profile:Dictionary=g.content.effect_profiles[id]
	signatures.append({"id":id,"position":point,"radius":radius,"born":g.time,"duration":profile.duration if duration<0 else duration,"color":Color(profile.color),"accent":Color(profile.accent),"kind":profile.kind})
	if signatures.size()>80:signatures.pop_front()
	if g.state.skills.has(id):g.stats.skills[id]=g.stats.skills.get(id,0)+1

func beam(id: String, start: Vector2, finish: Vector2, width: float=5, duration: float=0.6) -> void:
	if not SKILL_V1_EFFECTS_VISIBLE:return
	beams.append({"id":id,"start":start,"finish":finish,"width":width,"born":g.time,"duration":duration,"color":Color(g.content.by_id[id].color)})
	if beams.size()>96:beams.pop_front()

func update(delta: float) -> void:
	# Skill-owned effects remain on gameplay time for this migration stage.
	var alive:=0
	for item in signatures:
		if g.time-item.born<item.duration:signatures[alive]=item;alive+=1
	signatures.resize(alive)
	alive=0
	for item in beams:
		if g.time-item.born<item.duration:beams[alive]=item;alive+=1
	beams.resize(alive)

func advance_visual(delta: float) -> void:
	visual_time+=delta
	income.advance(delta)
	var live_trails:=0
	for remnant in trail_remnants:
		remnant.life-=delta
		if remnant.life>0:trail_remnants[live_trails]=remnant;live_trails+=1
	trail_remnants.resize(live_trails)
	var live_explosions:=0
	for event in explosions:
		if visual_time-event.born<1.4:explosions[live_explosions]=event;live_explosions+=1
	explosions.resize(live_explosions)
	var live_bombs:=0
	for event in bombs:
		if visual_time-event.born<1.1:bombs[live_bombs]=event;live_bombs+=1
	bombs.resize(live_bombs)
	var live_skill_events:=0
	for event in skill_events:
		if visual_time-event.born<event.life:skill_events[live_skill_events]=event;live_skill_events+=1
	skill_events.resize(live_skill_events)
	if particle_cursor>0:
		# At most one reorder per display frame, never once per burst. This
		# keeps oldest-first expiry and alpha-over ordering after wraparound.
		particles=particles.slice(particle_cursor)+particles.slice(0,particle_cursor);particle_cursor=0
	for brick in g.bricks:brick.flash=maxf(0,brick.flash-delta)
	for wall in g.obstacles:wall.flash=maxf(0,wall.flash-delta)
	var alive:=0
	for particle in particles:
		particle.age+=delta;particle.life=particle.max-particle.age
		if particle.has("polygon"):
			# Fast initial separation followed by drag gives the explosion a
			# readable hang time. Preserve opacity until the final fade beat.
			particle.position=particle.origin+particle.velocity*(1-exp(-5*particle.age))/5+Vector2(0,55*particle.age*particle.age)
			particle.rotation=particle.initial_rotation+particle.age*particle.spin
		else:
			particle.position=particle.origin+particle.velocity*particle.age+Vector2(0,210*particle.age*particle.age)
			particle.rotation=particle.initial_rotation+particle.age*3
		if particle.life>0:particles[alive]=particle;alive+=1
	particles.resize(alive)
	if alive<300:particle_cursor=0
	alive=0
	for item in specials:
		item.life-=delta
		if item.life>0:specials[alive]=item;alive+=1
	specials.resize(alive)
	alive=0
	for item in normal_breaks:
		if visual_time-item.born<item.life:normal_breaks[alive]=item;alive+=1
	normal_breaks.resize(alive)
	alive=0
	for text in texts:
		text.life-=delta;text.pop=maxf(0,text.pop-delta*5)
		text.display_pop=lerpf(text.display_pop,text.pop,1-exp(-delta*28))
		text.display_count=lerpf(text.display_count,float(text.count),1-exp(-delta*18))
		text.rise+=delta*(40 if text.arrow>=0 and text.life<0.5 else 0 if text.arrow>=0 else 25)
		text.position=text.position.lerp(text.target-Vector2(0,text.rise),1-exp(-delta*12)) if text.arrow>=0 else text.target-Vector2(0,text.rise)
		if text.life>0:texts[alive]=text;alive+=1
	texts.resize(alive)
	alive=0
	for item in rings:
		item.life-=delta;item.display_energy=lerpf(item.display_energy,item.energy,1-exp(-delta*24))
		if item.life>0:rings[alive]=item;alive+=1
	rings.resize(alive)
	alive=0
	for item in bolts:
		item.life-=delta
		if item.life>0:bolts[alive]=item;alive+=1
	bolts.resize(alive)
	shake=maxf(0,shake-delta*28);flash=maxf(0,flash-delta*1.4)
