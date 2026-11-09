extends TestCase

var r := Rules.load_default()


func _on() -> void:
    MatchState.reactions_enabled = true


func _off() -> void:
    MatchState.reactions_enabled = false


## A (time 0) em (2,0); D (time 1) em (3,0), virado para o lado `face`. A age primeiro.
func _setup(face := Vector2i(-1, 0), rows := [[0, 0, 0, 0, 0, 0, 0, 0]], a_pos := Vector2i(2, 0), d_pos := Vector2i(3, 0)) -> MatchState:
    var map := TestUtil.map_from(rows)
    var a := TestUtil.unit(0, 0, a_pos, r)
    var d := TestUtil.unit(1, 1, d_pos, r)
    a.speed = 20
    d.speed = 5
    var us: Array[Unit] = [a, d]
    var m := MatchState.from_parts(r, map, us)
    d.facing = face
    m.start()
    return m


func test_lado_do_ataque_frente_lateral_costas() -> void:
    var m := _setup(Vector2i(-1, 0))
    check_eq(m.side_of_attack(m.units[0], m.units[1]), "front", "defensor olha para o atacante")
    m.units[1].facing = Vector2i(1, 0)
    check_eq(m.side_of_attack(m.units[0], m.units[1]), "back", "defensor de costas")
    m.units[1].facing = Vector2i(0, 1)
    check_eq(m.side_of_attack(m.units[0], m.units[1]), "side", "defensor de lado")


func test_direcao_dos_times_no_inicio() -> void:
    var m := MatchState.create(3, r)
    for u in m.units:
        check_eq(u.facing, Vector2i(0, 1) if u.team == 0 else Vector2i(0, -1), "cada time olha para o outro")


func test_chances_de_defesa_e_correcoes_de_lado() -> void:
    var m := _setup(Vector2i(-1, 0))
    var a := m.units[0]
    var d := m.units[1]
    a.speed = 10
    d.speed = 10
    a.atk = 12
    d.defense = 6
    check(absf(m.defense_chance("dodge", a, d) - 11.0) < 0.001, "esquiva: base 10 +10% de frente = 11")
    check(absf(m.defense_chance("parry", a, d) - 8.8) < 0.001, "parry: base 8 +10% = 8,8")
    check(absf(m.defense_chance("block", a, d) - 11.0) < 0.001, "bloqueio: base 10 +10% = 11")
    d.facing = Vector2i(0, 1)
    check(absf(m.defense_chance("dodge", a, d) - 9.0) < 0.001, "de lado: atacante ganha 10% (esquiva 9)")
    d.facing = Vector2i(1, 0)
    check(absf(m.defense_chance("dodge", a, d) - 9.0) < 0.001, "pelas costas: 10% (esquiva 9)")
    d.speed = 40
    check(absf(m.defense_chance("dodge", a, d) - 60.0 * 0.9) < 0.001, "limite maximo de 60% antes da correcao")


func test_esquiva_evita_o_dano() -> void:
    _on()
    var m := _setup()
    var seen := []
    m.reaction_event.connect(func(u, k, t): seen.append([k, t]))
    m.roll_override = [1.0]
    var res := m.attack(0, 1)
    check_eq(res.damage, 0, "esquivou")
    check_eq(m.units[1].hp, 40, "sem dano")
    check_eq(seen, [["dodge", "Esquiva"]], "aviso so com o nome do resultado")
    check_eq(m.units[0].xp_earned, 0, "golpe que nao acerta nao rende XP")
    _off()


func test_parry_gera_contra_ataque_automatico_que_nao_pode_ser_resistido() -> void:
    _on()
    var m := _setup()
    var seen := []
    m.reaction_event.connect(func(u, k, t): seen.append(k))
    m.roll_override = [99.0, 1.0, 1.0]
    var before := m.units[0].hp
    var res := m.attack(0, 1)
    check_eq(res.damage, 0, "dano defletido")
    check_eq(seen, ["parry", "counter"], "parry e contra-ataque")
    check(m.units[0].hp < before, "o atacante levou o contra-ataque")
    check(m.units[1].reacted, "gastou a reacao do turno")
    check(m.roll_override.is_empty(), "o contra-ataque nao gerou novos testes")
    _off()


