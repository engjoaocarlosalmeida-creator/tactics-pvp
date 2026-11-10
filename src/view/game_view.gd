## CAMADA VISUAL E DE ENTRADA DA PARTIDA. Desenha o MatchState (terreno em lote, personagens 3D, barras,
## ponteiro, marcadores), trata cliques/teclado, fluxos de mover/atacar com confirmacao, lado,
## movimento extra, rede e conta. Nao contem regras. Opcoes de linha de comando: --mode=local|cpu|demo
## --seed=N --shot=arquivo.png --bot-turns=N --net=host|join --ip= --port= --auto-play --quit-on-end
## --fast --report= --roster= --open=team|classes|items|account|wiki --no-splash --cam=yaw,pitch,dist
## --focus=x,z.
class_name GameView
extends Node3D




enum Mode{LOCAL, VS_CPU, DEMO, ONLINE}

const CHARACTER_MODEL := preload("res://src/view/character_model.gd")
const TEAM_COLORS: Array[Color] = [Color(0.25, 0.55, 1.0), Color(1.0, 0.35, 0.3)]
const TEAM_NAMES: Array[String] = ["Azul", "Vermelho"]
const SPRITE_H := 1.8
const ALLY_COLOR := Color(0.3, 0.62, 1.0)
const ENEMY_COLOR := Color(0.95, 0.28, 0.25)
const ATTACK_ANIMATIONS := ["espadada_dentroparafora", "espadada_foraparadentro"]
const WALK_STEP_DURATION := 0.16

var animate := true
var test_mode := false
var save_in_test := false
var rules: Rules
var catalog: JobCatalog
var roster: Roster
var m: MatchState
var mode: int = Mode.LOCAL
var match_seed: int = 1

var terrain_root: Node3D
var units_root: Node3D
var overlay_root: Node3D
var labels_root: Node3D
var hover_marker: MeshInstance3D
var click_marker: Node3D
var camera_pivot: Node3D
var camera: Camera3D
var hud: Hud

var unit_nodes := {}
var _attack_animation_index := {}
var _attack_animations := {}
var _death_animation_started := {}
var _dying_turn_snapshots := {}
var _visual_generation := 0
var move_tiles := {}
var target_tiles := {}
var hover := Picking.NONE
var selected_tile := Picking.NONE
var busy := 0
var end_shown := false
var last_rewards := {}
var yaw := 30.0
var pitch := -55.0
var distance := 32.0
var cpu_wait := 0.0
var bot_rng := RandomNumberGenerator.new()
var _mats := {}
var _shot_path := ""
var _shot_frames := 0
var _autostart_mode := -1
var _focus_arg := ""
var _rc_start := Vector2.ZERO
var _rc_dragged := false
var preview := {}
var _committing_unit := -1
var attack_area := {}
var menu_unit: Unit
var reaction_tiles := {}        # casas do movimento extra (reacao)
var float_log: Array = []       # (testes) ultimos textos flutuantes
var _prompt_hint := false
var _cmd_queue: Array = []
var _visual_queue: Array[Callable] = []
var _collecting_visual_events := false
var _follow_timer := 0.0
var _t := 0.0


var mode_pending := ""
var menu_wanted := true
var pending_confirm := Callable()
var screen: CanvasLayer
var team_screen: TeamScreen


var net: NetSession
var my_team := 0
var awaiting := false
var desync := false
var opponent_left := false
var auto_play := false
var quit_on_end := false
var quit_after_turns := 0
var report_path := ""
var roster_path := Roster.SAVE_PATH
var settings: Settings
var account: Account
var account_path := Account.PATH


func _ready() -> void :
    rules = Rules.load_default()
    catalog = JobCatalog.load_default()
    var args := {}
    if not test_mode:
        for a in OS.get_cmdline_user_args():
            var kv := a.trim_prefix("--").split("=", true, 1)
            args[kv[0]] = kv[1] if kv.size() > 1 else "true"
        roster_path = args.get("roster", Roster.SAVE_PATH)
    roster = Roster.create_default(rules, catalog) if test_mode else Roster.load_or_default(rules, catalog, roster_path)
    settings = Settings.new() if test_mode else Settings.load_from()
    account = Account.new() if test_mode else Account.load_or_create()
    if not test_mode:
        settings.apply_to_window()
    _build_environment()
    hud = Hud.new()
    add_child(hud)
    net = NetSession.new()
    net.name = "Net"
    add_child(net)
    hud.menu_item_chosen.connect(choose)
    hud.confirm_ok.connect(confirm_accept)
    hud.confirm_cancel.connect(confirm_reject)
    hud.order_clicked.connect(_on_order_clicked)
    hud.options_requested.connect(_show_options)
    hud.option_changed.connect(_on_option_changed)
    hud.team_requested.connect( func(): open_screen("team"))
    hud.account_requested.connect( func(): open_screen("account"))
    hud.wiki_requested.connect( func(): open_screen("wiki"))
    hud.splash_done.connect( func(): hud.show_menu())
    hud.items_requested.connect( func(): open_screen("items"))
    hud.menu_choice.connect( func(md): start_match(md))
    hud.restart_pressed.connect( func(): _restart())
    hud.menu_pressed.connect( func(): _show_menu())
    hud.quit_pressed.connect( func(): get_tree().quit())
    hud.host_requested.connect( func(): _start_host(NetSession.DEFAULT_PORT))
    hud.join_requested.connect( func(addr): _start_join(addr, NetSession.DEFAULT_PORT))
    net.setup_received.connect(_on_net_setup)
    net.command_from_client.connect(_on_net_command_from_client)
    net.command_applied.connect(_on_net_command_applied)
    net.command_rejected.connect( func(): awaiting = false;_try_refresh())
    net.lost_connection.connect(_on_net_lost)
    net.connection_failed.connect( func(): hud.show_message("Não conectou", "Não foi possível conectar. Confira o IP e se o anfitrião já está esperando."))
    net.client_joined.connect( func(): hud.show_waiting("Adversário conectou", "Preparando a partida..."))
    if test_mode:
        return
    auto_play = args.has("auto-play")
    quit_on_end = args.has("quit-on-end")
    quit_after_turns = int(args.get("quit-after-turns", 0))
    report_path = args.get("report", "")
    if args.has("fast") or args.has("shot"):
        animate = false
    _shot_path = args.get("shot", "")
    if args.has("give-xp"):
        for c in roster.characters:
            c.add_xp(rules, catalog, int(args["give-xp"]))
    if args.has("focus"):
        _focus_arg = str(args["focus"])
    if args.has("cam"):
        var cv := str(args["cam"]).split(",")
        yaw = float(cv[0])
        pitch = float(cv[1])
        distance = float(cv[2])
    var seed_arg := int(args.get("seed", -1))
    var port := int(args.get("port", NetSession.DEFAULT_PORT))
    if args.get("net", "") == "host":
        net.forced_seed = seed_arg
        _start_host(port)
    elif args.get("net", "") == "join":
        _start_join(args.get("ip", "127.0.0.1"), port)
    elif args.has("open"):
        open_screen(str(args["open"]))
    else:
        _autostart_mode = {"local": Mode.LOCAL, "cpu": Mode.VS_CPU, "demo": Mode.DEMO}.get(args.get("mode", ""), -1)
        if _autostart_mode >= 0:
            start_match(_autostart_mode, seed_arg)
            if args.has("bot-turns"):
                var previous_animate := animate
                animate = false
                for i in int(args["bot-turns"]):
                    if m == null or m.is_over():
                        break
                    SimpleBot.take_turn(m, bot_rng)
                animate = previous_animate
                _try_refresh()
            if args.has("click-unit") and m != null and not m.is_over():
                click_tile(m.units[int(args["click-unit"])].pos, Vector2(700, 300))
            if args.has("confirm-demo") and m != null and not m.is_over():
                var dest: Vector2i = move_tiles.keys()[0] if not move_tiles.is_empty() else m.active.pos
                choose("move_mode")
                click_tile(dest)
        else:
            _show_menu( not args.has("no-splash"))




func open_screen(kind: String) -> void :
    close_screen()
    hud.hide_overlay()
    match kind:
        "team":
            team_screen = TeamScreen.new()
            screen = team_screen
        "classes":
            var cs := ClassScreen.new()
            screen = cs
        "items":
            var its := ItemsScreen.new()
            screen = its
        "account":
            var acs := AccountScreen.new()
            acs.account = account
            screen = acs
        "wiki":
            screen = WikiScreen.new()
        _:
            _show_menu()
            return
    add_child(screen)
    screen.setup(rules, catalog, roster)
    if screen.has_signal("changed"):
        screen.changed.connect(_save_roster)
    if screen.has_signal("open_other"):
        screen.open_other.connect( func(k, char_index): _open_from_screen(k, char_index))
    screen.closed.connect( func():
        close_screen()
        _show_menu())


func _open_from_screen(kind: String, char_index: int) -> void :
    open_screen(kind)
    if screen != null and screen.has_method("focus_character"):
        screen.focus_character(char_index)


func close_screen() -> void :
    if screen != null:
        remove_child(screen)
        screen.queue_free()
        screen = null
        team_screen = null


func open_team_screen() -> void :
    open_screen("team")


func close_team_screen() -> void :
    close_screen()
func _save_roster() -> void :
    if not test_mode or save_in_test:
        roster.save(roster_path)
    _save_account()


func _save_account() -> void :
    if not test_mode or save_in_test:
        account.save(account_path)
