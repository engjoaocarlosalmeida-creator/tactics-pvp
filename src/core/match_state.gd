## NUCLEO DAS REGRAS DA PARTIDA. Todo comando (move, attack, wait, switch, stand, face, react_*) entra
## por apply_command, e validado e aplicado aqui. Barra de acao, movimento fracionado, XP, defesas
## (esquiva/parry/bloqueio), reacoes, direcao, queda. Sem dependencia de visual (roda em testes e na
## rede).
class_name MatchState
extends RefCounted



signal turn_started(unit: Unit)
signal unit_moved(unit: Unit, path: Array)
signal unit_hurt(unit: Unit, amount: int, reason: String)
signal unit_died(unit: Unit)
signal unit_dying_turn(unit: Unit, turns_left: int)
signal unit_expired(unit: Unit)
signal match_over(winner: int)


signal xp_gained(unit: Unit, job_xp: int, char_xp: int, modifier_flag: int)
signal active_switched(unit: Unit)
signal attack_resolved(attacker: Unit, target: Unit, tile: Vector2i, damage: int)
## Resultado de reacao/defesa em segundo plano (so o nome e o feito): kind = dodge, parry, block, oa, counter, fall, stand, extra_move
signal reaction_event(unit: Unit, kind: String, text: String)
signal facing_requested(unit: Unit)

const DRAW := -2
const ONGOING := -1

var rules: Rules
var map: BattleMap
var units: Array[Unit] = []
var turns: TurnSystem
var active: Unit = null
var winner: int = ONGOING
var turn_serial: int = 0
var idle_streak: int = 0
static var reactions_enabled := true       # o executor de testes desliga para cenarios deterministicos
var combat_rng := RandomNumberGenerator.new()
var roll_override: Array = []              # (testes) resultados forcados de 0 a 100
var manual_facing_teams: Array = []        # times cujo jogador escolhe o lado ao fim de cada turno
var awaiting_facing := false
var pending_reaction := {}                 # {"type": "extra_move", "unit": id, "budget": casas}


static func create(map_seed: int, r: Rules) -> MatchState:
    var gen := MapGenerator.generate(map_seed, r)
    var us: Array[Unit] = []
    var next_id := 0
    for team in 2:
        for p in gen.spawns[team]:
            var u := Unit.create(next_id, team, "T%d-%d" % [team + 1, next_id], r)
            u.pos = p
            us.append(u)
            next_id += 1
    return MatchState.from_parts(r, gen.map, us, map_seed)



static func create_from_characters(map_seed: int, r: Rules, catalog: JobCatalog, 
        team0: Array, team1: Array) -> MatchState:
    var gen := MapGenerator.generate(map_seed, r)
    var us: Array[Unit] = []
    var next_id := 0
    var teams := [team0, team1]
    for team in 2:
        var spawns: Array = gen.spawns[team]
        for i in mini(spawns.size(), teams[team].size()):
            var u := Unit.from_character(next_id, team, teams[team][i], r, catalog)
            u.pos = spawns[i]
            us.append(u)
            next_id += 1
    return MatchState.from_parts(r, gen.map, us, map_seed)
static func from_parts(r: Rules, m: BattleMap, us: Array[Unit], turn_seed: int = 0) -> MatchState:
    var s := MatchState.new()
    s.rules = r
    s.map = m
    s.units = us
    s.turns = TurnSystem.new(r, turn_seed)
    s.combat_rng.seed = turn_seed + 7919
    for u in us:
        if u.ct == 0:
            u.ct = s.turns.threshold   # a barra de acao comeca cheia
        u.facing = Vector2i(0, 1) if u.team == 0 else Vector2i(0, -1)   # cada time olha para o lado do outro
    return s


func start() -> void :
    _begin_turn()


func _has_dying_units() -> bool:
    for u in units:
        if u.is_dying():
            return true
    return false


func is_over() -> bool:
    return winner != ONGOING


func unit_by_id(unit_id: int) -> Unit:
    for u in units:
        if u.id == unit_id:
            return u
    return null


func occupied() -> Dictionary:
    var d := {}
    for u in units:
        if u.is_alive():
            d[u.pos] = u
    return d


