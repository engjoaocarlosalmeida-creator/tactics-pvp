extends Node
class_name HudPopupController

const CHARACTER_MODEL := preload("res://src/view/character_model.gd")

var hud_ref


func setup(hud_node) -> void:
    hud_ref = hud_node


func _header(title: String, face: Texture2D, sex := "", small := false) -> HBoxContainer:
    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 8)
    head.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if face != null:
        head.add_child(UITheme.pixel_image(face, 1))
    var t := Label.new()
    t.text = title
    t.add_theme_font_override("font", UITheme.title_font if not small else UITheme.body_font)
    t.add_theme_font_size_override("font_size", 22 if not small else 10)
    t.add_theme_color_override("font_color", UITheme.GOLD if not small else UITheme.DIM)
    t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    head.add_child(t)
    if sex != "":
        head.add_child(UITheme.pixel_image(UIIcons.get_icon("sex_" + sex), 1))
    return head


func show_context_menu(title: String, items: Array, screen_pos: Vector2, view_size: Vector2, _face: Texture2D = null) -> void:
    var h = hud_ref
    hide_context_menu()
    h.context_panel.draggable = false
    h.context_panel.add_theme_stylebox_override("panel", UITheme.small_window())
    if title != "":
        h.context_box.add_child(_header(title, null, "", true))
    for it in items:
        var b := Button.new()
        b.text = str(it["label"])
        b.disabled = not bool(it["enabled"])
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.focus_mode = Control.FOCUS_NONE
        b.add_theme_font_size_override("font_size", 12)
        b.custom_minimum_size = Vector2(96, 0)
        UITheme.compact(b, 2)
        var id := str(it["id"])
        b.pressed.connect(func(): h.menu_item_chosen.emit(id))
        h.context_box.add_child(b)
        h.context_ids.append(id)
    h._place(h.context_panel, screen_pos, view_size)


func move_context_menu(screen_pos: Vector2, view_size: Vector2) -> void:
    var h = hud_ref
    if not h.context_panel.visible:
        return
    var sz: Vector2 = h.context_panel.size
    h.context_panel.position = Vector2(clampf(screen_pos.x, 2.0, maxf(2.0, view_size.x - sz.x - 2.0)),
            clampf(screen_pos.y, 2.0, maxf(2.0, view_size.y - sz.y - 2.0)))


func hide_context_menu() -> void:
    var h = hud_ref
    h._clear(h.context_box)
    h.context_ids.clear()
    h.context_panel.visible = false


func show_target_window(data: Dictionary, actions: Array, view_size: Vector2) -> void:
    var h = hud_ref
    hide_target_window()
    h.target_box.add_child(_header(str(data["title"]), null, str(data.get("sex", ""))))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    h.target_box.add_child(row)
    var stage := PanelContainer.new()
    stage.add_theme_stylebox_override("panel", UITheme.portrait_frame())
    stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.custom_minimum_size = Vector2(128, 160)
    stage.add_child(CHARACTER_MODEL.create_preview(
            CHARACTER_MODEL.team_color(int(data["team"])), Vector2i(128, 160)))
    row.add_child(stage)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 4)
    col.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(col)
    var info: RichTextLabel = h._rich(230)
    info.text = str(data["text"])
    col.add_child(info)
    var hp_row := HBoxContainer.new()
    hp_row.add_theme_constant_override("separation", 8)
    hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bar := HpBar.new()
    bar.custom_minimum_size = Vector2(140, 14)
    bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    bar.ratio = float(data["hp"]) / maxf(1.0, float(data["max_hp"]))
    hp_row.add_child(bar)
    var hp_l := Label.new()
    hp_l.text = "%d/%d" % [data["hp"], data["max_hp"]]
    hp_l.add_theme_font_size_override("font_size", 16)
    hp_row.add_child(hp_l)
    col.add_child(hp_row)
    var stats: RichTextLabel = h._rich(230)
    stats.text = str(data["stats"])
    col.add_child(stats)
    h.context_ids.clear()
    for it in actions:
        var b := Button.new()
        b.text = str(it["label"])
        b.disabled = not bool(it["enabled"])
        b.focus_mode = Control.FOCUS_NONE
        var id := str(it["id"])
        b.pressed.connect(func(): h.menu_item_chosen.emit(id))
        h.target_box.add_child(b)
        h.context_ids.append(id)
    h._place(h.target_panel, Vector2(view_size.x * 0.5 - 40.0, 90.0), view_size)


func hide_target_window() -> void:
    var h = hud_ref
    h._clear(h.target_box)
    h.target_panel.visible = false


func show_confirm(text_bbcode: String, view_size: Vector2) -> void:
    var h = hud_ref
    h.confirm_label.text = text_bbcode
    h._place(h.confirm_panel, Vector2(view_size.x * 0.5 - 190.0, view_size.y * 0.5 - 90.0), view_size)


func hide_confirm() -> void:
    hud_ref.confirm_panel.visible = false


func confirm_visible() -> bool:
    return hud_ref.confirm_panel.visible


func show_items_window(title: String, summary: String, rows: Array, view_size: Vector2, face: Texture2D = null) -> void:
    var h = hud_ref
    hide_items_window()
    h.items_box.add_child(_header(title, face))
    var s: RichTextLabel = h._rich(300)
    s.text = summary
    h.items_box.add_child(s)
    if rows.is_empty():
        var l := Label.new()
        l.text = "Nenhum item."
        h.items_box.add_child(l)
    for r in rows:
        var row := HBoxContainer.new()
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_theme_constant_override("separation", 8)
        row.add_child(UITheme.pixel_image(UIIcons.get_icon(str(r.get("icon", "items"))), 1))
        var n := Label.new()
        n.text = str(r["name"])
        n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        n.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(n)
        var w := Label.new()
        w.text = "peso %d" % int(r["weight"])
        w.add_theme_color_override("font_color", UITheme.DIM)
        w.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(w)
        h.items_box.add_child(row)
    h.items_box.add_child(h._button("Fechar", func(): h.menu_item_chosen.emit("items_close")))
    h._place(h.items_panel, Vector2(view_size.x * 0.5 - 160.0, 120.0), view_size)


func hide_items_window() -> void:
    var h = hud_ref
    h._clear(h.items_box)
    h.items_panel.visible = false


func any_popup_visible() -> bool:
    var h = hud_ref
    return h.context_panel.visible or h.target_panel.visible or h.confirm_panel.visible or h.items_panel.visible


func hide_popups() -> void:
    hide_context_menu()
    hide_target_window()
    hide_confirm()
    hide_items_window()