func _show_menu(with_splash := false) -> void :
    net.close()
    awaiting = false
    _clear_world()
    m = null
    hud.hide_popups()
    hud.clear_unit_info()
    hud.set_order_items([])
    hud.set_hint("")
    hud.clear_log()
    hud.show_game_hud(false)
    hud.set_account(account)
    if with_splash:
        hud.show_splash()
    else:
        hud.show_menu()


func _options_values() -> Dictionary:
    return {"display_mode": Settings.MODE_NAMES[settings.display_mode], "resolution": settings.resolution_text(),
            "can_resize": settings.display_mode == Settings.MODE_WINDOW, "volume": settings.volume}


func _show_options() -> void :
    hud.show_options(_options_values())


func _on_option_changed(key: String, delta: int) -> void :
    var screen_size := DisplayServer.screen_get_size() if DisplayServer.get_name() != "headless" else Vector2i(1920, 1080)
    settings.change(key, delta, screen_size)
    if not test_mode:
        settings.save()
        settings.apply_to_window()
    hud.show_options(_options_values())


func _restart() -> void :
    if mode == Mode.ONLINE:
        _show_menu()
    else:
        start_match(mode)


func start_match(new_mode: int, seed_value: int = -1) -> void :
    mode = new_mode
    match_seed = seed_value if seed_value >= 0 else randi() % 100000
    bot_rng.seed = match_seed
    hud.hide_overlay()
    hud.clear_log()
    var state := MatchState.create_from_characters(match_seed, rules, catalog,
            roster.team_chars(0, rules.get_int("match", "units_per_team")),
            roster.team_chars(1, rules.get_int("match", "units_per_team")))
    setup_match(state)



func setup_match(state: MatchState) -> void :
    _clear_world()
    end_shown = false
    last_rewards = {}
    mode_pending = ""
    menu_wanted = true
    selected_tile = Picking.NONE
    pending_confirm = Callable()
    m = state
    hud.show_game_hud(true)
    m.turn_started.connect(_on_turn_started)
    m.unit_moved.connect(_on_unit_moved)
    m.unit_hurt.connect(_on_unit_hurt)
    m.unit_died.connect(_on_unit_died)
    m.unit_dying_turn.connect(_on_unit_dying_turn)
    m.unit_expired.connect(_on_unit_expired)
    m.attack_resolved.connect(_on_attack_resolved)
    m.match_over.connect(_on_match_over)
    m.reaction_event.connect(_on_reaction_event)
    m.manual_facing_teams = _manual_teams()   # quem joga escolhe o lado ao fim do turno
    m.xp_gained.connect(_on_xp_gained)
    _build_terrain()
    _build_units()
    camera_pivot.position = Vector3.ZERO
    distance = clampf(m.map.width * 1.3, 14.0, 60.0)
    if _focus_arg != "":
        var fv := _focus_arg.split(",")
        camera_pivot.position = MapGeometry.tile_pos(m.map, Vector2i(int(fv[0]), int(fv[1])))
    _update_camera()
    m.start()
    _try_refresh()



func ally_team() -> int:
    return my_team if mode == Mode.ONLINE else 0


func _sex_icon(sex: String) -> String:
    return "[img=16]res://assets/icons/sex_%s.png[/img]" % ("f" if sex == "f" else "m")



func _follow(_u: Unit) -> void :
    _follow_timer = 1.1


func _actor_center() -> Vector3:
    if m == null or m.active == null or not unit_nodes.has(m.active.id):
        return Vector3.ZERO
    var p: Vector3 = unit_nodes[m.active.id].position
    return Vector3(p.x, 0, p.z)



func _cycle_actor(dir: int) -> void :
    if not _human_turn() or hud.confirm_visible() or m.active.moved or m.active.acted:
        return
    var cands: Array[Unit] = [m.active]
    for o in m.ready_alternates(m.active):
        if m.has_actions(o):
            cands.append(o)
    if cands.size() < 2:
        return
    cands.sort_custom( func(a: Unit, b: Unit): return a.id < b.id)
    var nxt: Unit = cands[(cands.find(m.active) + dir + cands.size()) % cands.size()]
    menu_wanted = true
    _command({"t": "switch", "unit": m.active.id, "to": nxt.id})


func _cpu_controls(u: Unit) -> bool:
    return mode == Mode.DEMO or (mode == Mode.VS_CPU and u.team == 1)



func _input_locked(u: Unit) -> bool:
    return _cpu_controls(u) or (mode == Mode.ONLINE and (u.team != my_team or awaiting))


func _player_name(team: int) -> String:
    if mode == Mode.ONLINE:
        return "Você" if team == my_team else "Adversário"
    if mode == Mode.DEMO:
        return "Computador %s" % TEAM_NAMES[team]
    if mode == Mode.VS_CPU and team == 1:
        return "Computador"
    return "Jogador %d" % (team + 1)
func step_cpu() -> void:
    if m == null or m.is_over() or busy > 0 or not _visual_queue.is_empty() \
            or _collecting_visual_events:
        return
    if not m.pending_reaction.is_empty():   # o computador nao usa o movimento extra
        _apply_command_with_visuals({"t": "react_skip", "unit": int(m.pending_reaction["unit"])})
        return
    _apply_command_with_visuals(SimpleBot.next_command(m, bot_rng))


func _apply_command_with_visuals(cmd: Dictionary) -> Dictionary:
    _collecting_visual_events = true
    var result := m.apply_command(cmd)
    _collecting_visual_events = false
    _drain_visual_queue()
    return result


func _command(cmd: Dictionary) -> bool:
    menu_wanted = true
    if mode != Mode.ONLINE:
        var res := _apply_command_with_visuals(cmd)
        _try_refresh()
        return res.ok
    if net.is_host:
        var res := _apply_command_with_visuals(cmd)
        if res.ok:
            net.broadcast(cmd, m.state_hash())
        _try_refresh()
        return res.ok
    awaiting = true
    net.submit(cmd)
    _try_refresh()
    return true


func _human_turn() -> bool:
    return m != null and not m.is_over() and busy == 0 and not _input_locked(m.active)




func _unit_at(p: Vector2i) -> Unit:
    for u in m.units:
        if u.is_alive() and u.pos == p:
            return u
    return null


func _item(id: String, label: String, enabled: bool, icon := "") -> Dictionary:
    var d := {"id": id, "label": label, "enabled": enabled}
    if icon != "":
        d["icon"] = icon
    return d
func _unit_menu_items() -> Array:
    var act := m.active
    var items: Array = []
    if act.down:
        items.append(_item("stand", "Levantar", not act.moved))   # personagem caido gasta a acao de movimento
    else:
        items.append(_item("move_mode", "Mover", not move_tiles.is_empty() or mode_pending == "move"))
    items.append(_item("skill_basic", "Atacar" if not act.acted else "Atacar (já atacou)", not act.acted))
    items.append(_item("items", "Itens", true))
    items.append(_item("end_turn", "Esperar", true))
    return items


func open_unit_menu() -> void :
    if not _human_turn() or hud.confirm_visible():
        return
    hud.hide_target_window()
    var act := m.active
    menu_unit = act
    hud.show_context_menu(act.short_name(), _unit_menu_items(), _menu_anchor(act), get_viewport().get_visible_rect().size)



func _menu_anchor(u: Unit) -> Vector2:
    var feet: Vector3 = unit_nodes[u.id].global_position + camera.global_transform.basis.x * 0.4
    return camera.unproject_position(feet) + Vector2(2, -4)
func _auto_menu() -> void:
    if menu_wanted and mode_pending == "" and not hud.target_panel.visible and not hud.items_panel.visible \
            and not m.awaiting_facing and m.pending_reaction.is_empty():
        open_unit_menu()


func click_tile(p: Vector2i, _screen_pos: Vector2 = Vector2(40, 40)) -> bool:
    if m == null or m.is_over() or busy > 0 or hud.confirm_visible() or screen != null:
        return false
    var special := _click_special(p)
    if special != 0:
        return special > 0
    selected_tile = p
    _update_click_marker()
    hud.hide_context_menu()
    hud.hide_target_window()
    hud.hide_items_window()
    if mode_pending != "" and _human_turn():
        var u := m.active
        if mode_pending == "move" and move_tiles.has(p):
            _preview_move(p)
            return true
        if mode_pending == "attack" and attack_area.has(p):
            var t := _unit_at(p)
            var text := "Atacar a casa (%d, %d)?\nNão há ninguém lá." % [p.x, p.y]
            var cmd := {"t": "attack", "unit": u.id, "x": p.x, "y": p.y}
            if t != null:
                text = _attack_text(u, t) + ("\n[color=#ffaa33]É um aliado![/color]" if t.team == u.team else "")
                cmd = {"t": "attack", "unit": u.id, "target": t.id}
            _ask_confirm(text, func(): _command(cmd))
            return true
        mode_pending = ""
        hud.set_hint("")
        menu_wanted = true
        _try_refresh()
        return false
    var target := _unit_at(p)
    if target == m.active:
        menu_wanted = true
        _try_refresh()
        return true
    if target != null and target.team == m.active.team:

        if _human_turn() and not m.active.moved and not m.active.acted and m.ready_alternates(m.active).has(target)\
and m.has_actions(target):
            menu_wanted = true
            _follow(target)
            return _command({"t": "switch", "unit": m.active.id, "to": target.id})
        return false
    menu_wanted = false
    if target != null:
        _open_target_window(target)
    _try_refresh()
    return true



