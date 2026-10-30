extends Control
## The sheet animates its viewport rectangle, leaving text at its layout size.
## The face and the scroll viewport follow the same rectangle on every frame.
var padding:=16.0
var layout_width:=380.0
var scroll:ScrollContainer
var face:Panel
var content:VBoxContainer

func setup(style:StyleBoxFlat,width:float,inset:float) -> void:
	layout_width=width;padding=inset;size=Vector2(width,0);clip_contents=true
	face=Panel.new();face.mouse_filter=Control.MOUSE_FILTER_IGNORE;face.add_theme_stylebox_override("panel",style);add_child(face)
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER;add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",0);scroll.add_child(content)
	resized.connect(_arrange);_arrange()

func desired_size() -> Vector2:
	return Vector2(layout_width,minf(883.0,content.get_combined_minimum_size().y+padding*2))

func _arrange() -> void:
	if scroll==null:return
	face.size=size
	scroll.position=Vector2(padding,padding)
	scroll.size=Vector2(layout_width-padding*2,maxf(0,size.y-padding*2))
