extends SceneTree
## Exercise the real picker signal handlers and progress I/O without Android deployment.
var failures:=0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var directory:=ProjectSettings.globalize_path("res://../agent-tmp/godot/file-transfer-tests")
	DirAccess.make_dir_recursive_absolute(directory)
	var saved:=directory+"/private-progress.json"
	var exported:=directory+"/exported-progress.json"
	var incoming:=directory+"/import-progress.json"
	var app:Node=load("res://scenes/main.tscn").instantiate()
	app.set_meta("test_mode",true);app.session.save_path=saved;root.add_child(app)
	await process_frame
	app.session.command("configure",{"performanceMode":true})
	app.session.command("choose",{"id":app.session.frame.draft.options[0]})
	for i in range(60):app.session.update(1.0/60.0)
	check(app.session.save(),"initial private save succeeds")
	var original:=FileAccess.get_file_as_string(saved)
	var ui:Control=app.interface
	ui._settings()
	ui._file(false)
	var dialog:FileDialog=ui.file_dialog
	check(dialog.use_native_dialog and dialog.access==FileDialog.ACCESS_FILESYSTEM,"picker requests the native filesystem UI")
	check(dialog.file_mode==FileDialog.FILE_MODE_SAVE_FILE and dialog.current_file.begins_with("slingbreak-progress-") and dialog.current_file.ends_with(".json"),"export uses system create-document mode and a suggested JSON name")
	check(dialog.filters[0].contains("application/json"),"native picker has an explicit JSON MIME filter")
	ui._file(true)
	check(ui.file_dialog==dialog,"repeated taps do not replace a pending picker")
	dialog.canceled.emit()
	check(ui.file_dialog==null and ui.modal_kind=="settings" and app.session.frame.paused,"cancel releases the picker and keeps settings paused")
	check(FileAccess.get_file_as_string(saved)==original,"cancel does not write progress")
	await process_frame
	ui._file(false)
	ui.file_dialog.file_selected.emit(exported)
	check(ui.file_dialog==null and ui.modal_kind=="file_result","export completes and reports success")
	var payload:Variant=JSON.parse_string(FileAccess.get_file_as_string(exported))
	check(payload is Dictionary and payload.format=="slingbreak-progress" and payload.version==1,"export retains the portable progress envelope")
	check(FileAccess.get_file_as_string(saved)==original,"export does not replace the private save")
	ui._close()
	var runtime:RefCounted=app.session.runtime
	for invalid in ["not JSON", "[]", '{"format":"wrong","version":1,"state":{}}']:
		write(incoming,invalid)
		app._action("importFile",{"path":incoming})
		check(ui.modal_kind=="error" and app.session.runtime==runtime,"invalid imports report an error without replacing the runtime")
		check(FileAccess.get_file_as_string(saved)==original,"invalid imports preserve the private save")
		ui._close()
	app._action("importFile",{"path":directory+"/missing/progress.json"})
	check(ui.modal_kind=="error" and app.session.runtime==runtime,"unreadable files fail without replacing progress")
	ui._close()
	app._action("exportFile",{"path":directory+"/missing/progress.json"})
	check(ui.modal_kind=="error","unwritable export reports failure instead of success")
	ui._close()
	payload.state.coins=1234
	write(incoming,JSON.stringify(payload))
	ui._file(true)
	check(ui.file_dialog.file_mode==FileDialog.FILE_MODE_OPEN_FILE,"import uses system open-document mode")
	ui.file_dialog.file_selected.emit(incoming)
	check(ui.file_dialog==null and ui.modal_kind=="file_result" and app.session.frame.coins==1234,"selected import is applied and reports success")
	check(app.session.runtime!=runtime and app.arena.simulation==app.session.runtime and app.audio.simulation==app.session.runtime,"import rebinds rendering and audio to the replacement session")
	check(app.session.load_progress().state.coins==1234,"import persists the new progress")
	check(app.session.frame.paused,"replacement session stays paused behind the result and settings")
	ui._close()
	check(ui.modal_kind=="settings" and app.session.frame.paused,"closing success returns to paused settings")
	ui._file(true);ui.file_dialog.canceled.emit()
	check(app.session.frame.coins==1234 and ui.modal_kind=="settings","picker can reopen and cancel after a successful operation")
	ui._close()
	check(not app.session.frame.paused,"closing settings restores the original pause state")
	ui._settings()
	app.session.save_path=directory+"/missing/private-progress.json"
	app._action("importFile",{"path":incoming})
	check(ui.modal_kind=="error" and app.arena.simulation==app.session.runtime and app.audio.simulation==app.session.runtime,"failed persistence reports an error and does not retain the disposed runtime")
	check(app.session.frame.paused,"failed persistence leaves imported gameplay paused")
	app.session.save_path=saved
	app.audio.shutdown();app.queue_free();await create_timer(.15).timeout
	print("Godot file transfer checks: %d failure(s)" % failures)
	quit(1 if failures else 0)

func write(path:String,text:String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text);file.close()

func check(ok:bool,message:String) -> void:
	if not ok:failures+=1;push_error(message)
