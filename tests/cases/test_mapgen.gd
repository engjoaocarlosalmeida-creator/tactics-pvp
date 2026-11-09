extends TestCase

var r := Rules.load_default()


func test_mesma_semente_gera_mesmo_mapa() -> void:
    var a := MapGenerator.generate(123, r)
    var b := MapGenerator.generate(123, r)
    check_eq(a.map.heights, b.map.heights, "alturas")
    check_eq(a.map.kinds, b.map.kinds, "terrenos")
    check_eq(a.spawns, b.spawns, "inicios")


func test_sementes_diferentes_geram_mapas_diferentes() -> void:
    var distinct := {}
    for s in range(1, 21):
        distinct[str(MapGenerator.generate(s, r).map.heights)] = true
    check(distinct.size() >= 18, "variedade (%d de 20)" % distinct.size())


func test_invariantes_em_muitas_sementes() -> void:
    var max_h := r.get_int("map", "max_height")
    var jump := r.get_int("movement", "base_jump")
    var per := r.get_int("match", "units_per_team")
    var zone := r.get_int("map", "spawn_zone")
    for s in 120:
        var g := MapGenerator.generate(s, r)
        var m := g.map
        check_eq(m.width, r.get_int("map", "width"), "largura")
        check_eq(m.depth, r.get_int("map", "depth"), "profundidade")
        var symmetric := true
        var in_range := true
        for z in m.depth:
            for x in m.width:
                var p := Vector2i(x, z)
                var q := m.rotated(p)
                if m.height_at(p) != m.height_at(q) or m.kind_at(p) != m.kind_at(q):
                    symmetric = false
                if m.height_at(p) < 0 or m.height_at(p) > max_h:
                    in_range = false
        check(symmetric, "simetria 180 graus (semente %d)" % s)
        check(in_range, "alturas dentro do limite (semente %d)" % s)
        check_eq(g.spawns[0].size(), per, "inicios do time 0")
        check_eq(g.spawns[1].size(), per, "inicios do time 1")
        for t in 2:
            for p in g.spawns[t]:
                check(not m.is_blocked(p) and m.kind_at(p) == BattleMap.Kind.NORMAL, "inicio livre")
        check(MapGenerator.is_connected_path(m, jump, g.spawns[0][0], g.spawns[1][0]),
                "lados conectados (semente %d)" % s)
        # zonas de inicio planas e na mesma altura
        var h0 := m.height_at(g.spawns[0][0])
        var x0 := MapGenerator.zone_x0(m, r)
        for z in zone:
            for x in zone:
                check_eq(m.height_at(Vector2i(x0 + x, z)), h0, "zona de inicio plana")
                check_eq(m.height_at(m.rotated(Vector2i(x0 + x, z))), h0, "zona do outro lado igual")


func test_mapas_tem_relevo_e_terrenos_especiais() -> void:
    var with_relief := 0
    var with_slippery := 0
    for s in 100:
        var m := MapGenerator.generate(s, r).map
        var hs := {}
        var slip := false
        for i in m.heights.size():
            hs[m.heights[i]] = true
            if m.kinds[i] == BattleMap.Kind.SLIPPERY:
                slip = true
        if hs.size() >= 3:
            with_relief += 1
        if slip:
            with_slippery += 1
    check(with_relief >= 80, "relevo em quase todos os mapas (%d/100)" % with_relief)
    check(with_slippery >= 30, "terreno escorregadio aparece (%d/100)" % with_slippery)
