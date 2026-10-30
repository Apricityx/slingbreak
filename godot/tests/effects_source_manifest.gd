extends RefCounted
## One fingerprint scope for sustained and fixed-peak comparisons.
static func hashes() -> Dictionary:
	var result:Dictionary={}
	for path in ["res://src/main.gd","res://tests/effects_stress_fixture.gd",
		"res://src/core/simulation.gd","res://src/effects/effects.gd","res://src/render/board.gd",
		"res://src/render/effect_foreground.gd","res://src/render/skill_impacts.gd",
		"res://src/render/skill_batch.gd","res://src/render/skill_batch.gdshader","res://src/render/effect_warmup.gd",
		"res://src/render/explosions.gd","res://src/render/explosion.gdshader",
		"res://src/render/frost.gd","res://src/render/frost.gdshader","res://src/render/effect_mesh.gd",
		"res://src/render/debris_batch.gd","res://src/render/debris.gdshader",
		"res://src/render/coin_batch.gd","res://src/render/coin_batch.gdshader",
		"res://tests/effects_source_manifest.gd"]:
		if FileAccess.file_exists(path):result[path]=FileAccess.get_sha256(path)
	return result