func test_bloqueio_forte_derruba_o_defensor() -> void:
    _on()
    var m := _setup()
    m.units[0].atk = 40
    m.units[1].attrs["forca"] = 2
    var seen := []
    m.reaction_event.connect(func(u, k, t): seen.append(k))
    m.roll_override = [99.0, 99.0, 1.0, 1.0]
    var res := m.attack(0, 1)
    check_eq(res.damage, 0, "absorveu tudo")
    check(m.units[1].down, "mas caiu")
    check_eq(seen, ["block", "fall"], "bloqueio e queda")
    _off()


func test_bloqueio_fraco_nao_derruba() -> void:
    _on()
    var m := _setup()
    m.roll_override = [99.0, 99.0, 1.0]
    m.attack(0, 1)
    check(not m.units[1].down, "dano pequeno: nao cai")
    check(m.roll_override.is_empty(), "sem segundo teste")
    _off()


func test_esquiva_com_dano_enorme_da_movimento_extra_usado_ou_cancelado() -> void:
    _on()
    var m := _setup()
    m.units[0].atk = 60
    m.units[1].speed = 1
    m.roll_override = [1.0, 1.0]
    m.attack(0, 1)
    check(not m.pending_reaction.is_empty(), "movimento extra pendente")
    check_eq(m.apply_command({"t": "wait", "unit": 0}).error, "reaction_pending", "o jogo espera a resposta")
    check_eq(m.apply_command({"t": "react_move", "unit": 1, "x": 7, "y": 0}).error, "unreachable", "so ate o limite do movimento extra")
    check(m.apply_command({"t": "react_move", "unit": 1, "x": 5, "y": 0}).ok, "usou o movimento extra")
    check_eq(m.units[1].pos, Vector2i(5, 0), "moveu")
    check(m.pending_reaction.is_empty() and m.units[1].reacted, "reacao gasta")
    var m2 := _setup()
    m2.units[0].atk = 60
    m2.units[1].speed = 1
    m2.roll_override = [1.0, 1.0]
    m2.attack(0, 1)
    check(m2.apply_command({"t": "react_skip", "unit": 1}).ok, "cancelou")
    check(m2.pending_reaction.is_empty() and m2.units[1].pos == Vector2i(3, 0) and not m2.units[1].reacted, "nada mudou")
    _off()


func test_ataque_de_oportunidade_ao_sair_da_casa_vizinha() -> void:
    _on()
    var m := _setup(Vector2i(-1, 0), [[0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0]])
    var seen := []
    m.reaction_event.connect(func(u, k, t): seen.append([k, t]))
    m.roll_override = [1.0, 99.0, 99.0, 99.0]
    var hp := m.units[0].hp
    check(m.move(0, Vector2i(1, 0)).ok, "saiu da casa vizinha")
    check_eq(seen, [["oa", "Ataque de oportunidade"]], "so o nome da acao")
    check(m.units[0].hp < hp, "levou o golpe automatico")
    check(m.units[1].reacted, "gastou a reacao")
    _off()


func test_sem_oportunidade_se_continua_vizinho_ou_ja_reagiu() -> void:
    _on()
    var m := _setup(Vector2i(-1, 0), [[0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0]])
    m.roll_override = [1.0, 1.0, 1.0]
    var hp := m.units[0].hp
    m.move(0, Vector2i(3, 1))
    check_eq(m.units[0].hp, hp, "sem golpe")
    check_eq(m.roll_override.size(), 3, "nem rolou o teste")
    var n := _setup(Vector2i(-1, 0), [[0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0]])
    n.units[1].reacted = true
    n.roll_override = [1.0]
    n.move(0, Vector2i(1, 0))
    check_eq(n.roll_override.size(), 1, "quem ja reagiu nao tem outra reacao")
    _off()


func test_ataque_de_reacao_pode_ser_esquivado_mas_nao_gera_novas_reacoes() -> void:
    _on()
    var m := _setup(Vector2i(-1, 0), [[0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0]])
    m.units[1].atk = 60
    m.units[0].speed = 1
    var seen := []
    m.reaction_event.connect(func(u, k, t): seen.append(k))
    m.roll_override = [1.0, 1.0, 1.0]
    m.move(0, Vector2i(1, 0))
    check_eq(seen, ["oa", "dodge"], "esquivou do golpe de reacao")
    check(m.pending_reaction.is_empty(), "sem movimento extra para ataque de reacao")
    check_eq(m.roll_override.size(), 1, "o segundo teste nao foi rolado")
    _off()


