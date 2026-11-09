## XP por acao e modificador pelo nivel do alvo (teto +20%), setas de sinalizacao e aplicacao ao
## personagem.
class_name Progression
extends RefCounted





static func action_xp(rules: Rules, killed: bool) -> int:
    return rules.get_int("progression", "xp_per_attack") + (rules.get_int("progression", "xp_per_kill") if killed else 0)



static func xp_modifier(rules: Rules, attacker_level: int, target_level: int) -> float:
    var ratio := float(target_level) / float(maxi(attacker_level, 1))
    if ratio < 1.0:
        return ratio
    return minf(ratio, 1.0 + rules.get_int("progression", "xp_mod_cap_percent") / 100.0)



static func modifier_flag(rules: Rules, modifier: float) -> int:
    var pct := snappedf((modifier - 1.0) * 100.0, 0.001)
    var limit := float(rules.get_int("progression", "xp_flag_percent"))
    if pct > limit:
        return 1
    if pct < - limit:
        return -1
    return 0




static func apply_xp(rules: Rules, catalog: JobCatalog, characters: Dictionary, u: Unit, job_xp: int, char_xp: int = -1) -> Dictionary:
    if u.character_id < 0 or not characters.has(u.character_id):
        return {}
    var res: Dictionary = characters[u.character_id].add_xp(rules, catalog, job_xp, char_xp)
    res["xp"] = job_xp
    res["char_xp"] = job_xp if char_xp < 0 else char_xp
    return res
