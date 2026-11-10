## Bot tatico. Decide UM comando serializavel por vez (next_command) e joga turnos inteiros
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
    if u.acted and not u.moved and u.move_budget() > 0:
        var assault_destination := _best_assault_destination(m, u, rng)
        if assault_destination != u.pos:
            return {"t": "move", "unit": u.id,
                    "x": assault_destination.x, "y": assault_destination.y}
    if not u.moved and u.move_budget() > 0:
        var tactical_destination := _best_destination(m, u, rng)
        if tactical_destination != u.pos:
            var current_score := _position_score(m, u, u.pos, 0)
            var destination_info: Dictionary = m.reachable_for(u)[tactical_destination]
            var destination_score := _position_score(
                    m, u, tactical_destination, int(destination_info.damage))
            var can_attack_now := not u.acted and not m.targets_for(u).is_empty()
            var advances_on_enemy := _approach_score(m, u, tactical_destination) \
                    < _approach_score(m, u, u.pos)
            if (not can_attack_now and advances_on_enemy) \
                    or destination_score + 4 < current_score:
                return {"t": "move", "unit": u.id, "x": tactical_destination.x, "y": tactical_destination.y}
    var targets := m.targets_for(u)
    if not u.acted and not targets.is_empty():
        return {"t": "attack", "unit": u.id, "target": _choose_target(m, u, targets).id}
    if not u.moved:
        var dest := _best_destination(m, u, rng)
        if dest != u.pos:
            return {"t": "move", "unit": u.id, "x": dest.x, "y": dest.y}
    return {"t": "wait", "unit": u.id}


static func _best_assault_destination(m: MatchState, u: Unit, rng: RandomNumberGenerator) -> Vector2i:
    var reach := m.reachable_for(u)
    var objectives: Array[Unit] = []
    for enemy in m.units:
        if enemy.is_alive() and enemy.team != u.team \
                and not m.tile_in_range_from(u, u.pos, enemy.pos):
            objectives.append(enemy)
    if objectives.is_empty():
        return u.pos

    var current_distance := _nearest_objective_distance(m, objectives, u.pos)
    var best_distance := current_distance
    var best_score := INF
    var best_positions: Array[Vector2i] = []
    for position in reach:
        if position == u.pos or not reach[position].can_stop:
            continue
        var distance := _nearest_objective_distance(m, objectives, position)
        if distance >= current_distance:
            continue
        var score := _position_score(m, u, position, int(reach[position].damage))
        if distance < best_distance:
            best_distance = distance
            best_score = score
            best_positions = [position]
        elif distance == best_distance:
            if score < best_score:
                best_score = score
                best_positions = [position]
            elif score == best_score:
                best_positions.append(position)
    if best_positions.is_empty():
        return u.pos
    return best_positions[rng.randi_range(0, best_positions.size() - 1)]


static func _nearest_objective_distance(
        m: MatchState, objectives: Array[Unit], position: Vector2i) -> int:
    var distance := 1000000
    for enemy in objectives:
        var candidate := absi(position.x - enemy.pos.x) + absi(position.y - enemy.pos.y)
        var height_difference := absi(m.map.height_at(position) - m.map.height_at(enemy.pos))
        var height_penalty := maxi(0, height_difference - m.rules.get_int("combat", "height_tolerance"))
        distance = mini(distance, candidate + height_penalty * 2)
    return distance



static func take_turn(m: MatchState, rng: RandomNumberGenerator) -> void :
    if m.active == null:
        return
    var serial := m.turn_serial
    var guard := 0
    while not m.is_over() and m.turn_serial == serial and guard < 8:
        guard += 1
        m.apply_command(next_command(m, rng))


static func _best_destination(m: MatchState, u: Unit, rng: RandomNumberGenerator) -> Vector2i:
    var reach := m.reachable_for(u)
    var options: Array[Vector2i] = []
    for p in reach:
        if reach[p].can_stop and p != u.pos:
            options.append(p)
    if options.is_empty():
        return u.pos
    var best: Vector2i = u.pos
    var best_score := _position_score(m, u, u.pos, 0)
    var best_positions: Array[Vector2i] = []
    for p in options:
        var score := _position_score(m, u, p, int(reach[p].damage))
        if score < best_score:
            best_score = score
            best_positions = [p]
        elif score == best_score:
            best_positions.append(p)
    if not best_positions.is_empty():
        best = best_positions[rng.randi_range(0, best_positions.size() - 1)]
    else:
        best = _best_safe_progress(m, u, options, reach, rng)
        if best == u.pos:
            best = _best_victory_progress(m, u, options, reach, rng)
    return best


static func _best_victory_progress(
        m: MatchState, u: Unit, options: Array[Vector2i], reach: Dictionary,
        rng: RandomNumberGenerator) -> Vector2i:
    var current_distance := _approach_score(m, u, u.pos)
    var advancing_positions: Array[Vector2i] = []
    var best_score := INF
    for position in options:
        if _approach_score(m, u, position) >= current_distance:
            continue
        var score := _position_score(m, u, position, int(reach[position].damage))
        if score < best_score:
            best_score = score
            advancing_positions = [position]
        elif score == best_score:
            advancing_positions.append(position)
    if advancing_positions.is_empty():
        return u.pos
    return advancing_positions[rng.randi_range(0, advancing_positions.size() - 1)]