func reserved_tiles() -> Dictionary:
    var d := {}
    for u in units:
        if u.is_dying() or u.is_expired():
            d[u.pos] = u
    return d


func reachable_for(u: Unit) -> Dictionary:
    return Pathing.reachable(map, rules, u, occupied(), reserved_tiles())
func move_options(u: Unit) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    if u.move_budget() <= 0 or u.down:
        return out
    var r := reachable_for(u)
    for p in r:
        if r[p].can_stop and p != u.pos:
            out.append(p)
    return out


func can_hit(a: Unit, t: Unit) -> bool:
    return tile_in_range(a, t.pos)



func tile_in_range(a: Unit, p: Vector2i) -> bool:
    return tile_in_range_from(a, a.pos, p)



func tile_in_range_from(a: Unit, from: Vector2i, p: Vector2i) -> bool:
    if not map.in_bounds(p) or map.is_blocked(p):
        return false
    var dist := absi(from.x - p.x) + absi(from.y - p.y)
    if dist == 0 or dist > a.attack_range:
        return false
    return absi(map.height_at(from) - map.height_at(p)) <= rules.get_int("combat", "height_tolerance")



func attack_tiles(u: Unit) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    for dz in range( - u.attack_range, u.attack_range + 1):
        for dx in range( - u.attack_range, u.attack_range + 1):
            var p := u.pos + Vector2i(dx, dz)
            if tile_in_range(u, p):
                out.append(p)
    return out



func targets_for(u: Unit) -> Array[Unit]:
    var out: Array[Unit] = []
    for t in units:
        if t.is_alive() and t.team != u.team and can_hit(u, t):
            out.append(t)
    return out



func units_in_range(u: Unit) -> Array[Unit]:
    var out: Array[Unit] = []
    for t in units:
        if t != u and t.is_alive() and can_hit(u, t):
            out.append(t)
    return out


func attack_damage(a: Unit, t: Unit) -> int:
    var diff := map.height_at(a.pos) - map.height_at(t.pos)
    var raw := a.atk - t.defense + diff * rules.get_int("combat", "height_damage_bonus_per_level")
    return maxi(rules.get_int("combat", "min_damage"), raw)



func skills_for(u: Unit) -> Array:
    return [{"id": "basic", "name": "Ataque básico", "range": u.attack_range, "stat": u.attack_stat}]
func has_actions(u: Unit) -> bool:
    if u.down and not u.moved:
        return true   # pode levantar (gasta a acao de movimento)
    if not move_options(u).is_empty():
        return true
    if not u.acted and not units_in_range(u).is_empty():
        return true
    return false


func ready_alternates(u: Unit) -> Array[Unit]:
    var out: Array[Unit] = []
    for o in units:
        if o != u and o.is_alive() and o.team == u.team and o.ct >= turns.threshold:
            out.append(o)
    return out



func turns_until(u: Unit, limit: int = 24) -> int:
    if u == active:
        return 0
    return turns.preview(units, limit).find(u.id)
func move(unit_id: int, dest: Vector2i) -> Dictionary:
    var err := _check_active(unit_id)
    if err != "":
        return {"ok": false, "error": err}
    if active.down:
        return {"ok": false, "error": "down"}
    var reach := reachable_for(active)
    if dest == active.pos or not reach.has(dest) or not reach[dest].can_stop:
        return {"ok": false, "error": "unreachable"}
    var info: Dictionary = reach[dest]
    var path := Pathing.path_to(reach, dest)
    var origin := active.pos
    active.move_left = active.move_budget() - int(info.cost)   # o movimento pode ser fracionado
    active.pos = dest
    active.moved = true
    idle_streak = 0
    if not path.is_empty():   # passa a olhar para onde andou
        var prev: Vector2i = path[path.size() - 2] if path.size() > 1 else origin
        active.facing = dominant_dir(prev, path[path.size() - 1])
    unit_moved.emit(active, path)
    if info.damage > 0:
        _damage(active, info.damage, "fall")
    if active.is_alive():
        _opportunity_attacks(active, origin, dest)
    _after_action()
    return {"ok": true, "damage": info.damage, "path": path}