func _preview_move(p: Vector2i) -> void :
    var u := m.active
    var path := Pathing.path_to(m.reachable_for(u), p)
    preview = {"unit": u, "from": u.pos, "to": p}
    var n: Node3D = unit_nodes[u.id]
    var ask := func(): _ask_confirm(_move_text(u, p), func(): _commit_preview())
    if not animate:
        n.position = MapGeometry.tile_pos(m.map, p)
        ask.call()
        return
    _animate_unit_path(u, path, ask)


func _commit_preview() -> void :
    if preview.is_empty():
        return
    var u: Unit = preview["unit"]
    var to: Vector2i = preview["to"]
    _committing_unit = u.id
    preview = {}
    _command({"t": "move", "unit": u.id, "x": to.x, "y": to.y})
    _committing_unit = -1


func _cancel_preview() -> void :
    if preview.is_empty():
        return
    var u: Unit = preview["unit"]
    var node: Node3D = unit_nodes[u.id]
    node.position = MapGeometry.tile_pos(m.map, preview["from"])
    CHARACTER_MODEL.play_animation(node.get_node("Body"), "Idle")
    CHARACTER_MODEL.set_facing(node.get_node("Body"), u.facing)
    preview = {}



func _approach_tile(u: Unit, t: Unit) -> Vector2i:
    if m.can_hit(u, t):
        return u.pos
    var best := Picking.NONE
    var best_key := 1000000
    for p in move_tiles:
        if m.tile_in_range_from(u, p, t.pos):
            var info: Dictionary = move_tiles[p]
            var key: int = int(info.cost) * 100 + int(info.damage)
            if key < best_key:
                best_key = key
                best = p
    return best


func _do_attack_approach(t: Unit) -> void :
    var u := m.active
    var dest := _approach_tile(u, t)
    var cmds: Array = []
    if dest != Picking.NONE and dest != u.pos:
        cmds.append({"t": "move", "unit": u.id, "x": dest.x, "y": dest.y})
    cmds.append({"t": "attack", "unit": u.id, "target": t.id})
    _run_commands(cmds)



func _run_commands(cmds: Array) -> bool:
    var first: Dictionary = cmds[0]
    var rest := cmds.slice(1)
    if mode == Mode.ONLINE and not net.is_host:
        _cmd_queue = rest
        return _command(first)
    var ok := _command(first)
    for c in rest:
        if not ok:
            break
        ok = _command(c)
    return ok


func _move_text(u: Unit, p: Vector2i) -> String:
    var info: Dictionary = move_tiles[p]
    var t := "Mover [b]%s[/b] para a casa (%d, %d)?\nCusto de movimento: %d" % [u.display_name, p.x, p.y, info.cost]
    if info.damage > 0:
        t += "\n[color=#ffaa33]Queda: perde %d de vida[/color]" % info.damage
    return t


func _attack_text(u: Unit, t: Unit) -> String:
    return "Atacar [b]%s[/b] com Ataque básico?\nDano previsto: %d" % [t.display_name, m.attack_damage(u, t)]


func _ask_confirm(text: String, action: Callable) -> void :
    pending_confirm = action
    hud.hide_context_menu()
    hud.set_hint("")
    hud.show_confirm(text, get_viewport().get_visible_rect().size)



func confirm_accept() -> void :
    var action := pending_confirm
    pending_confirm = Callable()
    hud.hide_confirm()
    mode_pending = ""
    if action.is_valid():
        action.call()


func confirm_reject() -> void :
    pending_confirm = Callable()
    hud.hide_confirm()
    _cancel_preview()
    if mode_pending == "":
        menu_wanted = true
    _try_refresh()


func _do_move(p: Vector2i) -> void :
    _command({"t": "move", "unit": m.active.id, "x": p.x, "y": p.y})


func _do_attack(t: Unit) -> void :
    _command({"t": "attack", "unit": m.active.id, "target": t.id})
func _open_target_window(t: Unit) -> void :
    var act := m.active
    var enemy := t.team != act.team
    var can := enemy and not act.acted and _human_turn() and _approach_tile(act, t) != Picking.NONE
    var data := {
        "title": t.display_name,
        "sex": t.look,
        "team": t.team,
        "hp": t.hp, "max_hp": t.max_hp,
        "text": "Nível %d · %s nv %d\n%s" % [t.char_level, _job_name(t), t.job_level, _player_name(t.team)],
        "stats": "ATK %d  DEF %d  VEL %d\nMOV %d  PULO %d  ALC %d\n[color=#8d95b8][font_size=15]Bravura %s · Fé %s[/font_size][/color]" % [
                t.atk, t.defense, t.speed, t.move, t.jump, t.attack_range, Character.classify(t.bravura), Character.classify(t.fe)],
    }
    var actions: Array = []
    if enemy:
        var label := "Atacar — dano previsto %d" % m.attack_damage(act, t) if can else "Atacar (fora de alcance)"
        actions.append(_item("t_attack", label, can))
    actions.append(_item("t_close", "Fechar", true))
    menu_ctx_unit = t
    hud.show_target_window(data, actions, get_viewport().get_visible_rect().size)


var menu_ctx_unit: Unit


func _choose_base(id: String) -> bool:
    if m == null or m.is_over():
        return false
    if id == "items_close":
        hud.hide_items_window()
        menu_wanted = true
        _try_refresh()
        return true
    if id == "t_close":
        hud.hide_target_window()
        menu_wanted = true
        _try_refresh()
        return true
    if id == "t_attack":
        var t := menu_ctx_unit
        if t == null or not _human_turn() or m.active.acted:
            return false
        var dest := _approach_tile(m.active, t)
        if dest == Picking.NONE:
            return false
        hud.hide_target_window()
        var text := _attack_text(m.active, t)
        if dest != m.active.pos:
            text += "\nO personagem se move até a casa (%d, %d) antes de atacar." % [dest.x, dest.y]
        _ask_confirm(text, func(): _do_attack_approach(t))
        return true
    if not _human_turn():
        return false
    var act := m.active
    if id == "items":
        hud.hide_context_menu()
        _open_items_window(act)
        return true
    if id == "move_mode":
        if move_tiles.is_empty():
            return false
        hud.hide_context_menu()
        mode_pending = "move"
        hud.set_hint("Escolha uma casa azul para mover (Esc ou botão direito cancela)")
        _try_refresh()
        return true
    if id.begins_with("skill_"):
        if act.acted:
            return false
        hud.hide_context_menu()
        mode_pending = "attack"
        hud.set_hint("Escolha uma casa marcada para atacar (Esc ou botão direito cancela)")
        _try_refresh()
        return true
    if id == "end_turn":
        _ask_confirm("Esperar e passar o turno de [b]%s[/b]?" % act.display_name, func(): _command({"t": "wait", "unit": act.id}))
        return true
    return false


func _ask_switch(to_id: int) -> bool:
    var act := m.active
    var to := m.unit_by_id(to_id)
    if to == null or act.moved or act.acted or not m.ready_alternates(act).has(to):
        return false
    _ask_confirm("Alternar para [b]%s[/b]?\n(%s ainda não gastou ações)" % [to.display_name, act.display_name],
            func(): _command({"t": "switch", "unit": act.id, "to": to_id}))
    return true


func _on_order_clicked(unit_id: int) -> void :
    if _human_turn() and not hud.confirm_visible():
        _ask_switch(unit_id)


func _open_items_window(u: Unit) -> void :
    var cat := ItemCatalog.get_default()
    var rows: Array = []
    for id in u.items:
        rows.append({"name": cat.item_name(id), "weight": cat.weight(id), "icon": cat.icon(id)})
    var summary := "Peso carregado: %d / %d" % [u.carry_weight, u.carry_capacity]
    if u.move_penalty > 0:
        summary += "\n[color=#ffaa33]Movimento reduzido em %d pelo peso[/color]" % u.move_penalty
    hud.show_items_window("Itens de " + u.display_name, summary, rows, get_viewport().get_visible_rect().size, JobArt.face(u.job_id, u.look))
func cancel_all() -> void:
    if hud.confirm_visible():
        confirm_reject()
        return
    if m != null and not m.pending_reaction.is_empty():   # cancelar o movimento extra
        var o := m.pending_unit()
        if o != null and _owner_human(o):
            _command({"t": "react_skip", "unit": o.id})
        return
    if m != null and m.awaiting_facing and _owner_human(m.active):   # Esc mantem o lado atual
        _command({"t": "face", "unit": m.active.id, "dir": maxi(0, BattleMap.DIRS.find(m.active.facing))})
        return
    _cancel_preview()
    hud.hide_popups()
    if mode_pending != "":
        mode_pending = ""
        hud.set_hint("")
        menu_wanted = true
        _try_refresh()
    else:
        menu_wanted = false


func wait() -> void :
    if _human_turn() and not hud.confirm_visible():
        choose("end_turn")




func _start_host(port: int) -> void :
    var err := net.host_game(port, _my_team_dicts())
    if err != OK:
        hud.show_message("Não foi possível hospedar", "A porta %d está em uso. Feche outra cópia do jogo e tente de novo." % port)
        return
    hud.show_game_hud(false)
    hud.show_waiting("Aguardando adversário",
            "Peça para o outro jogador escolher [b]Jogar online → Entrar[/b] e digitar este IP:\n[b]%s[/b]  (porta %d)\n[color=#aab]Pela internet, é preciso liberar a porta %d no roteador. Pela Steam isso não será necessário.[/color]" % [NetSession.local_ip(), port, port])


