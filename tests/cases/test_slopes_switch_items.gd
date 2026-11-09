extends TestCase

var r := Rules.load_default()
var cat := JobCatalog.load_default()
var items := ItemCatalog.get_default()


# ----------------------------------------------------------------- rampas

func _reach_for(rows: Array, start: Vector2i) -> Dictionary:
    var m := TestUtil.map_from(rows)
    var u := TestUtil.unit(0, 0, start, r)
    return Pathing.reachable(m, r, u, TestUtil.occ([u]))


func test_rampa_leva_na_direcao_da_inclinacao_e_nao_na_da_entrada() -> void:
    # entra andando para a direita em (1,0), mas a rampa desce para baixo (+z)
    var reach := _reach_for([[0, "0sv", 0], [0, 0, 0]], Vector2i(0, 0))
    check(not reach.has(Vector2i(1, 0)), "nao para na rampa")
    check_eq(reach[Vector2i(1, 1)].cost, 1, "escorrega para (1,1) gastando 1 passo")
    check_eq(Pathing.path_to(reach, Vector2i(1, 1)), [Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i], "caminho passa pela rampa")


func test_rampas_em_sequencia_mudam_a_direcao() -> void:
    var reach := _reach_for([[0, "0sv", 0, 0], [0, "0s>", 0, 0]], Vector2i(0, 0))
    check(reach.has(Vector2i(2, 1)), "desce e depois segue a segunda rampa ate o chao")
    check(not reach.has(Vector2i(1, 1)), "nao para na segunda rampa")


func test_rampa_nao_sobe() -> void:
    var reach := _reach_for([[0, "0s>", 3]], Vector2i(0, 0))
    check(reach.has(Vector2i(1, 0)), "fica na rampa se a descida seria uma subida")


func test_rampas_apontando_uma_para_a_outra_nao_travam() -> void:
    var reach := _reach_for([[0, "0s>", "0s<", 0]], Vector2i(0, 0))
    check(reach.size() >= 2, "terminou o calculo")


func test_geracao_de_rampas_e_simetrica() -> void:
    var seen_slippery := 0
    for s in 150:
        var m := MapGenerator.generate(s, r).map
        for z in m.depth:
            for x in m.width:
                var p := Vector2i(x, z)
                if m.kind_at(p) == BattleMap.Kind.SLIPPERY:
                    seen_slippery += 1
                    var d := m.slope_dir(p)
                    check(d != Vector2i.ZERO, "rampa tem direcao")
                    check_eq(m.slope_dir(m.rotated(p)), -d, "espelho tem a direcao oposta (semente %d)" % s)
                    var n := p + d
                    if m.in_bounds(n) and not m.is_blocked(n):
                        check(m.height_at(n) <= m.height_at(p) + 0, "rampa nao aponta para cima")
    check(seen_slippery > 100, "ha rampas nos mapas")


# ----------------------------------------------------------------- alternar personagem

func _pair() -> MatchState:
    var map := TestUtil.map_from([[0, 0, 0, 0, 0, 0]])
    var a0 := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var a1 := TestUtil.unit(1, 0, Vector2i(1, 0), r)
    var b := TestUtil.unit(2, 1, Vector2i(5, 0), r)
    a0.ct = 120
    a1.ct = 110
    b.speed = 1
    var us: Array[Unit] = [a0, a1, b]
    var s := MatchState.from_parts(r, map, us)
    s.start()
    return s


func test_alternar_entre_companheiros_prontos() -> void:
    var s := _pair()
    check_eq(s.active.id, 0, "o de maior contador age primeiro")
    check_eq(s.ready_alternates(s.active).size(), 1, "um companheiro tambem esta pronto")
    check_eq(s.apply_command({"t": "switch", "unit": 0, "to": 1}).ok, true, "alternou")
    check_eq(s.active.id, 1, "agora age o outro")
    check(not s.active.moved and not s.active.acted, "turno novo para ele")
    check_eq(s.apply_command({"t": "switch", "unit": 1, "to": 0}).ok, true, "pode voltar")


func test_nao_alterna_depois_de_agir_nem_com_inimigo_ou_nao_pronto() -> void:
    var s := _pair()
    check_eq(s.apply_command({"t": "switch", "unit": 0, "to": 2}).error, "not_ready", "inimigo nao")
    check_eq(s.apply_command({"t": "switch", "unit": 0, "to": 0}).error, "not_ready", "a si mesmo nao")
    check_eq(s.apply_command({"t": "switch", "unit": 1, "to": 0}).error, "not_active", "so o ativo pede")
    s.units[1].ct = 50
    check_eq(s.apply_command({"t": "switch", "unit": 0, "to": 1}).error, "not_ready", "contador baixo nao")
    s.units[1].ct = 110
    check(s.move(0, Vector2i(2, 0)).ok, "ativo se move")
    var after := s.active
    check(after.id != 0 or s.active.moved, "turno seguiu")
    if s.active.id == 0:
        check_eq(s.apply_command({"t": "switch", "unit": 0, "to": 1}).error, "already_started", "depois de mover nao troca")


func test_alternar_muda_o_hash_e_e_igual_nos_dois_lados() -> void:
    var a := _pair()
    var b := _pair()
    check_eq(a.state_hash(), b.state_hash(), "inicio igual")
    a.apply_command({"t": "switch", "unit": 0, "to": 1})
    check(a.state_hash() != b.state_hash(), "hash muda")
    b.apply_command({"t": "switch", "unit": 0, "to": 1})
    check_eq(a.state_hash(), b.state_hash(), "iguais depois do mesmo comando")


