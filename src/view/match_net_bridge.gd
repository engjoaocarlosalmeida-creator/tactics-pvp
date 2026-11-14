extends Node
class_name MatchNetBridge

var game_view_ref
var net: NetSession
var _cmd_queue: Array = []


func setup(gv) -> void:
    game_view_ref = gv
    net = NetSession.new()
    net.name = "Net"
    add_child(net)
    net.setup_received.connect(_on_net_setup)
    net.command_from_client.connect(_on_net_command_from_client)
    net.command_applied.connect(_on_net_command_applied)
    net.command_rejected.connect(func():
        game_view_ref.awaiting = false
        game_view_ref._try_refresh())
    net.lost_connection.connect(_on_net_lost)
    net.connection_failed.connect(func():
        game_view_ref.hud.show_message("Não conectou", "Não foi possível conectar. Confira o IP e se o anfitrião já está esperando."))
    net.client_joined.connect(func():
        game_view_ref.hud.show_waiting("Adversário conectou", "Preparando a partida..."))


func queue_commands(cmds: Array) -> void:
    _cmd_queue = cmds


func start_host(port: int) -> void:
    var err := net.host_game(port, _my_team_dicts())
    if err != OK:
        game_view_ref.hud.show_message("Não foi possível hospedar", "A porta %d está em uso. Feche outra cópia do jogo e tente de novo." % port)
        return
    game_view_ref.hud.show_game_hud(false)
    game_view_ref.hud.show_waiting("Aguardando adversário",
            "Peça para o outro jogador escolher [b]Jogar online → Entrar[/b] e digitar este IP:\n[b]%s[/b]  (porta %d)\n[color=#aab]Pela internet, é preciso liberar a porta %d no roteador. Pela Steam isso não será necessário.[/color]" % [NetSession.local_ip(), port, port])


func start_join(address: String, port: int) -> void:
    var err := net.join_game(address, port, _my_team_dicts())
    if err != OK:
        game_view_ref.hud.show_message("Não conectou", "Endereço inválido: %s" % address)
        return
    game_view_ref.hud.show_game_hud(false)
    game_view_ref.hud.show_waiting("Conectando...", "Conectando a %s ..." % address)


func _my_team_dicts() -> Array:
    var out: Array = []
    for c in game_view_ref.roster.team_chars(0, game_view_ref.rules.get_int("match", "units_per_team")):
        out.append(c.to_dict())
    return out


func _on_net_setup(seed_value: int, t0: Array, t1: Array) -> void:
    var gv = game_view_ref
    gv.mode = gv.Mode.ONLINE
    gv.my_team = 0 if net.is_host else 1
    gv.match_seed = seed_value
    gv.awaiting = false
    gv.desync = false
    var per: int = gv.rules.get_int("match", "units_per_team")
    var mine = gv.roster.team_chars(0, per)
    var theirs: Array = []
    for d in (t1 if net.is_host else t0):
        var c := Character.from_dict(d)
        c.id += 1000
        theirs.append(c)
    gv.hud.hide_overlay()
    gv.hud.clear_log()
    gv.setup_match(MatchState.create_from_characters(seed_value, gv.rules, gv.catalog,
            mine if net.is_host else theirs, theirs if net.is_host else mine))


func _on_net_command_from_client(cmd: Dictionary) -> void:
    var gv = game_view_ref
    if not gv._client_may_act():
        net.reject()
        return
    var res: Dictionary = gv._apply_command_with_visuals(cmd)
    if res.ok:
        net.broadcast(cmd, gv.m.state_hash())
    else:
        net.reject()
    gv.menu_wanted = true
    gv._try_refresh()


func _on_net_command_applied(cmd: Dictionary, host_hash: int) -> void:
    var gv = game_view_ref
    if gv.m == null:
        return
    gv._apply_command_with_visuals(cmd)
    gv.awaiting = false
    gv.menu_wanted = true
    if host_hash != gv.m.state_hash():
        gv.desync = true
        gv.hud.add_log("ATENÇÃO: os dois lados ficaram diferentes (dessincronia)")
    if not _cmd_queue.is_empty():
        var nxt: Dictionary = _cmd_queue.pop_front()
        gv._command(nxt)
        return
    gv._try_refresh()


func _on_net_lost() -> void:
    var gv = game_view_ref
    gv.opponent_left = true
    if gv.m != null and not gv.m.is_over() and not gv.end_shown:
        gv._write_report()
        gv.hud.show_message("Conexão perdida", "O adversário saiu da partida.")
        if gv.quit_on_end:
            get_tree().quit()
