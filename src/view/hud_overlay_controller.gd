extends Node
class_name HudOverlayController

const MAIN_MENU_SCENE := preload("res://scenes/main_menu.tscn")

enum MatchMode { LOCAL, VS_CPU, DEMO, ONLINE }

signal menu_choice(mode: int)
signal restart_pressed
signal menu_pressed
signal quit_pressed
signal team_requested
signal account_requested
signal wiki_requested
signal options_requested
signal option_changed(key: String, delta: int)
signal items_requested
signal host_requested
signal join_requested(address: String)

var hud_ref
var _main_menu_instance: Control


func setup(hud_node, root: Control) -> void:
    hud_ref = hud_node
    hud_ref.menu_bg = UITheme.background(0.18)
    hud_ref.menu_bg.visible = false
    root.add_child(hud_ref.menu_bg)


func build_menu_extras(root: Control) -> void:
    var h = hud_ref
    h.account_panel = PanelContainer.new()
    h.account_panel.visible = false
    h.account_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    root.add_child(h.account_panel)
    h.account_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 12)
    h.account_panel.gui_input.connect(func(ev):
        if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
            account_requested.emit())
    h.wiki_button = TextureButton.new()
    h.wiki_button.name = "WikiButton"
    h.wiki_button.texture_normal = UIIcons.get_icon("help")
    h.wiki_button.ignore_texture_size = true
    h.wiki_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    h.wiki_button.custom_minimum_size = Vector2(44, 44)
    h.wiki_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    h.wiki_button.tooltip_text = "Wiki: regras e mecânicas"
    h.wiki_button.visible = false
    h.wiki_button.pressed.connect(func(): wiki_requested.emit())
    root.add_child(h.wiki_button)
    h.wiki_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
    h.wiki_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    var holder := VBoxContainer.new()
    holder.visible = false
    holder.name = "MenuIcons"
    root.add_child(holder)
    holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 18)
    holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
    holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
    h.menu_icons = HBoxContainer.new()
    h.menu_icons.alignment = BoxContainer.ALIGNMENT_CENTER
    h.menu_icons.add_theme_constant_override("separation", 26)
    holder.add_child(h.menu_icons)
    h.menu_icon_label = Label.new()
    h.menu_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    h.menu_icon_label.add_theme_font_override("font", UITheme.title_font)
    h.menu_icon_label.add_theme_font_size_override("font_size", 20)
    h.menu_icon_label.add_theme_color_override("font_color", UITheme.GOLD)
    h.menu_icon_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
    h.menu_icon_label.add_theme_constant_override("outline_size", 6)
    h.menu_icon_label.custom_minimum_size = Vector2(0, 26)
    holder.add_child(h.menu_icon_label)
    for spec in [["items", "Itens", "items", items_requested], ["team", "Personalizar time", "class_escudeiro", team_requested]]:
        var b := TextureButton.new()
        b.name = "Icon_" + spec[0]
        b.texture_normal = UIIcons.get_icon(spec[2])
        b.ignore_texture_size = true
        b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
        b.custom_minimum_size = Vector2(72, 72)
        b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        b.tooltip_text = spec[1]
        var label_text: String = spec[1]
        var sig: Signal = spec[3]
        b.mouse_entered.connect(func():
            h.menu_icon_label.text = label_text
            b.modulate = Color(1.3, 1.2, 0.8))
        b.mouse_exited.connect(func():
            h.menu_icon_label.text = ""
            b.modulate = Color.WHITE)
        b.pressed.connect(func(): sig.emit())
        h.menu_icons.add_child(b)
    h.splash = Control.new()
    h.splash.visible = false
    h.splash.set_anchors_preset(Control.PRESET_FULL_RECT)
    h.splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(h.splash)
    var sbox := VBoxContainer.new()
    sbox.set_anchors_preset(Control.PRESET_CENTER)
    sbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
    sbox.grow_vertical = Control.GROW_DIRECTION_BOTH
    sbox.add_theme_constant_override("separation", 40)
    h.splash.add_child(sbox)
    var big := UITheme.title("TACTICS PVP", 86)
    big.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
    big.add_theme_constant_override("outline_size", 14)
    sbox.add_child(big)
    var press := Label.new()
    press.name = "PressAnyKey"
    press.text = "Pressione qualquer tecla para iniciar"
    press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    press.add_theme_font_size_override("font_size", 26)
    press.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
    press.add_theme_constant_override("outline_size", 8)
    sbox.add_child(press)
    var tw := create_tween().set_loops()
    tw.tween_property(press, "modulate:a", 0.25, 0.9)
    tw.tween_property(press, "modulate:a", 1.0, 0.9)

func set_account(acc: Account) -> void:
    var h = hud_ref
    for c in h.account_panel.get_children():
        h.account_panel.remove_child(c)
        c.queue_free()
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(AccountScreen.avatar_frame(acc, 1))
    var col := VBoxContainer.new()
    col.mouse_filter = Control.MOUSE_FILTER_IGNORE
    col.add_theme_constant_override("separation", 0)
    var name_l := RichTextLabel.new()
    name_l.bbcode_enabled = true
    name_l.fit_content = true
    name_l.scroll_active = false
    name_l.custom_minimum_size = Vector2(190, 0)
    name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    name_l.text = "[b]%s[/b] [img=14]res://assets/icons/sex_%s.png[/img]" % [acc.player_name, acc.sex]
    col.add_child(name_l)
    var t := Label.new()
    t.text = acc.title_name()
    t.add_theme_font_size_override("font_size", 15)
    t.add_theme_color_override("font_color", UITheme.DIM)
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    col.add_child(t)
    var rk := Label.new()
    rk.text = acc.rank_name()
    rk.add_theme_font_size_override("font_size", 16)
    rk.add_theme_color_override("font_color", UITheme.GOLD)
    rk.mouse_filter = Control.MOUSE_FILTER_IGNORE
    col.add_child(rk)
    row.add_child(col)
    h.account_panel.add_child(row)


