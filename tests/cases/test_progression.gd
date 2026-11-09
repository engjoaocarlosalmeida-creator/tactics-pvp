extends TestCase

var r := Rules.load_default()
var cat := JobCatalog.load_default()


func _team(first_id: int, jobs: Array, seed: int) -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var out := []
    for i in jobs.size():
        out.append(Character.create_new(first_id + i, "P%d" % (first_id + i), jobs[i], r, cat, rng))
    return out


func _duel(l0: int, l1: int) -> MatchState:
    var map := TestUtil.map_from([[0, 0]])
    var a := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var b := TestUtil.unit(1, 1, Vector2i(1, 0), r)
    a.speed = 20
    a.char_level = l0
    a.job_level = l0
    b.char_level = l1
    b.job_level = l1
    var us: Array[Unit] = [a, b]
    var m := MatchState.from_parts(r, map, us)
    m.start()
    return m


func test_xp_por_acao_e_modificador_de_nivel() -> void:
    check_eq(Progression.action_xp(r, false), 5, "ataque")
    check_eq(Progression.action_xp(r, true), 15, "abate")
    check_eq(Progression.xp_modifier(r, 10, 5), 0.5, "nivel 10 contra nivel 5: metade")
    check_eq(Progression.xp_modifier(r, 10, 10), 1.0, "mesmo nivel")
    check_eq(Progression.xp_modifier(r, 5, 10), 1.2, "teto de +20%")
    check_eq(int(floor(15 * Progression.xp_modifier(r, 10, 5))), 7, "arredonda para baixo")


func test_setas_do_modificador() -> void:
    check_eq(Progression.modifier_flag(r, 0.5), -1, "seta vermelha")
    check_eq(Progression.modifier_flag(r, 0.96), 0, "ate 5% para menos")
    check_eq(Progression.modifier_flag(r, 1.05), 0, "ate 5% para mais")
    check_eq(Progression.modifier_flag(r, 1.06), 1, "seta verde")


func test_mover_nao_da_xp() -> void:
    var events := []
    var map := TestUtil.map_from([[0, 0, 0, 0, 0, 0]])
    var a := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var b := TestUtil.unit(1, 1, Vector2i(5, 0), r)
    a.speed = 10
    var us: Array[Unit] = [a, b]
    var m := MatchState.from_parts(r, map, us)
    m.xp_gained.connect(func(u, j, c, f): events.append(1))
    m.start()
    check(m.move(0, Vector2i(2, 0)).ok, "moveu")
    check_eq(events.size(), 0, "movimento nao gera XP")


func test_ataque_gera_xp_de_classe_e_de_personagem_modificado() -> void:
    var events := []
    var m := _duel(1, 1)
    m.xp_gained.connect(func(u, j, c, f): events.append([j, c, f]))
    m.attack(0, 1)
    check_eq(events, [[5, 5, 0]], "5 e 5, sem seta")
    events.clear()
    var strong := _duel(10, 5)
    strong.xp_gained.connect(func(u, j, c, f): events.append([j, c, f]))
    strong.attack(0, 1)
    check_eq(events, [[2, 2, -1]], "alvo mais fraco: 5 * 0,5 = 2, seta vermelha")
    events.clear()
    var weak := _duel(5, 10)
    weak.xp_gained.connect(func(u, j, c, f): events.append([j, c, f]))
    weak.attack(0, 1)
    check_eq(events, [[6, 6, 1]], "alvo mais forte: 5 * 1,2 = 6, seta verde")


func test_abate_da_bonus() -> void:
    var m := _duel(1, 1)
    var events := []
    m.xp_gained.connect(func(u, j, c, f): events.append([j, c]))
    m.units[1].hp = 1
    m.attack(0, 1)
    check_eq(events, [[15, 15]], "abate = 5 + 10")
    check_eq(m.units[0].kills, 1, "abate contado")


func test_aplicar_xp_ao_personagem() -> void:
    var c: Character = _team(0, ["escudeiro"], 1)[0]
    var u := Unit.from_character(0, 0, c, r, cat)
    var res := Progression.apply_xp(r, cat, {0: c}, u, 30, 20)
    check_eq([res.levels_gained, res.char_levels_gained, c.attr_points], [1, 1, 2], "niveis e pontos")
    check_eq(Progression.apply_xp(r, cat, {0: c}, TestUtil.unit(9, 0, Vector2i.ZERO, r), 5), {}, "unidade avulsa nao recebe")


func test_partida_completa_xp_so_de_ataques() -> void:
    var t0 := _team(0, ["escudeiro", "aprendiz", "lutador", "escudeiro"], 11)
    var t1 := _team(10, ["lutador", "aprendiz", "escudeiro", "lutador"], 12)
    var chars := {}
    for c in t0 + t1:
        chars[c.id] = c
    var m := MatchState.create_from_characters(3, r, cat, t0, t1)
    var total := [0, 0]
    m.xp_gained.connect(func(u, j, c, _f):
        total[0] += j
        total[1] += c
        Progression.apply_xp(r, cat, chars, u, j, c))
    m.start()
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    var guard := 0
    while not m.is_over() and guard < 6000:
        guard += 1
        SimpleBot.take_turn(m, rng)
    check(m.is_over(), "terminou")
    var je := 0
    var ce := 0
    for u in m.units:
        je += u.job_xp_earned
        ce += u.xp_earned
    check_eq(total, [je, ce], "XP dos eventos = acumulado")
    var in_chars := 0
    for c in chars.values():
        in_chars += c.char_xp
    check_eq(in_chars, ce, "todo o XP chegou ao elenco")


func test_acoes_levam_a_desbloqueio() -> void:
    var c: Character = _team(0, ["escudeiro"], 4)[0]
    var n := 0
    while not c.is_unlocked(r, cat, "cavaleiro") and n < 50:
        c.add_xp(r, cat, 5)
        n += 1
    check_eq(n, 16, "16 ataques = 80 XP de classe = nivel 3")