func attack(unit_id: int, target_id: int) -> Dictionary:
    var err := _check_active(unit_id)
    if err != "":
        return {"ok": false, "error": err}
    if active.acted:
        return {"ok": false, "error": "already_acted"}
    var t := unit_by_id(target_id)
    if t == null or not t.is_alive() or t == active:
        return {"ok": false, "error": "invalid_target"}
    if not can_hit(active, t):
        return {"ok": false, "error": "out_of_range"}
    var base := attack_damage(active, t)
    active.acted = true
    active.facing = dominant_dir(active.pos, t.pos)
    idle_streak = 0
    var dmg := _resolve_hit(active, t, base, "normal")   # esquiva, parry e bloqueio rolam em segundo plano
    attack_resolved.emit(active, t, t.pos, dmg)
    if dmg > 0:
        _damage(t, dmg, "attack", active)
        if t.team != active.team:   # so golpes que acertam inimigos rendem XP
            _grant_xp(active, t)
    _after_action()
    return {"ok": true, "damage": dmg}


func attack_tile(unit_id: int, p: Vector2i) -> Dictionary:
    var err := _check_active(unit_id)
    if err != "":
        return {"ok": false, "error": err}
    if active.acted:
        return {"ok": false, "error": "already_acted"}
    if not tile_in_range(active, p):
        return {"ok": false, "error": "out_of_range"}
    for u in units:
        if u.is_alive() and u.pos == p:
            return attack(unit_id, u.id)
    active.acted = true
    idle_streak = 0
    attack_resolved.emit(active, null, p, 0)
    _after_action()
    return {"ok": true, "damage": 0}


func _grant_xp(a: Unit, t: Unit) -> void :
    var base := Progression.action_xp(rules, not t.is_alive())
    if not t.is_alive():
        a.kills += 1
    var cm := Progression.xp_modifier(rules, a.char_level, t.char_level)
    var jm := Progression.xp_modifier(rules, a.job_level, t.job_level)
    var char_xp := int(floor(base * cm))
    var job_xp := int(floor(base * jm))
    a.xp_earned += char_xp
    a.job_xp_earned += job_xp
    xp_gained.emit(a, job_xp, char_xp, Progression.modifier_flag(rules, cm))
func apply_command(cmd: Dictionary) -> Dictionary:
    if not cmd.has("t") or not cmd.has("unit"):
        return {"ok": false, "error": "bad_command"}
    var uid := int(cmd["unit"])
    var kind := str(cmd["t"])
    if not pending_reaction.is_empty() and kind != "react_move" and kind != "react_skip":
        return {"ok": false, "error": "reaction_pending"}
    if awaiting_facing and kind != "face":
        return {"ok": false, "error": "awaiting_facing"}
    match kind:
        "move":
            if not cmd.has("x") or not cmd.has("y"):
                return {"ok": false, "error": "bad_command"}
            return move(uid, Vector2i(int(cmd["x"]), int(cmd["y"])))
        "attack":
            if cmd.has("target"):
                return attack(uid, int(cmd["target"]))
            if cmd.has("x") and cmd.has("y"):
                return attack_tile(uid, Vector2i(int(cmd["x"]), int(cmd["y"])))
            return {"ok": false, "error": "bad_command"}
        "switch":
            if not cmd.has("to"):
                return {"ok": false, "error": "bad_command"}
            return switch_active(uid, int(cmd["to"]))
        "stand":
            return stand(uid)
        "face":
            if not cmd.has("dir"):
                return {"ok": false, "error": "bad_command"}
            return face(uid, int(cmd["dir"]))
        "react_move":
            if not cmd.has("x") or not cmd.has("y"):
                return {"ok": false, "error": "bad_command"}
            return react_move(uid, Vector2i(int(cmd["x"]), int(cmd["y"])))
        "react_skip":
            return react_skip(uid)
        "wait":
            var err := _check_active(uid)
            if err != "":
                return {"ok": false, "error": err}
            end_turn()
            return {"ok": true}
    return {"ok": false, "error": "bad_command"}


func switch_active(from_id: int, to_id: int) -> Dictionary:
    var err := _check_active(from_id)
    if err != "":
        return {"ok": false, "error": err}
    if active.moved or active.acted:
        return {"ok": false, "error": "already_started"}
    var to := unit_by_id(to_id)
    if to == null or to == active or not ready_alternates(active).has(to):
        return {"ok": false, "error": "not_ready"}
    active = to
    _reset_turn_flags(to)
    active_switched.emit(to)
    turn_started.emit(to)
    if rules.get_bool("turn", "auto_end") and not has_actions(to):
        idle_streak += 1
        end_turn()
    return {"ok": true}
