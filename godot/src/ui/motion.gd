extends RefCounted
## CanvasItem/Tween motion shared by sheets, cards and HUD. Every tween is
## bound to the affected node, so closing a sheet cancels its work safely.
const GLINT_SHADER = preload("res://src/ui/card_glint.gdshader")
const Easing = preload("res://src/ui/easing.gd")
const MotionSlot = preload("res://src/ui/motion_slot.gd")
static var face_properties:Dictionary={}
static var face_overrides:Dictionary={}

static func claim(node: Control,properties: Array) -> Tween:
	# One writer per property. Interrupting an animation retains its current
	# pose; the replacement reads that pose instead of restoring defaults.
	var interrupted:Array=[]
	for property in properties:
		var key:="motion_"+str(property)
		if node.has_meta(key):
			var old:Tween=node.get_meta(key)
			if old.is_valid() and not old in interrupted:interrupted.append(old)
	for old in interrupted:
		old.kill()
	var tween:=node.create_tween().set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	for property in properties:node.set_meta("motion_"+str(property),tween)
	return tween

static func stop(node: Control) -> void:
	if not is_instance_valid(node):return
	for key in node.get_meta_list():
		if str(key).begins_with("motion_"):
			var value:Variant=node.get_meta(key)
			if value is Tween and value.is_valid():value.kill()

static func cancel(node:Control,properties:Array) -> void:
	for property in properties:
		var key:="motion_"+str(property)
		var value:Variant=node.get_meta(key) if node.has_meta(key) else null
		if value is Tween and value.is_valid():value.kill()

static func focus_gate(node:Control,covered:bool) -> void:
	if covered:
		if not node.has_meta("covered_focus_mode"):node.set_meta("covered_focus_mode",node.focus_mode)
		if node.has_focus():node.release_focus()
		node.focus_mode=Control.FOCUS_NONE
	elif node.has_meta("covered_focus_mode"):
		node.focus_mode=int(node.get_meta("covered_focus_mode"));node.remove_meta("covered_focus_mode")
	for child in node.get_children():
		if child is Control:focus_gate(child,covered)

static func layout_active(node:Control) -> bool:
	var tween:Tween=node.get_meta("motion_extent") if node.has_meta("motion_extent") else null
	if tween!=null and tween.is_valid() and tween.is_running():return true
	for child in node.get_children():
		if child is Control and layout_active(child):return true
	return false

static func pivot(node: Control) -> void:
	var parent:=node.get_parent()
	if parent!=null and parent.get_meta("motion_slot",false):
		# The slot owns the layout origin. Changing its child's pivot must not
		# turn a folded card into a permanent offset from that origin.
		node.set_meta("motion_center_pivot",true);node.pivot_offset=node.size/2
		return
	# Changing the pivot on an already scaled Control must preserve its pose.
	var origin:=node.get_transform().origin
	node.pivot_offset=node.size/2
	node.position+=origin-node.get_transform().origin

static func pose_in(host: Control,node: Control) -> Dictionary:
	var transform:=host.get_global_transform().affine_inverse()*node.get_global_transform()
	var opacity:=node.modulate.a
	var parent:=node.get_parent()
	while parent!=null:
		if parent is CanvasItem:opacity*=parent.modulate.a
		parent=parent.get_parent()
	var host_opacity:=host.modulate.a
	parent=host.get_parent()
	while parent!=null:
		if parent is CanvasItem:host_opacity*=parent.modulate.a
		parent=parent.get_parent()
	opacity/=maxf(.001,host_opacity)
	return {"size":node.size,"center":transform*(node.size/2),"scale":transform.get_scale(),"rotation":transform.get_rotation(),"alpha":opacity}

static func mount(host: Control,node: Control,pose: Dictionary) -> void:
	stop(node)
	if node.get_parent()!=null:node.get_parent().remove_child(node)
	host.add_child(node)
	node.size=pose.size;node.pivot_offset=node.size/2
	node.scale=pose.scale;node.rotation=pose.rotation
	node.position=pose.center-node.size/2;node.modulate.a=pose.alpha

