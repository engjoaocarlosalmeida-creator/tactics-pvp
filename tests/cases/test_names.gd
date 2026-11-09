extends TestCase


func test_tabela_e_variada() -> void:
    var d := NameGenerator.data()
    var firsts := {}
    for sex in ["male", "female"]:
        for tag in d[sex]:
            for region in d[sex][tag]:
                for n in d[sex][tag][region]:
                    firsts[sex + n] = true
    check(firsts.size() >= 180, "muitos nomes (%d)" % firsts.size())
    var lasts := {}
    for region in d["surnames"]:
        for n in d["surnames"][region]:
            lasts[n] = true
    check(lasts.size() >= 120, "muitos sobrenomes (%d)" % lasts.size())
    check_eq(d["surnames"].keys().size(), 4, "4 regioes: America do Sul, America do Norte, Asia e Europa")


func test_gera_nome_completo_e_e_deterministico() -> void:
    var a := RandomNumberGenerator.new()
    var b := RandomNumberGenerator.new()
    a.seed = 5
    b.seed = 5
    for i in 20:
        var n1 := NameGenerator.generate(a, "f", 50, 50)
        var n2 := NameGenerator.generate(b, "f", 50, 50)
        check_eq(n1["full"], n2["full"], "mesma semente, mesmo nome")
        check(str(n1["full"]).contains(" "), "nome e sobrenome")


func test_sexo_escolhe_a_lista() -> void:
    var d := NameGenerator.data()
    var male := {}
    var female := {}
    for tag in d["male"]:
        for r in d["male"][tag]:
            for n in d["male"][tag][r]:
                male[n] = true
    for tag in d["female"]:
        for r in d["female"][tag]:
            for n in d["female"][tag][r]:
                female[n] = true
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    for i in 200:
        check(male.has(NameGenerator.generate(rng, "m", 50, 50)["first"]), "nome masculino")
        check(female.has(NameGenerator.generate(rng, "f", 50, 50)["first"]), "nome feminino")


func test_fe_e_bravura_puxam_listas_diferentes() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    var devout := 0
    var valiant := 0
    var base := 0
    for i in 600:
        if NameGenerator.pick_tag(rng, 40, 95) == "devoto":
            devout += 1
        if NameGenerator.pick_tag(rng, 95, 40) == "valente":
            valiant += 1
        if NameGenerator.pick_tag(rng, 50, 50) == "devoto":
            base += 1
    check(devout > base * 2, "fe alta: mais nomes devotos (%d x %d)" % [devout, base])
    check(valiant > base * 2, "bravura alta: mais nomes valentes (%d x %d)" % [valiant, base])


func test_personagens_do_elenco_tem_nomes_diferentes() -> void:
    var r := Rules.load_default()
    var ro := Roster.create_default(r, JobCatalog.load_default())
    var seen := {}
    var f := 0
    for c in ro.characters:
        seen[c.display_name] = true
        if c.look == "f":
            f += 1
        check(c.display_name.contains(" "), "nome completo")
    check_eq(seen.size(), 8, "nomes diferentes")
    check_eq(f, 4, "4 femininos e 4 masculinos")
