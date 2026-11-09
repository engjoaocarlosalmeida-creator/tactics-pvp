extends TestCase

var r := Rules.load_default()
var cat := JobCatalog.load_default()


func test_raio_acerta_a_casa_de_cima() -> void:
    var m := TestUtil.map_from([[0, 3, 0]])
    # raio vertical sobre o centro da casa do meio
    var c := MapGeometry.center_xz(m, Vector2i(1, 0))
    check_eq(Picking.pick_tile(m, Vector3(c.x, 10, c.y), Vector3.DOWN), Vector2i(1, 0), "casa alta")
    c = MapGeometry.center_xz(m, Vector2i(0, 0))
    check_eq(Picking.pick_tile(m, Vector3(c.x, 10, c.y), Vector3.DOWN), Vector2i(0, 0), "casa baixa")


func test_raio_fora_do_mapa_nao_acerta() -> void:
    var m := TestUtil.map_from([[0, 0]])
    check_eq(Picking.pick_tile(m, Vector3(50, 10, 50), Vector3.DOWN), Picking.NONE, "fora")


func test_rocha_nao_e_clicavel() -> void:
    var m := TestUtil.map_from([[0, "X", 0]])
    var c := MapGeometry.center_xz(m, Vector2i(1, 0))
    check_eq(Picking.pick_tile(m, Vector3(c.x, 10, c.y), Vector3.DOWN), Picking.NONE, "pilar de rocha")


func test_casa_alta_na_frente_esconde_a_de_tras() -> void:
    # camera baixa olhando para +x: a casa alta (x=0) esconde a baixa (x=1)
    var m := TestUtil.map_from([[5, 0]])
    var c0 := MapGeometry.center_xz(m, Vector2i(0, 0))
    var c1 := MapGeometry.center_xz(m, Vector2i(1, 0))
    var origin := Vector3(c0.x - 3.0, 1.0, c0.y)
    var target := Vector3(c1.x, MapGeometry.top_y(m, Vector2i(1, 0)), c1.y)
    check_eq(Picking.pick_tile(m, origin, (target - origin).normalized()), Vector2i(0, 0), "oclusao")


func test_elenco_padrao() -> void:
    var ro := Roster.create_default(r, cat)
    check_eq(ro.characters.size(), 8, "8 personagens")
    check_eq(ro.team_chars(0, 4).size(), 4, "time 0")
    check_eq(ro.team_chars(1, 4)[0].id, 4, "time 1 comeca no id 4")
    var ids := {}
    for c in ro.characters:
        check(not ids.has(c.id), "ids unicos")
        ids[c.id] = true
        check(cat.has_job(c.job_id), "classe valida")


func test_elenco_salva_e_carrega() -> void:
    var path := "user://test_roster.json"
    var ro := Roster.create_default(r, cat)
    ro.characters[2].add_xp(r, cat, 85)
    check(ro.save(path), "salvou")
    var back := Roster.load_or_default(r, cat, path)
    check_eq(back.to_dict(), ro.to_dict(), "ida e volta")
    DirAccess.remove_absolute(path)


func test_arquivo_invalido_volta_ao_padrao() -> void:
    var path := "user://test_roster_bad.json"
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_string("isto nao e json {{{")
    f.close()
    var ro := Roster.load_or_default(r, cat, path)
    check_eq(ro.characters.size(), 8, "padrao")
    check_eq(ro.to_dict(), Roster.create_default(r, cat).to_dict(), "igual ao padrao")
    var ro2 := Roster.create_default(r, cat)
    ro2.characters[0].job_id = "classe_que_nao_existe"
    ro2.save(path)
    check_eq(Roster.load_or_default(r, cat, path).characters[0].job_id, "escudeiro", "classe invalida descartada")
    DirAccess.remove_absolute(path)
    check_eq(Roster.load_or_default(r, cat, "user://nao_existe.json").characters.size(), 8, "sem arquivo")
