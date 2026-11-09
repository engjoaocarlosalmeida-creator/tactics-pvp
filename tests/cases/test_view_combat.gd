extends TestCase

var r := Rules.load_default()
var views: Array[GameView] = []


func _make() -> GameView:
    var v := GameView.new()
    v.animate = false
    v.test_mode = true
    (Engine.get_main_loop() as SceneTree).root.add_child(v)
    views.append(v)
    return v


func _cleanup() -> void:
    MatchState.reactions_enabled = false
    for v in views:
        v.free()
    views.clear()


func _duel(rows: Array, p0: Vector2i, p1: Vector2i) -> MatchState:
    var map := TestUtil.map_from(rows)
    var a := TestUtil.unit(0, 0, p0, r)
    var b := TestUtil.unit(1, 1, p1, r)
    a.speed = 10
    b.speed = 9
    var us: Array[Unit] = [a, b]
    return MatchState.from_parts(r, map, us)


func test_times_humanos_escolhem_o_lado_no_fim_do_turno() -> void:
    if not needs_display():
        return
    var v := _make()
    v.mode = GameView.Mode.LOCAL
    v.setup_match(_duel([[0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0]], Vector2i(2, 0), Vector2i(7, 1)))
    check_eq(v.m.manual_facing_teams, [0, 1], "os dois jogadores humanos escolhem o lado")
    v.choose("end_turn")
    v.confirm_accept()
    check(v.m.awaiting_facing, "Esperar pede o lado")
    check(v.hud.hint_label.text.contains("lado"), "a tela explica a escolha")
    check(not v.hud.context_panel.visible, "sem menu de acoes enquanto escolhe")
    var u := v.m.active
    check(v.click_tile(u.pos + Vector2i(0, 1)), "clicar numa casa vizinha escolhe o lado")
    check_eq(u.facing, Vector2i(0, 1), "virado para baixo")
    check_eq(v.m.active.id, 1, "turno passou")
    var mark: MeshInstance3D = v.unit_nodes[u.id].get_node("FacingMark")
    check((mark.basis.y - Vector3(0, 0, 1)).length() < 0.01, "o cone da base aponta para onde esta virado")
    _cleanup()


func test_esc_mantem_o_lado_e_clique_longe_nao_faz_nada() -> void:
    if not needs_display():
        return
    var v := _make()
    v.mode = GameView.Mode.LOCAL
    v.setup_match(_duel([[0, 0, 0, 0, 0, 0, 0, 0]], Vector2i(2, 0), Vector2i(7, 0)))
    v.choose("end_turn")
    v.confirm_accept()
    var facing := v.m.active.facing
    check(not v.click_tile(Vector2i(6, 0)), "casa longe nao serve")
    check(v.m.awaiting_facing, "continua esperando")
    var u := v.m.active
    v.cancel_all()
    check_eq(u.facing, facing, "Esc mantem o lado atual")
    check(not v.m.awaiting_facing, "turno terminou")
    _cleanup()


func test_setas_escolhem_o_lado_pela_camera() -> void:
    if not needs_display():
        return
    var v := _make()
    v.mode = GameView.Mode.LOCAL
    v.setup_match(_duel([[0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0]], Vector2i(2, 1), Vector2i(7, 1)))
    v.yaw = 0.0
    v._update_camera()
    v.choose("end_turn")
    v.confirm_accept()
    var u := v.m.active
    var key := InputEventKey.new()
    key.keycode = KEY_RIGHT
    key.pressed = true
    v._unhandled_input(key)
    check_eq(u.facing, Vector2i(1, 0), "seta para a direita da tela com a camera padrao = +x")
    _cleanup()


func test_contra_o_computador_so_o_jogador_escolhe_o_lado() -> void:
    if not needs_display():
        return
    var v := _make()
    v.start_match(GameView.Mode.VS_CPU, 5)
    check_eq(v.m.manual_facing_teams, [0], "so o time humano")
    var demo := _make()
    demo.start_match(GameView.Mode.DEMO, 5)
    check_eq(demo.m.manual_facing_teams, [], "computador x computador nunca para")
    var online := _make()
    online.mode = GameView.Mode.ONLINE
    check_eq(online._manual_teams(), [0, 1], "online: os dois lados")
    _cleanup()