func _start_join(address: String, port: int) -> void :
    var err := net.join_game(address, port, _my_team_dicts())
    if err != OK:
        hud.show_message("Não conectou", "Endereço inválido: %s" % address)
        return
    hud.show_game_hud(false)
    hud.show_waiting("Conectando...", "Conectando a %s ..." % address)


func _my_team_dicts() -> Array:
    var out: Array = []
    for c in roster.team_chars(0, rules.get_int("match", "units_per_team")):
        out.append(c.to_dict())
    return out


func _on_net_setup(seed_value: int, t0: Array, t1: Array) -> void :
    mode = Mode.ONLINE
    my_team = 0 if net.is_host else 1
    match_seed = seed_value
    awaiting = false
    desync = false
    var per := rules.get_int("match", "units_per_team")
    var mine := roster.team_chars(0, per)
    var theirs: Array = []
    for d in (t1 if net.is_host else t0):
        var c := Character.from_dict(d)
        c.id += 1000
        theirs.append(c)
    hud.hide_overlay()
    hud.clear_log()
    setup_match(MatchState.create_from_characters(seed_value, rules, catalog,
            mine if net.is_host else theirs, theirs if net.is_host else mine))
func _on_net_command_from_client(cmd: Dictionary) -> void:
    if not _client_may_act():
        net.reject()
        return
    var res := _apply_command_with_visuals(cmd)
    if res.ok:
        net.broadcast(cmd, m.state_hash())
    else:
        net.reject()
    menu_wanted = true
    _try_refresh()


func _on_net_command_applied(cmd: Dictionary, host_hash: int) -> void :
    if m == null:
        return
    _apply_command_with_visuals(cmd)
    awaiting = false
    menu_wanted = true
    if host_hash != m.state_hash():
        desync = true
        hud.add_log("ATENÇÃO: os dois lados ficaram diferentes (dessincronia)")
    if not _cmd_queue.is_empty():
        var nxt: Dictionary = _cmd_queue.pop_front()
        _command(nxt)
        return
    _try_refresh()


func _on_net_lost() -> void :
    opponent_left = true
    if m != null and not m.is_over() and not end_shown:
        _write_report()
        hud.show_message("Conexão perdida", "O adversário saiu da partida.")
        if quit_on_end:
            get_tree().quit()


func _write_report() -> void :
    if report_path == "":
        return
    var xp := 0
    for cid in last_rewards:
        xp += int(last_rewards[cid].xp)
    var d := {"mode": mode, "my_team": my_team, "winner": m.winner if m != null else -9,
            "turns": m.turn_serial if m != null else 0, "hash": m.state_hash() if m != null else 0,
            "desync": desync, "opponent_left": opponent_left, "xp": xp}
    var f := FileAccess.open(report_path, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(d))
        f.close()



func _on_turn_started(u: Unit) -> void :
    _queue_visual_action(Callable(self, "_present_turn_started").bind(u))


func _present_turn_started(u: Unit) -> void:
    mode_pending = ""
    menu_wanted = true
    hud.set_hint("")
    hud.add_log("Vez de %s (%s)" % [u.short_name(), _player_name(u.team)])
    _follow(u)


func _on_unit_moved(u: Unit, path: Array) -> void :
    _queue_visual_action(Callable(self, "_present_unit_moved").bind(
            u, path.duplicate(), u.pos, u.facing))


func _present_unit_moved(u: Unit, path: Array, destination: Vector2i, facing: Vector2i) -> void:
    var n: Node3D = unit_nodes[u.id]
    CHARACTER_MODEL.set_facing(n.get_node("Body"), facing)
    if _committing_unit == u.id or not animate or path.is_empty():
        n.position = MapGeometry.tile_pos(m.map, destination)
        CHARACTER_MODEL.play_animation(n.get_node("Body"), "Idle")
        return

    _animate_unit_path(u, path)


func _animate_unit_path(u: Unit, path: Array, on_finished := Callable()) -> void:
    var node: Node3D = unit_nodes[u.id]
    var body: Node3D = node.get_node("Body")
    var previous := Vector2i(
            roundi(node.position.x / MapGeometry.TILE_SIZE + float(m.map.width) / 2.0 - 0.5),
            roundi(node.position.z / MapGeometry.TILE_SIZE + float(m.map.depth) / 2.0 - 0.5))
    busy += 1
    var tw := create_tween()
    for point in path:
        var step: Vector2i = point
        var height_delta := m.map.height_at(step) - m.map.height_at(previous)
        var action := CHARACTER_MODEL.locomotion_action(height_delta)
        var duration := WALK_STEP_DURATION
        if height_delta != 0:
            duration = clampf(CHARACTER_MODEL.animation_duration(body, action) * 0.3, 0.3, 0.65)
        var direction := step - previous
        tw.tween_callback(_face_unit_for_step.bind(u.id, direction))
        tw.tween_callback(_play_unit_animation.bind(u.id, action, duration))
        tw.tween_property(node, "position", MapGeometry.tile_pos(m.map, step), duration)
        previous = step
    tw.tween_callback(_finish_unit_movement.bind(u.id))
    tw.finished.connect(func():
        busy = maxi(0, busy - 1)
        if on_finished.is_valid():
            on_finished.call()
        _drain_visual_queue())


func _face_unit_for_step(unit_id: int, direction: Vector2i) -> void:
    if unit_nodes.has(unit_id):
        CHARACTER_MODEL.set_facing(unit_nodes[unit_id].get_node("Body"), direction)


func _play_unit_animation(unit_id: int, action: String, duration: float) -> void:
    if unit_nodes.has(unit_id):
        var attack_action := str(_attack_animations.get(unit_id, ""))
        if attack_action != "" and attack_action != action:
            _finish_attack_animation(unit_id, attack_action)
        CHARACTER_MODEL.play_animation(unit_nodes[unit_id].get_node("Body"), action, duration)


func _finish_unit_movement(unit_id: int) -> void:
    if unit_nodes.has(unit_id):
        CHARACTER_MODEL.play_animation(unit_nodes[unit_id].get_node("Body"), "Idle")


func _on_attack_resolved(attacker: Unit, _target: Unit, _tile: Vector2i, _damage: int) -> void:
    var target_hp_before := _target.hp if _target != null else 0
    _queue_visual_action(Callable(self, "_present_attack_resolved").bind(
            attacker, attacker.facing, _target, _damage, target_hp_before))


func _present_attack_resolved(attacker: Unit, facing: Vector2i, target: Unit = null,
        damage: int = 0, target_hp_before: int = 0) -> void:
    if not animate or not unit_nodes.has(attacker.id):
        return
    if _attack_animations.has(attacker.id):
        _attack_animations.erase(attacker.id)
        busy = maxi(0, busy - 1)

    var index := int(_attack_animation_index.get(attacker.id, 0))
    var action: String = ATTACK_ANIMATIONS[index % ATTACK_ANIMATIONS.size()]
    _attack_animation_index[attacker.id] = index + 1
    var node: Node3D = unit_nodes[attacker.id]
    CHARACTER_MODEL.set_facing(node.get_node("Body"), facing)
    if not CHARACTER_MODEL.play_animation(node.get_node("Body"), action):
        return

    _attack_animations[attacker.id] = action
    busy += 1
    var duration := CHARACTER_MODEL.animation_duration(node.get_node("Body"), action)
    if target != null and damage > 0:
        var impact_delay := duration * 0.85
        get_tree().create_timer(impact_delay).timeout.connect(
                _present_attack_impact.bind(
                        target, damage, target_hp_before, _visual_generation))
    get_tree().create_timer(duration + 0.25).timeout.connect(
            _finish_attack_animation.bind(attacker.id, action))


func _present_attack_impact(target: Unit, damage: int, hp_before_hit: int,
        generation: int = -1) -> void:
    if (generation >= 0 and generation != _visual_generation) \
            or damage <= 0 or not unit_nodes.has(target.id):
        return
    var hp_after_hit := maxi(0, hp_before_hit - damage)
    var node: Node3D = unit_nodes[target.id]
    var hp_fill: Sprite3D = node.get_node("Over/HpFill")
    hp_fill.region_rect = Rect2(
            0, 0, maxf(0.0, 80.0 * float(hp_after_hit) / maxf(1.0, float(target.max_hp))), 8)
    hp_fill.visible = hp_after_hit > 0
    node.get_node("Over/HpBack").visible = hp_after_hit > 0
    hud.add_log("%s perde %d de vida (ataque)" % [target.display_name, damage])

    var damage_ratio := float(damage) / maxf(1.0, float(target.max_hp))
    var damage_size := 32 + roundi(clampf(damage_ratio, 0.0, 1.5) * 18.0)
    _float_text(node.position, "-%d" % damage, Color(1, 0.4, 0.3), damage_size, 0.6)
    var body := node.get_node_or_null("Body") as Node3D
    if body != null:
        CHARACTER_MODEL.flash(body, create_tween())

    if hp_after_hit == 0:
        _start_death_animation(target, int(_dying_turn_snapshots.get(
                target.id, target.dying_turns)))