func test_caido_nao_anda_levanta_gastando_o_movimento_e_nao_se_defende() -> void:
    _on()
    var m := _setup()
    m.units[0].down = true
    check_eq(m.move(0, Vector2i(1, 0)).error, "down", "caido nao anda")
    check(m.has_actions(m.units[0]), "tem a opcao de levantar")
    check(m.apply_command({"t": "stand", "unit": 0}).ok, "levantou")
    check(not m.units[0].down and m.units[0].moved, "gastou a acao de movimento")
    check_eq(m.units[0].move_left, 0, "sem mais movimento")
    var n := _setup()
    n.units[1].down = true
    n.roll_override = [1.0, 1.0, 1.0]
    check_eq(n.attack(0, 1).damage, 8, "caido nao esquiva, apara nem bloqueia")
    check_eq(n.roll_override.size(), 3, "sem testes")
    _off()


func test_direcao_apos_mover_e_atacar() -> void:
    var m := _setup(Vector2i(-1, 0), [[0, 0, 0, 0, 0, 0, 0, 0]], Vector2i(0, 0), Vector2i(7, 0))
    check_eq(m.units[0].facing, Vector2i(0, 1), "comeca virado para o lado do outro time")
    m.move(0, Vector2i(3, 0))
    check_eq(m.units[0].facing, Vector2i(1, 0), "depois de andar para a direita, olha para a direita")
    var n := _setup(Vector2i(-1, 0))
    n.attack(0, 1)
    check_eq(n.units[0].facing, Vector2i(1, 0), "ao atacar, olha para o alvo")


func test_escolher_o_lado_ao_terminar_o_turno() -> void:
    var m := _setup(Vector2i(-1, 0), [[0, 0, 0, 0, 0, 0, 0, 0]], Vector2i(0, 0), Vector2i(7, 0))
    m.manual_facing_teams = [0]
    m.units[0].move = 1
    var events := []
    m.facing_requested.connect(func(u): events.append(u.id))
    m.move(0, Vector2i(1, 0))
    check(m.awaiting_facing, "espera a escolha do lado")
    check_eq(m.active.id, 0, "o turno ainda nao acabou")
    check_eq(events, [0], "pediu a escolha")
    check_eq(m.apply_command({"t": "move", "unit": 0, "x": 2, "y": 0}).error, "awaiting_facing", "so vale escolher o lado")
    check(m.apply_command({"t": "face", "unit": 0, "dir": 3}).ok, "escolheu virar para cima")
    check_eq(m.units[0].facing, Vector2i(0, -1), "virado")
    check_eq(m.active.id, 1, "turno passou")
    check(not m.awaiting_facing, "escolha concluida")
    var n := _setup()
    n.manual_facing_teams = [0]
    n.apply_command({"t": "wait", "unit": 0})
    check(n.awaiting_facing, "Esperar tambem pergunta o lado")
    check_eq(n.apply_command({"t": "face", "unit": 1, "dir": 0}).error, "not_awaiting_facing", "so quem joga escolhe")


func test_estado_sincronizado_inclui_lado_queda_e_reacao() -> void:
    var a := _setup()
    var b := _setup()
    check_eq(a.state_hash(), b.state_hash(), "iguais no inicio")
    b.units[1].facing = Vector2i(0, 1)
    check(a.state_hash() != b.state_hash(), "lado diferente muda o hash")
    b.units[1].facing = a.units[1].facing
    b.units[1].down = true
    check(a.state_hash() != b.state_hash(), "queda muda o hash")


func test_partidas_completas_com_reacoes_ligadas() -> void:
    _on()
    var done := 0
    for seed in 6:
        var m := MatchState.create(seed, r)
        m.manual_facing_teams = [1]
        m.start()
        var rng := RandomNumberGenerator.new()
        rng.seed = seed
        var guard := 0
        while not m.is_over() and guard < 9000:
            guard += 1
            m.apply_command(SimpleBot.next_command(m, rng))
            var seen := {}
            for u in m.units:
                check(u.hp >= 0 and u.hp <= u.max_hp, "hp valido")
                if u.is_alive():
                    check(not seen.has(u.pos), "sem sobreposicao")
                    seen[u.pos] = true
        if m.is_over():
            done += 1
        check(m.pending_reaction.is_empty() or m.is_over(), "nenhuma reacao pendente no fim")
    check_eq(done, 6, "todas terminam")
    _off()
