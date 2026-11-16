## Tema dos menus (janelas azuis translucidas, botoes delimitados, fontes Lato/Marcellus) e itens de
## menu so de texto.
class_name UITheme
extends RefCounted



const CREAM := Color(0.93, 0.9, 0.77)
const GOLD := Color(1.0, 0.84, 0.35)
const DIM := Color(0.5, 0.52, 0.65)
static var _theme: Theme
static var title_font: Font
static var body_font: Font
static var bold_font: Font


static func _font(path: String) -> FontFile:
    var f: FontFile = load(path)
    f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
    f.hinting = TextServer.HINTING_LIGHT
    f.fallbacks = [ThemeDB.fallback_font]
    return f


static func _box(path: String, margin: int, content: int) -> StyleBoxTexture:
    var sb := StyleBoxTexture.new()
    sb.texture = load(path)
    sb.texture_margin_left = margin
    sb.texture_margin_right = margin
    sb.texture_margin_top = margin
    sb.texture_margin_bottom = margin
    sb.content_margin_left = content
    sb.content_margin_right = content
    sb.content_margin_top = content - 2
    sb.content_margin_bottom = content - 2
    return sb


static func get_theme() -> Theme:
    if _theme != null:
        return _theme
    var t := Theme.new()
    body_font = _font("res://assets/fonts/Lato-Regular.ttf")
    title_font = _font("res://assets/fonts/Marcellus-Regular.ttf")
    bold_font = _font("res://assets/fonts/Lato-Bold.ttf")
    t.default_font = body_font
    t.default_font_size = 19

    t.set_stylebox("panel", "PanelContainer", _box("res://assets/ui/window.png", 14, 14))
    t.set_stylebox("panel", "Panel", _box("res://assets/ui/window.png", 14, 14))

    var normal_button := _box("res://assets/ui/button_normal.png", 8, 10)
    normal_button.modulate_color = Color(1, 1, 1, 0.24)
    var hover_button := _box("res://assets/ui/button_hover.png", 8, 10)
    hover_button.modulate_color = Color(1, 1, 1, 0.48)
    var pressed_button := _box("res://assets/ui/button_pressed.png", 8, 10)
    pressed_button.modulate_color = Color(1, 1, 1, 0.38)
    var disabled_button := _box("res://assets/ui/button_disabled.png", 8, 10)
    disabled_button.modulate_color = Color(1, 1, 1, 0.12)
    t.set_stylebox("normal", "Button", normal_button)
    t.set_stylebox("hover", "Button", hover_button)
    t.set_stylebox("pressed", "Button", pressed_button)
    t.set_stylebox("disabled", "Button", disabled_button)
    t.set_stylebox("hover_pressed", "Button", hover_button)
    t.set_stylebox("focus", "Button", hover_button)
    t.set_color("font_color", "Button", CREAM)
    t.set_color("font_hover_color", "Button", GOLD)
    t.set_color("font_pressed_color", "Button", GOLD)
    t.set_color("font_hover_pressed_color", "Button", GOLD)
    t.set_color("font_focus_color", "Button", CREAM)
    t.set_color("font_disabled_color", "Button", DIM)
    t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.9))
    t.set_constant("outline_size", "Button", 0)
    t.set_constant("h_separation", "Button", 10)

    t.set_stylebox("normal", "LineEdit", _box("res://assets/ui/field.png", 8, 8))
    t.set_stylebox("focus", "LineEdit", _box("res://assets/ui/button_hover.png", 8, 8))
    t.set_color("font_color", "LineEdit", CREAM)
    t.set_color("caret_color", "LineEdit", GOLD)
    t.set_color("font_placeholder_color", "LineEdit", DIM)

    t.set_color("font_color", "Label", CREAM)
    t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.85))
    t.set_constant("shadow_offset_x", "Label", 1)
    t.set_constant("shadow_offset_y", "Label", 2)

    t.set_color("default_color", "RichTextLabel", CREAM)
    t.set_font("normal_font", "RichTextLabel", body_font)
    t.set_font("bold_font", "RichTextLabel", bold_font)
    t.set_font_size("normal_font_size", "RichTextLabel", 19)
    t.set_font_size("bold_font_size", "RichTextLabel", 19)
    _theme = t
    return t



static func portrait_frame() -> StyleBoxTexture:
    var sb := _box("res://assets/ui/portrait_frame.png", 6, 4)
    sb.content_margin_top = 4
    sb.content_margin_bottom = 4
    return sb



static func title(text: String, size := 26) -> Label:
    get_theme()
    var l := Label.new()
    l.text = text
    l.add_theme_font_override("font", title_font)
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", GOLD)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return l



static func pixel_image(tex: Texture2D, scale: int) -> TextureRect:
    var r := TextureRect.new()
    r.texture = tex
    r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    r.stretch_mode = TextureRect.STRETCH_SCALE
    r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    if tex != null:
        r.custom_minimum_size = Vector2(tex.get_width() * scale, tex.get_height() * scale)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return r



static func framed_face(job_id: String, look: String, scale: int) -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", portrait_frame())
    p.add_child(pixel_image(JobArt.face(job_id, look), scale))
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return p



static func compact(b: Button, pad := 3) -> void :
    for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
        var sb: StyleBoxTexture = get_theme().get_stylebox(state, "Button").duplicate()
        sb.content_margin_top = pad
        sb.content_margin_bottom = pad
        b.add_theme_stylebox_override(state, sb)




static func background(dim: float) -> Control:
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var tex := TextureRect.new()
    tex.texture = load("res://assets/ui/menu_bg.jpg")
    tex.set_anchors_preset(Control.PRESET_FULL_RECT)
    tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(tex)
    var shade := ColorRect.new()
    shade.color = Color(0.02, 0.04, 0.15, dim)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(shade)
    return root



static func small_window() -> StyleBoxTexture:
    var sb: StyleBoxTexture = get_theme().get_stylebox("panel", "PanelContainer").duplicate()
    sb.content_margin_left = 7
    sb.content_margin_right = 7
    sb.content_margin_top = 5
    sb.content_margin_bottom = 6
    return sb



static func menu_text(text: String, size := 28) -> Button:
    get_theme()
    var b := Button.new()
    b.text = text
    b.flat = true
    b.focus_mode = Control.FOCUS_NONE
    b.alignment = HORIZONTAL_ALIGNMENT_CENTER
    b.custom_minimum_size = Vector2(0, size + 18)
    b.add_theme_font_override("font", title_font)
    b.add_theme_font_size_override("font_size", size)
    for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
        b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
    b.add_theme_color_override("font_color", CREAM)
    for c in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
        b.add_theme_color_override(c, GOLD)
    b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
    b.add_theme_constant_override("outline_size", 7)
    var base := text
    var mark := func(on: bool): b.text = ("▶  %s  ◀" % base) if on else base
    b.mouse_entered.connect( func(): mark.call(true))
    b.mouse_exited.connect( func(): mark.call(b.has_focus()))
    b.focus_entered.connect( func(): mark.call(true))
    b.focus_exited.connect( func(): mark.call(b.is_hovered()))
    return b
