extends SceneTree
## Compare native numbers to the independent browser-source oracle.
const Sim=preload("res://src/core/simulation.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("_run")
func near(actual:float,expected:float,label:String,tolerance:float=.00001) -> void:
	checks+=1
	if not is_finite(actual) or not is_finite(expected) or absf(actual-expected)>tolerance:failures+=1;push_error("%s: %s != %s" % [label,actual,expected])
func _run() -> void:
	var path:="res://../agent-tmp/godot/reference-rules.json"
	if not FileAccess.file_exists(path):push_error("Run node godot/tools/capture-rules.cjs first");quit(1);return
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var sim:=Sim.new();sim.start(9128)
	sim.state.level=int(reference.level);sim.state.up=reference.up;sim.state.skillRuntime={"level":int(reference.level),"shots":int(reference.shots)}
	for fixture in reference.metrics:
		sim.state.skills={}
		for id in fixture.ids:sim.state.skills[id]=1
		var label:String=str(fixture.ids)
		near(sim.damage(),fixture.damage,label+" damage")
		near(sim.speed(),fixture.speed,label+" speed")
		near(sim.penetration(),fixture.penetration,label+" penetration")
		near(sim.bonus(),fixture.bonus,label+" bonus")
		near(sim.base_hp(),fixture.hp,label+" hp")
		near(sim.draw_interval(),fixture.draw,label+" firing interval")
		for key in fixture.costs:near(sim.cost(key),fixture.costs[key],label+" cost "+key)
		for key in fixture.reward:
			var parts:PackedStringArray=key.split(":")
			near(sim.reward(parts[0],int(parts[1])),fixture.reward[key],label+" reward "+key)
	sim.state.skills={}
	for fixture in reference.free:
		sim.bosses.wind=float(fixture.get("gravityX",0))*pow(1000.0/60.0,2)*0.001
		var arrow:RefCounted=sim.launch(Vector2(390,970),Vector2(fixture.velocity[0],fixture.velocity[1]))
		for at in range(fixture.points.size()):
			var step:float=fixture.steps[at]/1000.0 if fixture.has("steps") else 1.0/60
			sim.integrate(arrow,step)
			var expected:Array=fixture.points[at]
			var label:String=str(fixture.get("name","normal"))+" "+str(fixture.velocity)+" step "+str(at)
			near(arrow.px,expected[0],"Matter x "+label)
			near(arrow.py,expected[1],"Matter y "+label)
			near(arrow.vx,expected[2],"Matter vx "+label)
			near(arrow.vy,expected[3],"Matter vy "+label)
			# Rendering/collision sees one float32 conversion, without stale copies.
			near(arrow.position.x,arrow.px,"Vector2 x "+label,.00025)
			near(arrow.position.y,arrow.py,"Vector2 y "+label,.00025)
	sim.dispose()
	print("Independent native/reference rules: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
