extends TestCase

var r := Rules.load_default()


func _mk(id: int, speed: int, ct := 0) -> Unit:
    var u := TestUtil.unit(id, id % 2, Vector2i(id, 0), r)
    u.speed = speed
    u.ct = ct
    return u


func test_mais_rapido_age_mais_vezes() -> void:
    var a := _mk(0, 10)
    var b := _mk(1, 5)
    var ts := TurnSystem.new(r, 1)
    var count := {0: 0, 1: 0}
    for i in 30:
        var u := ts.next_unit([a, b])
        count[u.id] += 1
        ts.end_turn(u, true, true)
    check(absi(count[0] - 2 * count[1]) <= 2, "proporcao 2:1 (obtido %s)" % str(count))


func test_custo_do_turno_mover_50_atacar_50() -> void:
    var ts := TurnSystem.new(r, 1)
    check_eq(ts.turn_cost(true, true), 100, "mover + atacar = barra toda")
    check_eq(ts.turn_cost(true, false), 50, "so mover = metade")
    check_eq(ts.turn_cost(false, true), 50, "atacar parado = metade")
    check_eq(ts.turn_cost(false, false), 50, "esperar sem fazer nada = custo minimo")


func test_atacar_parado_gera_mais_turnos() -> void:
    var a := _mk(0, 10, 100)
    var b := _mk(1, 10, 100)
    var ts := TurnSystem.new(r, 2)
    var acts_a := 0
    var acts_b := 0
    for i in 60:
        var u := ts.next_unit([a, b])
        if u == a:
            acts_a += 1
            ts.end_turn(u, false, true)
        else:
            acts_b += 1
            ts.end_turn(u, true, true)
    check(acts_a > acts_b * 1.5, "quem ataca parado age mais (%d x %d)" % [acts_a, acts_b])


func test_barra_comeca_cheia_e_a_ordem_inicial_e_pela_velocidade() -> void:
    var slow := _mk(0, 5, 100)
    var fast := _mk(1, 12, 100)
    var mid := _mk(2, 8, 100)
    var ts := TurnSystem.new(r, 3)
    var order: Array[int] = []
    for i in 3:
        var u := ts.next_unit([slow, fast, mid])
        order.append(u.id)
        ts.end_turn(u, true, true)
    check_eq(order, [1, 2, 0], "mais rapido primeiro")


func test_empate_de_velocidade_usa_dado_e_e_deterministico() -> void:
    var firsts := {}
    for seed in 40:
        var ts1 := TurnSystem.new(r, seed)
        var ts2 := TurnSystem.new(r, seed)
        var f1 := ts1.next_unit([_mk(0, 10, 100), _mk(1, 10, 100)]).id
        var f2 := ts2.next_unit([_mk(0, 10, 100), _mk(1, 10, 100)]).id
        check_eq(f1, f2, "mesma semente, mesmo resultado")
        firsts[f1] = true
    check_eq(firsts.size(), 2, "os dois podem sair na frente conforme o dado")


func test_previsao_bate_com_ordem_real_sem_empates() -> void:
    var us: Array = [_mk(0, 9, 100), _mk(1, 7, 100), _mk(2, 12, 100), _mk(3, 5, 100)]
    var ts := TurnSystem.new(r, 4)
    var preview := ts.preview(us, 15)
    var real: Array[int] = []
    for i in 15:
        var u := ts.next_unit(us)
        real.append(u.id)
        ts.end_turn(u, true, true)
    check_eq(preview, real, "previsao")


func test_previsao_nao_altera_estado() -> void:
    var us: Array = [_mk(0, 9), _mk(1, 7)]
    var ts := TurnSystem.new(r, 1)
    var before := ts.rng.state
    ts.preview(us, 10)
    check_eq(us[0].ct + us[1].ct, 0, "barras intactas")
    check_eq(ts.rng.state, before, "dado intacto")


func test_morto_nao_age() -> void:
    var a := _mk(0, 10)
    var b := _mk(1, 10)
    a.hp = 0
    var ts := TurnSystem.new(r, 1)
    for i in 5:
        var u := ts.next_unit([a, b])
        check_eq(u.id, 1, "so o vivo age")
        ts.end_turn(u, true, true)


func test_morrendo_continua_na_ordem_de_turnos() -> void:
    var dying := _mk(0, 10, 100)
    dying.hp = 0
    dying.dying_turns = 3
    var alive := _mk(1, 5, 0)
    var ts := TurnSystem.new(r, 1)
    check(ts.next_unit([dying, alive]) != null, "uma unidade morrendo ainda avança o relógio")
    check(dying.is_dying(), "unidade fica elegível para o próprio turno")


func test_previsao_considera_turno_do_morrendo() -> void:
    var dying := _mk(0, 10, 100)
    dying.hp = 0
    dying.dying_turns = 1
    var alive := _mk(1, 5, 100)
    var ts := TurnSystem.new(r, 1)

    check_eq(ts.preview([dying, alive], 2), [0, 1],
            "o turno reservado para o morrendo aparece na previsão")
    check_eq(dying.dying_turns, 1, "a previsão não altera a contagem real")


func test_velocidade_zero_nao_trava() -> void:
    check_eq(TurnSystem.new(r, 1).next_unit([_mk(0, 0)]).id, 0, "velocidade 0 vira 1")


func test_sem_vivos_devolve_null() -> void:
    var a := _mk(0, 10)
    a.hp = 0
    check(TurnSystem.new(r, 1).next_unit([a]) == null, "ninguem vivo")
