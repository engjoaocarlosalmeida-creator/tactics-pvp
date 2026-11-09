## Personalizar time: personagem, atributos, nome (uma vez), carga; icone de Classes no canto superior
## esquerdo.
class_name TeamScreen
extends CanvasLayer




signal changed
signal closed
signal open_other(kind: String, char_index: int)

const ATTR_NAMES := {
    "agilidade": "Agilidade", "forca": "Força", "constituicao": "Constituição", 
    "carisma": "Carisma", "inteligencia": "Inteligência", "sabedoria": "Sabedoria", 
}
const ATTR_HELP := {
    "agilidade": "velocidade (ordem dos turnos)", 
    "forca": "ataque de Escudeiro, Lutador, Cavaleiro, Arqueiro, Ladrão", 
    "constituicao": "vida e defesa", 
    "carisma": "ainda sem efeito (virá com as habilidades)", 
    "inteligencia": "ataque de Aprendiz e Mago", 
    "sabedoria": "ataque do Sacerdote", 
}
const TEAM_TITLES := ["Time 1 (online e contra o computador)", "Time 2 (jogador 2, mesmo PC)"]

var rules: Rules
var catalog: JobCatalog
var roster: Roster
var team := 0
var selected := 0
var _list_box: VBoxContainer
var _detail_box: HBoxContainer
var _team_buttons: Array[Button] = []


func setup(r: Rules, c: JobCatalog, ro: Roster) -> void :
    rules = r
    catalog = c
    roster = ro
    layer = 20
    var bg := UITheme.background(0.68)
    bg.name = "Background"
    add_child(bg)
    var root := MarginContainer.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.theme = UITheme.get_theme()
    root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
    var classes_icon := TextureButton.new()
    classes_icon.name = "ClassesIcon"
    classes_icon.texture_normal = UIIcons.class_icon("escudeiro")
    classes_icon.ignore_texture_size = true
    classes_icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    classes_icon.custom_minimum_size = Vector2(44, 44)
    classes_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    classes_icon.tooltip_text = "Classes"
    classes_icon.pressed.connect( func(): open_other.emit("classes", team * 4 + selected))
    head.add_child(classes_icon)
    var classes_label := Label.new()
    classes_label.name = "ClassesLabel"
    classes_label.add_theme_color_override("font_color", UITheme.GOLD)
    classes_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    head.add_child(classes_label)
    classes_icon.mouse_entered.connect( func(): classes_label.text = "Classes")
    classes_icon.mouse_exited.connect( func(): classes_label.text = "")
    var title := UITheme.title("PERSONALIZAR TIME", 16)
    title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    head.add_child(title)
    for t in 2:
        var b := Button.new()
        b.text = "Time %d" % (t + 1)
        b.toggle_mode = true
        b.focus_mode = Control.FOCUS_NONE
        b.custom_minimum_size = Vector2(0, 38)
        b.pressed.connect( func(): select_team(t))
        head.add_child(b)
        _team_buttons.append(b)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(spacer)
    var back := Button.new()
    back.text = "Voltar ao menu"
    back.focus_mode = Control.FOCUS_NONE
    back.custom_minimum_size = Vector2(0, 38)
    back.pressed.connect(go_back)
    head.add_child(back)


    var body := HBoxContainer.new()
    body.add_theme_constant_override("separation", 10)
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(body)
    var left_panel := PanelContainer.new()
    left_panel.custom_minimum_size = Vector2(300, 0)
    body.add_child(left_panel)
    _list_box = VBoxContainer.new()
    _list_box.add_theme_constant_override("separation", 6)
    left_panel.add_child(_list_box)
    var right_panel := PanelContainer.new()
    right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(right_panel)
    _detail_box = HBoxContainer.new()
    _detail_box.add_theme_constant_override("separation", 16)
    right_panel.add_child(_detail_box)
    refresh()


func go_back() -> void :
    closed.emit()


func _unhandled_input(event: InputEvent) -> void :
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        go_back()


func current() -> Character:
    return roster.characters[team * 4 + selected]


