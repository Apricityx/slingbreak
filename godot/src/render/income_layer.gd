extends Node2D
## Fonts must not inherit the procedural stroke-mesh shader on the FX layer.
var board:Node2D
func _draw() -> void:
	if board.simulation==null:return
	board.draw_on=self
	board._draw_income(board.simulation)
	board.draw_on=board
