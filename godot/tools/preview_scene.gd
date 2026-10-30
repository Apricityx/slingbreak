extends SceneTree
## Dev-only preview: boot the native build, jump to a page, save one PNG, quit.
## Driven by godot/tools/preview.py; not part of any export.

var page := "draft"
var theme_name := "light"
var seconds := 0.0
var boss_id := "serpent"
var out_path := ""
var settle := 1.5
var failures := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var at := 0
	while at < args.size():
		var key: String = args[at]
		var value: String = args[at + 1] if at + 1 < args.size() else ""
		match key:
			"--page": page = value
			"--theme": theme_name = value
			"--seconds": seconds = value.to_float()
			"--boss": boss_id = value
			"--settle": settle = value.to_float()
			"--out": out_path = value
			_:
				push_error("Unknown preview argument: " + key)
				failures += 1
		at += 2
	if out_path.is_empty():
		out_path = ProjectSettings.globalize_path("res://") + "../agent-tmp/godot/preview/preview-" + page + ".png"
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var app: Node = load("res://scenes/main.tscn").instantiate()
	app.set_meta("test_mode", true)
	root.add_child(app)
	await process_frame
	var ui: Control = app.interface
	if theme_name != "light":
		app.session.command("configure", {"theme": theme_name})
	if page == "boss":
		app.session.command("enterBoss", {"id": boss_id})
		_advance(app, maxf(seconds, 1.5))
	elif seconds > 0.0:
		app.session.command("pause", {"paused": false})
		_advance(app, seconds)
	await _open(app, ui)
	await create_timer(settle).timeout
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(out_path) != OK:
		push_error("Preview capture failed: " + out_path)
		failures += 1
	else:
		print("preview: %s (%s, %s, %dx%d)" % [out_path, page, theme_name, image.get_width(), image.get_height()])
	app.audio.shutdown() if app.audio.has_method("shutdown") else null
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _advance(app: Node, duration: float) -> void:
	for i in range(int(duration * 60.0)):
		app.session.update(1.0 / 60.0)


func _open(app: Node, ui: Control) -> void:
	match page:
		"explosion", "frost":
			ui._select(_first_option(app))
			await create_timer(2.5).timeout
			_advance(app,3.0)
			var g:RefCounted=app.session.runtime
			g.board_entrance=null
			var target:RefCounted=g.bricks[g.bricks.size()/2]
			target.type="frost" if page=="frost" else "bomb"
			if page=="frost":
				for brick in g.bricks:brick.hp=20;brick.max_hp=20
			g.hit(target,1e9)
			g.fx.advance_visual(maxf(0.01,seconds))
			app.set_process(false)
		"intro":
			pass
		"draft":
			ui._draft()
		"game":
			await ui._select(_first_option(app))
			app.session.command("pause", {"paused": false})
			_advance(app, maxf(seconds, 3.0))
		"shop":
			ui._shop()
		"equipment":
			ui._equipment()
		"achievements":
			ui._equipment(true)
		"library":
			ui._library()
		"settings":
			ui._settings()
		"detail":
			ui._detail(_first_option(app))
		"swap":
			app.session.runtime.state.rerolls = 1
			ui._detail(_first_option(app))
			app.session.command("offerSwap", {"id": _first_option(app)})
		"reset":
			ui._reset_confirmation()
		"report":
			var value: Dictionary = app.session.frame.duplicate(true)
			value.phase = "clearing"
			value.transition.report = {
				"level": 1, "total": 1280,
				"parts": [
					{"label": "砖块收入", "value": 820, "color": "#98b95a"},
					{"label": "成就追补", "value": 180, "color": "#b2934d"},
					{"label": "核心奖金", "value": 240, "color": "#7ba5a7"},
					{"label": "技能奖金", "value": 40, "color": "#b485a0"},
				],
				"bestKills": 12, "bestMoney": 520, "record": true, "shots": 8, "bricks": 42,
				"skills": [{"name": "连击狂热", "icon": "flame", "count": 4}, {"name": "雷神降临", "icon": "zap-off", "count": 3}],
			}
			value.transition.bonus = 240
			ui._update_report(value)
		"pause":
			app.session.command("pause", {"paused": true})
		"boss":
			pass
		_:
			push_error("Unknown preview page: " + page)
			failures += 1
	await process_frame


func _first_option(app: Node) -> String:
	var options: Array = app.session.runtime.state.draft.options
	if options.is_empty():
		push_error("No draft options available for this preview page")
		failures += 1
		return ""
	return str(options[0])