func _start_death_animation(u: Unit, turns_left: int) -> void:
    if _death_animation_started.has(u.id) or not animate or not unit_nodes.has(u.id):
        return
    var node: Node3D = unit_nodes[u.id]
    var body := node.get_node_or_null("Body") as Node3D
    if body == null:
        return
    var action := "death_forward" if randi_range(0, 1) == 0 else "death_back"
    if not CHARACTER_MODEL.play_animation(body, action):
        return
    _death_animation_started[u.id] = action
    _show_dying_status(u, turns_left)
    hud.add_log("%s caiu e está morrendo (%d turnos)." % [u.display_name, turns_left])
    busy += 1
    var duration := CHARACTER_MODEL.animation_duration(body, action)
    get_tree().create_timer(duration + 0.25).timeout.connect(
            _anim_done_for_generation.bind(_visual_generation))


func _anim_done_for_generation(generation: int) -> void:
    if generation == _visual_generation:
        _anim_done()


func _on_unit_animation_finished(animation_name: StringName, unit_id: int) -> void:
    _finish_attack_animation(unit_id, str(animation_name))


func _finish_attack_animation(unit_id: int, action: String) -> void:
    if not _attack_animations.has(unit_id) or _attack_animations[unit_id] != action:
        return
    _attack_animations.erase(unit_id)
    if unit_nodes.has(unit_id):
        CHARACTER_MODEL.play_animation(unit_nodes[unit_id].get_node("Body"), "Idle")
    _anim_done()


func _on_unit_hurt(u: Unit, amount: int, reason: String) -> void :
    _queue_visual_action(Callable(self, "_present_unit_hurt").bind(u, amount, reason, u.hp))


func _present_unit_hurt(u: Unit, amount: int, reason: String, hp_after_hit: int) -> void:
    var cause := "queda" if reason == "fall" else "ataque"
    var hp_fill: Sprite3D = unit_nodes[u.id].get_node("Over/HpFill")
    var ratio := float(hp_after_hit) / maxf(1.0, float(u.max_hp))
    hp_fill.region_rect = Rect2(0, 0, maxf(0.0, 80.0 * ratio), 8)
    hp_fill.visible = hp_after_hit > 0
    unit_nodes[u.id].get_node("Over/HpBack").visible = hp_after_hit > 0
    if reason == "attack" and animate:
        return
    hud.add_log("%s perde %d de vida (%s)" % [u.display_name, amount, cause])
    var node: Node3D = unit_nodes[u.id]
    var damage_ratio := float(amount) / maxf(1.0, float(u.max_hp))
    var damage_size := 32 + roundi(clampf(damage_ratio, 0.0, 1.5) * 18.0)
    _float_text(node.position, "-%d" % amount, Color(1, 0.4, 0.3), damage_size, 0.6)
    if animate:
        var body := node.get_node_or_null("Body") as Node3D
        if body != null:
            CHARACTER_MODEL.flash(body, create_tween())
        if u.is_dying():
            _start_death_animation(u, int(_dying_turn_snapshots.get(u.id, u.dying_turns)))
        _pause_visual_sequence(0.6)


func _on_unit_died(u: Unit) -> void :
    _dying_turn_snapshots[u.id] = u.dying_turns
    _queue_visual_action(Callable(self, "_present_unit_died").bind(u, u.dying_turns))


func _present_unit_died(u: Unit, turns_left: int) -> void:
    if _death_animation_started.has(u.id):
        return
    hud.add_log("%s caiu e está morrendo (%d turnos)." % [u.display_name, turns_left])
    _show_dying_status(u, turns_left)
    if not animate:
        return
    _start_death_animation(u, turns_left)


func _on_unit_dying_turn(u: Unit, turns_left: int) -> void:
    _queue_visual_action(Callable(self, "_present_unit_dying_turn").bind(u, turns_left))


func _present_unit_dying_turn(u: Unit, turns_left: int) -> void:
    if turns_left <= 0:
        hud.add_log("%s não resistiu aos ferimentos." % u.display_name)
        if animate:
            _pause_visual_sequence(0.25)
        return
    hud.add_log("%s continua morrendo (%d turnos)." % [u.display_name, turns_left])
    _show_dying_status(u, turns_left)
    if animate:
        _pause_visual_sequence(0.4)


func _show_dying_status(u: Unit, turns_left: int) -> void:
    var node: Node3D = unit_nodes[u.id]
    var hp_fill: Sprite3D = node.get_node("Over/HpFill")
    hp_fill.visible = false
    node.get_node("Over/ApFill").visible = false
    node.get_node("Over/ApBack").visible = false
    var turns: Label3D = node.get_node("Over/Turns")
    turns.text = str(turns_left)
    turns.offset = Vector2.ZERO
    turns.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    turns.font_size = 52
    turns.modulate = Color(1.0, 0.35, 0.35)
    turns.visible = true


func _on_unit_expired(u: Unit) -> void:
    _queue_visual_action(Callable(self, "_present_unit_expired").bind(u))


func _present_unit_expired(u: Unit) -> void:
    var node: Node3D = unit_nodes[u.id]
    var body := node.get_node_or_null("Body") as Node3D
    if body != null:
        node.remove_child(body)
        body.queue_free()
    var skull := CHARACTER_MODEL.create_skull(CHARACTER_MODEL.team_color(u.team))
    if skull != null:
        node.add_child(skull)
    node.get_node("Ring").visible = false
    node.get_node("Over/HpFill").visible = false
    node.get_node("Over/ApFill").visible = false
    node.get_node("Over/ApBack").visible = false
    node.get_node("Over/Turns").visible = false



func _on_xp_gained(u: Unit, job_xp: int, char_xp: int, flag: int) -> void :
    _queue_visual_action(Callable(self, "_present_xp_gained").bind(u, job_xp, char_xp, flag))


func _present_xp_gained(u: Unit, job_xp: int, char_xp: int, flag: int) -> void:
    var res := Progression.apply_xp(rules, catalog, roster.by_id(), u, job_xp, char_xp)
    if res.is_empty():
        return
    var cid := u.character_id
    var acc: Dictionary = last_rewards.get(cid, {"xp": 0, "job_xp": 0, "levels_gained": 0, "char_levels_gained": 0, "new_jobs": []})
    acc.xp += char_xp
    acc.job_xp += job_xp
    acc.levels_gained += int(res.levels_gained)
    acc.char_levels_gained += int(res.char_levels_gained)
    for nj in res.new_jobs:
        acc.new_jobs.append(nj)
    last_rewards[cid] = acc
    var arrow := " ▲" if flag > 0 else (" ▼" if flag < 0 else "")
    _float_text(unit_nodes[u.id].position, "+%d XP%s" % [char_xp, arrow], Color(1, 0.9, 0.45) if flag >= 0 else Color(1, 0.55, 0.45))
    if res.char_levels_gained > 0:
        var ch: Character = roster.by_id()[cid]
        hud.add_log("%s subiu para o nível %d!" % [ch.first_name(), ch.char_level(rules)])
    if res.levels_gained > 0:
        var ch2: Character = roster.by_id()[cid]
        hud.add_log("%s: classe nível %d!" % [ch2.first_name(), ch2.job_level(rules, ch2.job_id)])
    _save_roster()
    if animate:
        _pause_visual_sequence(1.0)


func _on_match_over(_winner: int) -> void :
    pass


func _anim_done() -> void :
    busy = maxi(0, busy - 1)
    _drain_visual_queue()


func _queue_visual_action(action: Callable) -> void:
    _visual_queue.append(action)
    if not _collecting_visual_events:
        _drain_visual_queue()


func _drain_visual_queue() -> void:
    if _collecting_visual_events or busy > 0:
        return
    while not _visual_queue.is_empty() and busy == 0:
        var action: Callable = _visual_queue.pop_front()
        action.call()
    if _visual_queue.is_empty() and busy == 0:
        _try_refresh()


func _pause_visual_sequence(duration: float) -> void:
    busy += 1
    get_tree().create_timer(duration).timeout.connect(_anim_done)


func _try_refresh() -> void :
    if busy > 0 or not _visual_queue.is_empty() or _collecting_visual_events or m == null:
        return
    _refresh()
func _refresh() -> void:
    for c in overlay_root.get_children():
        overlay_root.remove_child(c)
        c.queue_free()
    move_tiles.clear()
    target_tiles.clear()
    attack_area.clear()
    reaction_tiles.clear()
    for u in m.units:
        _update_unit_visual(u)
        _update_unit_facing(u)
        unit_nodes[u.id].get_node("Ring").visible = (not m.is_over()) and u == m.active and u.is_alive()
        unit_nodes[u.id].get_node("Over/Pointer").visible = false
    if m.is_over():
        hud.hide_popups()
        hud.set_hint("")
        hud.clear_unit_info()
        hud.set_order_items([])
        _show_end()
        return
    var u := m.active
    var human := not _input_locked(u)
    var prompt := ""
    if not m.pending_reaction.is_empty():   # movimento extra (esquiva com dano enorme): usar na hora ou cancelar
        var o := m.pending_unit()
        if o != null and _owner_human(o):
            var saved := o.move_left
            o.move_left = int(m.pending_reaction["budget"])
            var reach_r := m.reachable_for(o)
            o.move_left = saved
            for p in reach_r:
                if reach_r[p].can_stop and p != o.pos:
                    reaction_tiles[p] = reach_r[p]
            prompt = "Movimento extra! Escolha uma casa verde (Esc ou botão direito cancela)"
        hud.hide_popups()
    elif m.awaiting_facing and _owner_human(u):
        prompt = "Escolha para que lado o personagem fica virado: clique numa casa vizinha ou use as setas (Enter mantém)"
        hud.hide_popups()
    elif not human:
        mode_pending = ""
        hud.hide_popups()
        hud.set_hint("")
    else:
        unit_nodes[u.id].get_node("Over/Pointer").visible = true
        if mode_pending != "attack" and not u.down:
            var reach := m.reachable_for(u)
            for p in reach:
                if reach[p].can_stop and p != u.pos:
                    move_tiles[p] = reach[p]
        if not u.acted and mode_pending != "move":
            for t in m.targets_for(u):
                target_tiles[t.pos] = t
        if mode_pending == "attack" and not u.acted:
            for p in m.attack_tiles(u):
                attack_area[p] = true
    if prompt != "":
        hud.set_hint(prompt)
        _prompt_hint = true
    elif _prompt_hint:
        hud.set_hint("")
        _prompt_hint = false
    _add_marker(u.pos, Color(1.0, 0.9, 0.2, 0.55))
    for p in move_tiles:
        var info: Dictionary = move_tiles[p]
        _add_marker(p, Color(1.0, 0.6, 0.1, 0.5) if info.damage > 0 else Color(0.2, 0.55, 1.0, 0.5))
    for p in attack_area:
        _add_marker(p, Color(1.0, 0.25, 0.2, 0.32))
    for p in target_tiles:
        _add_marker(p, Color(1.0, 0.15, 0.15, 0.6))
    for p in reaction_tiles:
        _add_marker(p, Color(0.3, 1.0, 0.45, 0.5))
    if m.awaiting_facing and _owner_human(u):
        for d in BattleMap.DIRS:
            if m.map.in_bounds(u.pos + d):
                _add_marker(u.pos + d, Color(0.3, 1.0, 0.45, 0.45))
    _update_hud()
    if human:
        _auto_menu()