static func _best_safe_progress(
        m: MatchState, u: Unit, options: Array[Vector2i], reach: Dictionary,
        rng: RandomNumberGenerator) -> Vector2i:
    var current_approach := _approach_score(m, u, u.pos)
    var lookahead := _lookahead_depth(m, u)
    var best_positions: Array[Vector2i] = []
    var best_score := INF
    for position in options:
        if _approach_score(m, u, position) >= current_approach:
            continue
        var movement_damage := int(reach[position].damage)
        var damage_tolerance := _damage_tolerance(m, u, position)
        if _incoming_damage(m, u, position, lookahead) + movement_damage \
                >= float(maxi(u.hp, 1)) * damage_tolerance:
            continue
        var score := _position_score(m, u, position, movement_damage)
        if score < best_score:
            best_score = score
            best_positions = [position]
        elif score == best_score:
            best_positions.append(position)
    if best_positions.is_empty():
        return u.pos
    return best_positions[rng.randi_range(0, best_positions.size() - 1)]


static func _position_score(m: MatchState, u: Unit, position: Vector2i, movement_damage: int) -> float:
    var tactical_value := 0.0
    for enemy in m.units:
        if not enemy.is_alive() or enemy.team == u.team:
            continue
        if not u.acted and m.tile_in_range_from(u, position, enemy.pos):
            var expected_damage := _expected_attack_damage(m, u, position, enemy, enemy.pos)
            var attack_value := expected_damage * (1.0 + _enemy_pressure(m, enemy) * 0.08)
            if expected_damage >= enemy.hp:
                attack_value += _elimination_value(m, enemy)
            tactical_value = maxf(tactical_value, attack_value)

    var intelligence := _intelligence(m, u)
    var incoming_damage := _incoming_damage(m, u, position, _lookahead_depth(m, u))
    var survivability := float(maxi(u.hp, 1)) / float(maxi(u.max_hp, 1))
    var bravery := clampf(float(u.bravura) / 100.0, 0.0, 1.0)
    var initiative := clampf(u.ai_initiative, -1.0, 1.0)
    var risk_aversion := clampf(
            2.2 - float(u.defense) * 0.07 - survivability * 0.35 \
                    - (bravery - 0.5) * 1.8 - initiative * 0.8,
            0.15, 2.4)
    var approach_factor := 1.0 + initiative * 0.65
    var faith_factor := clampf(float(u.fe) / 50.0, 0.0, 2.0)
    var support_value := _ally_support_value(m, u, position)
    return _approach_score(m, u, position) * approach_factor \
            + incoming_damage * risk_aversion \
            - tactical_value * 2.5 + _ally_crowding_penalty(m, u, position, intelligence) \
            - support_value * faith_factor * 2.0 + movement_damage * 3.0


static func _damage_tolerance(m: MatchState, u: Unit, position: Vector2i) -> float:
    var bravery := clampf(float(u.bravura) / 100.0, 0.0, 1.0)
    var initiative := clampf(u.ai_initiative, -1.0, 1.0)
    var faith := clampf(float(u.fe) / 100.0, 0.0, 1.0)
    var support_urgency := clampf(_ally_support_value(m, u, position) / 10.0, 0.0, 1.0)
    return clampf(0.55 + bravery * 0.45 + initiative * 0.25
            + faith * support_urgency * 0.3, 0.35, 1.4)


static func _approach_score(m: MatchState, u: Unit, position: Vector2i) -> float:
    var score := INF
    for enemy in m.units:
        if not enemy.is_alive() or enemy.team == u.team:
            continue
        var distance := absi(position.x - enemy.pos.x) + absi(position.y - enemy.pos.y)
        var height_difference := absi(m.map.height_at(position) - m.map.height_at(enemy.pos))
        var height_penalty := maxi(0, height_difference - m.rules.get_int("combat", "height_tolerance"))
        var range_error := maxi(0, distance - u.attack_range) * 10 + height_penalty * 15
        score = minf(score, range_error)
    return score


static func _ally_support_value(m: MatchState, u: Unit, position: Vector2i) -> float:
    var support_value := 0.0
    for ally in m.units:
        if ally == u or not ally.is_alive() or ally.team != u.team:
            continue
        var threatened_enemies: Array[Unit] = []
        for enemy in m.units:
            if enemy.is_alive() and enemy.team != u.team \
                    and m.tile_in_range_from(enemy, enemy.pos, ally.pos):
                threatened_enemies.append(enemy)
        var missing_health := 1.0 - float(ally.hp) / float(maxi(ally.max_hp, 1))
        var need := clampf(float(threatened_enemies.size()) * 0.35 + missing_health * 0.5,
                0.0, 1.0)
        if need <= 0.0:
            continue
        var distance := absi(position.x - ally.pos.x) + absi(position.y - ally.pos.y)
        var access := clampf((4.0 - float(distance)) / 3.0, 0.0, 1.0)
        support_value += need * access * 7.0
        for enemy in threatened_enemies:
            if m.tile_in_range_from(u, position, enemy.pos):
                support_value += need * 5.0
    return support_value


