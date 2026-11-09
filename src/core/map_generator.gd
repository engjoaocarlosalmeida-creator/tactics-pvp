## Gera mapas por semente: relevo, rampas, rochas; simetrico por rotacao de 180 graus; zonas de
## preparacao 4x4 iguais; garante caminho entre os lados.
class_name MapGenerator
extends RefCounted




class Result:
    var map: BattleMap
    var spawns: Array = []
    var seed_used: int = 0


static func generate(map_seed: int, rules: Rules) -> Result:
    for attempt in 64:
        var res := _try_generate(map_seed + attempt * 7919, rules)
        if res != null:
            return res
    return _flat(map_seed, rules)


static func _spawn_height(rules: Rules) -> int:
    return clampi(int(rules.get_int("map", "max_height") / 3.0), 0, rules.get_int("map", "max_height"))



static func zone_x0(map: BattleMap, rules: Rules) -> int:
    return (map.width - rules.get_int("map", "spawn_zone")) / 2


static func _spawns_for(map: BattleMap, rules: Rules) -> Array:
    var zone := rules.get_int("map", "spawn_zone")
    var x0 := zone_x0(map, rules)
    var per_team := rules.get_int("match", "units_per_team")
    var team0: Array[Vector2i] = []
    for z in range(zone - 1, -1, -1):
        for x in zone:
            if team0.size() < per_team:
                team0.append(Vector2i(x0 + x, z))
    var team1: Array[Vector2i] = []
    for p in team0:
        team1.append(map.rotated(p))
    return [team0, team1]


static func _try_generate(map_seed: int, rules: Rules) -> Result:
    var w := rules.get_int("map", "width")
    var d := rules.get_int("map", "depth")
    var max_h := rules.get_int("map", "max_height")
    var zone := rules.get_int("map", "spawn_zone")
    var buffer := rules.get_int("map", "spawn_buffer")
    var x0 := (w - zone) / 2
    var jump := rules.get_int("movement", "base_jump")
    var spawn_h := _spawn_height(rules)

    var n1 := FastNoiseLite.new()
    n1.seed = map_seed
    n1.frequency = rules.get_float("map", "noise_frequency")
    var n2 := FastNoiseLite.new()
    n2.seed = map_seed + 101
    n2.frequency = 0.25
    var rng := RandomNumberGenerator.new()
    rng.seed = map_seed

    var map := BattleMap.new(w, d)
    for z in d:
        for x in w:
            var p := Vector2i(x, z)
            var q := map.rotated(p)
            if map.idx(q) < map.idx(p):
                continue
            var n := n1.get_noise_2d(x, z)
            var h := clampi(int(round((n * 1.6 + 1.0) * 0.5 * max_h)), 0, max_h)
            var kind: int = BattleMap.Kind.NORMAL
            if z < zone and x >= x0 and x < x0 + zone:
                h = spawn_h
            elif z < zone + buffer and x >= x0 - buffer and x < x0 + zone + buffer:
                h = clampi(h, spawn_h - 1, spawn_h + 1)
            else:
                if n2.get_noise_2d(x, z) > rules.get_float("map", "slippery_noise_threshold"):
                    kind = BattleMap.Kind.SLIPPERY
                elif rng.randf() < rules.get_float("map", "blocked_chance"):
                    kind = BattleMap.Kind.BLOCKED
            map.set_tile(p, h, kind)
            map.set_tile(q, h, kind)

    _assign_slopes(map, rng)
    var spawns := _spawns_for(map, rules)
    if not _connected(map, jump, spawns[0][0], spawns[1][0]):
        return null
    var res := Result.new()
    res.map = map
    res.spawns = spawns
    res.seed_used = map_seed
    return res




static func _assign_slopes(map: BattleMap, rng: RandomNumberGenerator) -> void :
    for z in map.depth:
        for x in map.width:
            var p := Vector2i(x, z)
            var q := map.rotated(p)
            if map.idx(q) < map.idx(p) or map.kind_at(p) != BattleMap.Kind.SLIPPERY:
                continue
            var best: Array[int] = []
            var best_h := 1000
            var best_slip := 1
            for i in BattleMap.DIRS.size():
                var n: Vector2i = p + BattleMap.DIRS[i]
                if not map.in_bounds(n) or map.is_blocked(n):
                    continue
                var h := map.height_at(n)
                var slip := 1 if map.kind_at(n) == BattleMap.Kind.SLIPPERY else 0

                if h < best_h or (h == best_h and slip < best_slip):
                    best_h = h
                    best_slip = slip
                    best = [i]
                elif h == best_h and slip == best_slip:
                    best.append(i)
            if best.is_empty() or best_h > map.height_at(p):

                map.kinds[map.idx(p)] = BattleMap.Kind.NORMAL
                map.kinds[map.idx(q)] = BattleMap.Kind.NORMAL
                continue
            var pick: int = best[rng.randi() % best.size()]
            map.slopes[map.idx(p)] = pick
            map.slopes[map.idx(q)] = pick ^ 1


static func _flat(map_seed: int, rules: Rules) -> Result:
    var map := BattleMap.new(rules.get_int("map", "width"), rules.get_int("map", "depth"))
    for z in map.depth:
        for x in map.width:
            map.set_tile(Vector2i(x, z), _spawn_height(rules), BattleMap.Kind.NORMAL)
    var res := Result.new()
    res.map = map
    res.spawns = _spawns_for(map, rules)
    res.seed_used = map_seed
    return res



static func is_connected_path(map: BattleMap, jump: int, a: Vector2i, b: Vector2i) -> bool:
    return _connected(map, jump, a, b)


static func _connected(map: BattleMap, jump: int, a: Vector2i, b: Vector2i) -> bool:
    var seen := {a: true}
    var queue: Array[Vector2i] = [a]
    while not queue.is_empty():
        var cur: Vector2i = queue.pop_front()
        if cur == b:
            return true
        for dir in BattleMap.DIRS:
            var nx: Vector2i = cur + dir
            if not map.in_bounds(nx) or map.is_blocked(nx) or seen.has(nx):
                continue
            if map.height_at(nx) - map.height_at(cur) > jump:
                continue
            seen[nx] = true
            queue.append(nx)
    return false
