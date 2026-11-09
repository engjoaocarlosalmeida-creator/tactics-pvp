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
    check(decisive >= n * 0.6, "maioria termina com vencedor (%d/%d)" % [decisive, n])
