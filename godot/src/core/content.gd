extends RefCounted
## Committed content data; no extraction tools or browser code at build time.
var catalog: Array = []
var by_id: Dictionary = {}
var achievements: Array = []
var palettes: Dictionary = {}
var effect_profiles:Dictionary={}

func _init() -> void:
	catalog=_read("skills")
	achievements=_read("achievements")
	palettes=_read("palettes")
	effect_profiles=_read("effect_profiles")
	for item in catalog:by_id[item.id]=item

func _read(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+name+".json"))

func palette(theme: String) -> Dictionary:
	return palettes.get(theme,palettes.light)
