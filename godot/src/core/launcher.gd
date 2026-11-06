extends Node
## Optional native host boundary. Gameplay never infers host readiness from a percentage.
signal state_changed(state: Dictionary)
const METHODS=["get_progress","get_message","is_ready","should_leave","report"]
var bridge: Object
var session: RefCounted
var state: Dictionary={"progress":0,"message":"等待主游戏启动…","ready":false,"phase":"loading"}
var requested:=false
var completed:=false
var leave_seen:=false
var clock:=0.0

func discover() -> bool:
	if bridge==null and Engine.has_singleton("SlingPrototype"):
		bridge=Engine.get_singleton("SlingPrototype")
	if not is_instance_valid(bridge):return false
	for method in METHODS:
		if not has_bridge_method(method):bridge=null;return false
	return true

func has_bridge_method(method: String) -> bool:
	if not is_instance_valid(bridge):return false
	# Godot 4.7 Android JNISingleton keeps @UsedByGodot methods outside ClassDB.
	# Object.has_method() therefore rejects callable Java methods; use its JNI API.
	return bridge.has_method(method) or (bridge.has_method("has_java_method") and bool(bridge.has_java_method(method)))

func is_launcher_mode() -> bool:
	# Older prototype hosts were overlay-only. New hosts distinguish standalone play.
	return is_instance_valid(bridge) and (not has_bridge_method("is_launcher_mode") or bool(bridge.is_launcher_mode()))

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	if not discover():set_process(false);return
	_refresh()
	bridge.report("ready")
	if is_launcher_mode():bridge.report("launcher_ui_ready")

func _process(delta: float) -> void:
	clock+=delta
	if clock<.1:return
	clock=0.0;poll()

func poll() -> void:
	if not is_instance_valid(bridge) or completed:return
	_refresh()
	var leaving:bool=bridge.should_leave()
	if leaving and not leave_seen:
		leave_seen=true
		_save_and_leave()
	elif not leaving:
		leave_seen=false

func _refresh() -> void:
	var next:Dictionary=state.duplicate()
	next.progress=clampi(int(bridge.get_progress()),0,100)
	next.message=str(bridge.get_message()).strip_edges().left(240)
	next.ready=bool(bridge.is_ready())
	if next.message=="":next.message="游戏画面已准备完成" if next.ready else "正在启动主游戏…"
	if next.phase in ["loading","ready"]:next.phase="ready" if next.ready else "loading"
	_publish(next)

func request_enter() -> void:
	if not is_instance_valid(bridge) or requested or completed:return
	_refresh()
	if not state.ready:return
	requested=true
	_set_phase("entering")
	# Android owns the Activity transition; it responds by setting should_leave.
	bridge.report("enter_requested")

func retry_save() -> void:
	if state.phase=="save_error" and not completed:
		# Re-arm the host's save timeout if the user waited before retrying.
		bridge.report("save_retry_requested")
		_save_and_leave()

func _save_and_leave() -> void:
	_set_phase("saving")
	# SlingSession.save waits for queued autosaves, flushes and atomically renames.
	if session==null or not session.save():
		_set_phase("save_error")
		bridge.report("save_failed")
		return
	completed=true
	get_tree().paused=true
	_set_phase("saved")
	bridge.report("saved")

func _set_phase(value: String) -> void:
	var next:Dictionary=state.duplicate();next.phase=value;_publish(next)

func _publish(value: Dictionary) -> void:
	if state==value:return
	state=value;state_changed.emit(state.duplicate())
