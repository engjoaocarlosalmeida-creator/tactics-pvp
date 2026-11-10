extends TestCase

const CHARACTER_MODEL := preload("res://src/view/character_model.gd")

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
    check(not v.unit_nodes[u.id].has_node("FacingMark"), "a seta indicadora nao e mais exibida")
    var body: Node3D = v.unit_nodes[u.id].get_node("Body")
    check(is_zero_approx(body.rotation.y), "o modelo mantem a orientacao escolhida")
    _cleanup()


func test_modelos_3d_recebem_contorno_da_equipe() -> void:
    if not needs_display():
        return
    var v := _make()
    v.mode = GameView.Mode.LOCAL
    v.setup_match(_duel([[0, 0, 0, 0, 0, 0]], Vector2i(0, 0), Vector2i(5, 0)))

    for unit in v.m.units:
        var model: Node3D = v.unit_nodes[unit.id].get_node("Body")
        check_eq(model.scale, Vector3.ONE * CHARACTER_MODEL.MODEL_SCALE, "modelo mantem a escala esperada")

        var expected_color: Color = CHARACTER_MODEL.team_color(unit.team)
        var found_outline := false
        for node in model.find_children("*", "MeshInstance3D", true, false):
            var mesh_instance := node as MeshInstance3D
            for surface in mesh_instance.mesh.get_surface_count():
                var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
                if material == null:
                    continue
                check_eq(material.albedo_texture, CHARACTER_MODEL.CHARACTER_TEXTURE,
                        "a malha usa a textura do Ranger")
                var outline := material.next_pass as ShaderMaterial
                if outline == null:
                    continue
                found_outline = true
                check_eq(outline.get_shader_parameter("outline_color"), expected_color,
                        "o contorno usa a cor do time %d" % unit.team)
        check(found_outline, "modelo do time %d tem contorno" % unit.team)
    _cleanup()


func test_animacao_de_ataque_tambem_ocorre_em_casa_vazia() -> void:
    if not needs_display():
        return
    var v := _make()
    v.mode = GameView.Mode.LOCAL
    v.setup_match(_duel([[0, 0, 0, 0, 0, 0]], Vector2i(0, 0), Vector2i(5, 0)))
    v.animate = true
    var attacker: Unit = v.m.units[0]
    var body: Node3D = v.unit_nodes[attacker.id].get_node("Body")
    var animation_player := CHARACTER_MODEL.animation_player(body)

    check_eq(str(animation_player.current_animation), "Idle", "o personagem inicia em Idle")
    check(animation_player.has_animation("walk"), "a biblioteca contem walk")
    check(animation_player.has_animation("jump_up"), "a biblioteca contem jump_up")
    check(animation_player.has_animation("jump_down"), "a biblioteca contem jump_down")
    check(animation_player.has_animation("espadada_dentroparafora"), "a biblioteca contem o primeiro golpe")
    check(animation_player.has_animation("espadada_foraparadentro"), "a biblioteca contem o segundo golpe")
    check(animation_player.has_animation("death_forward"), "a biblioteca contem a queda para frente")
    check(animation_player.has_animation("death_back"), "a biblioteca contem a queda para trás")
    v._on_attack_resolved(attacker, null, Vector2i(1, 0), 0)
    check_eq(str(animation_player.current_animation), "espadada_dentroparafora",
            "atacar uma casa vazia ainda executa o golpe")
    _cleanup()


func test_expiracao_substitui_modelo_por_caveira_no_local() -> void:
    if not needs_display():
        return
    var v := _make()
    v.mode = GameView.Mode.LOCAL
    var state := _duel([[0, 0, 0, 0, 0, 0]], Vector2i(0, 0), Vector2i(5, 0))
    v.setup_match(state)
    var fallen: Unit = state.units[1]
    fallen.hp = 0
    fallen.dying_turns = 0
    var position: Vector3 = v.unit_nodes[fallen.id].position

    v._present_unit_expired(fallen)

    var node: Node3D = v.unit_nodes[fallen.id]
    check(node.get_node_or_null("Body") == null, "o corpo é removido")
    check(node.get_node_or_null("Skull") != null, "a caveira substitui o corpo")
    check_eq(node.position, position, "a caveira permanece no local da queda")
    check(not node.get_node("Ring").visible, "a caveira não aparece como unidade ativa")
    _cleanup()


func test_texto_de_dano_muda_de_tamanho_com_a_quantidade() -> void:
    if not needs_display():
        return
    var v := _make()
    v._float_text(Vector3.ZERO, "-3", Color.RED, 34, 0.6)
    v._float_text(Vector3.ZERO, "-30", Color.RED, 52, 0.6)
    var sizes: Array[int] = []
    for child in v.get_children():
        if child is Label3D:
            sizes.append((child as Label3D).font_size)
    check(sizes.has(34) and sizes.has(52), "dano maior recebe fonte maior")
    _cleanup()


