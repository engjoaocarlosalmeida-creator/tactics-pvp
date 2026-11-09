## Menu de classes: arvore, arte, bonus, requisitos; escolhe a classe do personagem em foco.
class_name ClassScreen
extends CanvasLayer



signal changed
signal closed
signal open_other(kind: String, char_index: int)

const MOD_NAMES := {"hp": "HP", "atk": "ATK", "defense": "DEF", "speed": "VEL", "move": "MOV", "jump": "PULO", "range": "ALC"}

var rules: Rules
var catalog: JobCatalog
var roster: Roster
var context_index := -1
var selected_job := "escudeiro"
var _list_box: VBoxContainer
var _detail_box: VBoxContainer


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
    var title := UITheme.title("CLASSES", 28)
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
    _list_box = VBoxContainer.new()
    _list_box.add_theme_constant_override("separation", 6)
    left.add_child(_list_box)
    var right := PanelContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(right)
    _detail_box = VBoxContainer.new()
    _detail_box.add_theme_constant_override("separation", 8)
    right.add_child(_detail_box)
    refresh()


func go_back() -> void :
    if context_index >= 0:
        open_other.emit("team", context_index)
    else:
        closed.emit()


func _unhandled_input(event: InputEvent) -> void :
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        go_back()


func character() -> Character:
    return roster.characters[context_index] if context_index >= 0 else null


func focus_character(index: int) -> void :
    context_index = index
    selected_job = roster.characters[index].job_id
    refresh()


func select_job(jid: String) -> void :
    selected_job = jid
    refresh()



func choose_job(jid: String) -> bool:
    var c := character()
    if c == null or not c.change_job(rules, catalog, jid):
        return false
    changed.emit()
    refresh()
    return true


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
    _clear(_list_box)
    var c := character()
    _list_box.add_child(_label("Árvore de classes" if c == null else "Classes de %s" % c.display_name, 20, UITheme.GOLD))
    for sid in catalog.starters():
        _list_box.add_child(_job_button(sid, 0))
        for child in catalog.children(sid):
            _list_box.add_child(_job_button(child, 28))
    _refresh_detail()


func _job_button(jid: String, indent: int) -> Control:
    var row := HBoxContainer.new()
    if indent > 0:
        var sp := Control.new()
        sp.custom_minimum_size = Vector2(indent, 0)
        row.add_child(sp)
        row.add_child(_label("└", 18, UITheme.DIM))
    var b := Button.new()
    b.name = "Job_" + jid
    var text := catalog.job_name(jid)
    var c := character()
    if c != null:
        text += "  nv %d" % c.job_level(rules, jid)
        if jid == c.job_id:
            text += "  (atual)"
        elif not c.is_unlocked(rules, catalog, jid):
            text += "  (bloqueada)"
    b.text = text
    b.icon = UIIcons.class_icon(jid)
    b.toggle_mode = true
    b.button_pressed = (jid == selected_job)
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.custom_minimum_size = Vector2(0, 44)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect( func(): select_job(jid))
    row.add_child(b)
    return row


func _refresh_detail() -> void :
    _clear(_detail_box)
    var jid := selected_job
    var job: Dictionary = catalog.jobs[jid]
    var c := character()
    var look := c.look if c != null else "m"
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 18)
    _detail_box.add_child(row)
    var stage := PanelContainer.new()
    stage.add_theme_stylebox_override("panel", UITheme.portrait_frame())
    stage.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    stage.add_child(UITheme.pixel_image(JobArt.body(jid, look), 3))
    row.add_child(stage)
    var info := VBoxContainer.new()
    info.add_theme_constant_override("separation", 6)
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(info)
    info.add_child(_label(str(job.name), 30, UITheme.GOLD))
    info.add_child(_label(str(job.get("desc", "")), 19, UITheme.CREAM, 640))
    if not JobArt.has_own_art(jid):
        info.add_child(_label("(arte provisória: usa a da classe base)", 16, UITheme.DIM))

    var mods: Dictionary = job.mods
    var parts: Array[String] = []
    for k in ["hp", "atk", "defense", "speed", "move", "jump", "range"]:
        var v := int(mods[k])
        if v != 0:
            parts.append("%s %s%d" % [MOD_NAMES[k], "+" if v > 0 else "", v])
    info.add_child(_label("Bônus: " + (", ".join(parts) if not parts.is_empty() else "nenhum"), 19))
    var stat_names := {"forca": "Força", "inteligencia": "Inteligência", "sabedoria": "Sabedoria"}
    info.add_child(_label("O ataque básico usa: %s" % stat_names.get(str(job.get("attack_stat", "forca")), "Força"), 19))

    if job.parent == null:
        info.add_child(_label("Classe inicial (sempre disponível).", 19))
    else:
        info.add_child(_label("Requer: %s nível %d" % [catalog.job_name(str(job.parent)), int(job.requires_level)], 19, UITheme.GOLD))
    var kids := catalog.children(jid)
    if not kids.is_empty():
        var names: Array[String] = []
        for k in kids:
            names.append(catalog.job_name(k))
        info.add_child(_label("Libera: " + ", ".join(names), 19))

    if c != null:
        var lvl := c.job_level(rules, jid)
        var th: Array = rules.data["progression"]["job_xp_thresholds"]
        var xp := int(c.job_xp.get(jid, 0))
        var line := "%s: nível %d" % [c.display_name, lvl]
        if lvl < th.size():
            line += "   XP %d / %d" % [xp, int(th[lvl])]
        else:
            line += "   (nível máximo)"
        info.add_child(_label(line, 20, UITheme.CREAM))
        var btn := Button.new()
        btn.name = "Choose"
        btn.focus_mode = Control.FOCUS_NONE
        btn.custom_minimum_size = Vector2(0, 42)
        if jid == c.job_id:
            btn.text = "Classe atual"
            btn.disabled = true
        elif c.is_unlocked(rules, catalog, jid):
            btn.text = "Escolher esta classe"
            btn.pressed.connect( func(): choose_job(jid))
        else:
            btn.text = "Bloqueada"
            btn.disabled = true
        info.add_child(btn)
    else:
        info.add_child(_label("Para trocar a classe de um personagem, abra este menu pela tela de personagem.", 17, UITheme.DIM, 640))
