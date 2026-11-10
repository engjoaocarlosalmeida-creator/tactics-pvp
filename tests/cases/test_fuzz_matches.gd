extends TestCase

var r := Rules.load_default()


func _invariants(s: MatchState, tag: String) -> void:
    var seen := {}
    for u in s.units:
        check(u.hp >= 0 and u.hp <= u.max_hp, "%s: hp valido" % tag)
        if u.is_alive():
            check(s.map.in_bounds(u.pos), "%s: dentro do mapa" % tag)
            check(not s.map.is_blocked(u.pos), "%s: fora de bloqueio" % tag)
            check(not seen.has(u.pos), "%s: sem sobreposicao" % tag)
            seen[u.pos] = true


func test_partidas_completas_com_bots() -> void:
    var finished := 0
    var decisive := 0
    var n := 8
    for seed in n:
        var s := MatchState.create(seed, r)
        s.start()
        var rng := RandomNumberGenerator.new()
        rng.seed = seed
        var guard := 0
        while not s.is_over() and guard < 8000:
            guard += 1
            SimpleBot.take_turn(s, rng)
            _invariants(s, "semente %d" % seed)
        if s.is_over():
            finished += 1
            if s.winner >= 0:
                decisive += 1
    check_eq(finished, n, "todas as partidas terminam")
    check_eq(decisive, n, "todas as partidas de bot terminam com vencedor (%d/%d)" % [decisive, n])


func test_bot_se_move_para_alcance_de_ataque_em_vez_de_parar_ao_lado() -> void:
    var map := TestUtil.map_from([
        [1, 1, 1, 1, 1],
        [1, 0, 3, 1, 1],
        [1, 1, 1, 1, 1],
    ])
    var attacker := TestUtil.unit(0, 0, Vector2i(1, 1), r)
    var defender := TestUtil.unit(1, 1, Vector2i(2, 1), r)
    var ally := TestUtil.unit(2, 0, Vector2i(2, 2), r)
    attacker.speed = 20
    defender.speed = 1
    ally.speed = 1
    var match_state := MatchState.from_parts(r, map, [attacker, defender, ally])
    match_state.start()
    var attacks := [0]
    match_state.attack_resolved.connect(func(_a: Unit, _t: Unit, _p: Vector2i, _d: int): attacks[0] += 1)

    var rng := RandomNumberGenerator.new()
    rng.seed = 1
    SimpleBot.take_turn(match_state, rng)

    check(attacks[0] > 0, "o bot chega a uma casa que permite atacar o inimigo")
    check(absi(attacker.pos.x - ally.pos.x) + absi(attacker.pos.y - ally.pos.y) > 1,
            "o bot escolhe um flanco livre em vez de se alinhar ao aliado")


func test_bot_avanca_depois_de_atacar_se_ainda_nao_moveu() -> void:
    var map := TestUtil.map_from([[0, 0, 0, 0, 0]])
    var attacker := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var defender := TestUtil.unit(1, 1, Vector2i(3, 0), r)
    attacker.attack_range = 3
    attacker.move = 1
    defender.defense = 100
    var match_state := MatchState.from_parts(r, map, [attacker, defender])
    match_state.start()
    var rng := RandomNumberGenerator.new()

    check(match_state.apply_command({"t": "attack", "unit": attacker.id,
            "target": defender.id}).ok, "a unidade realiza o ataque inicial")
    check(attacker.acted and not attacker.moved,
            "o cenario preserva movimento disponivel depois do ataque")

    var next_command := SimpleBot.next_command(match_state, rng)

    check_eq(next_command.get("t"), "move",
            "a unidade nao encerra o turno parada depois do primeiro ataque")
    check(int(next_command.get("x", attacker.pos.x)) > attacker.pos.x,
            "o movimento apos o ataque aproxima a unidade do inimigo")


