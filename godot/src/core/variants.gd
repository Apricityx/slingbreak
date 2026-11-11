extends RefCounted
## Level-variant host. Every non-boss level runs one rule from ORDER, drawn
## from a shuffled no-repeat deck kept in state.variantDeck; each rule is
## src/core/variants/<id>.gd extending variants/rule.gd. The id and the
## rule's data ride on the saved board, so a restored level keeps its rules.
const ORDER:=["drift","rush","fortress","quiver",
	"banked","bulwark","blink","seal",
	"collapse","domino","mimic","fusion",
	"gale","ballast","carom","hover",
	"wanted","escrow","streak","wager",
	"siege","hourglass","overheat","cadence"]
const ID:="^[a-z]+$"
## Teach visible, forgiving rules before timing, economy and restrictive cores.
const UNLOCK:={"rush":1,"fusion":2,"mimic":3,"collapse":4,"wanted":5,
	"gale":6,"drift":7,"domino":8,"hover":9,"ballast":10,"streak":11,
	"seal":12,"fortress":13,"carom":14,"bulwark":15,"banked":16,"blink":17,
	"siege":18,"hourglass":19,"quiver":20,"overheat":22,"escrow":24,"cadence":26,"wager":28}
var owner:WeakRef
var g:RefCounted:
	get:return owner.get_ref()
var id:=""
var rule:RefCounted=null
var announced:=false
var shown:=""

func _init(simulation:RefCounted) -> void:owner=weakref(simulation)
func reset() -> void:id="";rule=null;announced=false;shown=""

## Next rule from the deck; a fresh shuffle never opens with the last rule.
func draw_next() -> String:
	var deck:Array=g.state.get("variantDeck",[]).filter(func(item):return item in ORDER)
	if deck.is_empty():
		deck=g.shuffle(ORDER.duplicate())
	var available:Array=deck.filter(func(item):return int(g.state.level)>=UNLOCK[item])
	if available.is_empty():available=g.shuffle(ORDER.filter(func(item):return int(g.state.level)>=UNLOCK[item]))
	if available.size()>1 and available[0]==g.state.get("variantLast"):available.push_back(available.pop_front())
	var next:String=available[0]
	deck.erase(next)
	g.state.variantDeck=deck;g.state.variantLast=next
	return next

static func script_for(variant_id:Variant) -> Script:
	if not variant_id is String or variant_id=="rule" or RegEx.create_from_string(ID).search(variant_id)==null:return null
	var path:="res://src/core/variants/%s.gd" % variant_id
	return load(path) if ResourceLoader.exists(path) else null

## Saved board data: a known rule id plus data that rule accepts.
static func valid_saved(saved:Variant) -> bool:
	if not saved is Dictionary:return false
	var script:=script_for(saved.get("id"))
	if script==null:return false
	var data:Dictionary=saved.duplicate();data.erase("id")
	return script.new().valid(data)

func start(saved:Variant,restored:bool) -> void:
	reset()
	if not g.bosses.fight.is_empty():return
	if restored:
		# Boards saved before variants existed simply play as ordinary levels.
		if valid_saved(saved):_make(saved.id);rule.data=saved.duplicate(true);rule.data.erase("id");rule.restored()
		return
	# An override with id "" deliberately plays the level without a rule.
	var override:Variant=g.state.get("variantOverride")
	if override is Dictionary and override.get("level")==g.state.level:
		if script_for(override.get("id"))!=null:_make(override.id)
	elif g.developer.enabled and g.developer.counts.has(str(int(g.state.level))):return
	else:_make(draw_next())
	if rule!=null:rule.shape()

func _make(variant_id:String) -> void:
	id=variant_id;rule=script_for(variant_id).new(g)

func update(delta:float) -> void:
	if rule==null:return
	if not announced and g.phase in ["ready","flying"]:
		announced=true
		g.events.append({"type":"toast","text":"本关 · %s · 顶部查看规则" % rule.title()})
		g.fx.ring(Vector2(390,500),Color(rule.color()),380);g.cue("core")
	rule.update(delta)
	# Timers and physics states change even when no brick is hit. Publish only
	# when the human-readable state changes, not every physics frame.
	var text:String=rule.status()
	if text!=shown:shown=text;g.revision+=1

func on_shoot() -> void:if rule!=null:rule.on_shoot()
func launched(arrow:RefCounted) -> void:if rule!=null:rule.launched(arrow)
func destroyed(brick:RefCounted) -> void:if rule!=null:rule.destroyed(brick)
func bounced(arrow:RefCounted) -> void:if rule!=null:rule.bounced(arrow)
func core_spawned() -> void:if rule!=null:rule.core_spawned()
func core_hit(arrow:RefCounted) -> bool:return rule==null or rule.core_hit(arrow)
func core_note() -> String:return "命中即可清场" if rule==null else rule.core_note()
func damage_scale(brick:RefCounted,arrow:Variant) -> float:return 1.0 if rule==null else rule.damage_scale(brick,arrow)
func reward_scale(brick:RefCounted) -> float:return 1.0 if rule==null else rule.reward_scale(brick)
func bonus_scale() -> float:return 1.0 if rule==null else rule.bonus_scale()
func threshold_scale() -> float:return 1.0 if rule==null else rule.threshold_scale()
func gravity_scale() -> float:return 1.0 if rule==null else rule.gravity_scale()
func wind() -> float:return 0.0 if rule==null else rule.wind()
func interval_scale() -> float:return 1.0 if rule==null else rule.interval_scale()
func draw(canvas:CanvasItem) -> void:if rule!=null:rule.draw(canvas)

func status() -> Variant:
	if rule==null:return null
	var suffix:String=rule.status()
	return {"id":id,"name":rule.title(),"note":rule.note(),"color":rule.color(),"status":suffix,"seen":id in g.state.get("variantSeen",[]),"coreNote":rule.core_note(),"coreBlocked":rule.core_blocked(),"coreProgress":rule.core_progress(),"text":rule.title()+(" · "+suffix if suffix!="" else "")}

func summary() -> Dictionary:
	var items:Array=rule.summary().duplicate()
	if not is_equal_approx(rule.bonus_scale(),1.0):items.append("奖金 ×%s" % String.num(rule.bonus_scale(),2))
	return {"title":"变体关 · "+rule.title(),"items":items}

func serialize() -> Dictionary:
	var result:Dictionary=rule.data.duplicate(true);result.id=id
	return result
