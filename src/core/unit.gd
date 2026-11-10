## Unidade em campo (dados de batalha). Criada a partir de um Character por Unit.from_character.
class_name Unit
extends RefCounted


var id: int = 0
var team: int = 0
var display_name: String = ""
var max_hp: int = 1
var hp: int = 1
var atk: int = 1
var defense: int = 0
var speed: int = 1
var move: int = 1
var jump: int = 1
var attack_range: int = 1
var pos: Vector2i = Vector2i.ZERO
var ct: int = 0
var moved: bool = false
var acted: bool = false
var customization: Dictionary = {}
var attrs: Dictionary = {}
var bravura: int = 50
var fe: int = 50
var job_id: String = ""
var ai_initiative: float = 0.0
var look: String = "m"
var attack_stat: String = "forca"
var character_id: int = -1
var kills: int = 0
var xp_earned: int = 0
var carry_weight: int = 0
var carry_capacity: int = 0
var move_penalty: int = 0
var items: Array[String] = []
var move_left: int = -1
var max_mp: int = 0
var mp: int = 0
var char_level: int = 1
var job_level: int = 1
var job_xp_earned: int = 0
var facing: Vector2i = Vector2i(0, 1)   # lado para onde esta virado (uma das 4 direcoes)
var down: bool = false                  # caido: precisa gastar a acao de movimento para levantar
var reacted: bool = false               # ja teve uma reacao desde o seu ultimo turno
var dying_turns: int = 0


func is_alive() -> bool:
    return hp > 0


func is_dying() -> bool:
    return hp <= 0 and dying_turns > 0


func is_expired() -> bool:
    return hp <= 0 and dying_turns <= 0



func short_name() -> String:
    return display_name.get_slice(" ", 0)



func move_budget() -> int:
    return move if move_left < 0 else mini(move, move_left)


static func create(unit_id: int, unit_team: int, unit_name: String, rules: Rules) -> Unit:
    var u := Unit.new()
    u.id = unit_id
    u.team = unit_team
    u.display_name = unit_name
    u.max_hp = rules.get_int("unit_defaults", "hp")
    u.hp = u.max_hp
    u.atk = rules.get_int("unit_defaults", "atk")
    u.defense = rules.get_int("unit_defaults", "defense")
    u.speed = rules.get_int("unit_defaults", "speed")
    u.move = rules.get_int("movement", "base_move")
    u.jump = rules.get_int("movement", "base_jump")
    u.attack_range = rules.get_int("combat", "attack_range")
    u.max_mp = rules.get_int("unit_defaults", "mp")
    u.mp = u.max_mp
    for a in Character.ATTRS:
        u.attrs[a] = rules.get_int("attributes", "start")
    u.bravura = rules.get_int("attributes", "innate_default")
    u.fe = rules.get_int("attributes", "innate_default")
    return u




static func from_character(unit_id: int, unit_team: int, c: Character, rules: Rules, 
        catalog: JobCatalog) -> Unit:
    var u := Unit.create(unit_id, unit_team, c.display_name, rules)
    u.character_id = c.id
    u.job_id = c.job_id
    u.look = c.look
    u.attrs = c.attrs.duplicate()
    u.bravura = c.bravura
    u.fe = c.fe
    u.ai_initiative = float(catalog.jobs[c.job_id].get("ai_initiative", 0.0))
    var start := rules.get_int("attributes", "start")
    var m: Dictionary = catalog.mods(c.job_id)
    var d_agi := int(c.attrs["agilidade"]) - start
    u.attack_stat = str(catalog.jobs[c.job_id].get("attack_stat", "forca"))
    var d_atk := int(c.attrs[u.attack_stat]) - start
    var d_con := int(c.attrs["constituicao"]) - start
    u.max_hp = maxi(1, u.max_hp + int(m.hp) + int(floor(d_con * rules.get_float("attributes", "hp_per_con"))))
    u.hp = u.max_hp
    u.atk = maxi(1, u.atk + int(m.atk) + int(floor(d_atk * rules.get_float("attributes", "atk_per_attack_stat"))))
    u.defense = maxi(0, u.defense + int(m.defense) + int(floor(d_con * rules.get_float("attributes", "defense_per_con"))))
    u.speed = maxi(1, u.speed + int(m.speed) + int(floor(d_agi * rules.get_float("attributes", "speed_per_agi"))))
    u.items = c.items.duplicate()
    u.char_level = c.char_level(rules)
    u.job_level = c.job_level(rules, c.job_id)
    u.max_mp = maxi(0, u.max_mp + int(c.attrs["inteligencia"] - start) * rules.get_int("attributes", "mp_per_int")
            + int(c.attrs["sabedoria"] - start) * rules.get_int("attributes", "mp_per_wis"))
    u.mp = u.max_mp
    var items_cat := ItemCatalog.get_default()
    u.carry_capacity = Encumbrance.capacity(rules, int(c.attrs["forca"]))
    u.carry_weight = Encumbrance.total_weight(items_cat, c.items)
    u.move_penalty = Encumbrance.move_penalty(rules, u.carry_capacity, u.carry_weight)
    u.move = maxi(1, u.move + int(m.move) - u.move_penalty)
    u.jump = maxi(0, u.jump + int(m.jump))
    u.attack_range = maxi(1, u.attack_range + int(m.range))
    return u
