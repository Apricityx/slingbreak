extends SceneTree
## Invalidation coverage for native vector display-list reuse during live play.
const Main=preload("res://src/main.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func settle() -> void:
	await process_frame
	await process_frame

func run() -> void:
	var app:=Main.new();app.set_meta("test_mode",true);root.add_child(app)
	app.audio.shutdown();app.interface._close_all()
	var g=app.session.runtime
	g.phase="ready";g.board_entrance=null;g.state.skills={};g.state.skillChosenLevel=g.state.level
	var board:Node2D=app.arena.board
	await settle()
	var brick:RefCounted=g.bricks[0]
	var node:Node2D=board.retained[brick]
	var draws:=[0]
	node.draw.connect(func():draws[0]+=1)
	await settle()
	check(draws[0]==0,"unchanged brick reuses vector display list")
	brick.hp-=.5;await settle()
	check(draws[0]==1,"damage invalidates HP and crack geometry")
	brick.flash=.15;await settle()
	check(draws[0]==2,"impact flash invalidates the retained face")
	brick.flash=.10;await settle()
	check(draws[0]==3,"flash decay retains display cadence")
	brick.frozen=true;await settle()
	check(draws[0]==4,"freeze border invalidates the retained face")
	brick.flags.markUntil=g.time+.05;await settle()
	check(draws[0]==5,"mark starts on retained brick")
	g.time+=.1;await settle()
	check(draws[0]==6,"mark expiry invalidates without a physics mutation")
	g.theme="dark";await settle()
	check(draws[0]==7,"palette switch invalidates the retained face")
	brick.position+=Vector2(7,4);await settle()
	check(draws[0]==8,"moving targets update bounds")
	g.board_entrance={"start":g.presentation_time};await settle()
	var before:int=draws[0];g.presentation_time+=.08;await settle()
	check(draws[0]>before,"entrance pose invalidates at presentation cadence")
	before=draws[0];g.board_entrance.start-=.04;await settle()
	check(draws[0]>before,"restarted entrance invalidates at the same presentation time")
	g.board_entrance=null;await settle()
	g.obstacles.reverse();g.bricks.reverse();await settle()
	var ordered:=true;var index:=0
	for wall in g.obstacles:
		ordered=ordered and board.retained[wall].get_index()==index;index+=1
	for target in g.bricks:
		if target.type=="scale":continue
		ordered=ordered and board.retained[target].get_index()==index;index+=1
	check(ordered,"live target reordering preserves obstacles before bricks")
	g.phase="draft";await settle()
	check(not board.masonry.visible,"draft hides retained battlefield")
	g.phase="ready";await settle()
	check(board.masonry.visible,"returning to play restores retained battlefield")
	g.bricks.erase(brick);await settle()
	check(not board.retained.has(brick) and not is_instance_valid(node),"destroyed brick removes its retained node")
	var previous:Array=board.retained.values()
	g.generate();g.phase="ready";g.board_entrance=null;await settle()
	check(previous.all(func(item):return not is_instance_valid(item)) and board.retained.has(g.bricks[0]),"new generation retires old display lists and shows new targets")
	brick=g.bricks[0];brick.type="bomb";await settle();node=board.retained[brick]
	var mesh_draws:=[0];node.draw.connect(func():mesh_draws[0]+=1)
	var bundle:Resource=board.signatures.meshes.get("blast")
	check(bundle!=null and not node.get_meta("stroke_meshes",[]).is_empty(),"retained glyph owns its mesh bundle beyond cache lifetime")
	board.signatures.meshes.erase("blast");board.signatures.mesh_order.erase("blast")
	await settle()
	check(mesh_draws[0]>0,"eviction invalidates retained mesh glyph without a gameplay mutation")
	while "blast" in board.signatures.pending:await process_frame;board.signatures.collect()
	await settle()
	check(board.signatures.meshes.has("blast") and not node.get_meta("stroke_meshes",[]).is_empty(),"async mesh readiness invalidates fallback glyph and restores retained mesh")
	app.queue_free();await process_frame
	print("Native retained rendering: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
