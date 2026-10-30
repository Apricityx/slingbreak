extends Node2D
## Shop foreground adapter for the same bounded live bargain snapshot. The modal
## covers the board, so successful purchases also paint beside their own button.
const Painter=preload("res://src/render/skill_batch_four.gd")
var simulation:RefCounted
var event:Dictionary

static func show_at(ui:Control,g:RefCounted,key:String) -> void:
	if ui.modal_kind!="shop" or ui.panel==null:return
	var button:Control=ui.panel.find_child("Buy_"+key,true,false)
	if button==null:return
	var live:Array=g.fx.skill_events.filter(func(item):return item.id=="bargain")
	if live.is_empty():return
	var layer:Control=ui.motion_layer
	var old:Array=[]
	for child in layer.get_children():
		if child.has_meta("bargain_feedback"):old.append(child)
	while old.size()>=8:
		var first:Node=old.pop_front();layer.remove_child(first);first.queue_free()
	var feedback:=new();feedback.simulation=g;feedback.event=live.back().duplicate()
	feedback.set_meta("bargain_feedback",true)
	feedback.event.position=Vector2.ZERO
	layer.add_child(feedback)
	feedback.position=layer.get_global_transform().affine_inverse()*(button.get_global_transform()*(button.size*Vector2(0.12,0.5)))
	feedback.scale=Vector2.ONE*0.75

func _process(_delta:float) -> void:
	if simulation.fx.visual_time<event.born or simulation.fx.visual_time-event.born>=event.max or not simulation.rank("bargain"):
		queue_free();return
	var live:=false
	for item in simulation.fx.skill_events:
		if item.id=="bargain" and item.seed==event.seed and item.born==event.born:live=true;break
	if not live:queue_free();return
	queue_redraw()

func _draw() -> void:
	Painter.paint(self,event,simulation.fx.visual_time,simulation.reduced,simulation.theme=="dark")
