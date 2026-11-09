extends TestCase

var r := Rules.load_default()


func _u(bravura: int, fe: int) -> Unit:
    var u := TestUtil.unit(0, 0, Vector2i.ZERO, r)
    u.bravura = bravura
    u.fe = fe
    return u


func test_fe_para_magia_bravura_para_fisico_e_mental() -> void:
    check_eq(Checks.stat_for(Checks.MAGIC), "fe", "magia")
    check_eq(Checks.stat_for(Checks.PHYSICAL), "bravura", "fisico")
    check_eq(Checks.stat_for(Checks.MENTAL), "bravura", "mental/logico usa bravura")


func test_magia_ignora_bravura_e_fisico_ignora_fe() -> void:
    var a := _u(90, 50)
    var d := _u(10, 50)
    check_eq(Checks.apply_chance(r, Checks.MAGIC, a, d), 50.0, "magia: so a fe conta")
    a = _u(50, 90)
    d = _u(50, 10)
    check_eq(Checks.apply_chance(r, Checks.PHYSICAL, a, d), 50.0, "fisico: so a bravura conta")
    check_eq(Checks.apply_chance(r, Checks.MENTAL, a, d), 50.0, "mental: so a bravura conta")


func test_chance_cresce_com_atributo_de_quem_aplica_e_cai_com_o_de_quem_resiste() -> void:
    var d := _u(50, 50)
    check_eq(Checks.apply_chance(r, Checks.MAGIC, _u(50, 70), d), 60.0, "fe 70 vs 50")
    check_eq(Checks.apply_chance(r, Checks.MAGIC, _u(50, 30), d), 40.0, "fe 30 vs 50")
    var mago_das_trevas := _u(50, 80)
    var devoto := _u(50, 90)
    var cetico := _u(50, 20)
    check(Checks.apply_chance(r, Checks.MAGIC, mago_das_trevas, cetico)
            > Checks.apply_chance(r, Checks.MAGIC, mago_das_trevas, devoto),
            "alvo de muita fe resiste mais ao debuff de magia negra")
    check_eq(Checks.resist_chance(r, Checks.MAGIC, _u(50, 70), d), 40.0, "resistir = 100 - aplicar")


func test_limites_minimo_e_maximo() -> void:
    check_eq(Checks.apply_chance(r, Checks.MAGIC, _u(0, 100), _u(0, 0)), 95.0, "maximo")
    check_eq(Checks.apply_chance(r, Checks.MAGIC, _u(0, 0), _u(0, 100)), 5.0, "minimo")


func test_sorteio_respeita_a_chance() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 2026
    var a := _u(50, 70)
    var d := _u(50, 50)
    var hits := 0
    var n := 20000
    for i in n:
        if Checks.roll_apply(r, Checks.MAGIC, a, d, rng):
            hits += 1
    var rate := hits * 100.0 / n
    check(absf(rate - 60.0) < 1.5, "taxa observada %.1f%% perto de 60%%" % rate)
