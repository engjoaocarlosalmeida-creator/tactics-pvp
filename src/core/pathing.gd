## Movimento sobre o terreno: alcance (Dijkstra), pulo, custo de subida, dano de queda, escorregao pela
## rampa.
class_name Pathing
extends RefCounted




static func fall_damage(rules: Rules, unit: Unit, drop: int) -> int:
    var safe := rules.get_int("movement", "safe_fall")
    if drop <= safe:
        return 0
    var pct := rules.get_float("movement", "fall_damage_percent_per_level")
    return maxi(1, int(ceil(unit.max_hp * pct / 100.0 * float(drop - safe))))





static func resolve_step(map: BattleMap, rules: Rules, unit: Unit, from: Vector2i, 
        dir: Vector2i, occupied: Dictionary, reserved: Dictionary = {}) -> Dictionary:
    var to := from + dir
    if not map.in_bounds(to) or map.is_blocked(to):
        return {}
    var occ = occupied.get(to)
    if occ != null and occ.team != unit.team:
        return {}
    var dh := map.height_at(to) - map.height_at(from)
    if dh > unit.jump:
        return {}
    var cost := 1 + maxi(dh, 0) * rules.get_int("movement", "climb_extra_cost_per_level")
    var damage := fall_damage(rules, unit, - dh)
    var land := to
    var trail: Array[Vector2i] = [to]
    if occ == null and not reserved.has(land):
        var cur_dir := dir
        var seen := {land: true}
        while map.kind_at(land) == BattleMap.Kind.SLIPPERY:
            var sd := map.slope_dir(land)
            if sd != Vector2i.ZERO:
                cur_dir = sd
            var nxt := land + cur_dir
            if not map.in_bounds(nxt) or map.is_blocked(nxt) or occupied.has(nxt) \
                    or reserved.has(nxt) or seen.has(nxt):
                break
            var d2 := map.height_at(nxt) - map.height_at(land)
            if d2 > 0:
                break
            damage += fall_damage(rules, unit, - d2)
            land = nxt
            seen[land] = true
            trail.append(nxt)
    return {"land": land, "cost": cost, "damage": damage, "trail": trail}





static func reachable(map: BattleMap, rules: Rules, unit: Unit, occupied_all: Dictionary,
        reserved_all: Dictionary = {}) -> Dictionary:
    var occupied := occupied_all.duplicate()
    occupied.erase(unit.pos)
    var reserved := reserved_all.duplicate()
    reserved.erase(unit.pos)
    var best := {}
    best[unit.pos] = {"cost": 0, "damage": 0, "prev": null, "trail": [], "can_stop": true}
    var frontier: Array[Vector2i] = [unit.pos]
    while not frontier.is_empty():
        var bi := 0
        for i in range(1, frontier.size()):
            if best[frontier[i]].cost < best[frontier[bi]].cost:
                bi = i
        var cur: Vector2i = frontier[bi]
        frontier.remove_at(bi)
        var cur_info: Dictionary = best[cur]
        for dir in BattleMap.DIRS:
            var step := resolve_step(map, rules, unit, cur, dir, occupied, reserved)
            if step.is_empty():
                continue
            var nc: int = cur_info.cost + step.cost
            if nc > unit.move_budget():
                continue
            var nd: int = cur_info.damage + step.damage
            if nd >= unit.hp:
                continue
            var land: Vector2i = step.land
            if best.has(land):
                var old: Dictionary = best[land]
                if old.cost < nc or (old.cost == nc and old.damage <= nd):
                    continue
            best[land] = {"cost": nc, "damage": nd, "prev": cur, "trail": step.trail,
                    "can_stop": not occupied.has(land) and not reserved.has(land)}
            if not frontier.has(land):
                frontier.append(land)
    return best



static func path_to(reach: Dictionary, dest: Vector2i) -> Array[Vector2i]:
    var segments: Array = []
    var cur = dest
    while cur != null and reach.has(cur):
        var info: Dictionary = reach[cur]
        if info.prev == null:
            break
        segments.push_front(info.trail)
        cur = info.prev
    var out: Array[Vector2i] = []
    for seg in segments:
        for p in seg:
            out.append(p)
    return out
