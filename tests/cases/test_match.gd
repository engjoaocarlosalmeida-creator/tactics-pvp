extends TestCase

var r := Rules.load_default()


## Partida 6x1 plana: u0 (time 0, rapido) em x0, u1 (time 1) em x5.
func _duel(rows: Array = [[0, 0, 0, 0, 0, 0]], p0 := Vector2i(0, 0), p1 := Vector2i(5, 0), move0 := 4) -> MatchState:
    var m := TestUtil.map_from(rows)
    var a := TestUtil.unit(0, 0, p0, r)
    a.move = move0
    var b := TestUtil.unit(1, 1, p1, r)
    a.speed = 10
    b.speed = 9
    var us: Array[Unit] = [a, b]
    var s := MatchState.from_parts(r, m, us)
    s.start()
    return s


func test_primeiro_turno_e_do_mais_rapido() -> void:
    var s := _duel()
    check_eq(s.active.id, 0, "ativo")
    check_eq(s.turn_serial, 1, "turnos iniciados")


func test_mover_valida_alcance_e_turno() -> void:
    var s := _duel()
    check_eq(s.move(1, Vector2i(4, 0)).error, "not_active", "outro jogador")
    check_eq(s.move(0, Vector2i(5, 0)).error, "unreachable", "longe demais")
    check_eq(s.move(0, Vector2i(0, 0)).error, "unreachable", "mesma casa")


func test_mover_tudo_sem_alvo_encerra_turno_sozinho() -> void:
    var s := _duel([[0, 0, 0, 0, 0, 0]], Vector2i(0, 0), Vector2i(5, 0), 2)
    check(s.move(0, Vector2i(2, 0)).ok, "moveu")
    check_eq(s.active.id, 1, "gastou todo o movimento e nao ha ninguem ao alcance: passa sozinho")


func test_movimento_pode_ser_fracionado() -> void:
    var s := _duel()
    check(s.move(0, Vector2i(1, 0)).ok, "primeiro passo")
    check_eq(s.active.id, 0, "ainda e a vez dele")
    check_eq(s.units[0].move_left, 3, "sobram 3 de movimento")
    check_eq(s.move(0, Vector2i(5, 0)).error, "unreachable", "so alcanca o que o movimento restante permite")
    check(s.move(0, Vector2i(3, 0)).ok, "segundo trecho (2 casas)")
    check(s.move(0, Vector2i(4, 0)).ok, "ultima casa")
    check_eq(s.active.id, 0, "adjacente ao inimigo: ainda pode atacar")
    check(s.attack(0, 1).ok, "ataca")
    check_eq(s.active.id, 1, "movimento gasto + ataque feito: passa sozinho")


func test_custo_da_barra_depois_do_turno() -> void:
    var s := _duel()
    s.move(0, Vector2i(1, 0))
    s.end_turn()
    check_eq(s.units[0].ct, 50, "so moveu: gastou metade (100 - 50)")
    var t := _duel([[0, 0, 0]], Vector2i(1, 0), Vector2i(2, 0))
    t.attack(0, 1)
    t.end_turn()
    check_eq(t.units[0].ct, 50, "so atacou: gastou metade")


func test_atacar_aliado_e_casa_vazia() -> void:
    var map := TestUtil.map_from([[0, 0, 0, 0]])
    var a := TestUtil.unit(0, 0, Vector2i(1, 0), r)
    var ally := TestUtil.unit(1, 0, Vector2i(2, 0), r)
    var foe := TestUtil.unit(2, 1, Vector2i(3, 0), r)
    a.speed = 20
    var us: Array[Unit] = [a, ally, foe]
    var events := []
    var s := MatchState.from_parts(r, map, us)
    s.xp_gained.connect(func(u, j, c, f): events.append([j, c]))
    s.start()
    check(s.attack(0, 1).ok, "ataque a aliado e permitido")
    check_eq(ally.hp, 32, "aliado levou dano")
    check_eq(events.size(), 0, "bater em aliado nao da XP")
    check_eq(s.attack(0, 1).error, "already_acted", "uma acao de ataque por turno")
    var t := _duel([[0, 0, 0, 0]], Vector2i(1, 0), Vector2i(3, 0))
    var res := t.apply_command({"t": "attack", "unit": 0, "x": 0, "y": 0})
    check(res.ok and res.damage == 0, "ataque a casa vazia gasta a acao sem dano")
    var u := _duel([[0, 0, 0, 0]], Vector2i(1, 0), Vector2i(3, 0))
    check_eq(u.apply_command({"t": "attack", "unit": 0, "x": 3, "y": 0}).error, "out_of_range", "casa fora do alcance")


