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
		var extra_floor_meshes := 0
		for child in v.unit_nodes[unit.id].get_children():
			if child is MeshInstance3D:
				extra_floor_meshes += 1
		check_eq(extra_floor_meshes, 0, "unidade nao tem disco colorido no tile")
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

	v.game_visual_presenter._present_unit_expired(fallen)

	var node: Node3D = v.unit_nodes[fallen.id]
	check(node.get_node_or_null("Body") == null, "o corpo é removido")
	check(node.get_node_or_null("Skull") != null, "a caveira substitui o corpo")
	check_eq(node.position, position, "a caveira permanece no local da queda")
	var skull := node.get_node("Skull") as Node3D
	check_eq(skull.scale, Vector3.ONE * 0.5,
			"a caveira tem um quarto do tamanho anterior")
	check_eq(skull.position.y, 0.0,
			"a caveira fica apoiada no tile")
	var extra_floor_meshes := 0
	for child in node.get_children():
		if child is MeshInstance3D:
			extra_floor_meshes += 1
	check_eq(extra_floor_meshes, 0, "a caveira nao tem disco colorido no tile")
	var outline_found := false
	for mesh_node in skull.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if material == null:
				continue
			var outline := material.next_pass as ShaderMaterial
			if outline == null:
				continue
			outline_found = true
			check_eq(outline.get_shader_parameter("outline_color"),
					CHARACTER_MODEL.team_color(fallen.team),
					"a caveira mantém o contorno colorido da equipe")
	check(outline_found, "a caveira tem contorno que identifica a equipe")
	_cleanup()


func test_barra_de_hp_permanece_oculta_enquanto_unidade_morre() -> void:
	if not needs_display():
		return
	var v := _make()
	v.mode = GameView.Mode.LOCAL
	var state := _duel([[0, 0, 0, 0, 0, 0]], Vector2i(0, 0), Vector2i(5, 0))
	v.setup_match(state)
	var fallen: Unit = state.units[1]
	fallen.hp = 0
	fallen.dying_turns = 3

	v.game_visual_presenter._update_unit_visual(fallen)

	check(not v.unit_nodes[fallen.id].get_node("Over/HpFill").visible,
			"a barra vazia continua oculta durante o estado morrendo")
	_cleanup()


func test_impacto_exibe_dano_e_inicia_queda_antes_do_fim_do_golpe() -> void:
	if not needs_display():
		return
	var v := _make()
	v.mode = GameView.Mode.LOCAL
	var state := _duel([[0, 0, 0, 0, 0, 0]], Vector2i(2, 0), Vector2i(3, 0))
	v.setup_match(state)
	v.animate = true
	var victim: Unit = state.units[1]
	victim.hp = 0
	victim.dying_turns = 4
	var attacker_body: Node3D = v.unit_nodes[0].get_node("Body")
	var victim_body: Node3D = v.unit_nodes[1].get_node("Body")
	var attacker_player := CHARACTER_MODEL.animation_player(attacker_body)
	var victim_player := CHARACTER_MODEL.animation_player(victim_body)

	v.game_visual_presenter._present_attack_resolved(state.units[0], state.units[0].facing)
	check_eq(str(attacker_player.current_animation), "espadada_dentroparafora",
			"o golpe continua em andamento")
	v.game_visual_presenter._present_attack_impact(victim, 10, 10)

	check(str(victim_player.current_animation).begins_with("death_"),
			"a queda começa no impacto, antes de terminar o golpe")
	check(v.game_visual_presenter._death_animation_started.has(victim.id), "a animação de morte só inicia uma vez")
	check_eq(v.unit_nodes[victim.id].get_node("Over/Turns").text, "4",
			"o indicador mostra apenas a contagem")
	check_eq(v.unit_nodes[victim.id].get_node("Over/Turns").offset, Vector2.ZERO,
			"a contagem fica centralizada sobre o tile")
	v.game_visual_presenter.update_overheads()
	check_eq(v.unit_nodes[victim.id].get_node("Over").global_position,
			v.unit_nodes[victim.id].global_position + Vector3(0, 0.35, 0),
			"a contagem fica junto ao personagem caído no centro do tile")
	var damage_visible := false
	for child in v.overlay_root.get_children():
		if child is Label3D and (child as Label3D).text == "-10":
			damage_visible = true
	check(damage_visible, "o número de dano aparece no impacto")
	check_eq(v.busy, 2, "golpe e queda rodam juntos")
	_cleanup()


