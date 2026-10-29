extends RefCounted
## Bounded native presentation state. Visual randomness never advances gameplay.
var owner: WeakRef
var g: RefCounted:
	get:return owner.get_ref()
var particles: Array = []
var rings: Array = []
var bolts: Array = []
var texts: Array = []
var signatures: Array = []
var beams: Array = []
var shake := 0.0
var flash := 0.0
var cooldowns: Dictionary = {}
var visual_time := 0.0
var bolt_serial := 0
var particle_cursor:=0

func _init(simulation: RefCounted) -> void:owner=weakref(simulation)
func reset() -> void:particles.clear();particle_cursor=0;rings.clear();bolts.clear();texts.clear();signatures.clear();beams.clear();cooldowns.clear();shake=0;flash=0;visual_time=0;bolt_serial=0

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

func ring(point: Vector2, ink: Color, radius: float=90) -> void:
	for item in rings:
		if radius<260 and item.color==ink and item.life>0.48 and absf(item.radius-radius)<24 and item.position.distance_to(point)<24:item.energy=minf(2,item.energy+0.2);return
	rings.append({"position":point,"color":ink,"radius":radius,"life":0.55,"max":0.55,"energy":1.0,"display_energy":1.0})
	if rings.size()>48:rings.pop_front()

func floating(point: Vector2, text: String, ink: Color=Color("#48652c"), size: int=17) -> void:
	# A volley keeps one growing income tally per arrow, as in juice.js.
	var arrow:RefCounted=g.active_arrow
	var tally:=arrow!=null and text.begins_with("+") and text.substr(1).is_valid_int()
	var anchor:=point-Vector2(0,26) if tally else point
	if tally:
		for item in texts:
			if item.get("arrow",-1)==arrow.id and item.life>0.35:
				item.total+=int(text);item.text="+%d" % item.total;item.count+=1
				item.target=anchor;item.rise=0.0;item.life=1.25;item.pop=maxf(item.pop,1.0)
				return
	texts.append({"position":anchor,"target":anchor,"text":text,"color":ink,"size":size,"life":1.25 if tally else 1.05,"arrow":arrow.id if tally else -1,"total":int(text) if tally else 0,"count":1,"pop":1.0,"display_pop":0.0,"display_count":1.0,"rise":0.0})
	if texts.size()>48:texts.pop_front()

func bolt(start: Vector2, finish: Vector2) -> void:
	bolt_serial+=1
	bolts.append({"start":start,"finish":finish,"life":0.4,"phase":bolt_serial*13.0})
	if bolts.size()>64:bolts.pop_front()

func signature(id: String, point: Vector2, radius: float=75, duration: float=-1) -> void:
	if not g.content.by_id.has(id):return
	if g.time-cooldowns.get(id,-INF)<0.085:return
	cooldowns[id]=g.time
	var profile:Dictionary=g.content.effect_profiles[id]
	signatures.append({"id":id,"position":point,"radius":radius,"born":g.time,"duration":profile.duration if duration<0 else duration,"color":Color(profile.color),"accent":Color(profile.accent),"kind":profile.kind})
	if signatures.size()>80:signatures.pop_front()
	if g.state.skills.has(id):g.stats.skills[id]=g.stats.skills.get(id,0)+1

func beam(id: String, start: Vector2, finish: Vector2, width: float=5, duration: float=0.6) -> void:
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
	if particle_cursor>0:
		# At most one reorder per display frame, never once per burst. This
		# keeps oldest-first expiry and alpha-over ordering after wraparound.
		particles=particles.slice(particle_cursor)+particles.slice(0,particle_cursor);particle_cursor=0
	for brick in g.bricks:brick.flash=maxf(0,brick.flash-delta)
	for wall in g.obstacles:wall.flash=maxf(0,wall.flash-delta)
	var alive:=0
	for particle in particles:
		particle.age+=delta;particle.life=particle.max-particle.age
		particle.position=particle.origin+particle.velocity*particle.age+Vector2(0,210*particle.age*particle.age)
		particle.rotation=particle.initial_rotation+particle.age*3
		if particle.life>0:particles[alive]=particle;alive+=1
	particles.resize(alive)
	if alive<300:particle_cursor=0
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
