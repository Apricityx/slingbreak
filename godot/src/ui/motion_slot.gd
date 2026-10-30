extends Control
## Containers arrange the slot; its child retains its animated transform.
## Collapsing changes the layout height and clips a full-size card inside it.
var content:Control
var gap:=0.0
var extent:=-1.0:
	set(value):
		extent=value;update_minimum_size();_arrange()

func _init() -> void:
	set_meta("motion_slot",true);mouse_filter=Control.MOUSE_FILTER_PASS

func adopt(node:Control) -> void:
	content=node;add_child(node)
	node.minimum_size_changed.connect(_content_changed)
	resized.connect(_arrange)
	_content_changed()

func _get_minimum_size() -> Vector2:
	if not is_instance_valid(content) or content.get_parent()!=self:return Vector2.ZERO
	var minimum:=content.get_combined_minimum_size()
	return Vector2(minimum.x,minimum.y+gap if extent<0 else extent)

func _content_changed() -> void:
	update_minimum_size();_arrange.call_deferred()

func _arrange() -> void:
	if not is_instance_valid(content) or content.get_parent()!=self:return
	content.size=Vector2(size.x,maxf(content.get_combined_minimum_size().y,size.y-gap))
	if content.get_meta("motion_center_pivot",false):content.pivot_offset=content.size/2
