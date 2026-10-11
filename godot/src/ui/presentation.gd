extends RefCounted
## Standalone tokens, fonts and Lucide vectors. Cache per theme/colour.
var manifest: Dictionary
var icon_cache: Dictionary = {}
var fonts: Array[Font] = []
var mode := "light"

func _init() -> void:
	manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/manifest.json"))
	for key in ["regular","bold","cjk"]:
		var font: FontFile = load_font(key)
		fonts.append(font)
	fonts[0].fallbacks=[fonts[2]];fonts[1].fallbacks=[fonts[2]]
	# Chromium synthesizes bold for the installed single-weight CJK fallback.
	var cjk_bold:=FontVariation.new();cjk_bold.base_font=fonts[2];cjk_bold.variation_embolden=0.6
	fonts[1].fallbacks=[cjk_bold]

static func load_font(key: String) -> FontFile:
	var font:=FontFile.new()
	font.data=FileAccess.get_file_as_bytes("res://assets/fonts/"+key+".bin")
	return font

func color(key: String) -> Color:
	return Color(manifest.themes[mode].get(key,"#22271f"))

func mix(ink: Color,base: Color,weight: float) -> Color:
	return Color(base.r+(ink.r-base.r)*weight,base.g+(ink.g-base.g)*weight,base.b+(ink.b-base.b)*weight,base.a+(ink.a-base.a)*weight)

func margin(parent: Control,left: int,top: int,right: int,bottom: int) -> MarginContainer:
	var result:=MarginContainer.new()
	for pair in [["left",left],["top",top],["right",right],["bottom",bottom]]: result.add_theme_constant_override("margin_"+pair[0],pair[1])
	parent.add_child(result)
	if not parent is Container:result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return result

func column(parent: Control,gap: int=0) -> VBoxContainer:
	var result:=VBoxContainer.new();result.add_theme_constant_override("separation",gap);result.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(result);return result

func row(parent: Control,gap: int=0) -> HBoxContainer:
	var result:=HBoxContainer.new();result.add_theme_constant_override("separation",gap);result.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(result);return result

func text(parent: Control,value: String,size: int=12,token: String="ink",bold: bool=false,wrap: bool=false) -> Label:
	var result:=label(value,size,token,bold)
	if wrap:
		result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(result);return result

func image(parent: Control,id: String,ink: Color,dimensions: Vector2) -> TextureRect:
	var result:=TextureRect.new();result.texture=icon(id,ink);result.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;result.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;result.custom_minimum_size=dimensions;result.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(result);return result

func rule(parent: Control,token: String="line") -> ColorRect:
	var result:=ColorRect.new();result.color=color(token);result.custom_minimum_size.y=1;result.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(result);return result

func space(parent: Control,height: int) -> Control:
	var result:=Control.new();result.custom_minimum_size.y=height;result.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(result);return result

func button(parent: Control,value: String,callback: Callable,id: String="",height: int=36) -> Button:
	var result:=Button.new();result.text=value;result.custom_minimum_size.y=height;result.add_theme_font_size_override("font_size",12);result.pressed.connect(callback)
	if id!="":
		result.icon=icon(id,color("text-2"));result.expand_icon=true;result.add_theme_constant_override("icon_max_width",14)
		if value=="":result.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(result);return result

func badge(parent: Control,value: String,face: Color,edge: Color,ink: Color,size: int=10,radius: int=4) -> PanelContainer:
	var result:=PanelContainer.new();result.add_theme_stylebox_override("panel",box(face,edge,radius,4));parent.add_child(result)
	var title:=text(result,value,size);title.add_theme_color_override("font_color",ink);return result

func icon(id: String,ink: Color) -> Texture2D:
	var key := id+ink.to_html()
	if icon_cache.has(key): return icon_cache[key]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#%s" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [ink.to_html(false),manifest.icons.get(id,"")]
	var image := Image.new()
	# Icons are authored at design-pixel size but Android renders the 412px
	# canvas on much denser surfaces. Rasterize with headroom before scaling.
	if image.load_svg_from_string(svg,4.0)!=OK: return null
	var texture := ImageTexture.create_from_image(image)
	icon_cache[key]=texture
	return texture

func pointer_through(node: Node) -> void:
	if node is Control:node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():pointer_through(child)

func circle_icon(id: String,ink: Color,dimension: int,checked: bool=false) -> Texture2D:
	var svg: String='<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><rect x="0.5" y="0.5" width="%d" height="%d" rx="%d" fill="#%s" stroke="#%s"/>%s</svg>' % [dimension,dimension,dimension-1,dimension-1,3 if id=="check" else dimension/2,ink.to_html(false) if checked or id!="check" else color("surface").to_html(false),ink.to_html(false),'<path d="m4 9 3 3 7-7" fill="none" stroke="white" stroke-width="2"/>' if checked else ""]
	var image:=Image.new();image.load_svg_from_string(svg);return ImageTexture.create_from_image(image)

func box(face: Color,edge: Color,radius: int=8,padding: int=0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=face;style.border_color=edge
	style.set_border_width_all(1);style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style

func apply(control: Control) -> void:
	var theme := Theme.new()
	theme.default_font=fonts[0];theme.default_font_size=12
	theme.set_font("font","Button",fonts[1])
	for type in ["Label","Button","CheckButton","OptionButton","LineEdit"]:
		theme.set_color("font_color",type,color("ink"))
		theme.set_color("font_hover_color",type,color("ink"))
		theme.set_color("font_pressed_color",type,color("ink"))
	theme.set_constant("icon_max_width","Button",18)
	theme.set_stylebox("normal","Button",box(color("surface"),color("line-2"),7,8))
	theme.set_stylebox("hover","Button",box(color("surface-2"),color("accent-line"),7,8))
	theme.set_stylebox("pressed","Button",box(color("surface-3"),color("accent-line"),7,8))
	theme.set_stylebox("disabled","Button",box(color("disabled-bg"),color("line"),6,8))
	theme.set_stylebox("focus","Button",box(Color.TRANSPARENT,color("ink"),7))
	theme.set_color("font_disabled_color","Button",color("text-3"))
	theme.set_icon("checked","CheckBox",circle_icon("check",color("accent-ink"),18,true))
	theme.set_icon("unchecked","CheckBox",circle_icon("check",color("line-2"),18))
	for state in ["normal","hover","pressed"]:theme.set_stylebox(state,"CheckBox",StyleBoxEmpty.new())
	control.theme=theme

func label(text: String,size: int=12,token: String="ink",bold: bool=false) -> Label:
	var result := Label.new()
	result.text=text;result.add_theme_font_override("font",fonts[1] if bold else fonts[0])
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",color(token));result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result
