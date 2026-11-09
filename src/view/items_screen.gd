## Itens do jogador (estoque) e itens por personagem, com peso e efeito no movimento.
class_name ItemsScreen
extends CanvasLayer



signal changed
signal closed
signal open_other(kind: String, char_index: int)

var rules: Rules
var catalog: JobCatalog
var roster: Roster
var items: ItemCatalog
var team := 0
var selected := 0
var from_team_screen := false
var _stash_box: VBoxContainer
var _mid_box: VBoxContainer
var _carry_box: VBoxContainer
var _msg := ""


func setup(r: Rules, c: JobCatalog, ro: Roster) -> void :
    rules = r
    catalog = c
    roster = ro
    items = ItemCatalog.get_default()
    layer = 20
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
    var title := UITheme.title("ITENS", 28)
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
    var p1 := PanelContainer.new()
    p1.custom_minimum_size = Vector2(380, 0)
    body.add_child(p1)
    _stash_box = VBoxContainer.new()
    _stash_box.add_theme_constant_override("separation", 4)
    p1.add_child(_stash_box)
    var p2 := PanelContainer.new()
    p2.custom_minimum_size = Vector2(280, 0)
    body.add_child(p2)
    _mid_box = VBoxContainer.new()
    _mid_box.add_theme_constant_override("separation", 6)
    p2.add_child(_mid_box)
    var p3 := PanelContainer.new()
    p3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(p3)
    _carry_box = VBoxContainer.new()
    _carry_box.add_theme_constant_override("separation", 4)
    p3.add_child(_carry_box)
    refresh()


func go_back() -> void :
    if from_team_screen:
        open_other.emit("team", team * 4 + selected)
    else:
        closed.emit()


func _unhandled_input(event: InputEvent) -> void :
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        go_back()


func current() -> Character:
    return roster.characters[team * 4 + selected]


func focus_character(index: int) -> void :
    from_team_screen = true
    team = index / 4
    selected = index % 4
    refresh()


func select_team(t: int) -> void :
    team = clampi(t, 0, 1)
    selected = 0
    _msg = ""
    refresh()


func select_character(i: int) -> void :
    selected = clampi(i, 0, 3)
    _msg = ""
    refresh()



func give(item_id: String) -> bool:
    if roster.give_item(current(), rules, items, item_id):
        _msg = ""
        changed.emit()
        refresh()
        return true
    _msg = "%s não aguenta mais esse peso (limite %d)." % [current().display_name, 
            Encumbrance.max_weight(rules, current().carry_capacity(rules))]
    refresh()
    return false



func take(item_id: String) -> bool:
    if roster.take_back_item(current(), item_id):
        _msg = ""
        changed.emit()
        refresh()
        return true
    return false


func _clear(box: Control) -> void :
    for c in box.get_children():
        box.remove_child(c)
        c.queue_free()


func _label(text: String, size := 19, color := UITheme.CREAM, wrap_width := 0) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    if wrap_width > 0:
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(wrap_width, 0)
    return l


func refresh() -> void :
    _refresh_stash()
    _refresh_mid()
    _refresh_carry()


func _refresh_stash() -> void :
    _clear(_stash_box)
    _stash_box.add_child(_label("Itens do jogador", 22, UITheme.GOLD))
    var any := false
    for id in items.ids():
        var n := int(roster.stash.get(id, 0))
        if n <= 0:
            continue
        any = true
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        row.add_child(UITheme.pixel_image(UIIcons.get_icon(items.icon(id)), 1))
        var nm := _label("%s  x%d" % [items.item_name(id), n])
        nm.custom_minimum_size = Vector2(190, 0)
        row.add_child(nm)
        row.add_child(_label("peso %d" % items.weight(id), 17, UITheme.DIM))
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(spacer)
        var b := Button.new()
        b.name = "Give_" + id
        b.text = "Dar ▶"
        b.focus_mode = Control.FOCUS_NONE
        UITheme.compact(b, 3)
        b.pressed.connect( func(): give(id))
        row.add_child(b)
        _stash_box.add_child(row)
    if not any:
        _stash_box.add_child(_label("Nenhum item no estoque.", 19, UITheme.DIM))