func select_team(t: int) -> void :
    team = clampi(t, 0, 1)
    selected = 0
    refresh()


func focus_character(index: int) -> void :
    team = index / 4
    selected = index % 4
    refresh()


func select_character(i: int) -> void :
    selected = clampi(i, 0, 3)
    refresh()



func spend(attr: String) -> bool:
    if not current().spend_point(rules, attr):
        return false
    changed.emit()
    refresh()
    return true


func set_job(job_id: String) -> bool:
    if not current().change_job(rules, catalog, job_id):
        return false
    changed.emit()
    refresh()
    return true


func rename(new_name: String) -> void :
    if current().rename(new_name):
        changed.emit()
        refresh()


func _clear(box: Control) -> void :
    for c in box.get_children():
        box.remove_child(c)
        c.queue_free()


func refresh() -> void :
    for i in _team_buttons.size():
        _team_buttons[i].button_pressed = (i == team)
    _refresh_list()
    _refresh_detail()


func _refresh_list() -> void :
    _clear(_list_box)
    var cap := Label.new()
    cap.text = TEAM_TITLES[team]
    cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    cap.custom_minimum_size = Vector2(270, 0)
    cap.add_theme_color_override("font_color", UITheme.GOLD)
    _list_box.add_child(cap)
    for i in 4:
        var c: Character = roster.characters[team * 4 + i]
        var b := Button.new()
        b.text = "%s\n%s nv %d%s" % [c.display_name, catalog.job_name(c.job_id), c.job_level(rules, c.job_id), 
                ("  •  %d pts" % c.attr_points) if c.attr_points > 0 else ""]
        b.icon = JobArt.face(c.job_id, c.look)
        b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.toggle_mode = true
        b.button_pressed = (i == selected)
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.custom_minimum_size = Vector2(0, 64)
        b.focus_mode = Control.FOCUS_NONE
        b.pressed.connect( func(): select_character(i))
        _list_box.add_child(b)


func _label(text: String, size := 22, color := UITheme.CREAM, wrap_width := 0) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if wrap_width > 0:
        l.custom_minimum_size = Vector2(wrap_width, 0)
    return l


