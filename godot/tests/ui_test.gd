extends SceneTree
var failures := 0
var app: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	app=load("res://scenes/main.tscn").instantiate();app.set_meta("test_mode",true);app.set_meta("variant_cards",true);root.add_child(app)
	await create_timer(.1).timeout
	await process_frame
	await process_frame
	_check(app.session.ready,"UI runtime boots")
	var ui: Control=app.interface
	_check(not ui.hud_nodes.has("status") and not ui.hud_nodes.has("power"),"bottom corner status and power labels are removed")
	_check(ui.oversampling_with_scale==CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED,"scaled UI keeps font atlas resolution")
	_check(ui.visuals.fonts[0].oversampling>=2.0 and ui.visuals.fonts[2].oversampling>=2.0,"runtime UI fonts use oversampling")
	var icon_manifest:Dictionary=ui.visuals.manifest.get("icons",{})
	for skill in ui.catalog.values():
		var icon_id:String=str(skill.get("icon",""))
		_check(icon_manifest.has(icon_id),"skill icon is registered: "+str(skill.id)+" / "+icon_id)
		var texture:Texture2D=ui.visuals.icon(icon_id,Color.WHITE)
		_check(texture!=null and texture.get_image().get_used_rect().has_area(),"skill icon has visible pixels: "+str(skill.id)+" / "+icon_id)
	# Every level announces its rule before the draft.
	_check(ui.modal_kind=="variant" and ui.frame.variant is Dictionary,"level rule card opens before the draft")
	var rule_title:Label=ui.modal_content.find_child("VariantTitle",true,false) if ui.modal_content!=null else null
	_check(rule_title!=null and rule_title.text==ui.frame.variant.name and ui.modal_content.find_child("VariantContinue",true,false) is Button,"rule card names the rule and offers the draft")
	ui.modal_content.find_child("VariantContinue",true,false).pressed.emit()
	await process_frame
	await process_frame
	_check(ui.modal_kind=="draft","first draft is modal")
	var badge_host:=VBoxContainer.new();root.add_child(badge_host)
	for mode in ["light","dark"]:
		ui.visuals.mode=mode
		for tier in ["white","blue","gold"]:
			var badge:Control=ui.pages.rarity(badge_host,{"tier":tier},true)
			var style:StyleBoxFlat=badge.get_theme_stylebox("panel")
			var rank:int={"white":1,"blue":2,"gold":3}[tier]
			_check(style.border_width_left==0 and style.corner_radius_top_left==4,"draft rarity uses a soft rectangular label: "+mode+" "+tier)
			_check(badge.get_child(0).get_child(0).custom_minimum_size.x==rank*7-1,"draft rarity encodes tier in diamond count: "+tier)
			_check(badge.mouse_filter==Control.MOUSE_FILTER_IGNORE,"rarity leaves card input unobstructed")
	ui.visuals.mode="light"
	badge_host.queue_free()
	_check(ui.panel.position.x==8 and ui.panel.size.x==396,"draft dialog fits the 412px design grid: "+str(ui.panel.size))
	_check(ui.panel.position.y>=8 and ui.panel.position.y+ui.panel.size.y<=907,"dialog fits stage")
	_check(ui.panel.size.y<=ui.modal_content.get_combined_minimum_size().y+35,"draft hugs its content")
	_check(ui.hud_nodes.progress.size.y==5,"core progress track matches the browser's five-pixel height")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../agent-tmp/godot/native/draft-ui.png")
	var chosen: String=app.session.frame.draft.options[0]
	await create_timer(1.5).timeout
	await ui._select(chosen)
	_check(app.session.frame.phase=="entering","draft commits original skill rule")
	_check(ui.panel==null,"draft closes after selection")
	for i in range(60): app.session.update(1.0/60.0)
	ui._settings()
	_check(app.session.frame.paused,"settings pauses simulation")
	ui._detail(chosen)
	ui._close()
	_check(app.session.frame.paused and ui.modal_kind=="settings","nested modal returns to settings and keeps pause")
	ui._close()
	_check(not app.session.frame.paused,"final modal restores original pause state")
	ui._shop()
	_check(not app.session.frame.paused,"shop leaves gameplay live like browser")
	ui._close()
	ui._equipment()
	_check(app.session.frame.paused,"equipment pauses simulation")
	ui._achievements()
	_check(ui.modal_content.get_child_count()>=24,"all 12 achievements shown")
	ui._close()
	app.session.command("configure",{"theme":"dark"})
	_check(ui.visuals.mode=="dark","UI follows canvas palette")
	_check(not ui.hud_nodes.has("status") and not ui.hud_nodes.has("power"),"theme rebuild keeps bottom corner labels removed")
	ui._settings()
	await process_frame
	await process_frame
	_check(ui.panel.position.y>=8 and ui.panel.position.y+ui.panel.size.y<=907,"settings scrolls within stage")
	ui._close()
	app.session.command("configure",{"theme":"light"})
	_check(ui.visuals.mode=="light","UI restores light palette")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../agent-tmp/godot/native/board-ui.png")
	app.audio.shutdown()
	await create_timer(.1).timeout
	app.queue_free();await create_timer(.1).timeout
	print("Godot UI checks: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _check(ok: bool,message: String) -> void:
	if not ok: failures+=1;push_error(message)