func test_texto_de_dano_muda_de_tamanho_com_a_quantidade() -> void:
	if not needs_display():
		return
	var v := _make()
	v.game_visual_presenter._float_text(Vector3.ZERO, "-3", Color.RED, 34, 0.6)
	v.game_visual_presenter._float_text(Vector3.ZERO, "-30", Color.RED, 52, 0.6)
	var sizes: Array[int] = []
	for child in v.overlay_root.get_children():
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
	v.game_visual_presenter._play_unit_animation(attacker.id, "walk", 0.16)
	animation_player.advance(3.0)

	check_eq(v.busy, 0,
			"interromper o ataque para mover libera o bloqueio que impedia os turnos")
	check_eq(str(animation_player.current_animation), "walk",
			"a locomocao substitui a animacao de ataque")
	check_eq(attack_finished[0], 0,
			"o Godot nao emite animation_finished para um golpe interrompido pela locomocao")
	v.game_visual_presenter._on_unit_animation_finished("espadada_dentroparafora", attacker.id)
	check_eq(v.busy, 0, "o sinal atrasado nao libera o contador duas vezes")
	_cleanup()


func test_fila_visual_espera_a_etapa_atual_terminar() -> void:
	var v := _make()
	var events: Array[String] = []
	v.game_visual_presenter._collecting_visual_events = true
	v.game_visual_presenter.queue_action(func():
		events.append("movimento")
		v.busy += 1)
	v.game_visual_presenter.queue_action(func(): events.append("xp"))
	v.game_visual_presenter._collecting_visual_events = false
	v.game_visual_presenter.drain_queue()

	check_eq(events, ["movimento"], "o XP aguarda a etapa visual anterior")
	check_eq(v.busy, 1, "a etapa ativa mantem a fila bloqueada")
	v.game_visual_presenter.anim_done()
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
	attacker.character_id = v.roster.characters[0].id

	check(v._command({"t": "attack", "unit": attacker.id, "target": st.units[1].id}),
			"o ataque e aplicado")
	check(v.game_visual_presenter._attack_animations.has(attacker.id), "o golpe comeca primeiro")
	check_eq(v.game_visual_presenter._visual_queue.size(), 2, "dano e XP aguardam o golpe")
	check(v.last_rewards.is_empty(), "o XP ainda nao foi processado durante o golpe")

	v.game_visual_presenter._present_attack_impact(st.units[1], 8, st.units[1].max_hp)
	var labels: Array[String] = []
	for child in v.overlay_root.get_children():
		if child is Label3D:
			labels.append((child as Label3D).text)
	check(labels.any(func(text: String): return text.begins_with("-")),
			"o texto de dano aparece no impacto")
	check(v.last_rewards.is_empty(), "o XP continua aguardando o fim do golpe")

	var action := str(v.game_visual_presenter._attack_animations[attacker.id])
	v.game_visual_presenter._finish_attack_animation(attacker.id, action)
	check_eq(v.busy, 1, "o aviso de XP ocupa a fila depois do golpe")
	check(not v.last_rewards.is_empty(), "o XP só e processado depois do golpe")
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
	v.input_controller._unhandled_input(key)
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
	check_eq(v.game_visual_presenter.float_log, [["Esquiva", "dodge"]], "so o nome do resultado aparece")
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