func test_interromper_ataque_para_mover_libera_fila_cpu() -> void:
    var v := _make()
    v.mode = GameView.Mode.LOCAL
    v.setup_match(_duel([[0, 0, 0, 0, 0, 0]], Vector2i(0, 0), Vector2i(5, 0)))
    v.animate = true
    var attacker: Unit = v.m.units[0]
    var body: Node3D = v.unit_nodes[attacker.id].get_node("Body")
    var animation_player := CHARACTER_MODEL.animation_player(body)
    var attack_finished := [0]
    animation_player.animation_finished.connect(func(animation_name: StringName):
        if animation_name == "espadada_dentroparafora":
            attack_finished[0] += 1)

    v._on_attack_resolved(attacker, null, Vector2i(1, 0), 0)
    check_eq(v.busy, 1, "a animacao de ataque bloqueia a proxima acao enquanto executa")
    v._play_unit_animation(attacker.id, "walk", 0.16)
    animation_player.advance(3.0)

    check_eq(v.busy, 0,
            "interromper o ataque para mover libera o bloqueio que impedia os turnos")
    check_eq(str(animation_player.current_animation), "walk",
            "a locomocao substitui a animacao de ataque")
    check_eq(attack_finished[0], 0,
            "o Godot nao emite animation_finished para um golpe interrompido pela locomocao")
    v._on_unit_animation_finished("espadada_dentroparafora", attacker.id)
    check_eq(v.busy, 0, "o sinal atrasado nao libera o contador duas vezes")
    _cleanup()


func test_fila_visual_espera_a_etapa_atual_terminar() -> void:
    var v := _make()
    var events: Array[String] = []
    v._collecting_visual_events = true
    v._queue_visual_action(func():
        events.append("movimento")
        v.busy += 1)
    v._queue_visual_action(func(): events.append("xp"))
    v._collecting_visual_events = false
    v._drain_visual_queue()

    check_eq(events, ["movimento"], "o XP aguarda a etapa visual anterior")
    check_eq(v.busy, 1, "a etapa ativa mantem a fila bloqueada")
    v._anim_done()
    check_eq(events, ["movimento", "xp"], "a fila avanca depois da conclusao")
    check_eq(v.busy, 0, "a conclusao libera o bloqueio")
    _cleanup()


func test_xp_aguarda_ataque_e_aviso_de_dano() -> void:
    if not needs_display():
        return
    var v := _make()
    MatchState.reactions_enabled = false
    v.mode = GameView.Mode.LOCAL
    var st := _duel([[0, 0, 0, 0, 0, 0]], Vector2i(2, 0), Vector2i(3, 0))
    v.setup_match(st)
    v.animate = true
    var attacker: Unit = st.units[0]

    check(v._command({"t": "attack", "unit": attacker.id, "target": st.units[1].id}),
            "o ataque e aplicado")
    check(v._attack_animations.has(attacker.id), "o golpe comeca primeiro")
    check_eq(v._visual_queue.size(), 2, "dano e XP aguardam o golpe")
    check(v.last_rewards.is_empty(), "o XP ainda nao foi processado durante o golpe")

    var action := str(v._attack_animations[attacker.id])
    v._finish_attack_animation(attacker.id, action)
    check_eq(v.busy, 1, "o aviso de dano e mostrado antes do XP")
    check(v.last_rewards.is_empty(), "o XP aguarda a conclusao do aviso de dano")
    var labels: Array[String] = []
    for child in v.get_children():
        if child is Label3D:
            labels.append((child as Label3D).text)
    check(labels.any(func(text: String): return text.begins_with("-")),
            "o texto de dano aparece apos o golpe")
    check(not labels.any(func(text: String): return text.contains("XP")),
            "o texto de XP nao se sobrepoe ao aviso de dano")
    _cleanup()


func test_animacoes_de_pulo_nao_deslocam_o_quadril_no_plano() -> void:
    var library := load(CHARACTER_MODEL.ANIMATIONS_PATH) as AnimationLibrary
    check(library != null, "biblioteca de animacoes carregada")
    if library == null:
        return

    for action in ["jump_up", "jump_down"]:
        var animation := library.get_animation(action)
        var root_track := -1
        for track in animation.get_track_count():
            if animation.track_get_type(track) == Animation.TYPE_POSITION_3D \
                    and str(animation.track_get_path(track)).ends_with(":mixamorig_Hips"):
                root_track = track
                break
        check(root_track >= 0, "%s contem a trilha do quadril" % action)
        if root_track < 0:
            continue

        var initial_position: Vector3 = animation.track_get_key_value(root_track, 0)
        for key in animation.track_get_key_count(root_track):
            var position: Vector3 = animation.track_get_key_value(root_track, key)
            check(is_equal_approx(position.x, initial_position.x)
                    and is_equal_approx(position.z, initial_position.z),
                    "%s nao duplica deslocamento horizontal do movimento" % action)


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
