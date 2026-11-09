extends TestCase

var r := Rules.load_default()
var cat := JobCatalog.load_default()


func _char(job: String, seed := 1) -> Character:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    return Character.create_new(1, "Teste", job, r, cat, rng)


func test_arvore_de_classes_do_dono_do_projeto() -> void:
    check_eq(cat.starters(), ["aprendiz", "escudeiro", "lutador"], "classes iniciais")
    check_eq(cat.children("escudeiro"), ["arqueiro", "cavaleiro"], "escudeiro")
    check_eq(cat.children("aprendiz"), ["mago", "sacerdote"], "aprendiz")
    check_eq(cat.children("lutador"), ["ladrao"], "lutador")
    check_eq(cat.jobs.size(), 8, "total de classes")


func test_catalogo_consistente() -> void:
    for id in cat.jobs:
        var job: Dictionary = cat.jobs[id]
        if job.parent != null:
            check(cat.has_job(str(job.parent)), "pai existe: " + str(id))
            check(cat.jobs[str(job.parent)].parent == null, "so 2 niveis por enquanto: " + str(id))
            check(job.has("requires_level"), "pede nivel: " + str(id))
        for k in JobCatalog.MOD_KEYS:
            check(job.mods.has(k), "%s tem mod %s" % [id, k])


func test_novo_personagem() -> void:
    var c := _char("escudeiro")
    for a in Character.ATTRS:
        check_eq(c.attrs[a], 5, "atributo inicial " + a)
    check(c.bravura >= 35 and c.bravura <= 65, "bravura sorteada na faixa")
    check(c.fe >= 35 and c.fe <= 65, "fe sorteada na faixa")
    check_eq(c.job_id, "escudeiro", "classe")
    check_eq(_char("lutador", 9).bravura, _char("lutador", 9).bravura, "determinista por semente")


func test_bravura_e_fe_sao_natos() -> void:
    var c := _char("aprendiz")
    c.attr_points = 10
    check(not c.spend_point(r, "bravura"), "nao gasta ponto em bravura")
    check(not c.spend_point(r, "fe"), "nao gasta ponto em fe")
    check(not c.spend_point(r, "inexistente"), "atributo invalido")
    var b := c.bravura
    var f := c.fe
    c.add_xp(r, cat, 1000)
    check_eq(c.bravura, b, "bravura intacta apos subir de nivel")
    check_eq(c.fe, f, "fe intacta apos subir de nivel")


func test_niveis_de_classe_e_de_personagem() -> void:
    var c := _char("escudeiro")
    check_eq(c.job_level(r, "escudeiro"), 1, "classe comeca no 1")
    check_eq(c.char_level(r), 1, "personagem comeca no 1")
    var res := c.add_xp(r, cat, 19)
    check_eq([c.job_level(r, "escudeiro"), c.char_level(r), res.levels_gained, res.char_levels_gained], [1, 1, 0, 0], "19 XP: nada sobe")
    res = c.add_xp(r, cat, 1)
    check_eq(c.char_level(r), 2, "20 XP = nivel 2 de personagem")
    check_eq(c.job_level(r, "escudeiro"), 1, "classe ainda no 1")
    check_eq(c.attr_points, 2, "pontos vem do nivel de PERSONAGEM")
    res = c.add_xp(r, cat, 10)
    check_eq(c.job_level(r, "escudeiro"), 2, "30 XP = nivel 2 de classe")
    check_eq(res.levels_gained, 1, "ganhou 1 nivel de classe")
    c.add_xp(r, cat, 100000)
    check_eq(c.job_level(r, "escudeiro"), 5, "classe tem limite de nivel 5")
    check(c.char_level(r) > 50, "personagem continua subindo (nivel %d)" % c.char_level(r))
    check_eq(c.attr_points, (c.char_level(r) - 1) * 2, "2 pontos por nivel de personagem")


func test_xp_de_classe_so_vai_para_a_classe_equipada() -> void:
    var c := _char("escudeiro")
    c.add_xp(r, cat, 80)
    check_eq(c.job_level(r, "escudeiro"), 3, "escudeiro nivel 3")
    c.change_job(r, cat, "arqueiro")
    c.add_xp(r, cat, 30)
    check_eq(c.job_level(r, "escudeiro"), 3, "classe antiga parada")
    check_eq(c.job_level(r, "arqueiro"), 2, "classe equipada sobe")
    check_eq(c.char_xp, 110, "XP de personagem soma tudo")
    c.add_xp(r, cat, 10, 50)
    check_eq(c.char_xp, 160, "XP de personagem e de classe podem ser diferentes")