func test_camera_trava_ajustes_manuais_durante_animacao() -> void:
	var v := _make()
	var st := _duel([[0, 0, 0]], Vector2i(0, 0), Vector2i(2, 0))
	v.setup_match(st)
	var initial_yaw: float = v.yaw
	var initial_dist: float = v.distance
	var initial_pos: Vector3 = v.camera_pivot.position

	v.busy = 1
	check(v.camera_rig.is_locked(), "camera trava enquanto ha animacao ativa")
	v.camera_rig.handle_rotation_input(25.0)
	v.camera_rig.handle_movement_input(Vector3(1, 0, 0))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	v.camera_rig._unhandled_input(wheel)

	check_eq(v.yaw, initial_yaw, "rotacao manual ignorada durante animacao")
	check_eq(v.distance, initial_dist, "zoom manual ignorado durante animacao")
	check_eq(v.camera_pivot.position, initial_pos, "movimento manual ignorado durante animacao")

	v.busy = 0
	check(not v.camera_rig.is_locked(), "camera destrava ao fim da animacao")
	v.camera_rig.handle_rotation_input(25.0)
	check_eq(v.yaw, initial_yaw + 25.0, "rotacao manual funciona quando livre")
	_cleanup()


func test_camera_escolhe_angulo_perpendicular_em_combate() -> void:
	var v := _make()
	var st := _duel([[0, 0, 0]], Vector2i(0, 0), Vector2i(2, 0))
	v.setup_match(st)
	v.yaw = 15.0
	var attacker: Unit = st.units[0]
	var target: Unit = st.units[1]

	v.camera_rig.focus_combat(attacker, target)
	check(v.camera_rig._cine_active, "enquadramento cinematografico ativado")
	var expected_mid: Vector3 = (v.unit_nodes[attacker.id].position + v.unit_nodes[target.id].position) * 0.5
	check_eq(v.camera_rig._cine_target_pos, expected_mid, "foco centralizado entre atacante e defensor")
	check(absf(v.camera_rig._cine_target_yaw) < 0.01, "angulo perpendicular escolhido para observador")
	_cleanup()


func test_camera_nao_muda_angulo_em_reacoes_entre_mesmos_personagens() -> void:
	var v := _make()
	var st := _duel([[0, 0, 0]], Vector2i(0, 0), Vector2i(2, 0))
	v.setup_match(st)
	v.yaw = 15.0
	var attacker: Unit = st.units[0]
	var target: Unit = st.units[1]

	v.camera_rig.focus_combat(attacker, target)
	var locked_yaw: float = v.camera_rig._cine_target_yaw
	var locked_pos: Vector3 = v.camera_rig._cine_target_pos

	v.yaw = 140.0
	v.camera_rig.on_reaction(target)
	v.camera_rig.focus_combat(target, attacker)
	check_eq(v.camera_rig._cine_target_yaw, locked_yaw, "reacao entre mesmos personagens mantem angulo")
	check_eq(v.camera_rig._cine_target_pos, locked_pos, "reacao entre mesmos personagens mantem foco")

	v.game_visual_presenter.drain_queue()
	check(not v.camera_rig._cine_active, "enquadramento libera quando a fila esvazia")
	_cleanup()

func test_menu_principal_e_opcoes_fecham_ao_iniciar_partida() -> void:
	var v := _make()
	v.hud.show_menu()
	check(is_instance_valid(v.hud.overlay_ctrl._main_menu_instance), "menu principal instanciado pela cena")
	v.hud.show_options({"display_mode": "Janela", "resolution": "1280x720", "can_resize": true, "volume": 1.0})
	check(not is_instance_valid(v.hud.overlay_ctrl._main_menu_instance), "menu principal removido ao abrir opcoes")
	check(is_instance_valid(v.hud.overlay_ctrl._options_menu_instance), "menu de opcoes instanciado pela cena")
	v.hud.hide_overlay()
	check(not is_instance_valid(v.hud.overlay_ctrl._options_menu_instance), "menu de opcoes removido ao ocultar overlay")
	v.hud.show_menu()
	v.hud.hide_overlay()
	check(not is_instance_valid(v.hud.overlay_ctrl._main_menu_instance), "menu principal removido ao iniciar partida")
	_cleanup()

