extends SceneTree
## Run production rewards/purchases across ten thousand levels, including
## low/high combo, damage saving, and a deliberately rich late-game envelope.
const Model=preload("res://tools/upgrade_economy_model.gd")

func _initialize() -> void:
	var results:Array=[]
	for strategy in ["balanced","arsenal","wealth"]:
		results.append(Model.run({"strategy":strategy}))
	for config in [{"kills":1},{"kills":12,"achievements":true},{"strategy":"damage_only"},{"strategy":"damage_only","core_only":true},{"kills":12,"achievements":true,"economic_envelope":true}]:
		results.append(Model.run(config))
	for seed_value in range(10):results.append(Model.run({"seed":431+seed_value,"draft":true,"levels":1000}))
	var path:="res://../agent-tmp/godot/upgrade-economy.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../agent-tmp/godot"))
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(results,"  "));file.close()
	for result in results:print(JSON.stringify({"config":result.config,"milestones":result.milestones,"final":result.checkpoints.back()}))
	print("Economy model saved: "+path);quit()