func _refresh_detail() -> void :
    _clear(_detail_box)
    var c := current()
    var lvl := c.job_level(rules, c.job_id)


    var left := VBoxContainer.new()
    left.add_theme_constant_override("separation", 8)
    left.custom_minimum_size = Vector2(210, 0)
    _detail_box.add_child(left)
    var stage := PanelContainer.new()
    stage.add_theme_stylebox_override("panel", UITheme.portrait_frame())
    stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    stage.add_child(UITheme.pixel_image(JobArt.body(c.job_id, c.look), 3))
    left.add_child(stage)
    if not JobArt.has_own_art(c.job_id):
        var note := _label("(arte provisória: usa a da classe base)", 16, UITheme.DIM)
        note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        left.add_child(note)
    var look_row := HBoxContainer.new()
    look_row.alignment = BoxContainer.ALIGNMENT_CENTER
    look_row.add_theme_constant_override("separation", 6)
    var sex_text := "Sexo: " + ("masculino ♂" if c.look == "m" else "feminino ♀") + "  (não muda)"
    left.add_child(_label(sex_text, 18, Color(0.55, 0.75, 1.0) if c.look == "m" else Color(1.0, 0.6, 0.8)))
    var edit := LineEdit.new()
    edit.name = "NameEdit"
    edit.text = c.display_name
    edit.max_length = 30
    edit.editable = not c.renamed
    edit.custom_minimum_size = Vector2(0, 38)
    edit.text_submitted.connect(rename)
    edit.focus_exited.connect( func(): if edit.editable: rename(edit.text))
    left.add_child(_label("Nome e sobrenome", 20, UITheme.GOLD))
    left.add_child(edit)
    left.add_child(_label("O nome pode ser editado só uma vez." if not c.renamed else "Nome já editado (definitivo).", 15, UITheme.DIM, 200))


    var right := VBoxContainer.new()
    right.add_theme_constant_override("separation", 6)
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _detail_box.add_child(right)
    var th: Array = rules.data["progression"]["job_xp_thresholds"]
    var xp := int(c.job_xp.get(c.job_id, 0))
    var xp_text := "%s  nível %d" % [catalog.job_name(c.job_id), lvl]
    if lvl < th.size():
        xp_text += "   XP %d / %d" % [xp, int(th[lvl])]
    else:
        xp_text += "   (nível máximo)"
    var base := Character.char_xp_for_level(rules, c.char_level(rules))
    var nxt := Character.char_xp_for_level(rules, c.char_level(rules) + 1)
    right.add_child(_label("Personagem nível %d   XP %d / %d" % [c.char_level(rules), c.char_xp, nxt], 20, UITheme.CREAM))
    right.add_child(_label("Classe atual: " + xp_text, 22, UITheme.GOLD))

    right.add_child(_label("Atributos — pontos livres: %d      Bravura %s • Fé %s" % [c.attr_points, Character.classify(c.bravura), Character.classify(c.fe)], 20, UITheme.GOLD))
    for a in Character.ATTRS:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        var nm := _label("%s  %d" % [ATTR_NAMES[a], int(c.attrs[a])])
        nm.custom_minimum_size = Vector2(190, 0)
        row.add_child(nm)
        var plus := Button.new()
        plus.name = "Plus_" + a
        plus.text = "+"
        plus.custom_minimum_size = Vector2(40, 0)
        plus.focus_mode = Control.FOCUS_NONE
        UITheme.compact(plus, 1)
        plus.disabled = c.attr_points <= 0 or int(c.attrs[a]) >= rules.get_int("attributes", "max")
        plus.pressed.connect( func(): spend(a))
        row.add_child(plus)
        row.add_child(_label(ATTR_HELP[a], 17, UITheme.DIM))
        right.add_child(row)

    var u := Unit.from_character(0, 0, c, rules, catalog)
    var stat_names := {"forca": "Força", "inteligencia": "Inteligência", "sabedoria": "Sabedoria"}
    var load_row := HBoxContainer.new()
    load_row.add_theme_constant_override("separation", 10)
    var load_text := "Carga: %d / %d" % [u.carry_weight, u.carry_capacity]
    if u.move_penalty > 0:
        load_text += "  (movimento -%d)" % u.move_penalty
    load_row.add_child(_label(load_text, 20, UITheme.GOLD if u.move_penalty > 0 else UITheme.CREAM))
    var items_btn := Button.new()
    items_btn.name = "OpenItems"
    items_btn.text = "Itens deste personagem"
    items_btn.focus_mode = Control.FOCUS_NONE
    UITheme.compact(items_btn, 4)
    items_btn.pressed.connect( func(): open_other.emit("items", team * 4 + selected))
    load_row.add_child(items_btn)
    right.add_child(load_row)
    right.add_child(_label("Status em batalha", 20, UITheme.GOLD))
    right.add_child(_label("HP %d  ATK %d  DEF %d  VEL %d  MOV %d  PULO %d  ALC %d  (ataque: %s)" % [
            u.max_hp, u.atk, u.defense, u.speed, u.move, u.jump, u.attack_range, 
            stat_names.get(u.attack_stat, u.attack_stat)]))


func _job_button(c: Character, jid: String) -> Button:
    var b := Button.new()
    b.name = "Job_" + jid
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 20)
    UITheme.compact(b, 3)
    var lvl := c.job_level(rules, jid)
    var unlocked := c.is_unlocked(rules, catalog, jid)
    var job: Dictionary = catalog.jobs[jid]
    if jid == c.job_id:
        b.text = "✔ %s nv %d" % [catalog.job_name(jid), lvl]
        b.disabled = true
    elif unlocked:
        b.text = "%s nv %d" % [catalog.job_name(jid), lvl]
        b.pressed.connect( func(): set_job(jid))
    else:
        b.text = "%s\n(requer %s nv %d)" % [catalog.job_name(jid), catalog.job_name(str(job.parent)), int(job.requires_level)]
        b.disabled = true
        b.add_theme_font_size_override("font_size", 17)
    return b