func test_ataque_de_oportunidade_ocorre_no_ponto_de_saida_antes_de_andar() -> void:
	var m := BattleMap.new(6, 6)
	var a := TestUtil.unit(0, 0, Vector2i(1, 0), r)
	var b := TestUtil.unit(1, 1, Vector2i(1, 1), r)
	a.speed = 10
	b.speed = 9
	var us: Array[Unit] = [a, b]
	var st := MatchState.from_parts(r, m, us)
	MatchState.reactions_enabled = true
	st.roll_override = [1.0, 99.0, 99.0, 99.0]
	var events: Array[String] = []
	var hit_tile := [Vector2i(-1, -1)]
	st.reaction_event.connect(func(_u, kind, _txt): events.append("react:" + kind))
	st.attack_resolved.connect(func(_a, _t, tile, _dmg):
		events.append("attack")
		hit_tile[0] = tile
	)
	st.unit_moved.connect(func(_u, _path): events.append("move"))
	st.start()
	var res := st.move(0, Vector2i(3, 0))
	check(res.ok, "movimento valido com ataque de oportunidade")
	check(str(events.slice(0, 3)) == str(["react:oa", "attack", "move"]), "ataque de oportunidade ocorre antes de andar")
	check(hit_tile[0] == Vector2i(1, 0), "golpe de oportunidade acerta no ponto de saida adjacente")
	_cleanup()

func test_animacoes_de_reacao_e_impacto_nao_deslocam_o_quadril_no_plano() -> void:
	var library := load(CHARACTER_MODEL.ANIMATIONS_PATH) as AnimationLibrary
	check(library != null, "biblioteca de animacoes carregada")
	if library == null:
		return

	for action in ["defend", "dodge", "parry", "impact"]:
		check(library.has_animation(action), "biblioteca contem %s" % action)
		if not library.has_animation(action):
			continue
		var animation := library.get_animation(action)
		var root_track := -1
		for track in animation.get_track_count():
			if animation.track_get_type(track) == Animation.TYPE_POSITION_3D \
					and str(animation.track_get_path(track)).ends_with(":mixamorig_Hips"):
				root_track = track
				break
		if root_track < 0:
			continue
		var initial_position: Vector3 = animation.track_get_key_value(root_track, 0)
		for key in animation.track_get_key_count(root_track):
			var position: Vector3 = animation.track_get_key_value(root_track, key)
			check(is_equal_approx(position.x, initial_position.x)
					and is_equal_approx(position.z, initial_position.z),
					"%s nao desloca o quadril no plano horizontal" % action)


func test_reacoes_e_impacto_tocam_animacoes_correspondentes() -> void:
	if not needs_display():
		return
	var v := _make()
	v.mode = GameView.Mode.LOCAL
	var st := _duel([[0, 0, 0, 0]], Vector2i(1, 0), Vector2i(2, 0))
	v.setup_match(st)
	v.animate = true
	var defender: Unit = st.units[1]
	var body: Node3D = v.unit_nodes[defender.id].get_node("Body")
	var player := CHARACTER_MODEL.animation_player(body)

	v.game_visual_presenter._present_attack_impact(defender, 4, defender.max_hp)
	check_eq(str(player.current_animation), "impact", "golpe nao letal dispara animacao impact")
	v.game_visual_presenter._on_unit_animation_finished("impact", defender.id)
	check_eq(str(player.current_animation), "Idle", "personagem volta para Idle apos impact")

	var expected := {"block": "defend", "dodge": "dodge", "parry": "parry"}
	for kind in expected:
		var anim_name: String = expected[kind]
		v.game_visual_presenter._present_reaction_event(defender, kind, kind)
		v.game_visual_presenter._present_attack_resolved(st.unit_by_id(0), Vector2i.RIGHT, defender, 0, defender.max_hp)
		v.game_visual_presenter._trigger_defensive_reaction_animation(defender.id, kind)
		check_eq(str(player.current_animation), anim_name, "reacao %s dispara %s" % [kind, anim_name])
		v.game_visual_presenter._on_unit_animation_finished(anim_name, defender.id)
		check_eq(str(player.current_animation), "Idle", "personagem volta para Idle apos %s" % anim_name)
	_cleanup()