func state_hash() -> int:
    var arr := []
    for u in units:
        arr.append([u.id, u.pos.x, u.pos.y, u.hp, u.ct, u.moved, u.acted, u.move_left,
                u.facing.x, u.facing.y, u.down, u.reacted, u.dying_turns])
    arr.append(active.id if active != null else -1)
    arr.append(turn_serial)
    arr.append(winner)
    arr.append(awaiting_facing)
    arr.append(str(pending_reaction))
    arr.append(combat_rng.state)
    return str(arr).hash()
func end_turn() -> void:
    if is_over() or active == null:
        return
    if active.team in manual_facing_teams and not awaiting_facing and active.is_alive():
        awaiting_facing = true   # antes de passar a vez, o jogador escolhe para que lado o personagem fica virado
        facing_requested.emit(active)
        return
    _end_turn_now()


func _end_turn_now() -> void:
    if is_over() or active == null:
        return
    awaiting_facing = false
    if _has_dying_units():
        idle_streak = 0
    elif active.is_alive() and not active.moved and not active.acted:
        idle_streak += 1
    turns.end_turn(active, active.moved, active.acted)
    _begin_turn()


func _check_active(unit_id: int) -> String:
    if is_over():
        return "match_over"
    if active == null or active.id != unit_id:
        return "not_active"
    return ""
func _reset_turn_flags(u: Unit) -> void:
    u.moved = false
    u.acted = false
    u.reacted = false   # a reacao so vale uma vez entre os turnos do personagem
    u.move_left = u.move


func _damage(u: Unit, amount: int, reason: String, attacker: Unit = null) -> void :
    var previous_hp := u.hp
    u.hp = maxi(0, u.hp - amount)
    unit_hurt.emit(u, amount, reason)
    if previous_hp > 0 and u.hp == 0:
        u.dying_turns = _dying_duration(u, attacker, amount, reason, previous_hp)
        idle_streak = 0
        unit_died.emit(u)


func _dying_duration(victim: Unit, attacker: Unit, amount: int, reason: String,
        previous_hp: int) -> int:
    var duration := combat_rng.randi_range(2, 7)
    var victim_resolve := clampi(victim.fe, 0, 100) + clampi(victim.bravura, 0, 100)
    var attacker_resolve := 100
    if attacker != null:
        attacker_resolve = clampi(attacker.fe, 0, 100) + clampi(attacker.bravura, 0, 100)
    duration += clampi(roundi(float(victim_resolve - attacker_resolve) / 50.0), -2, 2)

    if reason == "attack" and amount * 100 >= victim.max_hp * 60:
        duration -= 1
    if amount >= previous_hp + ceili(float(victim.max_hp) * 0.6):
        duration -= 1
    return clampi(duration, 2, 7)
func _after_action() -> void:
    if _check_victory():
        return
    if not pending_reaction.is_empty():
        return   # espera a resposta do movimento extra
    if not active.is_alive():
        _end_turn_now()
        return
    if rules.get_bool("turn", "auto_end") and not has_actions(active):
        end_turn()


func _begin_turn() -> void :
    while true:
        if _check_victory():
            return
        if turn_serial >= rules.get_int("match", "max_turns") or idle_streak >= units.size() * 2:
            _finish(DRAW)
            return
        active = turns.next_unit(units)
        if active == null:
            _finish(DRAW)
            return
        turn_serial += 1
        if active.is_dying():
            active.dying_turns -= 1
            unit_dying_turn.emit(active, active.dying_turns)
            if active.dying_turns == 0:
                unit_expired.emit(active)
            turns.end_turn(active, false, false)
            continue
        _reset_turn_flags(active)
        turn_started.emit(active)
        if rules.get_bool("turn", "auto_end") and not has_actions(active):
            if _has_dying_units():
                idle_streak = 0
            else:
                idle_streak += 1
            turns.end_turn(active, false, false)
            continue
        return