func _add_marker(p: Vector2i, color: Color) -> void :
    var mi := MeshInstance3D.new()
    var box := BoxMesh.new()
    var marker_size := MapGeometry.TILE_SIZE * 0.9
    box.size = Vector3(marker_size, 0.04, marker_size)
    mi.mesh = box
    mi.material_override = _mat(color, true)
    mi.position = MapGeometry.tile_pos(m.map, p) + Vector3(0, 0.03, 0)
    overlay_root.add_child(mi)



func _add_label(p: Vector2i, text: String, color: Color, size: int, corner: float) -> Label3D:
    var l := Label3D.new()
    l.text = text
    l.modulate = color
    l.font = UITheme.bold_font
    l.font_size = size
    l.pixel_size = 0.0065
    l.outline_size = 10
    l.outline_modulate = Color(0, 0, 0, 0.9)
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = (corner == 0.0)
    var base := MapGeometry.tile_pos(m.map, p)
    l.position = base + Vector3(corner, 0.12, corner)
    if corner == 0.0:
        overlay_root.add_child(l)
    else:
        labels_root.add_child(l)
    return l


func _label_free_heights() -> int:
    var n := 0
    for c in labels_root.get_children():
        if c is Label3D:
            n += 1
    return n


func _job_name(u: Unit) -> String:
    return catalog.job_name(u.job_id) if catalog.has_job(u.job_id) else "-"


func _job_level(u: Unit) -> int:
    var ch: Character = roster.by_id().get(u.character_id)
    return ch.job_level(rules, u.job_id) if ch != null else 1
func _update_hud() -> void :
    var u := m.active
    var col := (ALLY_COLOR if u.team == ally_team() else ENEMY_COLOR).lightened(0.2).to_html(false)
    var head := "[b][color=#%s]%s[/color][/b] %s\nNível %d · %s nv %d" % [col, u.display_name, _sex_icon(u.look), u.char_level, _job_name(u), u.job_level]
    var stats := "ATK %d   DEF %d   VEL %d\nMOV %d   PULO %d   ALC %d\n[color=#8d95b8][font_size=15]Bravura %s · Fé %s[/font_size][/color]" % [
            u.atk, u.defense, u.speed, u.move, u.jump, u.attack_range, Character.classify(u.bravura), Character.classify(u.fe)]
    hud.set_unit_info(head, u.hp, u.max_hp, stats, JobArt.face(u.job_id, u.look),
            ALLY_COLOR if u.team == ally_team() else ENEMY_COLOR, u.mp, u.max_mp)
    var spent := float(m.turns.turn_cost(u.moved, u.acted)) / float(m.turns.threshold) if (u.moved or u.acted) else 0.0
    hud.set_action_bar(_action_remaining(u), minf(spent, 1.0))
    var items: Array = []
    var order := m.turns.preview(m.units, 8)
    var alts := m.ready_alternates(u)
    var can_switch := _human_turn() and not u.moved and not u.acted
    for i in order.size():
        var o := m.unit_by_id(order[i])
        items.append({"id": o.id, "team": o.team, "face": JobArt.face(o.job_id, o.look), "number": i + 1,
                "current": o == u and i == 0, "switchable": can_switch and alts.has(o) and i > 0 and not _listed_before(items, o.id)})
    hud.set_order_items(items)


func _listed_before(items: Array, id: int) -> bool:
    for it in items:
        if it["id"] == id:
            return true
    return false


func _show_end() -> void :
    if end_shown:
        return
    end_shown = true
    _save_roster()
    var title := "Empate!"
    if m.winner >= 0:
        title = "%s venceu!" % _player_name(m.winner)
    var body := "[b]XP ganho nesta partida (por ações)[/b]\n"
    var by_id := roster.by_id()
    if last_rewards.is_empty():
        body += "Nenhum personagem do seu elenco atacou."
    for cid in last_rewards:
        var ch: Character = by_id[cid]
        var r: Dictionary = last_rewards[cid]
        var line := "%s: +%d XP (personagem nv %d) · +%d XP de classe" % [ch.display_name, r.xp, ch.char_level(rules), r.job_xp]
        if r.levels_gained > 0:
            line += "  [color=#ffe066]classe nv %d![/color]" % ch.job_level(rules, ch.job_id)
        for nj in r.new_jobs:
            line += "  [color=#7fffa0]libera %s[/color]" % catalog.job_name(nj)
        if ch.attr_points > 0:
            line += "  (%d pts livres)" % ch.attr_points
        body += line + "\n"
    if mode != Mode.DEMO:
        var kills := 0
        for u in m.units:
            if u.team == ally_team():
                kills += u.kills
        var won := m.winner == ally_team()
        account.record_match(kills, won, mode == Mode.ONLINE)
        _save_account()
        body += "\n[color=#8d95b8]Conta: +1 partida, %d unidade(s) abatida(s)%s[/color]" % [kills,
                (" · rank %+d" % (Account.RANK_WIN if won else Account.RANK_LOSS)) if mode == Mode.ONLINE else ""]
    hud.show_end(title, body)
    _write_report()
    if quit_on_end:
        get_tree().quit()




func _mat(color: Color, translucent := false) -> StandardMaterial3D:
    var key := "%s_%s" % [color.to_html(true), translucent]
    if translucent and _mats.has(key):
        return _mats[key]
    if not translucent and _mats.has(key):
        return _mats[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    if not translucent:
        _mats[key] = mat
        mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    if translucent:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _mats[key] = mat
    return mat


func _build_environment() -> void :
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.09, 0.1, 0.15)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.75, 0.8, 0.9)
    env.ambient_light_energy = 0.4
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -35, 0)
    sun.light_energy = 0.9
    sun.shadow_enabled = true
    add_child(sun)
    terrain_root = Node3D.new()
    add_child(terrain_root)
    labels_root = Node3D.new()
    add_child(labels_root)
    units_root = Node3D.new()
    add_child(units_root)
    overlay_root = Node3D.new()
    add_child(overlay_root)
    hover_marker = MeshInstance3D.new()
    var hb := BoxMesh.new()
    var hover_size := MapGeometry.TILE_SIZE * 0.98
    hb.size = Vector3(hover_size, 0.06, hover_size)
    hover_marker.mesh = hb
    hover_marker.material_override = _mat(Color(1, 1, 1, 0.3), true)
    hover_marker.visible = false
    add_child(hover_marker)

    click_marker = Node3D.new()
    click_marker.visible = false
    var cm := _mat(Color(1.0, 0.92, 0.25, 0.95), true)
    var marker_edge := MapGeometry.TILE_SIZE * 0.46
    var marker_length := MapGeometry.TILE_SIZE * 0.9
    var marker_thickness := MapGeometry.TILE_SIZE * 0.07
    for spec in [[Vector3(0, 0, -marker_edge), Vector3(marker_length, 0.05, marker_thickness)],
            [Vector3(0, 0, marker_edge), Vector3(marker_length, 0.05, marker_thickness)],
            [Vector3(-marker_edge, 0, 0), Vector3(marker_thickness, 0.05, marker_length)],
            [Vector3(marker_edge, 0, 0), Vector3(marker_thickness, 0.05, marker_length)]]:
        var side := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = spec[1]
        side.mesh = bm
        side.material_override = cm
        side.position = spec[0]
        click_marker.add_child(side)
    add_child(click_marker)
    camera_pivot = Node3D.new()
    add_child(camera_pivot)
    camera = Camera3D.new()
    camera.fov = 45
    camera_pivot.add_child(camera)
    camera.current = true
    _update_camera()


func _update_click_marker() -> void :
    if m == null or selected_tile == Picking.NONE:
        click_marker.visible = false
        return
    click_marker.visible = true
    click_marker.position = MapGeometry.tile_pos(m.map, selected_tile) + Vector3(0, 0.08, 0)