func set_menu_chrome(on: bool) -> void:
    var h = hud_ref
    h.account_panel.visible = on
    h.wiki_button.visible = on
    h.menu_icons.get_parent().visible = on
    if not on:
        h.menu_icon_label.text = ""


func _clear_overlay() -> void:
    if is_instance_valid(_main_menu_instance):
        _main_menu_instance.queue_free()
    _main_menu_instance = null
    var h = hud_ref
    h._clear(h.overlay_box)
    h.overlay.remove_theme_stylebox_override("panel")
    set_menu_chrome(false)


func show_splash() -> void:
    var h = hud_ref
    _clear_overlay()
    h.overlay.visible = false
    h.menu_bg.visible = true
    h.splash.visible = true


func show_menu() -> void:
    var h = hud_ref
    _clear_overlay()
    h.splash.visible = false
    h.menu_bg.visible = true
    h.overlay.visible = false
    _main_menu_instance = MAIN_MENU_SCENE.instantiate()
    _main_menu_instance.mode_selected.connect(func(mode: int): menu_choice.emit(mode))
    _main_menu_instance.online_pressed.connect(show_online_menu)
    _main_menu_instance.options_pressed.connect(func(): options_requested.emit())
    _main_menu_instance.quit_pressed.connect(func(): quit_pressed.emit())
    var ui_root: Node = h.menu_bg.get_parent()
    ui_root.add_child(_main_menu_instance)
    ui_root.move_child(_main_menu_instance, h.menu_bg.get_index() + 1)
    set_menu_chrome(true)
    h._focus_first.call_deferred()


func show_options(values: Dictionary) -> void:
    var h = hud_ref
    _clear_overlay()
    h.menu_bg.visible = not h._game_on
    h.overlay_box.add_child(UITheme.title("OPÇÕES", 30))
    h.overlay_box.add_child(h._button("Modo de tela: %s" % values["display_mode"], func(): option_changed.emit("display_mode", 0)))
    var res: Button = h._button("Resolução da janela: %s" % values["resolution"], func(): option_changed.emit("resolution", 0))
    res.disabled = not values["can_resize"]
    h.overlay_box.add_child(res)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var minus: Button = h._button("−", func(): option_changed.emit("volume", -1))
    minus.custom_minimum_size = Vector2(60, 38)
    row.add_child(minus)
    var vol := Label.new()
    vol.text = "Volume geral: %d%%" % int(round(float(values["volume"]) * 100.0))
    vol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(vol)
    var plus: Button = h._button("+", func(): option_changed.emit("volume", 1))
    plus.custom_minimum_size = Vector2(60, 38)
    row.add_child(plus)
    h.overlay_box.add_child(row)
    h.overlay_box.add_child(h._button("Voltar", func(): menu_pressed.emit()))
    h.overlay.visible = true
    h._focus_first.call_deferred()


func show_online_menu() -> void:
    var h = hud_ref
    _clear_overlay()
    h.menu_bg.visible = not h._game_on
    h.overlay_box.add_child(UITheme.title("JOGAR ONLINE", 28))
    h.overlay_box.add_child(h._button("Hospedar uma partida", func(): host_requested.emit()))
    var edit := LineEdit.new()
    edit.name = "IpEdit"
    edit.text = "127.0.0.1"
    edit.placeholder_text = "IP de quem hospeda"
    edit.custom_minimum_size = Vector2(0, 38)
    h.overlay_box.add_child(edit)
    h.overlay_box.add_child(h._button("Entrar na partida desse IP", func(): join_requested.emit(edit.text.strip_edges())))
    h.overlay_box.add_child(h._button("Voltar", func(): menu_pressed.emit()))
    h.overlay.visible = true
    h._focus_first.call_deferred()


func show_waiting(title: String, bbcode: String) -> void:
    var h = hud_ref
    _clear_overlay()
    h.menu_bg.visible = not h._game_on
    h.overlay_box.add_child(UITheme.title(title.to_upper(), 24))
    var body: RichTextLabel = h._rich(460)
    body.text = bbcode
    h.overlay_box.add_child(body)
    h.overlay_box.add_child(h._button("Cancelar", func(): menu_pressed.emit()))
    h.overlay.visible = true


func show_message(title: String, bbcode: String) -> void:
    var h = hud_ref
    _clear_overlay()
    h.menu_bg.visible = not h._game_on
    h.overlay_box.add_child(UITheme.title(title.to_upper(), 24))
    var body: RichTextLabel = h._rich(460)
    body.text = bbcode
    h.overlay_box.add_child(body)
    h.overlay_box.add_child(h._button("Voltar ao menu", func(): menu_pressed.emit()))
    h.overlay.visible = true


func show_end(title: String, bbcode: String) -> void:
    var h = hud_ref
    _clear_overlay()
    h.menu_bg.visible = false
    h.overlay_box.add_child(UITheme.title(title.to_upper(), 28))
    var body: RichTextLabel = h._rich(460)
    body.text = bbcode
    h.overlay_box.add_child(body)
    h.overlay_box.add_child(h._button("Revanche (nova partida)", func(): restart_pressed.emit()))
    h.overlay_box.add_child(h._button("Voltar ao menu", func(): menu_pressed.emit()))
    h.overlay.visible = true


func hide_overlay() -> void:
    var h = hud_ref
    h.overlay.visible = false
    h.menu_bg.visible = false