func test_bot_reposiciona_apos_atacar_para_alcancar_outro_inimigo() -> void:
    var map := TestUtil.map_from([
        [0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0],
    ])
    var attacker := TestUtil.unit(0, 0, Vector2i(1, 1), r)
    var engaged_enemy := TestUtil.unit(1, 1, Vector2i(2, 1), r)
    var distant_enemy := TestUtil.unit(2, 1, Vector2i(5, 1), r)
    attacker.attack_range = 1
    attacker.move = 3
    attacker.move_left = 3
    engaged_enemy.defense = 100
    distant_enemy.defense = 100
    var match_state := MatchState.from_parts(r, map,
            [attacker, engaged_enemy, distant_enemy])
    match_state.start()
    var rng := RandomNumberGenerator.new()

    check(match_state.apply_command({"t": "attack", "unit": attacker.id,
            "target": engaged_enemy.id}).ok, "a unidade ataca o inimigo ao alcance")
    var before_distance := absi(attacker.pos.x - distant_enemy.pos.x) \
            + absi(attacker.pos.y - distant_enemy.pos.y)

    var command := SimpleBot.next_command(match_state, rng)

    check_eq(command.get("t"), "move",
            "apos atacar, a unidade nao fica parada enquanto outro inimigo esta distante")
    if command.get("t") == "move":
        var destination := Vector2i(int(command.x), int(command.y))
        var after_distance := absi(destination.x - distant_enemy.pos.x) \
                + absi(destination.y - distant_enemy.pos.y)
        check(after_distance < before_distance,
                "o movimento pos-ataque avanca em direcao ao inimigo ainda fora de alcance")


func test_inteligencia_amplia_a_previsao_de_ameacas() -> void:
    var map := TestUtil.map_from([[0, 0, 0, 0, 0, 0, 0, 0, 0, 0]])
    var low := TestUtil.unit(0, 0, Vector2i(3, 0), r)
    var enemy := TestUtil.unit(1, 1, Vector2i(8, 0), r)
    low.speed = 20
    enemy.speed = 1
    var match_state := MatchState.from_parts(r, map, [low, enemy])

    low.attrs["inteligencia"] = 5
    var immediate_only := SimpleBot._incoming_damage(match_state, low, Vector2i(4, 0),
            SimpleBot._lookahead_depth(match_state, low))
    low.attrs["inteligencia"] = 29
    var several_steps := SimpleBot._incoming_damage(match_state, low, Vector2i(4, 0),
            SimpleBot._lookahead_depth(match_state, low))

    check_eq(SimpleBot._lookahead_depth(match_state, low), 3,
            "inteligencia alta projeta multiplas etapas de movimento inimigo")
    check(several_steps > immediate_only,
            "a previsao longa identifica ameacas que ainda estao fora do alcance imediato")


func test_defesa_e_durabilidade_definem_quem_assume_a_linha_de_frente() -> void:
    var map := TestUtil.map_from([[0, 0, 0, 0, 0, 0, 0, 0, 0]])
    var tank := TestUtil.unit(0, 0, Vector2i(1, 0), r)
    var fragile := TestUtil.unit(2, 0, Vector2i(1, 0), r)
    var tank_enemy := TestUtil.unit(1, 1, Vector2i(5, 0), r)
    var fragile_enemy := TestUtil.unit(3, 1, Vector2i(5, 0), r)
    tank.defense = 20
    tank.speed = 20
    tank_enemy.atk = 20
    fragile.defense = 0
    fragile.max_hp = 20
    fragile.hp = 20
    fragile.speed = 20
    fragile_enemy.atk = 20
    fragile_enemy.speed = 1
    tank_enemy.speed = 1
    var tank_match := MatchState.from_parts(r, map, [tank, tank_enemy])
    tank_match.start()
    var fragile_match := MatchState.from_parts(r, map, [fragile, fragile_enemy])
    fragile_match.start()
    var rng := RandomNumberGenerator.new()
    rng.seed = 1

    var tank_destination := SimpleBot._best_destination(tank_match, tank, rng)
    var fragile_destination := SimpleBot._best_destination(fragile_match, fragile, rng)

    check(absi(tank_destination.x - tank_enemy.pos.x)
            < absi(fragile_destination.x - fragile_enemy.pos.x),
            "a unidade duravel assume posicao mais avancada que a fragil")


