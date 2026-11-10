## Barra de acao: todos comecam cheios, velocidade enche, mover gasta 50% e atacar 50%, empate de
## velocidade = dado 1..6 deterministico.
class_name TurnSystem
extends RefCounted




var threshold: int
var cost_move: int
var cost_attack: int
var cost_wait: int
var tie_die: int
var rng := RandomNumberGenerator.new()


func _init(rules: Rules = null, turn_seed: int = 0) -> void :
    if rules != null:
        threshold = rules.get_int("turn", "ct_threshold")
        cost_move = rules.get_int("turn", "cost_move")
        cost_attack = rules.get_int("turn", "cost_attack")
        cost_wait = rules.get_int("turn", "cost_wait")
        tie_die = rules.get_int("turn", "tie_die")
    else:
        threshold = 100
        cost_move = 50
        cost_attack = 50
        cost_wait = 50
        tie_die = 6
    rng.seed = turn_seed



func turn_cost(moved: bool, acted: bool) -> int:
    var spent := (cost_move if moved else 0) + (cost_attack if acted else 0)
    return spent if spent > 0 else cost_wait



func next_unit(units: Array) -> Unit:
    return _next(units, rng)


func _next(units: Array, r: RandomNumberGenerator) -> Unit:
    var alive: Array = []
    for u in units:
        if u.is_alive() or u.is_dying():
            alive.append(u)
    if alive.is_empty():
        return null
    while true:
        var ready: Array = []
        for u in alive:
            if u.ct >= threshold:
                ready.append(u)
        if not ready.is_empty():
            return _pick(ready, r)
        for u in alive:
            u.ct += maxi(u.speed, 1)
    return null



func _pick(ready: Array, r: RandomNumberGenerator) -> Unit:
    ready.sort_custom( func(a: Unit, b: Unit): return a.ct > b.ct if a.ct != b.ct else a.speed > b.speed)
    var tied: Array = [ready[0]]
    for i in range(1, ready.size()):
        if ready[i].ct == ready[0].ct and ready[i].speed == ready[0].speed:
            tied.append(ready[i])
    while tied.size() > 1:
        var best := 0
        var rolls: Array[int] = []
        for u in tied:
            var roll := r.randi_range(1, tie_die)
            rolls.append(roll)
            best = maxi(best, roll)
        var winners: Array = []
        for i in tied.size():
            if rolls[i] == best:
                winners.append(tied[i])
        tied = winners
    return tied[0]


func end_turn(unit: Unit, moved := true, acted := true) -> void :
    unit.ct -= turn_cost(moved, acted)



func preview(units: Array, count: int) -> Array[int]:
    var sim: Array = []
    for u in units:
        if u.is_alive() or u.is_dying():
            var c := Unit.new()
            c.id = u.id
            c.team = u.team
            c.ct = u.ct
            c.speed = u.speed
            c.hp = u.hp
            c.dying_turns = u.dying_turns
            sim.append(c)
    var out: Array[int] = []
    if sim.is_empty():
        return out
    var sim_rng := RandomNumberGenerator.new()
    sim_rng.seed = rng.seed
    sim_rng.state = rng.state
    for i in count:
        var n := _next(sim, sim_rng)
        out.append(n.id)
        if n.is_dying():
            n.dying_turns -= 1
            n.ct -= cost_wait
        else:
            n.ct -= cost_move + cost_attack
    return out