func _check_victory() -> bool:
    if winner != ONGOING:
        return true
    var alive_teams := {}
    for u in units:
        if u.is_alive():
            alive_teams[u.team] = true
    if alive_teams.size() <= 1:
        _finish(alive_teams.keys()[0] if alive_teams.size() == 1 else DRAW)
        return true
    return false


func _finish(w: int) -> void :
    winner = w
    match_over.emit(w)


# ---------------------------------------------------------------- lados, defesas e reacoes

static func dominant_dir(from: Vector2i, to: Vector2i) -> Vector2i:
    var d := to - from
    if d == Vector2i.ZERO:
        return Vector2i.ZERO
    if absi(d.x) >= absi(d.y):
        return Vector2i(signi(d.x), 0)
    return Vector2i(0, signi(d.y))


## De que lado do defensor o ataque vem: "front" (de frente), "side" (lateral) ou "back" (costas).
func side_of_attack(attacker: Unit, defender: Unit) -> String:
    var d := dominant_dir(defender.pos, attacker.pos)
    var dot := d.x * defender.facing.x + d.y * defender.facing.y
    if dot > 0:
        return "front"
    return "back" if dot < 0 else "side"


func _rc(key: String) -> float:
    return float(rules.data["reactions"][key])


func _agi(u: Unit) -> int:
    return int(u.attrs.get("agilidade", 5))


func _roll() -> float:
    if not roll_override.is_empty():
        return float(roll_override.pop_front())
    return combat_rng.randf() * 100.0


## Chance (0 a 100) de `defender` esquivar (velocidade), aparar (agilidade) ou bloquear (defesa).
## De frente: +10% nos testes defensivos; pelo lado ou pelas costas o atacante ganha 10% de correcao.
func defense_chance(kind: String, attacker: Unit, defender: Unit) -> float:
    var base := 0.0
    var diff := 0.0
    match kind:
        "dodge":
            base = _rc("dodge_base")
            diff = float(defender.speed - attacker.speed)
        "parry":
            base = _rc("parry_base")
            diff = float(_agi(defender) - _agi(attacker))
        "block":
            base = _rc("block_base")
            diff = float(defender.defense) - attacker.atk * 0.5
    var c := clampf(base + diff * _rc("per_point"), _rc("min"), _rc("max"))
    match side_of_attack(attacker, defender):
        "front":
            c *= 1.0 + _rc("front_bonus_pct") / 100.0
        "side":
            c *= 1.0 - _rc("flank_penalty_pct") / 100.0
        "back":
            c *= 1.0 - _rc("back_penalty_pct") / 100.0
    return clampf(c, 0.0, 100.0)


## Aplica os testes de defesa e devolve o dano que realmente entra.
## mode: "normal" (testes + segundos testes), "reaction" (so os testes; ataques de reacao nao geram novas reacoes),
## "unresistable" (nao pode ser esquivado, aparado nem bloqueado).
func _resolve_hit(attacker: Unit, defender: Unit, base: int, mode: String) -> int:
    if mode == "unresistable" or not reactions_enabled or defender.down:
        return base
    for kind in ["dodge", "parry", "block"]:
        if _roll() < defense_chance(kind, attacker, defender):
            _on_defended(kind, attacker, defender, base, mode)
            return 0
    return base


func _on_defended(kind: String, attacker: Unit, defender: Unit, base: int, mode: String) -> void:
    reaction_event.emit(defender, kind, {"dodge": "Esquiva", "parry": "Parry", "block": "Bloqueio"}[kind])
    if mode != "normal":
        return
    var ratio := _rc("second_ratio")
    var chance := _rc("second_chance")
    match kind:
        "dodge":   # dano grande demais para a velocidade: ganha um movimento extra (usar na hora ou cancelar)
            if base >= ratio * defender.speed and not defender.reacted and _roll() < chance:
                pending_reaction = {"type": "extra_move", "unit": defender.id, "budget": int(_rc("extra_move"))}
                reaction_event.emit(defender, "extra_move", "Movimento extra")
        "parry":   # dano defletido pequeno para a agilidade: contra-ataque automatico que nao pode ser resistido
            if base <= ratio * _agi(defender) and not defender.reacted and can_hit(defender, attacker) and _roll() < chance:
                defender.reacted = true
                reaction_event.emit(defender, "counter", "Contra-ataque")
                var dmg := attack_damage(defender, attacker)
                attack_resolved.emit(defender, attacker, attacker.pos, dmg)
                _damage(attacker, dmg, "attack", defender)
                if attacker.team != defender.team:
                    _grant_xp(defender, attacker)
        "block":   # dano muito maior que a forca: absorve tudo, mas o defensor cai
            if base >= ratio * int(defender.attrs.get("forca", 5)) and _roll() < chance:
                defender.down = true
                reaction_event.emit(defender, "fall", "Caiu")