static func copy(node:Control) -> Control:
	# Snapshot layout as ordinary Controls. Cloned Containers would sort their
	# children again and copied tween metadata would refer to the live source.
	var result:Control
	if node.has_method("motion_copy"):result=node.call("motion_copy")
	elif node is PanelContainer:
		result=Panel.new();result.add_theme_stylebox_override("panel",node.get_theme_stylebox("panel"))
	elif node is Container:result=Control.new()
	else:
		# Node.duplicate() always copies the entire subtree, even with flags=0.
		# Copy stored native properties only; the single child walk below owns
		# the frozen hierarchy. Fonts/textures remain shared with the live face.
		result=ClassDB.instantiate(node.get_class()) as Control
	for key in result.get_meta_list():result.remove_meta(key)
	result.anchor_left=0;result.anchor_top=0;result.anchor_right=0;result.anchor_bottom=0
	result.name=node.name;result.theme=_face_theme(node)
	# Off-tree Controls have not received the theme notification yet. Sizing
	# them first shapes Chinese text using the engine's system-font fallback.
	# Resolve our shared font before measuring this frozen face.
	result.notification(Control.NOTIFICATION_THEME_CHANGED)
	result.size=node.size;result.position=node.position;result.pivot_offset=node.pivot_offset;result.scale=node.scale;result.rotation=node.rotation
	if not node.has_method("motion_copy") and not node is Container:
		# Geometry comes before text, including stored offsets/anchors: their
		# setters can otherwise measure partially configured labels repeatedly.
		result.begin_bulk_theme_override()
		var type:String=node.get_class()
		if not face_properties.has(type):
			var stored:Array=[];var overrides:Array=[]
			for property in node.get_property_list():
				var usage:int=property.usage
				var key:String=property.name
				if key.begins_with("theme_override_"):
					var section:String=key.get_slice("/",0).trim_prefix("theme_override_")
					var category:int={"colors":Theme.DATA_TYPE_COLOR,"constants":Theme.DATA_TYPE_CONSTANT,"fonts":Theme.DATA_TYPE_FONT,"font_sizes":Theme.DATA_TYPE_FONT_SIZE,"icons":Theme.DATA_TYPE_ICON,"styles":Theme.DATA_TYPE_STYLEBOX}.get(section,-1)
					if category>=0:overrides.append([key,category,key.get_slice("/",1)])
				elif usage&PROPERTY_USAGE_STORAGE and not usage&PROPERTY_USAGE_SCRIPT_VARIABLE and key not in ["script","theme","custom_minimum_size","size","position","pivot_offset","scale","rotation","layout_mode","anchors_preset"] and not key.begins_with("metadata/") and not key.begins_with("anchor_") and not key.begins_with("offset_"):stored.append(key)
			face_properties[type]=stored;face_overrides[type]=overrides
		for key in face_properties[type]:result.set(key,node.get(key))
		for override in face_overrides[type]:
			if _has_override(node,override[1],override[2]):result.set(override[0],node.get(override[0]))
		result.end_bulk_theme_override()
		result.notification(Control.NOTIFICATION_THEME_CHANGED)
	result.modulate=node.modulate;result.self_modulate=node.self_modulate
	result.material=node.material.duplicate() if node.material!=null else null
	result.visible=node.visible;result.clip_contents=node.clip_contents;result.mouse_filter=Control.MOUSE_FILTER_IGNORE;result.focus_mode=Control.FOCUS_NONE
	result.z_index=node.z_index;result.z_as_relative=node.z_as_relative
	for child in node.get_children():
		if child is Control:result.add_child(copy(child))
	return result

static func _face_theme(node:Control) -> Theme:
	var ancestor:Node=node
	while ancestor!=null:
		if ancestor is Control and ancestor.theme!=null:return ancestor.theme
		ancestor=ancestor.get_parent()
	return null

