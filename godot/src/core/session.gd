class_name SlingSession
extends RefCounted
## Godot simulation and persistence boundary. JSON is used for files only.
signal failed(message: String)
signal changed(frame: Dictionary)
signal sound_requested(voices: Array)
signal events_received(events: Array)
const Simulation=preload("res://src/core/simulation.gd")
const Progress=preload("res://src/core/progress.gd")
const SAVE="user://slingbreak-progress.json"
const SETTINGS="user://slingbreak-settings.json"
var runtime: RefCounted
var frame: Dictionary={}
var catalog: Array=[]
var error:=""
var ready:=false
var presented_revision:=-1
var save_thread:Thread
var queued_save:=""
var save_path:=SAVE

func poll_save() -> void:
	if save_thread!=null and not save_thread.is_alive():
		var ok:bool=save_thread.wait_to_finish();save_thread=null
		if not ok:failed.emit("无法写入游戏进度")
	if save_thread==null and queued_save!="":
		var payload:=queued_save;queued_save=""
		# The Chromium-89 web template is deliberately single-threaded.
		if OS.has_feature("web"):
			if not _write_save(payload,save_path):failed.emit("无法写入游戏进度")
			return
		save_thread=Thread.new()
		if save_thread.start(_write_save.bind(payload,save_path))!=OK:
			save_thread=null
			if not _write_save(payload,save_path):failed.emit("无法写入游戏进度")

func request_save() -> void:
	if not ready:return
	# Serialize only main-thread state. Disk writes, flush and atomic rename
	# run off the animation thread; pending requests coalesce to the latest save.
	queued_save=JSON.stringify(runtime.export_progress());poll_save()

func finish_save() -> void:
	if save_thread!=null:
		var ok:bool=save_thread.wait_to_finish();save_thread=null
		if not ok:failed.emit("无法写入游戏进度")
	if queued_save!="":
		if not _write_save(queued_save,save_path):failed.emit("无法写入游戏进度")
		queued_save=""

static func _write_save(payload:String,path:String) -> bool:
	var file:=FileAccess.open(path+".pending",FileAccess.WRITE)
	if file==null:return false
	file.store_string(payload);file.flush();file.close()
	return DirAccess.rename_absolute(path+".pending",path)==OK

func start(seed_value: int=1, progress: Dictionary={}) -> bool:
	if not progress.is_empty() and not Progress.valid(progress):return _fail("Invalid progress")
	finish_save()
	if runtime!=null:runtime.dispose()
	runtime=Simulation.new()
	var preferences=JSON.parse_string(FileAccess.get_file_as_string(SETTINGS)) if FileAccess.file_exists(SETTINGS) else {}
	runtime.start(seed_value,progress,preferences if preferences is Dictionary else {})
	catalog=runtime.content.catalog
	ready=true;error="";presented_revision=-1
	_accept()
	return true

func update(delta: float) -> void:
	if not ready:return
	runtime.update(delta)
	if runtime.revision!=presented_revision or runtime.phase in ["entering","clearing"] or runtime.wipe!=null or runtime.drag!=null:_accept()
	else:_events()

func command(method: String, input: Dictionary={}) -> Variant:
	if not ready:return null
	var result=call_method(method,input)
	_accept()
	return result

