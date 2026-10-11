extends RefCounted
## CanvasItem/Tween motion shared by sheets, cards and HUD. Every tween is
## bound to the affected node, so closing a sheet cancels its work safely.
const GLINT_SHADER = preload("res://src/ui/card_glint.gdshader")
const Easing = preload("res://src/ui/easing.gd")

static func pulse(node: Control,amount: float=1.12) -> void:
	if not is_instance_valid(node):return
	if node.has_meta("pulse"):
		var old:Tween=node.get_meta("pulse")
		if old.is_valid():old.kill()
	node.pivot_offset=node.size/2;node.scale=Vector2.ONE
	var tween:=node.create_tween();node.set_meta("pulse",tween)
	tween.tween_property(node,"scale",Vector2.ONE*amount,.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node,"scale",Vector2.ONE,.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func enter(node: Control,delay: float=0) -> void:
	if not is_instance_valid(node):return
	node.pivot_offset=node.size/2;node.scale=Vector2(.96,.96);node.modulate.a=0
	var tween:=node.create_tween().set_parallel()
	tween.tween_property(node,"scale",Vector2.ONE,.38).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node,"modulate:a",1.0,.26).set_delay(delay)

static func leave(node:Control) -> void:
	if not is_instance_valid(node):return
	node.pivot_offset=node.size/2
	var tween:=node.create_tween().set_parallel()
	tween.tween_property(node,"scale",Vector2.ONE*.97,.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(node,"modulate:a",0.0,.16)
	tween.chain().tween_callback(node.queue_free)

static func glint(card: Control, delay: float, tint: Color) -> void:
	if not is_instance_valid(card):
		return
	var sheen := ColorRect.new()
	sheen.name = "DealGlint"
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = GLINT_SHADER
	material.set_shader_parameter("tint", tint)
	sheen.material = material
	card.add_child(sheen)
	# Anchors follow late container sorting and card resize during flight.
	sheen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := sheen.create_tween()
	# The reference's cubic-bezier(.3,0,.2,1), shared with native sheet easing.
	tween.tween_method(func(progress: float): material.set_shader_parameter("progress", Easing.bezier(progress,.3,0,.2,1)), 0.0, 1.0, 0.8).set_delay(delay)
	tween.tween_callback(sheen.queue_free)

static func deal(card: Control,index: int) -> void:
	card.pivot_offset=card.size/2;card.scale=Vector2(.94,.02);card.modulate.a=.2
	var tween:=card.create_tween().set_parallel()
	tween.tween_property(card,"scale",Vector2.ONE,.44).set_delay(index*.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card,"modulate:a",1.0,.28).set_delay(index*.07)

static func fold(card: Control,index: int) -> void:
	card.pivot_offset=card.size/2
	var tween:=card.create_tween().set_parallel()
	tween.tween_property(card,"scale",Vector2(.94,.02),.26).set_delay(index*.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(card,"modulate:a",.2,.26).set_delay(index*.06)

static func flight(host: Control,ghost: Control,from: Rect2,to: Rect2,duration: float=.62) -> Tween:
	ghost.position=from.position;ghost.size=from.size;ghost.pivot_offset=from.size/2
	ghost.z_index=32;host.add_child(ghost)
	var a:=from.get_center();var b:=to.get_center()
	var bend:Vector2=(a+b)/2+Vector2(35,-60)
	var end_scale:=to.size/from.size
	var tween:=ghost.create_tween()
	tween.tween_method(func(value:float):
		var u:=1-value
		ghost.position=u*u*a+2*u*value*bend+value*value*b-from.size/2
		ghost.scale=Vector2.ONE.lerp(end_scale,value)
		ghost.rotation=sin(value*PI)*-.12
	,0.0,1.0,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return tween