func test_casas_ao_alcance_do_ataque() -> void:
    var s := _duel([[0, 0, 0, 0, 0]], Vector2i(2, 0), Vector2i(4, 0))
    var tiles := s.attack_tiles(s.units[0])
    check_eq(tiles.size(), 2, "alcance 1 em linha: duas casas")
    check(tiles.has(Vector2i(1, 0)) and tiles.has(Vector2i(3, 0)), "vizinhas")


func test_mover_ate_inimigo_permite_atacar_e_depois_encerra() -> void:
    var s := _duel([[0, 0, 0, 0, 0, 0]], Vector2i(0, 0), Vector2i(5, 0))
    s.units[0].move = 5
    check(s.move(0, Vector2i(4, 0)).ok, "move ate adjacente")
    check_eq(s.active.id, 0, "continua: ha alvo")
    var res := s.attack(0, 1)
    check(res.ok, "atacou")
    check_eq(res.damage, 8, "12 - 4")
    check_eq(s.units[1].hp, 32, "hp do alvo")
    check_eq(s.active.id, 1, "acoes esgotadas: turno passa")


func test_atacar_antes_de_mover_ainda_pode_mover() -> void:
    var s := _duel([[0, 0, 0, 0, 0, 0]], Vector2i(2, 0), Vector2i(3, 0))
    check(s.attack(0, 1).ok, "ataque")
    check_eq(s.active.id, 0, "ainda pode mover")
    check_eq(s.attack(0, 1).error, "already_acted", "nao ataca duas vezes")
    check(s.move(0, Vector2i(1, 0)).ok, "move depois de atacar")
    check_eq(s.active.id, 0, "sobra movimento: a vez continua ate esperar ou gastar tudo")
    s.end_turn()
    check_eq(s.active.id, 1, "esperar passa a vez")


func test_alvo_invalido_e_fora_de_alcance() -> void:
    var s := _duel()
    check_eq(s.attack(0, 1).error, "out_of_range", "longe")
    check_eq(s.attack(0, 0).error, "invalid_target", "a si mesmo")
    check_eq(s.attack(0, 99).error, "invalid_target", "id inexistente")


func test_bonus_de_altura() -> void:
    var s := _duel([[2, 0]], Vector2i(0, 0), Vector2i(1, 0))
    check_eq(s.attack(0, 1).damage, 10, "8 + 2 de vantagem de altura")


func test_altura_demais_impede_ataque() -> void:
    # u0 em cima (altura 4), inimigo embaixo; (0,1) existe para u0 ter para onde ir
    var s := _duel([[4, 0], [4, 4]], Vector2i(0, 0), Vector2i(1, 0))
    check_eq(s.attack(0, 1).error, "out_of_range", "diferenca de 4 > tolerancia 2")


func test_vitoria_e_fim_de_partida() -> void:
    var s := _duel([[0, 0, 0], [0, 0, 0], [0, 0, 0]],
            Vector2i(1, 1), Vector2i(2, 1))
    s.units[1].hp = 1
    var seen := []
    var dying_turns_seen: Array[int] = []
    var initial_dying_turns := [-1]
    s.match_over.connect(func(w): seen.append(w))
    s.unit_died.connect(func(unit):
        if unit.id == 1:
            initial_dying_turns[0] = unit.dying_turns)
    s.unit_dying_turn.connect(func(unit, turns_left):
        if unit.id == 1:
            dying_turns_seen.append(turns_left))
    check(s.attack(0, 1).ok, "golpe final")
    check(not s.is_over(), "o personagem fica morrendo antes da vitoria")
    check(s.units[1].is_dying(), "HP zero inicia o estado morrendo")
    check(initial_dying_turns[0] >= 2 and initial_dying_turns[0] <= 7,
            "a duracao fica entre 2 e 7 turnos")
    check_eq(s.units[1].hp, 0, "HP permanece em zero")

    var guard := 0
    while not s.is_over() and guard < 100:
        guard += 1
        if s.active.is_alive():
            s.end_turn()
    check(s.is_over(), "a partida termina quando o morrendo expira")
    check_eq(s.winner, 0, "time 0 venceu")
    check_eq(seen, [0], "sinal emitido uma vez")
    check_eq(dying_turns_seen.size(), initial_dying_turns[0],
            "a contagem só avança nos turnos que seriam do caído")
    check_eq(dying_turns_seen.back(), 0, "o estado termina quando o contador chega a zero")
    check_eq(s.attack(0, 1).error, "match_over", "nada apos o fim")
    check_eq(s.move(0, Vector2i(0, 0)).error, "match_over", "nada apos o fim")


