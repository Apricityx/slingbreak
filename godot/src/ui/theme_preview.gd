extends Control
var mode: String="light"

func _ready() -> void:
	custom_minimum_size=Vector2(0,58);mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	_paint(false)
	if mode=="system":
		var polygon:=PackedVector2Array([Vector2(size.x,0),size,Vector2(0,size.y)])
		draw_colored_polygon(polygon,Color("#131711"))
		draw_rect(Rect2(Vector2(0,size.y-9),Vector2(size.x,9)),Color("#0e120c"))

func _paint(_unused: bool) -> void:
	var dark:=mode=="dark"
	draw_rect(Rect2(Vector2.ZERO,size),Color("#131711" if dark else "#f5f6f3"))
	draw_circle(Vector2(size.x/2,size.y*.22),4,Color("#b6ed66"))
	for i in range(3):
		draw_rect(Rect2(Vector2(size.x*(.12+i*.24),34),Vector2(size.x*.18,7)),Color("#a2503e" if dark else "#f6a38f") if i==1 else Color("#323b2b" if dark else "#dce2d0"))
	draw_rect(Rect2(Vector2(0,size.y-9),Vector2(size.x,9)),Color("#0e120c" if dark else "#252e20"))