static func _adjacent(a: Vector2i, b: Vector2i) -> bool:
    return absi(a.x - b.x) + absi(a.y - b.y) == 1


## Ao sair de uma casa vizinha a um inimigo, ele pode (teste de agilidade) dar um golpe automatico.
func _opportunity_attacks(mover: Unit, origin: Vector2i, dest: Vector2i) -> void:
    if not reactions_enabled:
        return
    for e in units:
        if not mover.is_alive():
            return
        if e == mover or not e.is_alive() or e.team == mover.team or e.reacted or e.down:
            continue
        if _adjacent(origin, e.pos) and not _adjacent(dest, e.pos):
            var chance := clampf(_rc("oa_base") + float(_agi(e) - _agi(mover)) * _rc("per_point"), _rc("min"), _rc("max"))
            if _roll() < chance:
                e.reacted = true
                reaction_event.emit(e, "oa", "Ataque de oportunidade")
                var dmg := _resolve_hit(e, mover, attack_damage(e, mover), "reaction")
                attack_resolved.emit(e, mover, mover.pos, dmg)
                if dmg > 0:
                    _damage(mover, dmg, "attack", e)
                    _grant_xp(e, mover)


## Levantar (personagem caido): gasta a acao de movimento.
func stand(unit_id: int) -> Dictionary:
    var err := _check_active(unit_id)
    if err != "":
        return {"ok": false, "error": err}
    if not active.down or active.moved:
        return {"ok": false, "error": "not_down"}
    active.down = false
    active.moved = true
    active.move_left = 0
    idle_streak = 0
    reaction_event.emit(active, "stand", "Levantou")
    _after_action()
    return {"ok": true}


## Escolhe o lado para onde o personagem fica virado ao terminar o turno (0..3 = direcoes de BattleMap.DIRS).
func face(unit_id: int, dir_index: int) -> Dictionary:
    if not awaiting_facing or active == null or active.id != unit_id:
        return {"ok": false, "error": "not_awaiting_facing"}
    if dir_index < 0 or dir_index >= BattleMap.DIRS.size():
        return {"ok": false, "error": "bad_command"}
    active.facing = BattleMap.DIRS[dir_index]
    _end_turn_now()
    return {"ok": true}


## Dono do movimento extra pendente (null se nao ha).
func pending_unit() -> Unit:
    return unit_by_id(int(pending_reaction["unit"])) if not pending_reaction.is_empty() else null


func react_move(unit_id: int, dest: Vector2i) -> Dictionary:
    if pending_reaction.is_empty() or int(pending_reaction["unit"]) != unit_id or str(pending_reaction["type"]) != "extra_move":
        return {"ok": false, "error": "no_reaction"}
    var u := unit_by_id(unit_id)
    var saved := u.move_left
    u.move_left = int(pending_reaction["budget"])
    var reach := reachable_for(u)
    u.move_left = saved
    if dest == u.pos or not reach.has(dest) or not reach[dest].can_stop:
        return {"ok": false, "error": "unreachable"}
    var info: Dictionary = reach[dest]
    var path := Pathing.path_to(reach, dest)
    u.pos = dest
    u.reacted = true
    pending_reaction = {}
    unit_moved.emit(u, path)
    if info.damage > 0:
        _damage(u, info.damage, "fall")
    _after_action()
    return {"ok": true}


func react_skip(unit_id: int) -> Dictionary:
    if pending_reaction.is_empty() or int(pending_reaction["unit"]) != unit_id:
        return {"ok": false, "error": "no_reaction"}
    pending_reaction = {}
    _after_action()
    return {"ok": true}