func test_duracao_morrendo_considera_fe_bravura_e_dano() -> void:
    var victim_high := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var victim_low := TestUtil.unit(1, 0, Vector2i(0, 0), r)
    var attacker_high := TestUtil.unit(2, 1, Vector2i(1, 0), r)
    var attacker_low := TestUtil.unit(3, 1, Vector2i(1, 0), r)
    victim_high.fe = 100
    victim_high.bravura = 100
    victim_low.fe = 0
    victim_low.bravura = 0
    victim_high.max_hp = 100
    victim_low.max_hp = 100
    attacker_high.fe = 100
    attacker_high.bravura = 100
    attacker_low.fe = 0
    attacker_low.bravura = 0
    var first := _duel()
    var second := _duel()
    first.combat_rng.seed = 123
    second.combat_rng.seed = 123
    var resilient_duration := first._dying_duration(victim_high, attacker_low, 10, "attack", 100)
    var fragile_duration := second._dying_duration(victim_low, attacker_high, 10, "attack", 100)
    check(resilient_duration > fragile_duration,
            "fé e bravura altas do caído aumentam a chance de resistir")

    first.combat_rng.seed = 456
    second.combat_rng.seed = 456
    var normal_hit := first._dying_duration(victim_high, attacker_low, 59, "attack", 60)
    var heavy_hit := second._dying_duration(victim_high, attacker_low, 60, "attack", 60)
    check(normal_hit >= heavy_hit, "um golpe de 60% da vida aplica penalidade")

    first.combat_rng.seed = 789
    second.combat_rng.seed = 789
    var heavy_overkill := first._dying_duration(victim_high, attacker_low, 60, "attack", 20)
    var extreme_overkill := second._dying_duration(victim_high, attacker_low, 80, "attack", 20)
    check(heavy_overkill > extreme_overkill, "dano muito acima da vida restante recebe penalidade extra")


func test_casa_de_morrendo_pode_ser_atravessada_mas_nao_ocupada() -> void:
    var map := TestUtil.map_from([[0, 0, 0]])
    var mover := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var corpse := TestUtil.unit(1, 1, Vector2i(1, 0), r)
    corpse.hp = 0
    corpse.dying_turns = 3
    var state := MatchState.from_parts(r, map, [mover, corpse])
    var reach := state.reachable_for(mover)
    check(reach.has(Vector2i(1, 0)), "o caminho atravessa a casa reservada")
    check(not reach[Vector2i(1, 0)].can_stop, "não pode terminar na casa reservada")
    check(reach.has(Vector2i(2, 0)) and reach[Vector2i(2, 0)].can_stop,
            "pode atravessar e ocupar a casa seguinte")
    check(not state.occupied().has(corpse.pos), "morrendo não bloqueia a passagem")
    check(state.reserved_tiles().has(corpse.pos), "morrendo ainda reserva o local")
    corpse.dying_turns = 0
    check(state.reserved_tiles().has(corpse.pos), "a caveira continua reservando o local")


func test_impasse_vira_empate_sem_travar() -> void:
    var s := _duel([[0, "X", 0, "X", 0]], Vector2i(0, 0), Vector2i(4, 0))
    check(s.is_over(), "terminou")
    check_eq(s.winner, MatchState.DRAW, "empate")


func test_esperar_passa_a_vez() -> void:
    var s := _duel()
    s.end_turn()
    check_eq(s.active.id, 1, "vez do outro")


func test_dano_de_queda_no_movimento() -> void:
    var s := _duel([[6, 0, 0, 0, 0, 0]], Vector2i(0, 0), Vector2i(5, 0))
    var res := s.move(0, Vector2i(1, 0))
    check_eq(res.damage, 12, "dano de queda informado")
    check_eq(s.units[0].hp, 28, "hp reduzido")


func test_partida_gerada_tem_times_e_posicoes_unicas() -> void:
    var s := MatchState.create(7, r)
    s.start()
    var per := r.get_int("match", "units_per_team")
    check_eq(s.units.size(), per * 2, "unidades")
    var seen := {}
    for u in s.units:
        check(not seen.has(u.pos), "posicao unica")
        seen[u.pos] = true
        check(not s.map.is_blocked(u.pos), "fora de bloqueios")
    check(s.active != null, "alguem ativo")
