extends Node
class_name HudPresenter

var game_view_ref


func setup(gv) -> void:
    game_view_ref = gv


func _item(id: String, label: String, enabled: bool, icon := "") -> Dictionary:
    var d := {"id": id, "label": label, "enabled": enabled}
    if icon != "":
        d["icon"] = icon
    return d


func unit_menu_items() -> Array:
    var gv = game_view_ref
    var act: Unit = gv.m.active
    var items: Array = []
    if act.down:
        items.append(_item("stand", "Levantar", not act.moved))
    else:
        items.append(_item("move_mode", "Mover", not gv.move_tiles.is_empty() or gv.mode_pending == "move"))
    items.append(_item("skill_basic", "Atacar" if not act.acted else "Atacar (já atacou)", not act.acted))
    items.append(_item("items", "Itens", true))
    items.append(_item("end_turn", "Esperar", true))
    return items


func open_unit_menu() -> void:
    var gv = game_view_ref
    if not gv._human_turn() or gv.hud.confirm_visible():
        return
    gv.hud.hide_target_window()
    var act: Unit = gv.m.active
    gv.menu_unit = act
    gv.hud.show_context_menu(act.short_name(), unit_menu_items(), gv._menu_anchor(act), gv.get_viewport().get_visible_rect().size)


func open_target_window(t: Unit) -> void:
    var gv = game_view_ref
    var act: Unit = gv.m.active
    var enemy := t.team != act.team
    var can: bool = enemy and not act.acted and gv._human_turn() and gv._approach_tile(act, t) != Picking.NONE
    var data := {
        "title": t.display_name,
        "sex": t.look,
        "team": t.team,
        "hp": t.hp, "max_hp": t.max_hp,
        "text": "Nível %d · %s nv %d\n%s" % [t.char_level, gv._job_name(t), t.job_level, gv._player_name(t.team)],
        "stats": "ATK %d  DEF %d  VEL %d\nMOV %d  PULO %d  ALC %d\n[color=#8d95b8][font_size=15]Bravura %s · Fé %s[/font_size][/color]" % [
                t.atk, t.defense, t.speed, t.move, t.jump, t.attack_range, Character.classify(t.bravura), Character.classify(t.fe)],
    }
    var actions: Array = []
    if enemy:
        var label := "Atacar — dano previsto %d" % gv.m.attack_damage(act, t) if can else "Atacar (fora de alcance)"
        actions.append(_item("t_attack", label, can))
    actions.append(_item("t_close", "Fechar", true))
    gv.menu_ctx_unit = t
    gv.hud.show_target_window(data, actions, gv.get_viewport().get_visible_rect().size)


func open_items_window(u: Unit) -> void:
    var gv = game_view_ref
    var cat := ItemCatalog.get_default()
    var rows: Array = []
    for id in u.items:
        rows.append({"name": cat.item_name(id), "weight": cat.weight(id), "icon": cat.icon(id)})
    var summary := "Peso carregado: %d / %d" % [u.carry_weight, u.carry_capacity]
    if u.move_penalty > 0:
        summary += "\n[color=#ffaa33]Movimento reduzido em %d pelo peso[/color]" % u.move_penalty
    gv.hud.show_items_window("Itens de " + u.display_name, summary, rows, gv.get_viewport().get_visible_rect().size, JobArt.face(u.job_id, u.look))


func update_hud() -> void:
    var gv = game_view_ref
    var u: Unit = gv.m.active
    var col: String = (gv.ALLY_COLOR if u.team == gv.ally_team() else gv.ENEMY_COLOR).lightened(0.2).to_html(false)
    var head := "[b][color=#%s]%s[/color][/b] %s\nNível %d · %s nv %d" % [col, u.display_name, gv._sex_icon(u.look), u.char_level, gv._job_name(u), u.job_level]
    var stats := "ATK %d   DEF %d   VEL %d\nMOV %d   PULO %d   ALC %d\n[color=#8d95b8][font_size=15]Bravura %s · Fé %s[/font_size][/color]" % [
            u.atk, u.defense, u.speed, u.move, u.jump, u.attack_range, Character.classify(u.bravura), Character.classify(u.fe)]
    gv.hud.set_unit_info(head, u.hp, u.max_hp, stats, JobArt.face(u.job_id, u.look),
            gv.ALLY_COLOR if u.team == gv.ally_team() else gv.ENEMY_COLOR, u.mp, u.max_mp)
    var spent := float(gv.m.turns.turn_cost(u.moved, u.acted)) / float(gv.m.turns.threshold) if (u.moved or u.acted) else 0.0
    gv.hud.set_action_bar(gv._action_remaining(u), minf(spent, 1.0))
    var items: Array = []
    var order: Array = gv.m.turns.preview(gv.m.units, 8)
    var alts: Array = gv.m.ready_alternates(u)
    var can_switch: bool = gv._human_turn() and not u.moved and not u.acted
    for i in order.size():
        var o: Unit = gv.m.unit_by_id(order[i])
        items.append({"id": o.id, "team": o.team, "face": JobArt.face(o.job_id, o.look), "number": i + 1,
                "current": o == u and i == 0, "switchable": can_switch and alts.has(o) and i > 0 and not _listed_before(items, o.id)})
    gv.hud.set_order_items(items)


func _listed_before(items: Array, id: int) -> bool:
    for it in items:
        if it["id"] == id:
            return true
    return false


func show_end() -> void:
    var gv = game_view_ref
    if gv.end_shown:
        return
    gv.end_shown = true
    gv.screen_router.save_roster()
    var title := "Empate!"
    if gv.m.winner >= 0:
        title = "%s venceu!" % gv._player_name(gv.m.winner)
    var body := "[b]XP ganho nesta partida (por ações)[/b]\n"
    var by_id: Dictionary = gv.roster.by_id()
    if gv.last_rewards.is_empty():
        body += "Nenhum personagem do seu elenco atacou."
    for cid in gv.last_rewards:
        var ch: Character = by_id[cid]
        var r: Dictionary = gv.last_rewards[cid]
        var line := "%s: +%d XP (personagem nv %d) · +%d XP de classe" % [ch.display_name, r.xp, ch.char_level(gv.rules), r.job_xp]
        if r.levels_gained > 0:
            line += "  [color=#ffe066]classe nv %d![/color]" % ch.job_level(gv.rules, ch.job_id)
        for nj in r.new_jobs:
            line += "  [color=#7fffa0]libera %s[/color]" % gv.catalog.job_name(nj)
        if ch.attr_points > 0:
            line += "  (%d pts livres)" % ch.attr_points
        body += line + "\n"
    if gv.mode != gv.Mode.DEMO:
        var kills := 0
        for u in gv.m.units:
            if u.team == gv.ally_team():
                kills += u.kills
        var won: bool = gv.m.winner == gv.ally_team()
        gv.account.record_match(kills, won, gv.mode == gv.Mode.ONLINE)
        gv.screen_router.save_account()
        body += "\n[color=#8d95b8]Conta: +1 partida, %d unidade(s) abatida(s)%s[/color]" % [kills,
                (" · rank %+d" % (Account.RANK_WIN if won else Account.RANK_LOSS)) if gv.mode == gv.Mode.ONLINE else ""]
    gv.hud.show_end(title, body)
    gv._write_report()
    if gv.quit_on_end:
        gv.get_tree().quit()
