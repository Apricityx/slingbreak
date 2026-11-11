extends "res://src/core/variants/rule.gd"
## A shot owns its main arrow, descendants and delayed skill work. Other shots
## may overlap it, but cannot supply its kills or keep its settlement open.
## Flight is not saved: restoring cancels unfinished obligations, never fines
## the player for projectiles that persistence deliberately does not restore.
var rounds:Dictionary={}

static func shot_id(arrow:Variant) -> int:
	if arrow==null:return -1
	while arrow.source!=null:arrow=arrow.source
	return int(arrow.id) if arrow.flags.get("main",false) else -1

func launched(arrow:RefCounted) -> void:
	if not arrow.flags.get("main",false):return
	var shot:Dictionary={"kills":0,"done":false}
	rounds[arrow.id]=shot
	opened(shot)

func opened(_shot:Dictionary) -> void:pass
func scored(_shot:Dictionary) -> void:pass
func finished(_shot:Dictionary) -> void:pass

func record_kill() -> void:
	var key:=shot_id(g.active_arrow)
	if not rounds.has(key):return
	var shot:Dictionary=rounds[key]
	shot.kills=int(shot.kills)+1
	scored(shot)

func update(_delta:float) -> void:
	if g.phase not in ["ready","flying"]:return
	var live:Dictionary={}
	for arrow in g.arrows:live[shot_id(arrow)]=true
	for job in g.skills.jobs:live[shot_id(job.source)]=true
	for field in g.skills.fields:live[shot_id(field.source)]=true
	for key in rounds.keys():
		if live.has(key):continue
		var shot:Dictionary=rounds[key]
		rounds.erase(key)
		if not shot.done:finished(shot)

func latest() -> Dictionary:return {} if rounds.is_empty() else rounds[rounds.keys().back()]

func restored() -> void:
	rounds.clear()
	# Old boards stored one global open round. It has no surviving projectiles.
	if data.has("open"):data.open=false
	if data.has("armed"):data.armed=false
	if data.has("kills"):data.kills=0