# ----------------------------------------------------------------- itens e peso

func _char(job: String, forca := 5) -> Character:
    var rng := RandomNumberGenerator.new()
    rng.seed = 1
    var c := Character.create_new(1, "T", job, r, cat, rng)
    c.attrs["forca"] = forca
    return c


func test_capacidade_cresce_com_a_forca() -> void:
    check_eq(Encumbrance.capacity(r, 5), 16, "forca 5")
    check_eq(Encumbrance.capacity(r, 10), 26, "forca 10")
    check(Encumbrance.capacity(r, 15) > Encumbrance.capacity(r, 10), "mais forte, mais capacidade")


func test_penalidade_de_movimento_por_peso() -> void:
    check_eq(Encumbrance.move_penalty(r, 16, 0), 0, "sem peso")
    check_eq(Encumbrance.move_penalty(r, 16, 8), 0, "ate metade da capacidade e livre")
    check_eq(Encumbrance.move_penalty(r, 16, 9), 1, "passou da metade")
    check_eq(Encumbrance.move_penalty(r, 16, 12), 1, "ate +25%")
    check_eq(Encumbrance.move_penalty(r, 16, 13), 2, "mais um degrau")
    check_eq(Encumbrance.move_penalty(r, 16, 24), 4, "limite maximo")
    check_eq(Encumbrance.max_weight(r, 16), 24, "150% da capacidade")


func test_peso_total_e_limite_de_carga() -> void:
    var c := _char("escudeiro")
    check(c.add_item(r, items, "armadura_ferro"), "10 de peso")
    check(c.add_item(r, items, "armadura_ferro"), "20 de peso")
    check_eq(c.carry_weight(items), 20, "peso somado")
    check(not c.add_item(r, items, "armadura_ferro"), "30 passa do limite de 24")
    check(c.add_item(r, items, "escudo_madeira"), "24 e exatamente o limite")
    check(not c.add_item(r, items, "pocao"), "25 nao cabe")
    check(not c.add_item(r, items, "item_que_nao_existe"), "item invalido")
    check(c.remove_item("armadura_ferro"), "largar")
    check_eq(c.carry_weight(items), 14, "peso apos largar")
    check(not c.remove_item("cajado"), "nao tem")


func test_peso_reduz_o_movimento_na_batalha() -> void:
    var c := _char("escudeiro")
    check_eq(Unit.from_character(0, 0, c, r, cat).move, 4, "sem itens")
    c.add_item(r, items, "armadura_ferro")
    c.add_item(r, items, "escudo_madeira")
    var u := Unit.from_character(0, 0, c, r, cat)
    check_eq([u.carry_weight, u.carry_capacity, u.move_penalty, u.move], [14, 16, 2, 2], "14 de 16: -2 de movimento")
    var strong := _char("escudeiro", 15)
    strong.add_item(r, items, "armadura_ferro")
    strong.add_item(r, items, "escudo_madeira")
    check_eq(Unit.from_character(0, 0, strong, r, cat).move, 4, "mais forte carrega o mesmo sem perder movimento")
    var heavy := _char("cavaleiro")
    for i in 2:
        heavy.add_item(r, items, "armadura_ferro")
    check_eq(Unit.from_character(0, 0, heavy, r, cat).move, 1, "movimento nunca cai abaixo de 1 (cavaleiro ja e lento)")


func test_estoque_do_jogador_e_transferencias() -> void:
    var ro := Roster.create_default(r, cat)
    check_eq(int(ro.stash["pocao"]), 6, "estoque inicial")
    var c := ro.characters[0]
    check(ro.give_item(c, r, items, "pocao"), "pegar poção")
    check_eq(int(ro.stash["pocao"]), 5, "saiu do estoque")
    check_eq(c.items, ["pocao"] as Array[String], "esta com o personagem")
    check(ro.take_back_item(c, "pocao"), "devolver")
    check_eq(int(ro.stash["pocao"]), 6, "voltou")
    check(not ro.give_item(c, r, items, "item_que_nao_existe"), "item inexistente")
    ro.stash["armadura_ferro"] = 5
    ro.give_item(c, r, items, "armadura_ferro")
    ro.give_item(c, r, items, "armadura_ferro")
    check(not ro.give_item(c, r, items, "armadura_ferro"), "limite de peso impede")
    check_eq(int(ro.stash["armadura_ferro"]), 3, "o que nao coube fica no estoque")


func test_itens_e_estoque_sao_salvos_e_saves_antigos_funcionam() -> void:
    var ro := Roster.create_default(r, cat)
    ro.give_item(ro.characters[2], r, items, "espada_curta")
    var text := JSON.stringify(ro.to_dict())
    var back := Roster.from_dict(JSON.parse_string(text), cat)
    check_eq(back.characters[2].items, ["espada_curta"] as Array[String], "itens do personagem")
    check_eq(int(back.stash["espada_curta"]), 1, "estoque")
    var old := ro.to_dict()
    old.erase("stash")
    for cd in old["characters"]:
        cd.erase("items")
    var legacy := Roster.from_dict(old, cat)
    check(legacy != null, "save antigo carrega")
    check_eq(legacy.characters[0].items.size(), 0, "sem itens")
    check_eq(int(legacy.stash["pocao"]), 6, "estoque inicial para saves antigos")
