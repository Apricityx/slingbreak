extends SceneTree
const Interface=preload("res://src/ui/interface.gd")
var failures:=0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui:=Interface.new();root.add_child(ui)
	var cases:=[[0,"0"],[999,"999"],[1000,"1K"],[1250,"1.25K"],[10000,"10K"],[999990,"999.99K"],[999999,"1M"],[1000000,"1M"],[1250000000,"1.25B"],[1000000000000,"1T"],[1000000000000000,"1Qa"],[1000000000000000000,"1Qi"],[1e21,"1Sx"],[1e24,"1Sp"],[1e27,"1Oc"],[1e30,"1No"],[1e33,"1Dc"],[-1250,"-1.25K"]]
	for item in cases:
		check(ui.pages.fmt(item[0])==item[1],"money format: "+str(item))
		check(ui._counter_text("wallet",item[0])==item[1],"HUD wallet uses money format")
	ui.pages.f={"phase":"ready","paused":false}
	var buy:=Button.new()
	for item in cases:
		ui.pages._shop_button(buy,{"cost":item[0],"maxed":false,"locked":false,"affordable":true})
		check(buy.text=="＋  "+item[1],"upgrade price uses money format")
	buy.free()
	for mode in ["light","dark"]:
		for launcher in [false,true]:
			ui.visuals.mode=mode;ui.launcher_mode=launcher;ui._build_hud()
			await process_frame
			for balance in ["0","999","9.99K","999.99M","999.99B","999.99Qa","999.99Qi","999.99Dc"]:
				var wallet:Button=ui.hud_nodes.wallet;wallet.text=balance
				await process_frame
				var icon:TextureRect=wallet.get_node("WalletIcon")
				check(icon.is_visible_in_tree() and icon.size==Vector2(12,12),"wallet icon keeps its size: "+mode+" / "+balance)
				check(icon.texture.get_image().get_used_rect().has_area(),"wallet icon has visible pixels")
				check(icon.mouse_filter==Control.MOUSE_FILTER_IGNORE,"icon does not intercept wallet clicks")
				check(wallet.get_rect().end.x<=400 and wallet.get_minimum_size().x<=wallet.size.x,"balance stays within the header")
				var font:Font=wallet.get_theme_font("font")
				check(font.get_string_size(balance,HORIZONTAL_ALIGNMENT_LEFT,-1,wallet.get_theme_font_size("font_size")).x<=wallet.size.x-26,"full balance fits beside icon: "+balance)
				for state in ["normal","hover","pressed","disabled"]:
					check(wallet.get_theme_stylebox(state).content_margin_left>=icon.get_rect().end.x+4,"button state reserves icon space: "+state)
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../agent-tmp/godot/checks/wallet-"+mode+("-launcher" if launcher else "")+".png")
	ui.queue_free();await process_frame
	print("Wallet checks: %d failure(s)" % failures)
	quit(1 if failures else 0)

func check(ok:bool,message:String) -> void:
	if not ok:failures+=1;push_error(message)