func test_bot_prioriza_alvo_que_pode_eliminar() -> void:
    var map := TestUtil.map_from([[0, 0, 0]])
    var attacker := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var durable_target := TestUtil.unit(1, 1, Vector2i(1, 0), r)
    var vulnerable_target := TestUtil.unit(2, 1, Vector2i(2, 0), r)
    attacker.attack_range = 2
    durable_target.hp = 30
    vulnerable_target.hp = 1
    var match_state := MatchState.from_parts(r, map,
            [attacker, durable_target, vulnerable_target])

    var chosen := SimpleBot._choose_target(match_state, attacker,
            [durable_target, vulnerable_target])

    check_eq(chosen.id, vulnerable_target.id,
            "o bot considera a vantagem tática de eliminar um inimigo")


func test_eliminar_ultimo_inimigo_tem_valor_de_vitoria() -> void:
    var map := TestUtil.map_from([[0, 0, 0]])
    var attacker := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var final_enemy := TestUtil.unit(1, 1, Vector2i(1, 0), r)
    var match_state := MatchState.from_parts(r, map, [attacker, final_enemy])

    check(SimpleBot._elimination_value(match_state, final_enemy) >= 1000.0,
            "eliminar o ultimo inimigo representa vencer a partida")


func test_bot_avanca_se_a_proxima_posicao_for_arriscada_mas_sobrevivivel() -> void:
    var map := TestUtil.map_from([[0, 0, 0, 0]])
    var attacker := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var defender := TestUtil.unit(1, 1, Vector2i(2, 0), r)
    attacker.max_hp = 100
    attacker.hp = 100
    attacker.defense = 0
    attacker.move = 1
    attacker.move_left = 1
    defender.atk = 50
    defender.speed = 1
    var match_state := MatchState.from_parts(r, map, [attacker, defender])
    match_state.start()
    var rng := RandomNumberGenerator.new()

    var current_score := SimpleBot._position_score(match_state, attacker, attacker.pos, 0)
    var exposed_score := SimpleBot._position_score(match_state, attacker, Vector2i(1, 0), 0)
    var destination := SimpleBot._best_destination(match_state, attacker, rng)

    check(exposed_score > current_score,
            "o custo de risco torna a posição de avanço pior na pontuação normal")
    check_eq(destination, Vector2i(1, 0),
            "o bot rompe o impasse avançando quando consegue sobreviver à ameaça")


func test_bot_se_sacrifica_quando_o_avanco_e_necessario_para_lutar() -> void:
    var map := TestUtil.map_from([[0, 0, 0, 0]])
    var attacker := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var defender := TestUtil.unit(1, 1, Vector2i(2, 0), r)
    attacker.max_hp = 20
    attacker.hp = 20
    attacker.move = 1
    attacker.move_left = 1
    defender.atk = 1000
    defender.speed = 1
    var match_state := MatchState.from_parts(r, map, [attacker, defender])
    match_state.start()
    var rng := RandomNumberGenerator.new()

    var incoming_damage := SimpleBot._incoming_damage(
            match_state, attacker, Vector2i(1, 0), SimpleBot._lookahead_depth(match_state, attacker))
    var destination := SimpleBot._best_destination(match_state, attacker, rng)
    var command := SimpleBot.next_command(match_state, rng)

    check(incoming_damage >= attacker.hp,
            "o avanço escolhido é previsto como fatal")
    check_eq(destination, Vector2i(1, 0),
            "o bot avança mesmo com risco fatal para alcançar o inimigo")
    check_eq(command.get("t"), "move",
            "o bot nao deixa a autopreservacao cancelar a decisao de avancar")