static func _has_override(node:Control,category:int,key:String) -> bool:
	match category:
		Theme.DATA_TYPE_COLOR:return node.has_theme_color_override(key)
		Theme.DATA_TYPE_CONSTANT:return node.has_theme_constant_override(key)
		Theme.DATA_TYPE_FONT:return node.has_theme_font_override(key)
		Theme.DATA_TYPE_FONT_SIZE:return node.has_theme_font_size_override(key)
		Theme.DATA_TYPE_ICON:return node.has_theme_icon_override(key)
		Theme.DATA_TYPE_STYLEBOX:return node.has_theme_stylebox_override(key)
	return false

static func rect_in(host: Control,node: Control) -> Rect2:
	# get_rect() omits an in-progress scale/rotation around the pivot. Capture
	# all four visible corners before moving a card between UI owners.
	var transform:=host.get_global_transform().affine_inverse()*node.get_global_transform()
	var result:=Rect2(transform*Vector2.ZERO,Vector2.ZERO)
	for point in [Vector2(node.size.x,0),node.size,Vector2(0,node.size.y)]:result=result.expand(transform*point)
	return result

static func fade(node: Control,to: float,duration: float=.18,delay: float=0) -> Tween:
	var tween:=claim(node,["alpha"])
	tween.tween_property(node,"modulate:a",to,duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween

static func cards(list:Control) -> Array:
	var result:Array=[]
	if list==null:return result
	for slot in list.get_children():
		var card:Control=slot
		if slot.get_meta("motion_slot",false):card=slot.get("content") as Control
		if card is Button:result.append(card)
	return result

static func travel(node:Control,to:Vector2,duration:float=.32,delay:float=0,spring:bool=false) -> Tween:
	var start:=node.position
	var tween:=claim(node,["position"])
	tween.tween_method(func(p:float):node.position=start.lerp(to,Easing.bezier(p,.2,1.3,.4,1) if spring else Easing.bezier(p,.22,1,.36,1)),0.0,1.0,duration).set_delay(delay)
	return tween

static func reveal(node:Control,delay:float=0,duration:float=.32,offset:Vector2=Vector2(0,6)) -> void:
	var fresh:=not node.has_meta("motion_revealed")
	var resting:Vector2=node.get_meta("reveal_position",node.position)
	if fresh:
		node.set_meta("motion_revealed",true);node.set_meta("reveal_position",resting)
		node.position+=offset;node.modulate.a=0
	travel(node,resting,duration,delay,true);fade(node,1.0,minf(.26,duration),delay)

static func collapse(card:Control,duration:float=.28,delay:float=0) -> void:
	var slot:Control=card.get_parent()
	if not slot.get_meta("motion_slot",false):return
	var holder:MotionSlot=slot as MotionSlot
	holder.clip_contents=true
	holder.extent=holder.size.y
	var tween:=claim(slot,["extent"])
	tween.tween_property(holder,"extent",0.0,duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# The gap belongs to the slot, so removing it adds no last-frame jump.
	tween.tween_callback(holder.hide)

static func restore(card:Control) -> void:
	var slot:Control=card.get_parent()
	if slot.get_meta("motion_slot",false):
		var holder:MotionSlot=slot as MotionSlot
		holder.show();holder.clip_contents=false
		if holder.extent>=0:
			var target:float=card.get_combined_minimum_size().y+holder.gap
			var tween:=claim(slot,["extent"])
			tween.tween_property(holder,"extent",target,.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_callback(func():holder.extent=-1.0)
	travel(card,Vector2.ZERO,.3,0,true);deal(card,0)

static func dismiss(card:Control,index:int=0,direction:float=1,duration:float=.26) -> void:
	pivot(card)
	travel(card,card.position+Vector2(direction*16,34),duration,index*.04)
	var tween:=claim(card,["scale","rotation"]).set_parallel()
	tween.tween_property(card,"scale",card.scale*.92,duration).set_delay(index*.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(card,"rotation",card.rotation+direction*.07,duration).set_delay(index*.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade(card,0.0,duration,index*.04)

static func settle_scale(node:Control,peak:float=1.28) -> void:
	if not is_instance_valid(node) or node.get_meta("retiring",false):return
	pivot(node)
	var tween:=claim(node,["scale"])
	tween.tween_property(node,"scale",Vector2.ONE*peak,.075).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node,"scale",Vector2.ONE*.92,.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node,"scale",Vector2.ONE,.205).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

static func meter(node: Range,to: float,duration: float=.16,immediate: bool=false) -> void:
	if node.has_meta("motion_value"):
		var old:Tween=node.get_meta("motion_value")
		if old.is_valid():old.kill()
	if immediate:node.value=to;return
	var tween:=node.create_tween();node.set_meta("motion_value",tween)
	tween.tween_property(node,"value",to,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func pulse(node: Control,amount: float=1.12) -> void:
	if not is_instance_valid(node) or node.get_meta("retiring",false):return
	pivot(node)
	var tween:=claim(node,["scale"]);node.set_meta("pulse",tween)
	var peak:=Vector2(maxf(node.scale.x,amount),maxf(node.scale.y,amount))
	tween.tween_property(node,"scale",peak,.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node,"scale",Vector2.ONE,.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func enter(node: Control,delay: float=0) -> void:
	if not is_instance_valid(node) or node.get_meta("retiring",false):return
	var fresh:=not node.has_meta("motion_entered")
	node.set_meta("motion_entered",true);pivot(node)
	var tween:=claim(node,["scale"])
	if fresh:node.scale=Vector2(.96,.96);node.modulate.a=0
	var start:=node.scale
	tween.tween_method(func(p:float):
		node.scale=start.lerp(Vector2.ONE,Easing.bezier(p,.2,1.3,.4,1))
	,0.0,1.0,.38).set_delay(delay)
	fade(node,1.0,.26,delay)

static func leave(node:Control,duration:float=.18) -> Tween:
	if not is_instance_valid(node):return null
	stop(node);pivot(node);node.set_meta("retiring",true)
	var tween:=claim(node,["scale"])
	tween.tween_property(node,"scale",node.scale*.97,duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var fading:=fade(node,0.0,duration)
	fading.tween_callback(node.queue_free)
	return fading

static func backdrop(node: Control,amount: float,duration: float,retire: bool=false) -> Tween:
	var start:float=node.get_meta("backdrop_amount",1.0)
	var material:ShaderMaterial=node.material as ShaderMaterial
	var tween:=claim(node,["backdrop"])
	tween.tween_method(func(p:float):
		var value:=lerpf(start,amount,Easing.bezier(p,.22,1,.36,1))
		node.set_meta("backdrop_amount",value)
		if material!=null:material.set_shader_parameter("amount",value)
		else:node.modulate.a=value
	,0.0,1.0,duration)
	if retire:tween.tween_callback(node.queue_free)
	return tween

static func glint(card: Control, delay: float, tint: Color) -> void:
	if not is_instance_valid(card) or card.get_meta("retiring",false):
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

static func prepare_deal(card:Control) -> void:
	if card.has_meta("motion_dealt"):return
	card.set_meta("motion_dealt",true);card.set_meta("motion_center_pivot",true);card.pivot_offset=card.size/2;card.scale=Vector2(.94,.015);card.modulate.a=.2

static func deal(card: Control,index: int) -> void:
	if not is_instance_valid(card) or card.get_meta("retiring",false):return
	prepare_deal(card);pivot(card)
	var tween:=claim(card,["scale","rotation"])
	var start:=card.scale
	var turn:=card.rotation
	tween.tween_method(func(p:float):
		var t:=Easing.bezier(p,.22,1,.36,1)
		# A subtle opening overshoot evokes the JS rotateX flap in CanvasItem.
		var opened:=Vector2(1.01,1.045)
		card.scale=start.lerp(opened,t/.62) if t<.62 else opened.lerp(Vector2.ONE,(t-.62)/.38)
		card.rotation=lerpf(turn,0.0,t)
	,0.0,1.0,.44).set_delay(index*.07)
	fade(card,1.0,.28,index*.07)

static func fold(card: Control,index: int) -> void:
	if not is_instance_valid(card) or card.get_meta("retiring",false):return
	pivot(card)
	var tween:=claim(card,["scale"])
	tween.tween_property(card,"scale",Vector2(.94,.02),.26).set_delay(index*.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade(card,.2,.26,index*.06)

static func flight(host: Control,ghost: Control,from: Rect2,to: Rect2,duration: float=.62,source: Dictionary={},destination:Control=null) -> Tween:
	if source.is_empty() and ghost.get_parent()!=null:source=pose_in(host,ghost)
	if source.is_empty():
		var intrinsic:=ghost.size.max(Vector2.ONE)
		source={"size":intrinsic,"center":from.get_center(),"scale":from.size/intrinsic,"rotation":0.0,"alpha":ghost.modulate.a}
	mount(host,ghost,source);ghost.z_index=32
	# Keep the card's intrinsic content size during the ownership handoff;
	# only its visual transform follows the destination rectangle.
	var content_size:=ghost.size.max(Vector2.ONE)
	var a:Vector2=source.center;var b:=to.get_center()
	var bend:Vector2=(a+b)/2+Vector2(35,-60)
	var start_scale:=ghost.scale
	var start_rotation:=ghost.rotation
	var tween:=claim(ghost,["position","scale","rotation"])
	tween.tween_method(func(p:float):
		var value:=Easing.bezier(p,.45,0,.2,1)
		var u:=1-value
		var end:Rect2=rect_in(host,destination) if is_instance_valid(destination) else to
		ghost.position=u*u*a+2*u*value*bend+value*value*end.get_center()-content_size/2
		ghost.scale=start_scale.lerp(end.size/content_size,value)
		ghost.rotation=lerpf(start_rotation,0,value)+sin(value*PI)*-.12
	,0.0,1.0,duration)
	fade(ghost,1.0,minf(.18,duration))
	return tween

static func card_flight(host:Control,card:Control,slot:Control,from:Rect2,to:Rect2,duration:float=.64,source:Dictionary={}) -> Control:
	# Keep both faces at fixed layout sizes while one neutral shell follows the
	# curved path. This is the native equivalent of the JS dialog flight ghost.
	if source.is_empty():source=pose_in(host,card)
	stop(card)
	var shell:=Control.new();shell.mouse_filter=Control.MOUSE_FILTER_IGNORE;shell.size=source.size;shell.pivot_offset=shell.size/2;shell.position=source.center-shell.size/2;shell.rotation=source.rotation;shell.z_index=32;host.add_child(shell)
	var card_pose:Dictionary=source.duplicate();card_pose.center=shell.size/2;card_pose.rotation=0.0
	mount(shell,card,card_pose)
	shell.add_child(slot);slot.size=to.size;slot.pivot_offset=slot.size/2;slot.position=shell.size/2-slot.size/2;slot.modulate.a=0.0
	var a:Vector2=source.center;var b:=to.get_center();var bend:Vector2=(a+b)/2+Vector2(35,-70)
	var start_scale:Vector2=source.scale
	var tween:=claim(shell,["position","rotation","faces"])
	tween.tween_method(func(progress:float):
		var t:=Easing.bezier(progress,.45,0,.2,1);var u:=1-t
		shell.position=u*u*a+2*u*t*bend+t*t*b-shell.size/2
		shell.rotation=lerpf(float(source.rotation),0.0,t)+sin(t*PI)*(.09 if b.x>=a.x else -.09)
		var size_now:=from.size.lerp(to.size,t)
		card.scale=start_scale*(1.0-clampf(progress/.45,0,1)*.45)
		card.modulate.a=float(source.alpha)*(1.0-Easing.bezier(clampf(progress/.45,0,1),.5,0,.75,0))
		slot.scale=size_now/to.size.max(Vector2.ONE)
		slot.modulate.a=Easing.bezier(clampf((progress-.24)/.46,0,1),.22,1,.36,1)
	,0.0,1.0,duration)
	return shell