func call_method(method: String,input: Dictionary={}) -> Variant:
	if runtime==null:return null
	match method:
		"developerTap":
			runtime.developer.tap(Time.get_ticks_msec());runtime.revision+=1
			if runtime.developer.unlocked:save_settings()
			return {"unlocked":runtime.developer.unlocked}
		"developer":
			var accepted:bool=runtime.developer.apply(runtime,input)
			if accepted:save_settings()
			return {"accepted":accepted}
		"shoot":return {"accepted":runtime.shoot(float(input.get("dx",0)),float(input.get("dy",0)))}
		"seenVariant":
			var id:String=runtime.variants.id
			if id!="":
				if not runtime.state.has("variantSeen"):runtime.state.variantSeen=[]
				if not id in runtime.state.variantSeen:runtime.state.variantSeen.append(id)
		"choose":return {"accepted":runtime.choose(input.get("id",""))}
		"holdEntrance":
			if runtime.phase=="entering":runtime.entrance_held=true;runtime.board_entrance={"start":runtime.time+3600,"end":runtime.time+3600.85}
		"landEntrance":
			if runtime.phase=="entering":runtime.entrance_held=false;runtime.board_entrance={"start":runtime.time,"end":runtime.time+0.85}
		"buy":return {"accepted":runtime.buy(input.get("key",""),input.get("node",""))}
		"pause":runtime.paused=input.get("paused",false);runtime.drag=null
		"drag":runtime.drag={"dx":float(input.get("dx",0)),"dy":float(input.get("dy",0))} if input.get("active",false) else null
		"pointer":runtime.pointer=Vector2(input.get("x",0),input.get("y",0)) if input.get("active",false) and not input.get("touch",false) else null
		"keyboard":runtime.keyboard_angle=input.get("angle",0);runtime.keyboard_power=input.get("power",0.85)
		"cue":runtime.cue(input.get("type","tap"),int(input.get("n",1)),float(input.get("x",390)),false,input.get("ui",true))
		"reroll":
			if runtime.phase!="draft" or runtime.paused or runtime.state.rerolls<=0:return {"accepted":false}
			var old:Dictionary=runtime.state.draft
			runtime.state.rerolls-=1
			runtime.state.draft={"level":runtime.state.level,"options":runtime.roll(old.options),"rerolled":old.get("rerolled",0)+1}
			return {"accepted":true}
		"offerSwap":
			var target:String=input.get("id","")
			if runtime.phase!="ready" or not runtime.rank(target) or runtime.state.rerolls<=0:return {"offer":null}
			var previous:Array=[]
			if runtime.state.swapOffer is Dictionary and runtime.state.swapOffer.target==target:previous=runtime.state.swapOffer.options
			runtime.state.rerolls-=1
			runtime.state.swapOffer={"level":runtime.state.level,"target":target,"options":runtime.roll(previous)}
			return {"offer":runtime.state.swapOffer}
		"swap":
			var offer:Variant=runtime.state.swapOffer
			var target:String=input.get("target","");var id:String=input.get("id","")
			if runtime.phase!="ready" or not offer is Dictionary or offer.level!=runtime.state.level or offer.target!=target or not id in offer.options or not runtime.rank(target) or runtime.rank(id):return {"accepted":false}
			var queue:Dictionary={}
			for key in runtime.state.skills:queue[id if key==target else key]=1
			runtime.state.skills=queue;runtime.state.swapOffer=null;runtime.apply_passives();runtime.cue("upgrade")
			return {"accepted":true}
		"predict":return runtime.predict(Vector2(input.x,input.y),Vector2(input.vx,input.vy),input.get("distance",720))
		"skipClear":
			if runtime.phase=="clearing" and runtime.clock-runtime.clear_shown_at>0.7:runtime.clear_at=minf(runtime.clear_at,runtime.time+0.05)
		"exportProgress":return runtime.export_progress()
		"importProgress":return {"accepted":Progress.valid(input)}
		"jump":
			if not Progress.finite_number(input.get("level"),1,100000,true):return false
			runtime.state.level=int(input.level);runtime.state.board=null;runtime.state.bossOverride=null;runtime.generate()
		"enterBoss":
			if not input.get("id") in ["eye","forge","serpent","clock"]:return {"accepted":false}
			runtime.state.bossOverride={"level":runtime.state.level,"boss":input.id};runtime.state.board=null;runtime.generate();runtime.state.skillChosenLevel=runtime.state.level;runtime.state.draft=null;runtime.phase="ready"
			return {"accepted":true}
		"configure":
			if input.get("theme") in ["system","light","dark"]:runtime.theme_mode=input.theme;runtime.resolve_theme()
			if input.has("volume") and Progress.finite_number(input.volume,0,100,true):runtime.state.volume=int(input.volume);runtime.state.sound=input.volume>0
			if input.get("performanceMode") is bool:runtime.state.performanceMode=input.performanceMode
		"reset":
			runtime.reset_progress()
		"boot","snapshot":return runtime.snapshot()
		_:return null
	runtime.revision+=1
	return runtime.snapshot()

func save() -> bool:
	if not ready:return false
	finish_save()
	return _write_save(JSON.stringify(runtime.export_progress()),save_path)

func save_settings() -> void:
	var file:=FileAccess.open(SETTINGS,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify({"theme":runtime.theme_mode,"developer":runtime.developer.config()}));file.close()

func load_progress() -> Dictionary:
	finish_save()
	if not FileAccess.file_exists(save_path):return {}
	var value=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	return value if value is Dictionary and Progress.valid(value) else {}

func import_progress(progress: Dictionary) -> bool:
	if not Progress.valid(progress):return false
	if not start(1,progress):return false
	return save()

func _accept() -> void:
	frame=runtime.snapshot();presented_revision=runtime.revision
	changed.emit(frame);_events()

func _events() -> void:
	if not runtime.sounds.is_empty():
		var values:Array=runtime.sounds;runtime.sounds=[];sound_requested.emit(values)
	if not runtime.events.is_empty():
		var values:Array=runtime.events;runtime.events=[];events_received.emit(values)

func _fail(message: String) -> bool:
	error=message;ready=false;failed.emit(message);return false