func test_textos_flutuantes_das_reacoes_so_com_nome_e_cores() -> void:
    if not needs_display():
        return
    check_eq(GameView.reaction_color("dodge"), Color(0.35, 0.9, 0.45), "esquiva verde")
    check_eq(GameView.reaction_color("parry"), Color(1.0, 0.9, 0.3), "parry amarelo")
    check_eq(GameView.reaction_color("block"), Color(0.65, 0.42, 0.2), "bloqueio marrom")
    var v := _make()
    MatchState.reactions_enabled = true
    v.mode = GameView.Mode.LOCAL
    var st := _duel([[0, 0, 0, 0, 0, 0]], Vector2i(2, 0), Vector2i(3, 0))
    v.setup_match(st)
    st.units[1].facing = Vector2i(-1, 0)
    st.roll_override = [1.0]
    v.choose("skill_basic")
    v.click_tile(Vector2i(3, 0))
    v.confirm_accept()
    check_eq(v.float_log, [["Esquiva", "dodge"]], "so o nome do resultado aparece")
    _cleanup()


func test_menu_mostra_levantar_para_personagem_caido() -> void:
    if not needs_display():
        return
    var v := _make()
    v.mode = GameView.Mode.LOCAL
    var st := _duel([[0, 0, 0, 0, 0, 0]], Vector2i(0, 0), Vector2i(5, 0))
    st.units[0].down = true
    v.setup_match(st)
    check(v.hud.context_ids.has("stand") and not v.hud.context_ids.has("move_mode"), "Levantar no lugar de Mover")
    check(v.choose("stand"), "escolheu levantar")
    check(v.hud.confirm_visible(), "pede confirmacao")
    v.confirm_accept()
    check(not st.units[0].down and st.units[0].moved, "levantou gastando o movimento")
    _cleanup()


func test_movimento_extra_o_dono_escolhe_a_casa_ou_cancela() -> void:
    if not needs_display():
        return
    var v := _make()
    MatchState.reactions_enabled = true
    v.mode = GameView.Mode.LOCAL
    var st := _duel([[0, 0, 0, 0, 0, 0, 0, 0]], Vector2i(2, 0), Vector2i(3, 0))
    st.units[0].atk = 60
    st.units[1].speed = 1
    v.setup_match(st)
    st.units[1].facing = Vector2i(-1, 0)
    st.roll_override = [1.0, 1.0]
    v.choose("skill_basic")
    v.click_tile(Vector2i(3, 0))
    v.confirm_accept()
    check(not st.pending_reaction.is_empty(), "movimento extra pendente")
    check(v.reaction_tiles.has(Vector2i(5, 0)) and not v.reaction_tiles.has(Vector2i(7, 0)), "casas verdes ate o limite")
    check(v.hud.hint_label.text.contains("Movimento extra"), "aviso")
    check(not v.hud.context_panel.visible, "sem menu enquanto decide")
    check(v.click_tile(Vector2i(5, 0)), "clicar numa casa verde usa o movimento")
    check_eq(st.units[1].pos, Vector2i(5, 0), "moveu")
    check(st.pending_reaction.is_empty(), "resolvido")
    _cleanup()


func test_movimento_extra_do_computador_e_cancelado_sozinho() -> void:
    if not needs_display():
        return
    var v := _make()
    MatchState.reactions_enabled = true
    v.mode = GameView.Mode.VS_CPU
    var st := _duel([[0, 0, 0, 0, 0, 0, 0, 0]], Vector2i(2, 0), Vector2i(3, 0))
    st.units[0].atk = 60
    st.units[1].speed = 1
    v.setup_match(st)
    st.units[1].facing = Vector2i(-1, 0)
    st.roll_override = [1.0, 1.0]
    v.choose("skill_basic")
    v.click_tile(Vector2i(3, 0))
    v.confirm_accept()
    check(v._cpu_owns_reaction(), "o dono e o computador")
    v.step_cpu()
    check(st.pending_reaction.is_empty(), "o computador cancelou")
    _cleanup()


func test_cliente_online_so_age_quando_e_dele() -> void:
    if not needs_display():
        return
    var v := _make()
    v.mode = GameView.Mode.ONLINE
    var st := _duel([[0, 0, 0, 0, 0, 0]], Vector2i(0, 0), Vector2i(5, 0))
    v.setup_match(st)
    check(not v._client_may_act(), "vez do host: cliente nao age")
    st.manual_facing_teams = []
    st.end_turn()
    check(v._client_may_act(), "vez do cliente")
    st.pending_reaction = {"type": "extra_move", "unit": 0, "budget": 2}
    check(not v._client_may_act(), "movimento extra do host: cliente nao responde")
    st.pending_reaction = {"type": "extra_move", "unit": 1, "budget": 2}
    check(v._client_may_act(), "movimento extra do cliente: ele responde")
    _cleanup()
