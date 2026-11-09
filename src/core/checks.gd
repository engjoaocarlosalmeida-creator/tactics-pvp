## Testes de aplicar/resistir efeitos com os atributos natos: fe para magia, bravura para fisico e
## mental. (Ainda sem habilidades que o usem.)
class_name Checks
extends RefCounted




const MAGIC := "magic"
const PHYSICAL := "physical"
const MENTAL := "mental"



static func stat_for(kind: String) -> String:
    match kind:
        MAGIC:
            return "fe"
        PHYSICAL, MENTAL:
            return "bravura"
    push_error("tipo de efeito desconhecido: %s" % kind)
    return "bravura"


static func innate(u: Unit, stat: String) -> int:
    return u.fe if stat == "fe" else u.bravura



static func apply_chance(rules: Rules, kind: String, attacker: Unit, defender: Unit) -> float:
    var stat := stat_for(kind)
    var diff := innate(attacker, stat) - innate(defender, stat)
    var raw := rules.get_float("checks", "base") + diff * rules.get_float("checks", "per_point")
    return clampf(raw, rules.get_float("checks", "min"), rules.get_float("checks", "max"))



static func resist_chance(rules: Rules, kind: String, attacker: Unit, defender: Unit) -> float:
    return 100.0 - apply_chance(rules, kind, attacker, defender)



static func roll_apply(rules: Rules, kind: String, attacker: Unit, defender: Unit, 
        rng: RandomNumberGenerator) -> bool:
    return rng.randf() * 100.0 < apply_chance(rules, kind, attacker, defender)
