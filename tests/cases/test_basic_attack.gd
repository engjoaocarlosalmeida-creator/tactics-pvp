extends TestCase

var r := Rules.load_default()
var cat := JobCatalog.load_default()


func _unit(job: String, id: int, team: int, pos: Vector2i, attrs := {}) -> Unit:
    var rng := RandomNumberGenerator.new()
    rng.seed = id + 1
    var c := Character.create_new(id, "c%d" % id, job, r, cat, rng)
    for k in attrs:
        c.attrs[k] = attrs[k]
    var u := Unit.from_character(id, team, c, r, cat)
    u.pos = pos
    return u


func _match(a: Unit, b: Unit, width := 6) -> MatchState:
    var row := []
    for i in width:
        row.append(0)
    var us: Array[Unit] = [a, b]
    a.speed = 20
    b.speed = 5
    var s := MatchState.from_parts(r, TestUtil.map_from([row]), us)
    s.start()
    return s


func test_alcance_por_classe() -> void:
    var ranges := {"escudeiro": 1, "lutador": 1, "cavaleiro": 1, "ladrao": 1, "aprendiz": 1,
            "sacerdote": 1, "mago": 2, "arqueiro": 3}
    for job in ranges:
        check_eq(_unit(job, 0, 0, Vector2i.ZERO).attack_range, ranges[job], "alcance de " + job)


func test_arqueiro_acerta_ate_3_casas_e_nao_mais() -> void:
    var s := _match(_unit("arqueiro", 0, 0, Vector2i(0, 0)), _unit("escudeiro", 1, 1, Vector2i(4, 0)))
    check_eq(s.attack(0, 1).error, "out_of_range", "4 casas e longe demais")
    s = _match(_unit("arqueiro", 0, 0, Vector2i(0, 0)), _unit("escudeiro", 1, 1, Vector2i(3, 0)))
    check(s.attack(0, 1).ok, "3 casas acerta")


func test_corpo_a_corpo_so_adjacente() -> void:
    var s := _match(_unit("lutador", 0, 0, Vector2i(0, 0)), _unit("escudeiro", 1, 1, Vector2i(2, 0)))
    check_eq(s.attack(0, 1).error, "out_of_range", "2 casas e longe para corpo a corpo")


func test_mago_alcance_2() -> void:
    var s := _match(_unit("mago", 0, 0, Vector2i(0, 0)), _unit("escudeiro", 1, 1, Vector2i(2, 0)))
    check(s.attack(0, 1).ok, "mago acerta a 2 casas")


func test_dano_escala_com_o_atributo_da_classe() -> void:
    var base := _unit("lutador", 0, 0, Vector2i.ZERO).atk
    check(_unit("lutador", 0, 0, Vector2i.ZERO, {"forca": 15}).atk > base, "forca aumenta o ataque do lutador")
    check_eq(_unit("lutador", 0, 0, Vector2i.ZERO, {"inteligencia": 15}).atk, base, "inteligencia nao afeta o lutador")
    var mage := _unit("mago", 0, 0, Vector2i.ZERO).atk
    check(_unit("mago", 0, 0, Vector2i.ZERO, {"inteligencia": 15}).atk > mage, "inteligencia aumenta o ataque do mago")
    check_eq(_unit("mago", 0, 0, Vector2i.ZERO, {"forca": 15}).atk, mage, "forca nao afeta o mago")
    var priest := _unit("sacerdote", 0, 0, Vector2i.ZERO).atk
    check(_unit("sacerdote", 0, 0, Vector2i.ZERO, {"sabedoria": 15}).atk > priest, "sabedoria aumenta o ataque do sacerdote")


func test_dano_real_na_partida_usa_o_atributo() -> void:
    var weak := _match(_unit("lutador", 0, 0, Vector2i(0, 0)), _unit("escudeiro", 1, 1, Vector2i(1, 0)))
    var d1: int = weak.attack(0, 1).damage
    var strong := _match(_unit("lutador", 0, 0, Vector2i(0, 0), {"forca": 25}), _unit("escudeiro", 1, 1, Vector2i(1, 0)))
    var d2: int = strong.attack(0, 1).damage
    check(d2 > d1, "mais forca = mais dano (%d vs %d)" % [d1, d2])


func test_habilidades_por_enquanto_so_ataque_basico() -> void:
    var s := _match(_unit("arqueiro", 0, 0, Vector2i(0, 0)), _unit("escudeiro", 1, 1, Vector2i(1, 0)))
    for u in s.units:
        check_eq(s.skills_for(u).size(), 1, "uma habilidade")
        check_eq(s.skills_for(u)[0].id, "basic", "ataque basico")
    check_eq(s.skills_for(s.units[0])[0].range, 3, "alcance informado")