func test_sexo_fixo_e_nome_editavel_uma_vez() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var c := Character.create_new(1, "", "lutador", r, cat, rng)
    var sex := c.look
    check(sex == "m" or sex == "f", "tem sexo")
    check(c.display_name.contains(" "), "nome e sobrenome sorteados")
    check(c.rename("Maria Souza"), "primeira edicao vale")
    check_eq(c.display_name, "Maria Souza", "nome novo")
    check(not c.rename("Outra Pessoa"), "so uma vez")
    check_eq(c.look, sex, "sexo nunca muda")
    check(not _char("lutador", 8).rename("   "), "nome vazio e recusado")


func test_classificacao_de_bravura_e_fe() -> void:
    check_eq(Character.classify(49), "baixa", "49")
    check_eq(Character.classify(50), "média", "50")
    check_eq(Character.classify(70), "média", "70")
    check_eq(Character.classify(71), "alta", "71")
    check_eq(Character.classify(90), "alta", "90")
    check_eq(Character.classify(91), "muito alta", "91")


func test_progresso_libera_classes_filhas() -> void:
    var c := _char("escudeiro")
    check(not c.is_unlocked(r, cat, "cavaleiro"), "bloqueado no inicio")
    check(c.is_unlocked(r, cat, "lutador"), "classes iniciais sempre livres")
    check(not c.change_job(r, cat, "cavaleiro"), "nao troca para bloqueada")
    var res := c.add_xp(r, cat, 79)
    check_eq(res.new_jobs, [], "nivel 2 ainda nao libera")
    res = c.add_xp(r, cat, 1)
    check_eq(res.new_jobs, ["arqueiro", "cavaleiro"], "nivel 3 libera as duas filhas")
    check(not c.is_unlocked(r, cat, "mago"), "mago depende do aprendiz")
    check(not c.is_unlocked(r, cat, "ladrao"), "ladrao depende do lutador")
    check(c.change_job(r, cat, "arqueiro"), "troca para arqueiro")
    check_eq(c.job_id, "arqueiro", "classe atual")
    check_eq(c.job_level(r, "arqueiro"), 1, "arqueiro comeca do nivel 1")
    check_eq(c.job_level(r, "escudeiro"), 3, "progresso do escudeiro mantido")
    check(c.change_job(r, cat, "escudeiro"), "pode voltar")
    check(c.is_unlocked(r, cat, "cavaleiro"), "desbloqueio permanece")


func test_gastar_pontos() -> void:
    var c := _char("lutador")
    check(not c.spend_point(r, "forca"), "sem pontos")
    c.attr_points = 2
    check(c.spend_point(r, "forca"), "gasta")
    check_eq(c.attrs["forca"], 6, "forca subiu")
    check_eq(c.attr_points, 1, "ponto consumido")
    c.attrs["agilidade"] = 30
    check(not c.spend_point(r, "agilidade"), "respeita o maximo")


func test_salvar_e_carregar_via_json() -> void:
    var c := _char("escudeiro", 5)
    c.add_xp(r, cat, 85)
    c.spend_point(r, "forca")
    c.change_job(r, cat, "cavaleiro")
    c.add_xp(r, cat, 31)
    var text := JSON.stringify(c.to_dict())
    var back := Character.from_dict(JSON.parse_string(text))
    check_eq(back.to_dict(), c.to_dict(), "ida e volta pelo JSON")
    check_eq(typeof(back.attrs["forca"]), TYPE_INT, "inteiros voltam como inteiros")
    check_eq(back.job_level(r, "cavaleiro"), 2, "progresso preservado")


func test_status_derivados_de_classe_e_atributos() -> void:
    var c := _char("escudeiro")
    var u := Unit.from_character(0, 0, c, r, cat)
    check_eq([u.max_hp, u.atk, u.defense, u.speed, u.move, u.jump, u.attack_range],
            [46, 12, 6, 8, 4, 2, 1], "escudeiro sem pontos")
    c.attrs["forca"] = 15
    c.attrs["constituicao"] = 9
    c.attrs["agilidade"] = 10
    u = Unit.from_character(0, 0, c, r, cat)
    check_eq([u.max_hp, u.atk, u.defense, u.speed], [58, 17, 7, 10], "atributos escalam")
    var rng := RandomNumberGenerator.new()
    var archer := Unit.from_character(1, 0, Character.create_new(2, "A", "arqueiro", r, cat, rng), r, cat)
    check_eq([archer.attack_range, archer.atk, archer.speed], [3, 13, 9], "arqueiro tem alcance 3")
    var thief := Unit.from_character(2, 0, Character.create_new(3, "L", "ladrao", r, cat, rng), r, cat)
    check_eq([thief.speed, thief.move, thief.jump], [11, 5, 3], "ladrao rapido e agil")


func test_unidade_herda_natos_do_personagem() -> void:
    var c := _char("aprendiz", 77)
    var u := Unit.from_character(0, 0, c, r, cat)
    check_eq(u.bravura, c.bravura, "bravura")
    check_eq(u.fe, c.fe, "fe")
    check_eq(u.character_id, c.id, "origem")
    check_eq(u.job_id, "aprendiz", "classe")
