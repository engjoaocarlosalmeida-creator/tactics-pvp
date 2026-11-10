## Wiki dentro do jogo (data/wiki.json): regras e mecanicas explicadas.
class_name WikiScreen
extends CanvasLayer


signal closed

const PATH := "res://data/wiki.json"

var topics: Array = []
var selected := 0
var _list: VBoxContainer
var _text: RichTextLabel


func setup(_r: Rules, _c: JobCatalog, _ro: Roster) -> void :
    layer = 20
    var f := FileAccess.open(PATH, FileAccess.READ)
    if f != null:
        var parsed = JSON.parse_string(f.get_as_text())
        if typeof(parsed) == TYPE_DICTIONARY:
            topics = parsed.get("topics", [])
    var bg := UITheme.background(0.68)
    bg.name = "Background"
    add_child(bg)
    var root := MarginContainer.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.theme = UITheme.get_theme()
    for side in ["left", "right", "top", "bottom"]:
        root.add_theme_constant_override("margin_" + side, 14)
    add_child(root)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 10)
    root.add_child(col)
    var head_panel := PanelContainer.new()
    col.add_child(head_panel)
    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 12)
    head_panel.add_child(head)
    var title := UITheme.title("WIKI — REGRAS E MECÂNICAS", 26)
    title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    head.add_child(title)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(spacer)
    var back := Button.new()
    back.name = "Back"
    back.text = "Voltar"
    back.focus_mode = Control.FOCUS_NONE
    back.custom_minimum_size = Vector2(0, 38)
    back.pressed.connect(go_back)
    head.add_child(back)
    var body := HBoxContainer.new()
    body.add_theme_constant_override("separation", 10)
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(body)
    var left := PanelContainer.new()
    left.custom_minimum_size = Vector2(280, 0)
    body.add_child(left)
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    left.add_child(sc)
    _list = VBoxContainer.new()
    _list.add_theme_constant_override("separation", 5)
    _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(_list)
    var right := PanelContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(right)
    _text = RichTextLabel.new()
    _text.bbcode_enabled = true
    _text.scroll_active = true
    _text.add_theme_font_size_override("normal_font_size", 20)
    _text.add_theme_font_size_override("bold_font_size", 20)
    right.add_child(_text)
    select(0)


func select(i: int) -> void :
    if topics.is_empty():
        return
    selected = clampi(i, 0, topics.size() - 1)
    for c in _list.get_children():
        _list.remove_child(c)
        c.queue_free()
    for k in topics.size():
        var b := Button.new()
        b.name = "Topic_" + str(topics[k]["id"])
        b.text = str(topics[k]["title"])
        b.toggle_mode = true
        b.button_pressed = (k == selected)
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.custom_minimum_size = Vector2(0, 40)
        b.focus_mode = Control.FOCUS_NONE
        var idx := k
        b.pressed.connect( func(): select(idx))
        _list.add_child(b)
    _text.text = "[b][font_size=26]%s[/font_size][/b]\n\n%s" % [topics[selected]["title"], topics[selected]["text"]]


func go_back() -> void :
    closed.emit()


func _unhandled_input(event: InputEvent) -> void :

    if event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        go_back()

