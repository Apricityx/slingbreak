extends SceneTree

var failures:=0
const Presentation=preload("res://src/ui/presentation.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var visuals:=Presentation.new()
	for mode in ["light","dark"]:
		visuals.mode=mode
		var host:=VBoxContainer.new();root.add_child(host);visuals.apply(host)
		var standard:Button=visuals.button(host,"Standard",func():pass)
		var custom:Button=visuals.button(host,"Custom",func():pass)
		custom.add_theme_stylebox_override("normal",visuals.box(visuals.color("surface"),visuals.color("line"),20,8))
		var checkbox:=CheckBox.new();host.add_child(checkbox)
		visuals.button_states(host)
		for button in [standard,custom,checkbox]:
			button.grab_focus()
			_check(button.has_focus(),mode+": keyboard focus remains available")
			_check(button.get_theme_stylebox("focus") is StyleBoxEmpty,mode+": no extra focus outline")
		_check(not custom.has_theme_stylebox_override("focus"),mode+": custom button inherits shared focus style")
		for state in ["hover","pressed"]:
			_check(custom.get_theme_stylebox(state).corner_radius_top_left==20,mode+": custom geometry preserved for "+state)
		host.free()
	print("Godot button focus checks: %d failure(s)" % failures)
	quit(1 if failures else 0)

func _check(ok:bool,message:String) -> void:
	if not ok:failures+=1;push_error(message)
