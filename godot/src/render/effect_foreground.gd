extends Node2D
## Preserve the original order: skill/rings -> batched special hits -> arrows,
## particles, text -> explosion/frost children. No gameplay state lives here.
var board:Node2D

func _draw() -> void:
	set_meta("stroke_meshes",[])
	board.draw_on=self
	board._draw_foreground()
	board.draw_on=board
