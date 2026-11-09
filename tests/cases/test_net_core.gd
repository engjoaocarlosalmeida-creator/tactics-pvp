extends TestCase

var r := Rules.load_default()


func _duel() -> MatchState:
    var map := TestUtil.map_from([[0, 0, 0, 0, 0, 0]])
    var a := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var b := TestUtil.unit(1, 1, Vector2i(5, 0), r)
    a.speed = 10
    b.speed = 9
    var us: Array[Unit] = [a, b]
    var s := MatchState.from_parts(r, map, us)
    s.start()
    return s


func test_comandos_validos_e_invalidos() -> void:
    var s := _duel()
    check_eq(s.apply_command({}).error, "bad_command", "vazio")
    check_eq(s.apply_command({"t": "voar", "unit": 0}).error, "bad_command", "tipo desconhecido")
    check_eq(s.apply_command({"t": "move", "unit": 0}).error, "bad_command", "sem destino")
    check_eq(s.apply_command({"t": "move", "unit": 1, "x": 4, "y": 0}).error, "not_active", "unidade errada")
    check_eq(s.apply_command({"t": "move", "unit": 0, "x": 5, "y": 0}).error, "unreachable", "longe")
    check_eq(s.apply_command({"t": "attack", "unit": 0, "target": 1}).error, "out_of_range", "alcance")
    check_eq(s.apply_command({"t": "attack", "unit": 0, "x": 4, "y": 0}).error, "out_of_range", "casa longe")
    check(s.apply_command({"t": "move", "unit": 0, "x": 2, "y": 0}).ok, "mover")
    check_eq(s.active.id, 0, "movimento fracionado: a vez continua")
    check_eq(s.apply_command({"t": "wait", "unit": 1}).error, "not_active", "wait fora da vez")
    check(s.apply_command({"t": "wait", "unit": 0}).ok, "esperar passa o turno")
    check_eq(s.active.id, 1, "vez do outro")


func test_mesmos_comandos_geram_o_mesmo_estado() -> void:
    for seed in 5:
        var a := MatchState.create(seed, r)
        var b := MatchState.create(seed, r)
        a.start()
        b.start()
        check_eq(a.state_hash(), b.state_hash(), "inicio igual")
        var rng := RandomNumberGenerator.new()
        rng.seed = seed
        var guard := 0
        while not a.is_over() and guard < 6000:
            guard += 1
            var cmd := SimpleBot.next_command(a, rng)
            var ra := a.apply_command(cmd)
            var rb := b.apply_command(cmd)
            check_eq(ra.ok, rb.ok, "mesmo resultado")
            check_eq(a.state_hash(), b.state_hash(), "estados iguais (semente %d)" % seed)
        check(a.is_over() and b.is_over() and a.winner == b.winner, "mesmo fim")


func test_divergencia_muda_o_hash() -> void:
    var a := _duel()
    var b := _duel()
    a.apply_command({"t": "move", "unit": 0, "x": 2, "y": 0})
    b.apply_command({"t": "move", "unit": 0, "x": 3, "y": 0})
    check(a.state_hash() != b.state_hash(), "hash detecta posicoes diferentes")


func test_bot_um_comando_equivale_ao_turno_inteiro() -> void:
    var a := MatchState.create(4, r)
    var b := MatchState.create(4, r)
    a.start()
    b.start()
    var ra := RandomNumberGenerator.new()
    var rb := RandomNumberGenerator.new()
    ra.seed = 9
    rb.seed = 9
    for i in 30:
        if a.is_over():
            break
        SimpleBot.take_turn(a, ra)
        var serial := b.turn_serial
        var guard := 0
        while not b.is_over() and b.turn_serial == serial and guard < 8:
            guard += 1
            b.apply_command(SimpleBot.next_command(b, rb))
        check_eq(a.state_hash(), b.state_hash(), "turno %d" % i)
