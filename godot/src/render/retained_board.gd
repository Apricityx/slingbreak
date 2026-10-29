extends Node2D
## Native vector display lists retained until a brick/wall's appearance changes.
## No raster snapshot: resizing still draws the original curves and font glyphs.
var board:Node2D
var entity:RefCounted
var wall:=false
var background:=false
var appearance:Array=[]

func refresh(key:Array) -> void:
	if appearance==key:return
	appearance=key;queue_redraw()

func _draw() -> void:
	set_meta("stroke_meshes",[])
	board.draw_on=self
	if background:
		draw_dashed_line(Vector2(85,840),Vector2(695,840),board.ink("guide"),1,6)
		if board.simulation.phase not in ["draft","clearing"]:board._draw_boss(false)
	elif wall:board._wall(entity)
	else:board._brick(entity)
	board.draw_on=board