func _clear_world() -> void :
    _visual_generation += 1
    for root in [terrain_root, units_root, overlay_root, labels_root]:
        for c in root.get_children():
            root.remove_child(c)
            c.queue_free()
    unit_nodes.clear()
    _attack_animation_index.clear()
    _attack_animations.clear()
    _death_animation_started.clear()
    _dying_turn_snapshots.clear()
    _visual_queue.clear()
    _collecting_visual_events = false
    move_tiles.clear()
    target_tiles.clear()
    hover_marker.visible = false
    click_marker.visible = false
    selected_tile = Picking.NONE
    busy = 0


func _tile_color(p: Vector2i) -> Color:
    var map := m.map
    var c: Color
    match map.kind_at(p):
        BattleMap.Kind.SLIPPERY:
            c = Color(0.42, 0.72, 0.88)
        BattleMap.Kind.BLOCKED:
            c = Color(0.28, 0.28, 0.33)
        _:
            var t := float(map.height_at(p)) / maxf(1.0, float(rules.get_int("map", "max_height")))
            c = Color(0.25, 0.5, 0.28).lerp(Color(0.8, 0.7, 0.48), t)
    if (p.x + p.y) % 2 == 0:
        c = c.darkened(0.06)
    return c


func _build_terrain() -> void :
    var map := m.map
    var batches := {}
    var colors := {}
    for z in map.depth:
        for x in map.width:
            var p := Vector2i(x, z)
            var color := _tile_color(p)
            var key := color.to_html(false)
            if not batches.has(key):
                var new_batch := SurfaceTool.new()
                new_batch.begin(Mesh.PRIMITIVE_TRIANGLES)
                batches[key] = new_batch
                colors[key] = color
            var c := MapGeometry.center_xz(map, p)
            var batch_surface: SurfaceTool = batches[key]
            if map.kind_at(p) == BattleMap.Kind.SLIPPERY and map.slope_dir(p) != Vector2i.ZERO:
                batch_surface.append_from(MapGeometry.slope_mesh(map, p), 0, Transform3D(Basis.IDENTITY, Vector3(c.x, 0, c.y)))
            else:
                var top := MapGeometry.column_top(map, p)
                var box := BoxMesh.new()
                box.size = Vector3(MapGeometry.TILE_SIZE, top, MapGeometry.TILE_SIZE)
                batch_surface.append_from(box, 0, Transform3D(Basis.IDENTITY, Vector3(c.x, top / 2.0, c.y)))
    var mesh := ArrayMesh.new()
    for key in batches:
        var completed_batch: SurfaceTool = batches[key]
        completed_batch.commit(mesh)
        var mat := _mat(colors[key])
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    terrain_root.add_child(mi)
func _build_units() -> void :
    for u in m.units:
        var n := Node3D.new()
        var model := CHARACTER_MODEL.create_model(TEAM_COLORS[u.team])
        if model == null:
            continue
        CHARACTER_MODEL.set_facing(model, u.facing)
        var animation_player := CHARACTER_MODEL.animation_player(model)
        animation_player.animation_finished.connect(_on_unit_animation_finished.bind(u.id))
        n.add_child(model)
        var ring := MeshInstance3D.new()
        ring.name = "Ring"
        var torus := TorusMesh.new()
        torus.inner_radius = 0.4
        torus.outer_radius = 0.5
        ring.mesh = torus
        var rmat := StandardMaterial3D.new()
        rmat.albedo_color = Color(1, 0.9, 0.2)
        rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        ring.material_override = rmat
        ring.position.y = 0.06
        ring.visible = false
        n.add_child(ring)

        var over := Node3D.new()
        over.name = "Over"
        var back := _hp_sprite(Color(0.03, 0.04, 0.1, 0.95), 82.0, -41.0)
        back.name = "HpBack"
        over.add_child(back)
        var fill := _hp_sprite(ALLY_COLOR, 80.0, -40.0)
        fill.name = "HpFill"
        fill.render_priority = 1
        over.add_child(fill)
        var ap_back := _hp_sprite(Color(0.03, 0.04, 0.1, 0.9), 82.0, -41.0, 6, -10.0)
        ap_back.name = "ApBack"
        over.add_child(ap_back)
        var ap_fill := _hp_sprite(Color(1.0, 0.82, 0.25), 80.0, -40.0, 4, -10.0)
        ap_fill.name = "ApFill"
        ap_fill.render_priority = 1
        over.add_child(ap_fill)
        var turns := Label3D.new()
        turns.name = "Turns"
        turns.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        turns.font = UITheme.bold_font
        turns.font_size = 44
        turns.pixel_size = 0.0065
        turns.outline_size = 12
        turns.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        turns.offset = Vector2(-72, -4)
        turns.no_depth_test = true
        over.add_child(turns)
        var pointer := Label3D.new()
        pointer.name = "Pointer"
        pointer.text = "▼"
        pointer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        pointer.font = UITheme.bold_font
        pointer.font_size = 64
        pointer.pixel_size = 0.0075
        pointer.modulate = Color(1.0, 0.86, 0.25)
        pointer.outline_size = 12
        pointer.offset = Vector2(0, 62)
        pointer.no_depth_test = true
        pointer.visible = false
        over.add_child(pointer)
        n.add_child(over)
        n.position = MapGeometry.tile_pos(m.map, u.pos)
        units_root.add_child(n)
        unit_nodes[u.id] = n
        _update_unit_facing(u)
        _update_unit_visual(u)
func _hp_sprite(color: Color, width_px: float, offset_x: float, height := 8, off_y := 0.0) -> Sprite3D:
    var s := Sprite3D.new()
    var img := Image.create(84, 10, false, Image.FORMAT_RGBA8)
    img.fill(Color.WHITE)
    s.texture = ImageTexture.create_from_image(img)
    s.pixel_size = 0.01
    s.centered = false
    s.offset = Vector2(offset_x, off_y)
    s.region_enabled = true
    s.region_rect = Rect2(0, 0, width_px, height)
    s.modulate = color
    s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    s.shaded = false
    s.no_depth_test = true
    return s



func _action_remaining(u: Unit) -> float:
    var cost := m.turns.turn_cost(u.moved, u.acted) if u == m.active and (u.moved or u.acted) else 0
    return clampf(float(u.ct - cost) / float(m.turns.threshold), 0.0, 1.0)


func _update_unit_visual(u: Unit) -> void :
    var n: Node3D = unit_nodes[u.id]
    var ally := u.team == ally_team()
    var col := ALLY_COLOR if ally else ENEMY_COLOR
    var fill: Sprite3D = n.get_node("Over/HpFill")
    var hp_back: Sprite3D = n.get_node("Over/HpBack")
    var ap: Sprite3D = n.get_node("Over/ApFill")
    var turns: Label3D = n.get_node("Over/Turns")
    if u.is_expired():
        fill.visible = false
        hp_back.visible = false
        ap.visible = false
        n.get_node("Over/ApBack").visible = false
        turns.visible = false
        return
    var ratio := float(u.hp) / maxf(1.0, float(u.max_hp))
    fill.region_rect = Rect2(0, 0, maxf(0.0, 80.0 * ratio), 8)
    fill.modulate = col
    fill.visible = u.hp > 0 and u.is_alive()
    hp_back.visible = fill.visible
    ap.region_rect = Rect2(0, 0, 80.0 * _action_remaining(u), 4)
    ap.visible = u.hp > 0
    n.get_node("Over/ApBack").visible = u.hp > 0
    if u.is_dying():
        turns.text = str(u.dying_turns)
        turns.offset = Vector2.ZERO
        turns.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        turns.font_size = 52
        turns.modulate = Color(1.0, 0.35, 0.35)
        turns.visible = true
        return
    var tu := m.turns_until(u) if u.is_alive() else -1
    turns.text = str(tu) if tu >= 0 else "+"
    turns.modulate = col.lightened(0.35)
    turns.outline_modulate = col.darkened(0.15)
    turns.visible = u.is_alive()
func _float_text(pos: Vector3, text: String, color: Color, font_size := 34,
        duration := 1.0) -> void :
    var l := Label3D.new()
    l.text = text
    l.modulate = color
    l.font = UITheme.body_font
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = true
    l.pixel_size = 0.008
    l.font_size = font_size
    l.outline_size = 9
    add_child(l)
    l.position = pos + Vector3(0, SPRITE_H + 0.35, 0)
    if animate:
        var tw := create_tween()
        tw.set_parallel(true)
        tw.tween_property(l, "position:y", l.position.y + 0.7, duration)
        tw.tween_property(l, "modulate:a", 0.0, duration)
        tw.chain().tween_callback(l.queue_free)
    else:
        l.queue_free()


func _pan_limit() -> Vector3:
    var half := float(m.map.width) / 2.0 if m != null else 9.0
    return Vector3(half, 0, half)


func _update_camera() -> void :
    camera_pivot.rotation_degrees = Vector3(pitch, yaw, 0)
    camera.position = Vector3(0, 0, distance)


func pick_at(screen_pos: Vector2) -> Vector2i:
    if m == null:
        return Picking.NONE
    var o := camera.project_ray_origin(screen_pos)
    var d := camera.project_ray_normal(screen_pos)
    return Picking.pick_tile(m.map, o, d)