func _refresh_mid() -> void :
    _clear(_mid_box)
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 6)
    for t in 2:
        var b := Button.new()
        b.text = "Time %d" % (t + 1)
        b.toggle_mode = true
        b.button_pressed = (t == team)
        b.focus_mode = Control.FOCUS_NONE
        UITheme.compact(b, 4)
        b.pressed.connect( func(): select_team(t))
        tabs.add_child(b)
    _mid_box.add_child(tabs)
    for i in 4:
        var c: Character = roster.characters[team * 4 + i]
        var b := Button.new()
        b.name = "Char_%d" % i
        b.text = "%s\n%s — %d/%d" % [c.display_name, catalog.job_name(c.job_id), c.carry_weight(items), c.carry_capacity(rules)]
        b.icon = JobArt.face(c.job_id, c.look)
        b.toggle_mode = true
        b.button_pressed = (i == selected)
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.custom_minimum_size = Vector2(0, 62)
        b.focus_mode = Control.FOCUS_NONE
        b.pressed.connect( func(): select_character(i))
        _mid_box.add_child(b)


func _refresh_carry() -> void :
    _clear(_carry_box)
    var c := current()
    var cap := c.carry_capacity(rules)
    var w := c.carry_weight(items)
    var penalty := Encumbrance.move_penalty(rules, cap, w)
    var base_move := Unit.from_character(0, 0, c, rules, catalog)
    _carry_box.add_child(_label("%s carrega" % c.display_name, 22, UITheme.GOLD))
    var bar_row := HBoxContainer.new()
    bar_row.add_theme_constant_override("separation", 8)
    var bar := HpBar.new()
    bar.custom_minimum_size = Vector2(220, 16)
    bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    bar.ratio = 1.0 - float(w) / maxf(1.0, float(Encumbrance.max_weight(rules, cap)))
    bar_row.add_child(bar)
    bar_row.add_child(_label("Peso %d / %d" % [w, cap], 19))
    _carry_box.add_child(bar_row)
    var mv := "Movimento: %d" % base_move.move
    if penalty > 0:
        mv += "   (-%d pelo peso)" % penalty
    _carry_box.add_child(_label(mv, 19, UITheme.GOLD if penalty > 0 else UITheme.CREAM))
    _carry_box.add_child(_label("Capacidade cresce com a Força (%d). Até %d de peso não atrapalha; o limite é %d." % [
            int(c.attrs["forca"]), int(cap * rules.get_float("items", "free_fraction")), Encumbrance.max_weight(rules, cap)], 16, UITheme.DIM, 520))
    if _msg != "":
        _carry_box.add_child(_label(_msg, 18, Color(1, 0.6, 0.4), 520))
    if c.items.is_empty():
        _carry_box.add_child(_label("Sem itens.", 19, UITheme.DIM))
    var counts := {}
    for id in c.items:
        counts[id] = int(counts.get(id, 0)) + 1
    for id in counts:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        row.add_child(UITheme.pixel_image(UIIcons.get_icon(items.icon(id)), 1))
        var nm := _label("%s  x%d" % [items.item_name(id), counts[id]])
        nm.custom_minimum_size = Vector2(190, 0)
        row.add_child(nm)
        row.add_child(_label("peso %d" % (items.weight(id) * counts[id]), 17, UITheme.DIM))
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(spacer)
        var b := Button.new()
        b.name = "Take_" + id
        b.text = "◀ Devolver"
        b.focus_mode = Control.FOCUS_NONE
        UITheme.compact(b, 3)
        b.pressed.connect( func(): take(id))
        row.add_child(b)
        _carry_box.add_child(row)
