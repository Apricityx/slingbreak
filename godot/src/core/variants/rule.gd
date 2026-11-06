extends RefCounted
## Base for one level-variant rule. Each rule lives in its own file under
## src/core/variants/<id>.gd and overrides only the hooks it needs; every
## default below is neutral, so an ordinary level is a rule-free host.
## `data` is saved on the board; keep it JSON-plain (numbers, bools, strings,
## arrays and dictionaries of those) and validate it in valid().
var owner:WeakRef
var g:RefCounted:
	get:return owner.get_ref()
var data:Dictionary={}

## `simulation` is null only for the validation-only instance made on load.
func _init(simulation:RefCounted=null) -> void:owner=weakref(simulation) if simulation!=null else null

## Display name, colour (#rrggbb) and the one-line rule shown on entry.
func title() -> String:return ""
func color() -> String:return "#8a9480"
func note() -> String:return ""

## Fresh level: reshape g.bricks/g.obstacles and seed `data`. Not called on restore.
func shape() -> void:pass
## Reject malformed saved `data` (the host has already checked the id).
func valid(_saved:Dictionary) -> bool:return true

## Fixed 60 Hz step while the level is live (not during draft or clearing).
func update(_delta:float) -> void:pass
## After the main arrow and its skill volley have been launched.
func on_shoot() -> void:pass
## Every projectile created by launch(); adjust speed/pierce/damage/flags here.
func launched(_arrow:RefCounted) -> void:pass
## A brick has just been destroyed (before chain reactions resolve).
func destroyed(_brick:RefCounted) -> void:pass
## A live arrow reflected off a side/top wall or an obstacle.
func bounced(_arrow:RefCounted) -> void:pass
## The core has just appeared.
func core_spawned() -> void:pass
## The arrow touched the core. Return false to deny the clear; the host then
## reflects the arrow away from the core as if it were a wall.
func core_hit(_arrow:RefCounted) -> bool:return true

## Multiplies brick damage. `arrow` is null for passive/area damage.
func damage_scale(_brick:RefCounted,_arrow:Variant) -> float:return 1.0
## Multiplies every brick coin reward.
func reward_scale(_brick:RefCounted) -> float:return 1.0
## Multiplies the settled core bonus.
func bonus_scale() -> float:return 1.0
## Multiplies the share of bricks needed before the core appears (clamped to all bricks).
func threshold_scale() -> float:return 1.0
## Physics: gravity multiplier and extra horizontal wind (velocity units per 60 Hz tick).
func gravity_scale() -> float:return 1.0
func wind() -> float:return 0.0
## Multiplies the delay between shots.
func interval_scale() -> float:return 1.0

## Live HUD suffix after the name, e.g. "剩余 3 箭"; "" shows the name only.
func status() -> String:return ""
## Extra settlement badges; the host adds "奖金 ×N" whenever bonus_scale()!=1.
func summary() -> Array:return []
## Optional board overlay. `canvas` is the board CanvasItem, drawn each frame
## after the core and before bricks; use canvas.draw_* calls only.
func draw(_canvas:CanvasItem) -> void:pass