func test_bravura_alta_reduz_a_aversao_a_risco() -> void:
    var map := TestUtil.map_from([[0, 0, 0, 0]])
    var unit := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var enemy := TestUtil.unit(1, 1, Vector2i(2, 0), r)
    unit.max_hp = 100
    unit.hp = 100
    enemy.atk = 30
    var match_state := MatchState.from_parts(r, map, [unit, enemy])

    unit.bravura = 20
    var cautious_delta := SimpleBot._position_score(
            match_state, unit, Vector2i(1, 0), 0) \
            - SimpleBot._position_score(match_state, unit, unit.pos, 0)
    unit.bravura = 90
    var brave_delta := SimpleBot._position_score(
            match_state, unit, Vector2i(1, 0), 0) \
            - SimpleBot._position_score(match_state, unit, unit.pos, 0)

    check(brave_delta < cautious_delta,
            "bravura alta torna o avanco arriscado relativamente mais aceitavel")


func test_fe_alta_prioriza_posicao_de_apoio_a_aliado_ameacado() -> void:
    var map := TestUtil.map_from([
        [0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0],
    ])
    var unit := TestUtil.unit(0, 0, Vector2i(0, 1), r)
    var ally := TestUtil.unit(1, 0, Vector2i(3, 1), r)
    var enemy := TestUtil.unit(2, 1, Vector2i(4, 1), r)
    unit.max_hp = 100
    unit.hp = 100
    var match_state := MatchState.from_parts(r, map, [unit, ally, enemy])
    var support_position := Vector2i(2, 1)
    var distant_position := Vector2i(2, 0)

    unit.fe = 10
    var low_faith_delta := SimpleBot._position_score(
            match_state, unit, support_position, 0) \
            - SimpleBot._position_score(match_state, unit, distant_position, 0)
    unit.fe = 100
    var high_faith_delta := SimpleBot._position_score(
            match_state, unit, support_position, 0) \
            - SimpleBot._position_score(match_state, unit, distant_position, 0)

    check(SimpleBot._ally_support_value(match_state, unit, support_position) > 0.0,
            "uma posicao que protege um aliado ameacado recebe valor de suporte")
    check(high_faith_delta < low_faith_delta,
            "fe alta aumenta a prioridade de apoiar o aliado sob ataque")


func test_modificador_de_classe_altera_a_iniciativa_tatica() -> void:
    var map := TestUtil.map_from([[0, 0, 0, 0, 0]])
    var unit := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var enemy := TestUtil.unit(1, 1, Vector2i(4, 0), r)
    var match_state := MatchState.from_parts(r, map, [unit, enemy])
    var front_position := Vector2i(1, 0)

    unit.ai_initiative = 0.8
    var frontline_delta := SimpleBot._position_score(
            match_state, unit, front_position, 0) \
            - SimpleBot._position_score(match_state, unit, unit.pos, 0)
    unit.ai_initiative = -0.55
    var ranged_delta := SimpleBot._position_score(
            match_state, unit, front_position, 0) \
            - SimpleBot._position_score(match_state, unit, unit.pos, 0)

    check(frontline_delta < ranged_delta,
            "classes de linha de frente valorizam mais a iniciativa que classes cautelosas")


func test_classes_definem_modificador_de_iniciativa_da_ia() -> void:
    var catalog := JobCatalog.load_default()
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var knight_character := Character.create_new(0, "Cavaleiro", "cavaleiro", r, catalog, rng)
    var archer_character := Character.create_new(1, "Arqueiro", "arqueiro", r, catalog, rng)
    var knight := Unit.from_character(0, 0, knight_character, r, catalog)
    var archer := Unit.from_character(1, 0, archer_character, r, catalog)

    check(knight.ai_initiative > 0.0,
            "a classe cavaleiro recebe iniciativa de linha de frente")
    check(archer.ai_initiative < 0.0,
            "a classe arqueiro recebe iniciativa cautelosa")
