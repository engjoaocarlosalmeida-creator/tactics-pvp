class_name TestUtil
extends RefCounted
## Atalhos para montar cenarios de teste.


## Mapa a partir de linhas: inteiro = altura normal; "2s" = altura 2 escorregadia; "X" = bloqueado.
static func map_from(rows: Array) -> BattleMap:
    var m := BattleMap.new(rows[0].size(), rows.size())
    for z in rows.size():
        for x in rows[z].size():
            var c = rows[z][x]
            var p := Vector2i(x, z)
            if typeof(c) == TYPE_INT:
                m.set_tile(p, c, BattleMap.Kind.NORMAL)
            elif str(c) == "X":
                m.set_tile(p, 0, BattleMap.Kind.BLOCKED)
            elif str(c).contains("s"):
                # "2s" = escorregadia sem direcao; "2s>" "2s<" "2sv" "2s^" = rampa descendo para a direita/esquerda/baixo/cima
                var parts := str(c).split("s")
                var arrows := {">": 0, "<": 1, "v": 2, "^": 3}
                m.set_tile(p, int(parts[0]), BattleMap.Kind.SLIPPERY, arrows.get(parts[1], -1))
    return m


static func unit(id: int, team: int, pos: Vector2i, r: Rules) -> Unit:
    var u := Unit.create(id, team, "u%d" % id, r)
    u.pos = pos
    return u


static func occ(units: Array) -> Dictionary:
    var d := {}
    for u in units:
        d[u.pos] = u
    return d
