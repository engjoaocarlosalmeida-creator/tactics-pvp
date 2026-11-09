## Tela da conta (identidade uma vez, avatar, titulo, borda, scores).
class_name AccountScreen
extends CanvasLayer


signal changed
signal closed

var account: Account
var _preview: VBoxContainer
var _options: VBoxContainer
var _name_edit: LineEdit
var _sex := "m"


func setup(_r: Rules, _c: JobCatalog, _ro: Roster) -> void :
    layer = 20
    if account == null:
        account = Account.new()
    _sex = account.sex
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
    head_panel.add_child(head)
    var title := UITheme.title("CONTA", 28)
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
    left.custom_minimum_size = Vector2(330, 0)
    body.add_child(left)
    _preview = VBoxContainer.new()
    _preview.add_theme_constant_override("separation", 8)
    left.add_child(_preview)
    var right := PanelContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(right)
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    right.add_child(sc)
    _options = VBoxContainer.new()
    _options.add_theme_constant_override("separation", 8)
    _options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(_options)
    refresh()


func go_back() -> void :
    closed.emit()


func _unhandled_input(event: InputEvent) -> void :
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        go_back()




func confirm_identity(new_name: String, new_sex: String) -> bool:
    if not account.edit_identity(new_name, new_sex):
        return false
    changed.emit()
    refresh()
    return true


func pick_avatar(id: String) -> bool:
    if not account.set_avatar(id):
        return false
    changed.emit()
    refresh()
    return true


func pick_title(id: String) -> bool:
    if not account.set_title(id):
        return false
    changed.emit()
    refresh()
    return true


func pick_border(id: String) -> bool:
    if not account.set_border(id):
        return false
    changed.emit()
    refresh()
    return true




func _clear(box: Control) -> void :
    for c in box.get_children():
        box.remove_child(c)
        c.queue_free()


func _label(text: String, size := 19, color := UITheme.CREAM) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l



static func avatar_frame(acc: Account, scale: int) -> PanelContainer:
    var p := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.05, 0.07, 0.2)
    sb.border_color = acc.border_color()
    sb.set_border_width_all(4)
    sb.set_corner_radius_all(5)
    sb.set_content_margin_all(3)
    p.add_theme_stylebox_override("panel", sb)
    var parts := acc.avatar.split("_")
    p.add_child(UITheme.pixel_image(JobArt.face(parts[0], parts[1]), scale))
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return p


func refresh() -> void :
    _clear(_preview)
    var card := HBoxContainer.new()
    card.add_theme_constant_override("separation", 12)
    card.add_child(avatar_frame(account, 2))
    var info := VBoxContainer.new()
    info.add_child(_label(account.player_name, 22, UITheme.GOLD))
    info.add_child(_label(("♂ masculino" if account.sex == "m" else "♀ feminino"), 17, 
            Color(0.55, 0.75, 1.0) if account.sex == "m" else Color(1.0, 0.6, 0.8)))
    info.add_child(_label(account.title_name(), 18))
    info.add_child(_label("Patente: " + account.rank_name(), 18, UITheme.GOLD))
    card.add_child(info)
    _preview.add_child(card)
    var nxt := account.points_to_next_rank()
    _preview.add_child(_label("Rank PVP: %d pontos%s" % [account.rank_points, ("  (faltam %d para a próxima patente)" % nxt) if nxt >= 0 else "  (patente máxima)"], 16, UITheme.DIM))
    _preview.add_child(_label("Partidas jogadas: %d" % account.matches, 19))
    _preview.add_child(_label("Vitórias: %d   Derrotas: %d" % [account.wins, account.losses], 19))
    _preview.add_child(_label("Unidades abatidas: %d" % account.kills, 19))

    _clear(_options)

    _options.add_child(_label("Nome e sexo", 22, UITheme.GOLD))
    _name_edit = LineEdit.new()
    _name_edit.name = "NameEdit"
    _name_edit.text = account.player_name
    _name_edit.max_length = 30
    _name_edit.editable = not account.identity_edited
    _name_edit.custom_minimum_size = Vector2(0, 38)
    _options.add_child(_name_edit)
    var sex_row := HBoxContainer.new()
    sex_row.add_theme_constant_override("separation", 8)
    for pair in [["m", "Masculino"], ["f", "Feminino"]]:
        var b := Button.new()
        b.name = "Sex_" + pair[0]
        b.text = pair[1]
        b.toggle_mode = true
        b.button_pressed = (_sex == pair[0])
        b.disabled = account.identity_edited
        b.focus_mode = Control.FOCUS_NONE
        var sx: String = pair[0]
        b.pressed.connect( func():
            _sex = sx
            refresh())
        sex_row.add_child(b)
    var ok := Button.new()
    ok.name = "ConfirmIdentity"
    ok.text = "Confirmar (só pode uma vez)" if not account.identity_edited else "Identidade definida"
    ok.disabled = account.identity_edited
    ok.focus_mode = Control.FOCUS_NONE
    ok.pressed.connect( func(): confirm_identity(_name_edit.text, _sex))
    sex_row.add_child(ok)
    _options.add_child(sex_row)

    _options.add_child(_label("Avatar", 22, UITheme.GOLD))
    var grid := GridContainer.new()
    grid.columns = 8
    grid.add_theme_constant_override("h_separation", 6)
    grid.add_theme_constant_override("v_separation", 6)
    for job in JobCatalog.load_default().jobs:
        var id: String = "%s_%s" % [job, account.sex]
        var b := Button.new()
        b.name = "Avatar_" + id
        b.icon = JobArt.face(job, account.sex)
        b.toggle_mode = true
        b.button_pressed = (account.avatar == id)
        b.focus_mode = Control.FOCUS_NONE
        b.tooltip_text = JobCatalog.load_default().job_name(job)
        b.pressed.connect( func(): pick_avatar(id))
        grid.add_child(b)
    _options.add_child(grid)

    _options.add_child(_label("Título", 22, UITheme.GOLD))
    for id in Account.TITLES:
        var t: Array = Account.TITLES[id]
        var b := Button.new()
        b.name = "Title_" + id
        var unlocked := account.title_unlocked(id)
        b.text = str(t[0]) if unlocked else "%s  (requer %s %d)" % [t[0], {"matches": "partidas", "kills": "abates", "wins": "vitórias", "rank_points": "pontos de rank"}[t[1]], t[2]]
        b.toggle_mode = true
        b.button_pressed = (account.title_id == id)
        b.disabled = not unlocked
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.focus_mode = Control.FOCUS_NONE
        b.pressed.connect( func(): pick_title(id))
        _options.add_child(b)

    _options.add_child(_label("Borda do avatar", 22, UITheme.GOLD))
    var brow := HBoxContainer.new()
    brow.add_theme_constant_override("separation", 6)
    for id in Account.BORDERS:
        var bd: Array = Account.BORDERS[id]
        var b := Button.new()
        b.name = "Border_" + id
        var unlocked := account.border_unlocked(id)
        b.text = str(bd[0]) if unlocked else "%s (%s)" % [bd[0], Account.RANKS[int(bd[2])][0]]
        b.toggle_mode = true
        b.button_pressed = (account.border_id == id)
        b.disabled = not unlocked
        b.add_theme_color_override("font_color", bd[1])
        b.add_theme_color_override("font_disabled_color", Color(bd[1], 0.45))
        b.focus_mode = Control.FOCUS_NONE
        b.pressed.connect( func(): pick_border(id))
        brow.add_child(b)
    _options.add_child(brow)
