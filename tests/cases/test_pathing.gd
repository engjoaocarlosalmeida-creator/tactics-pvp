extends TestCase

var r := Rules.load_default()


func _reach(rows: Array, start: Vector2i, extra: Array = [], setup: Callable = Callable()) -> Dictionary:
    var m := TestUtil.map_from(rows)
    var u := TestUtil.unit(0, 0, start, r)
    if setup.is_valid():
        setup.call(u)
    var all: Array = [u]
    all.append_array(extra)
    return Pathing.reachable(m, r, u, TestUtil.occ(all))


func test_terreno_plano_forma_losango() -> void:
    var rows := []
    for z in 7:
        rows.append([0, 0, 0, 0, 0, 0, 0])
    var reach := _reach(rows, Vector2i(3, 3), [], func(u): u.move = 2)
    check_eq(reach.size(), 13, "losango de raio 2 (com a casa inicial)")


func test_subir_custa_mais_e_respeita_pulo() -> void:
    var rows := [[0, 1, 3, 0]]
    var reach := _reach(rows, Vector2i(0, 0), [], func(u): u.jump = 1; u.move = 6)
    check(reach.has(Vector2i(1, 0)), "sobe 1 nivel com pulo 1")
    check_eq(reach[Vector2i(1, 0)].cost, 2, "custo de subir 1 nivel = 1 + 1")
    check(not reach.has(Vector2i(2, 0)), "nao sobe 2 niveis com pulo 1")


func test_orcamento_de_movimento_inclui_subida() -> void:
    var rows := [[0, 1, 3, 0]]
    var reach := _reach(rows, Vector2i(0, 0), [], func(u): u.jump = 2; u.move = 4)
    check(reach.has(Vector2i(1, 0)), "1 nivel acima custa 2")
    check(not reach.has(Vector2i(2, 0)), "total 5 passa do movimento 4")
    reach = _reach(rows, Vector2i(0, 0), [], func(u): u.jump = 2; u.move = 5)
    check(reach.has(Vector2i(2, 0)), "com movimento 5 chega")


func test_queda_segura_nao_causa_dano() -> void:
    var reach := _reach([[3, 0]], Vector2i(0, 0))
    check_eq(reach[Vector2i(1, 0)].damage, 0, "queda de 3 e segura")


func test_queda_alta_causa_dano() -> void:
    var reach := _reach([[6, 0]], Vector2i(0, 0))
    # queda 6, seguro 3 => 3 niveis * 10% de 40 = 12
    check_eq(reach[Vector2i(1, 0)].damage, 12, "dano de queda")


func test_queda_que_mataria_nao_e_destino() -> void:
    var reach := _reach([[6, 0]], Vector2i(0, 0), [], func(u): u.hp = 10)
    check(not reach.has(Vector2i(1, 0)), "nao pode pular para a propria morte")


func test_escorregar_ate_terreno_normal() -> void:
    var reach := _reach([[0, "0s", "0s", 0, 0]], Vector2i(0, 0))
    check(not reach.has(Vector2i(1, 0)), "nao para em gelo")
    check(not reach.has(Vector2i(2, 0)), "nao para em gelo (2)")
    check_eq(reach[Vector2i(3, 0)].cost, 1, "escorrega com 1 passo de custo")
    check_eq(reach[Vector2i(4, 0)].cost, 2, "e continua andando")
    var path := Pathing.path_to(reach, Vector2i(3, 0))
    check_eq(path.size(), 3, "caminho inclui as casas escorregadas")


func test_escorregao_para_antes_de_inimigo() -> void:
    var m := TestUtil.map_from([[0, "0s", "0s", 0, 0]])
    var u := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var e := TestUtil.unit(1, 1, Vector2i(3, 0), r)
    var reach := Pathing.reachable(m, r, u, TestUtil.occ([u, e]))
    check(reach.has(Vector2i(2, 0)), "para na ultima casa antes do inimigo")


func test_escorregao_nao_sobe() -> void:
    var reach := _reach([[0, "0s", 1, 0]], Vector2i(0, 0))
    check(reach.has(Vector2i(1, 0)), "para na rampa de gelo se a proxima sobe")


func test_escorregao_com_queda_causa_dano() -> void:
    var reach := _reach([[5, "5s", 0]], Vector2i(0, 0))
    check_eq(reach[Vector2i(2, 0)].damage, 8, "queda de 5 = 2 niveis acima do seguro = 8")


func test_inimigo_bloqueia_aliado_so_atravessa() -> void:
    var m := TestUtil.map_from([[0, 0, 0]])
    var u := TestUtil.unit(0, 0, Vector2i(0, 0), r)
    var enemy := TestUtil.unit(1, 1, Vector2i(1, 0), r)
    var reach := Pathing.reachable(m, r, u, TestUtil.occ([u, enemy]))
    check(not reach.has(Vector2i(1, 0)) and not reach.has(Vector2i(2, 0)), "inimigo bloqueia corredor")
    var ally := TestUtil.unit(2, 0, Vector2i(1, 0), r)
    reach = Pathing.reachable(m, r, u, TestUtil.occ([u, ally]))
    check(reach.has(Vector2i(2, 0)) and reach[Vector2i(2, 0)].can_stop, "atravessa aliado")
    check(not reach[Vector2i(1, 0)].can_stop, "nao para em cima do aliado")


func test_bloqueio_e_limites_do_mapa() -> void:
    var reach := _reach([[0, "X", 0]], Vector2i(0, 0))
    check_eq(reach.size(), 1, "so a casa inicial")
