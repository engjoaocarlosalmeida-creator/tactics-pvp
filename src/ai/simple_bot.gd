## Bot simples (guloso). Decide UM comando serializavel por vez (next_command) e joga turnos inteiros
## (take_turn). Usado no modo contra o computador, nos testes e no auto-play online dos testes.
class_name SimpleBot
extends RefCounted





static func next_command(m: MatchState, rng: RandomNumberGenerator) -> Dictionary:
    if not m.pending_reaction.is_empty():
        return {"t": "react_skip", "unit": int(m.pending_reaction["unit"])}   # o bot nao usa o movimento extra
    var u := m.active
    if m.awaiting_facing:   # termina o turno virado para o inimigo mais proximo
        var best_dir := u.facing
        var best_d := 1000000
        for e in m.units:
            if e.is_alive() and e.team != u.team and absi(e.pos.x - u.pos.x) + absi(e.pos.y - u.pos.y) < best_d:
                best_d = absi(e.pos.x - u.pos.x) + absi(e.pos.y - u.pos.y)
                best_dir = MatchState.dominant_dir(u.pos, e.pos)
        return {"t": "face", "unit": u.id, "dir": maxi(0, BattleMap.DIRS.find(best_dir))}
    if u.down:
        return {"t": "stand", "unit": u.id}
    var targets := m.targets_for(u)
    if not u.acted and not targets.is_empty():
        var best := targets[0]
        for t in targets:
            if t.hp < best.hp:
                best = t
        return {"t": "attack", "unit": u.id, "target": best.id}
    var dest := _pick_destination(m, u, rng)
    if dest != u.pos:
        return {"t": "move", "unit": u.id, "x": dest.x, "y": dest.y}
    return {"t": "wait", "unit": u.id}



static func take_turn(m: MatchState, rng: RandomNumberGenerator) -> void :
    if m.active == null:
        return
    var serial := m.turn_serial
    var guard := 0
    while not m.is_over() and m.turn_serial == serial and guard < 8:
        guard += 1
        m.apply_command(next_command(m, rng))


static func _pick_destination(m: MatchState, u: Unit, rng: RandomNumberGenerator) -> Vector2i:
    var reach := m.reachable_for(u)
    var options: Array[Vector2i] = []
    for p in reach:
        if reach[p].can_stop and p != u.pos:
            options.append(p)
    if options.is_empty():
        return u.pos
    if rng.randf() < 0.08:
        return options[rng.randi() % options.size()]
    var stay := 1000000
    for e in m.units:
        if e.is_alive() and e.team != u.team:
            stay = mini(stay, absi(u.pos.x - e.pos.x) + absi(u.pos.y - e.pos.y))
    var best: Vector2i = u.pos
    var best_score := stay * 10
    for p in options:
        var nearest := 1000000
        for e in m.units:
            if e.is_alive() and e.team != u.team:
                nearest = mini(nearest, absi(p.x - e.pos.x) + absi(p.y - e.pos.y))
        var score: int = nearest * 10 + int(reach[p].damage)
        if score < best_score:
            best_score = score
            best = p
    return best