func _process(delta: float) -> void :
    _t += delta
    if m != null:
        _update_overheads()
    if test_mode:
        return
    var shift := Input.is_key_pressed(KEY_SHIFT)
    var rot := 0.0
    if Input.is_key_pressed(KEY_Q):
        rot += 1.0
    if Input.is_key_pressed(KEY_E):
        rot -= 1.0
    if rot != 0.0:
        yaw += rot * 90.0 * delta
    var mv := Vector3.ZERO
    if not shift:
        if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
            mv.z -= 1
        if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
            mv.z += 1
        if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
            mv.x -= 1
        if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
            mv.x += 1
    if mv != Vector3.ZERO or rot != 0.0:
        camera_pivot.position += mv.normalized().rotated(Vector3.UP, deg_to_rad(yaw)) * 16.0 * delta
        camera_pivot.position = camera_pivot.position.clamp(_pan_limit() * -1.0, _pan_limit())
        _update_camera()
    if m != null and (shift or _follow_timer > 0.0):
        _follow_timer = maxf(0.0, _follow_timer - delta)
        camera_pivot.position = camera_pivot.position.lerp(_actor_center(), clampf(delta * 6.0, 0.0, 1.0))
        _update_camera()
    if m != null and hud.context_panel.visible and menu_unit != null and unit_nodes.has(menu_unit.id):
        hud.move_context_menu(_menu_anchor(menu_unit), get_viewport().get_visible_rect().size)
    if m != null and not m.is_over() and busy == 0 and (_cpu_controls(m.active) or _cpu_owns_reaction()):
        cpu_wait += delta
        if cpu_wait >= 0.7:
            cpu_wait = 0.0
            step_cpu()
    if auto_play and mode == Mode.ONLINE and m != null and not m.is_over() and busy == 0\
and not awaiting and _auto_actor_is_me():
        _command(SimpleBot.next_command(m, bot_rng))
    if quit_after_turns > 0 and m != null and m.turn_serial >= quit_after_turns:
        get_tree().quit()
    if _shot_path != "":
        _shot_frames += 1
        if _shot_frames == 12:
            var img := get_viewport().get_texture().get_image()
            img.save_png(_shot_path)
            get_tree().quit()



func _update_overheads() -> void :
    var up := camera.global_transform.basis.y
    for id in unit_nodes:
        var n: Node3D = unit_nodes[id]
        var over: Node3D = n.get_node("Over")
        var u := m.unit_by_id(int(id))
        if u != null and u.is_dying():
            over.global_position = n.global_position + Vector3(0, 0.35, 0)
        else:
            over.global_position = n.global_position + Vector3(0, SPRITE_H * 0.5, 0) + up * (SPRITE_H * 0.5 + 0.14)
        var pointer: Label3D = over.get_node("Pointer")
        if pointer.visible:
            pointer.offset.y = 62.0 + sin(_t * 5.0) * 7.0
func _unhandled_input(event: InputEvent) -> void :
    if m != null and m.awaiting_facing and screen == null and event is InputEventKey and event.pressed and not event.echo \
            and _owner_human(m.active) and not event.shift_pressed:
        var sd := Vector2.ZERO
        match event.keycode:
            KEY_LEFT, KEY_A:
                sd = Vector2(-1, 0)
            KEY_RIGHT, KEY_D:
                sd = Vector2(1, 0)
            KEY_UP, KEY_W:
                sd = Vector2(0, -1)
            KEY_DOWN, KEY_S:
                sd = Vector2(0, 1)
            KEY_ENTER, KEY_SPACE, KEY_ESCAPE:
                cancel_all()
                return
        if sd != Vector2.ZERO:
            _command({"t": "face", "unit": m.active.id, "dir": _dir_from_screen(sd)})
            return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE\
and m == null and screen == null and net != null and not net.active:
        _show_menu()
        return
    if m == null or screen != null:
        return
    if event is InputEventMouseButton and event.pressed:
        match event.button_index:
            MOUSE_BUTTON_RIGHT:
                _rc_start = event.position
                _rc_dragged = false
            MOUSE_BUTTON_LEFT:
                var p := pick_at(event.position)
                if p != Picking.NONE:
                    click_tile(p, event.position)
                else:
                    cancel_all()
            MOUSE_BUTTON_WHEEL_UP:
                distance = clampf(distance - 2.0, 8.0, 60.0)
                _update_camera()
            MOUSE_BUTTON_WHEEL_DOWN:
                distance = clampf(distance + 2.0, 8.0, 60.0)
                _update_camera()
    elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        if not _rc_dragged:
            cancel_all()
    elif event is InputEventMouseMotion:
        if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
            if event.position.distance_to(_rc_start) > 6.0:
                _rc_dragged = true
            yaw -= event.relative.x * 0.3
            pitch = clampf(pitch - event.relative.y * 0.2, -80.0, -25.0)
            _update_camera()
        else:
            set_hover(pick_at(event.position))
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.shift_pressed and (event.keycode == KEY_RIGHT or event.keycode == KEY_LEFT):
            _cycle_actor(1 if event.keycode == KEY_RIGHT else -1)
        elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
            wait()
        elif event.keycode == KEY_ESCAPE:
            cancel_all()


func set_hover(p: Vector2i) -> void :
    hover = p
    if p == Picking.NONE or m == null:
        hover_marker.visible = false
    else:
        hover_marker.visible = true
        hover_marker.position = MapGeometry.tile_pos(m.map, p) + Vector3(0, 0.06, 0)


# ---------------------------------------------------------------- lado, reacoes e movimento extra

func _manual_teams() -> Array:
    match mode:
        Mode.LOCAL, Mode.ONLINE:
            return [0, 1]
        Mode.VS_CPU:
            return [0]
    return []


## O jogador (e nao o computador nem o adversario online) controla esta unidade?
func _owner_human(u: Unit) -> bool:
    if _cpu_controls(u):
        return false
    return mode != Mode.ONLINE or u.team == my_team


func _cpu_owns_reaction() -> bool:
    var o := m.pending_unit() if m != null else null
    return o != null and _cpu_controls(o)


func _auto_actor_is_me() -> bool:
    if not m.pending_reaction.is_empty():
        var o := m.pending_unit()
        return o != null and o.team == my_team
    return m.active.team == my_team


## O cliente (time 1) pode mandar comando agora? (e a vez dele, ou o movimento extra pendente e dele)
func _client_may_act() -> bool:
    if m == null or m.is_over():
        return false
    if not m.pending_reaction.is_empty():
        var o := m.pending_unit()
        return o != null and o.team == 1
    return m.active.team == 1


static func reaction_color(kind: String) -> Color:
    match kind:
        "dodge", "extra_move":
            return Color(0.35, 0.9, 0.45)   # esquiva: verde
        "parry":
            return Color(1.0, 0.9, 0.3)     # parry: amarelo
        "block", "fall":
            return Color(0.65, 0.42, 0.2)   # bloqueio: marrom
        "counter":
            return Color(1.0, 0.85, 0.35)
        "oa":
            return Color(1.0, 0.6, 0.35)
    return Color(1, 1, 1)


## Reacoes aparecem so com o nome e o feito (o jogo nao explica as regras na tela).
func _on_reaction_event(u: Unit, kind: String, text: String) -> void:
    _queue_visual_action(Callable(self, "_present_reaction_event").bind(u, kind, text))


func _present_reaction_event(u: Unit, kind: String, text: String) -> void:
    if unit_nodes.has(u.id):
        _float_text(unit_nodes[u.id].position, text, reaction_color(kind))
    float_log.append([text, kind])
    if float_log.size() > 30:
        float_log.pop_front()
    if animate:
        _pause_visual_sequence(1.0)


func _update_unit_facing(u: Unit) -> void:
    var node: Node3D = unit_nodes[u.id]
    var model := node.get_node_or_null("Body") as Node3D
    if model != null:
        CHARACTER_MODEL.set_facing(model, u.facing)


## 0 = clique normal; 1 = tratado; -1 = tratado e ignorado.
func _click_special(p: Vector2i) -> int:
    if not m.pending_reaction.is_empty():
        var o := m.pending_unit()
        if o != null and _owner_human(o) and reaction_tiles.has(p):
            _command({"t": "react_move", "unit": o.id, "x": p.x, "y": p.y})
            return 1
        return -1
    if m.awaiting_facing:
        var u := m.active
        var d := p - u.pos
        if _owner_human(u) and absi(d.x) + absi(d.y) == 1:
            _command({"t": "face", "unit": u.id, "dir": BattleMap.DIRS.find(d)})
            return 1
        return -1
    return 0


## Seta da tela -> direcao do mapa (conforme a camera).
func _dir_from_screen(sd: Vector2) -> int:
    var fwd := Vector3(-camera.global_transform.basis.z.x, 0, -camera.global_transform.basis.z.z).normalized()
    var rgt := Vector3(camera.global_transform.basis.x.x, 0, camera.global_transform.basis.x.z).normalized()
    var w := rgt * sd.x + fwd * (-sd.y)
    var best := 0
    var best_dot := -10.0
    for i in BattleMap.DIRS.size():
        var dot := w.x * BattleMap.DIRS[i].x + w.z * BattleMap.DIRS[i].y
        if dot > best_dot:
            best_dot = dot
            best = i
    return best


func choose(id: String) -> bool:
    if m == null or m.is_over():
        return false
    if id == "stand":
        if not _human_turn() or not m.active.down or m.active.moved:
            return false
        hud.hide_context_menu()
        var act := m.active
        _ask_confirm("Levantar [b]%s[/b]?\n(gasta a ação de movimento)" % act.display_name, func(): _command({"t": "stand", "unit": act.id}))
        return true
    return _choose_base(id)