static func _allied_attack_pressure(m: MatchState, u: Unit, enemy: Unit) -> int:
    var pressure := 0
    for ally in m.units:
        if ally == u or not ally.is_alive() or ally.team != u.team:
            continue
        if m.tile_in_range_from(ally, ally.pos, enemy.pos):
            pressure += 12
    return pressure


static func _ally_crowding_penalty(m: MatchState, u: Unit, position: Vector2i, intelligence: int) -> int:
    var penalty := 0
    var fragility := maxi(1, u.max_hp / 10 - u.defense)
    for ally in m.units:
        if ally == u or not ally.is_alive() or ally.team != u.team:
            continue
        var distance := absi(position.x - ally.pos.x) + absi(position.y - ally.pos.y)
        if distance == 1:
            penalty += fragility * 2
        elif distance == 2:
            penalty += fragility / 2
    return penalty


static func _incoming_damage(m: MatchState, u: Unit, position: Vector2i, lookahead: int) -> float:
    var incoming_damage := 0.0
    var occupied := m.occupied()
    occupied.erase(u.pos)
    if occupied.has(position):
        return 100000.0
    occupied[position] = u
    for enemy in m.units:
        if not enemy.is_alive() or enemy.team == u.team:
            continue
        if m.tile_in_range_from(enemy, enemy.pos, position):
            incoming_damage += _expected_attack_damage(m, enemy, enemy.pos, u, position)
            continue
        if lookahead <= 0:
            continue
        var moves_per_turn := maxi(enemy.move, 1)
        var original_move := enemy.move
        var original_move_left := enemy.move_left
        enemy.move = moves_per_turn * lookahead
        enemy.move_left = -1
        var reachable := Pathing.reachable(m.map, m.rules, enemy, occupied, m.reserved_tiles())
        enemy.move = original_move
        enemy.move_left = original_move_left
        var attack_cost := 1000000
        var threat_position := enemy.pos
        for attack_position in reachable:
            if not m.tile_in_range_from(enemy, attack_position, position):
                continue
            var cost := int(reachable[attack_position].cost)
            if cost < attack_cost:
                attack_cost = cost
                threat_position = attack_position
        if attack_cost < 1000000:
            var turns_to_threat := ceili(float(attack_cost) / float(moves_per_turn))
            var attenuation := 1.0 / float(turns_to_threat + 1)
            incoming_damage += _expected_attack_damage(m, enemy, threat_position, u, position) * attenuation
    return incoming_damage


static func _starting_intelligence(m: MatchState) -> int:
    return m.rules.get_int("attributes", "start")


static func _intelligence(m: MatchState, u: Unit) -> int:
    return int(u.attrs.get("inteligencia", _starting_intelligence(m)))


static func _lookahead_depth(m: MatchState, u: Unit) -> int:
    return clampi((_intelligence(m, u) - _starting_intelligence(m)) / 8, 0, 3)


static func _expected_attack_damage(
        m: MatchState, attacker: Unit, attacker_position: Vector2i,
        defender: Unit, defender_position: Vector2i) -> float:
    var original_attacker_position := attacker.pos
    var original_defender_position := defender.pos
    attacker.pos = attacker_position
    defender.pos = defender_position
    var damage := float(m.attack_damage(attacker, defender))
    if m.reactions_enabled and not defender.down:
        for kind in ["dodge", "parry", "block"]:
            damage *= 1.0 - m.defense_chance(kind, attacker, defender) / 100.0
    attacker.pos = original_attacker_position
    defender.pos = original_defender_position
    return damage


static func _enemy_pressure(m: MatchState, enemy: Unit) -> int:
    var pressure := 0
    for ally in m.units:
        if ally.is_alive() and ally.team != enemy.team and m.can_hit(enemy, ally):
            pressure += 1
    return pressure


static func _choose_target(m: MatchState, u: Unit, targets: Array[Unit]) -> Unit:
    var best := targets[0]
    var best_score := -INF
    for target in targets:
        var expected_damage := _expected_attack_damage(m, u, u.pos, target, target.pos)
        var score := expected_damage + _enemy_pressure(m, target) * 3
        if expected_damage >= target.hp:
            score += _elimination_value(m, target)
        score -= _allied_attack_pressure(m, u, target) * 2
        if score > best_score:
            best_score = score
            best = target
    return best


static func _elimination_value(m: MatchState, target: Unit) -> float:
    var remaining_enemies := 0
    for unit in m.units:
        if unit.is_alive() and unit.team == target.team:
            remaining_enemies += 1
    return 1000.0 if remaining_enemies == 1 else 25.0
