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

func _init(simulation: RefCounted) -> void:owner=weakref(simulation)
func reset() -> void:particles.clear();rings.clear();bolts.clear();texts.clear();signatures.clear();beams.clear();cooldowns.clear();shake=0;flash=0

func brick_color(type: String) -> Color:
	return Color(g.content.palette(g.theme).brick.get(type,"#dce2d0"))

func burst(point: Vector2, ink: Color, count: int=16, force: float=1) -> void:
	count=mini(count,5) if g.reduced else ceili(count*0.55)
	for index in range(count):
		var angle=g.visual_rng.randf()*TAU
		var velocity=Vector2.from_angle(angle)*(1+g.visual_rng.randf()*5)*force
		particles.append({"position":point,"velocity":velocity*60-Vector2(0,60),"life":g.visual_rng.randf_range(0.5,0.9),"size":g.visual_rng.randf_range(2,7),"color":ink,"rotation":g.visual_rng.randf()*TAU})
	if particles.size()>300:particles=particles.slice(particles.size()-300)

func ring(point: Vector2, ink: Color, radius: float=90) -> void:
	for item in rings:
		if radius<260 and item.color==ink and item.life>0.48 and absf(item.radius-radius)<24 and item.position.distance_to(point)<24:item.energy=minf(2,item.energy+0.2);return
	rings.append({"position":point,"color":ink,"radius":radius,"life":0.55,"max":0.55,"energy":1.0})
	if rings.size()>48:rings.pop_front()

func floating(point: Vector2, text: String, ink: Color=Color("#48652c"), size: int=17) -> void:
	texts.append({"position":point,"text":text,"color":ink,"size":size,"life":1.05})
	if texts.size()>48:texts.pop_front()

func bolt(start: Vector2, finish: Vector2) -> void:
	bolts.append({"start":start,"finish":finish,"life":0.4})
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
	for particle in particles:
		particle.position+=particle.velocity*delta;particle.velocity.y+=420*delta;particle.life-=delta;particle.rotation+=delta*3
	particles=particles.filter(func(p):return p.life>0)
	for text in texts:text.position.y-=delta*25;text.life-=delta
	texts=texts.filter(func(p):return p.life>0)
	for item in rings:item.life-=delta
	rings=rings.filter(func(p):return p.life>0)
	for item in bolts:item.life-=delta
	bolts=bolts.filter(func(p):return p.life>0)
	signatures=signatures.filter(func(p):return g.time-p.born<p.duration)
	beams=beams.filter(func(p):return g.time-p.born<p.duration)
	shake=maxf(0,shake-delta*28);flash=maxf(0,flash-delta*1.4)
