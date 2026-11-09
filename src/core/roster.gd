## Elenco do jogador (8 personagens, 2 times) e estoque de itens; salva/carrega user://roster.json.
class_name Roster
extends RefCounted


const SAVE_PATH := "user://roster.json"
const VERSION := 1

var characters: Array[Character] = []
var stash: Dictionary = {}

const STARTER_STASH := {"espada_curta": 2, "arco_curto": 1, "cajado": 1, "escudo_madeira": 2, 
        "armadura_couro": 2, "armadura_ferro": 1, "pocao": 6, "corda": 2}


static func create_default(rules: Rules, catalog: JobCatalog, roster_seed: int = 2026) -> Roster:
    var ro := Roster.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = roster_seed
    var jobs := ["escudeiro", "aprendiz", "lutador", "escudeiro", "lutador", "escudeiro", "aprendiz", "lutador"]
    for i in 8:

        ro.characters.append(Character.create_new(i, "", jobs[i], rules, catalog, rng, "m" if i % 2 == 0 else "f"))
    ro.stash = STARTER_STASH.duplicate()
    return ro



func team_chars(team: int, per_team: int) -> Array:
    var out: Array = []
    for i in mini(per_team, 4):
        out.append(characters[team * 4 + i])
    return out


var _by_id := {}



func by_id() -> Dictionary:
    if _by_id.size() != characters.size():
        _by_id = {}
        for c in characters:
            _by_id[c.id] = c
    return _by_id


func to_dict() -> Dictionary:
    var list := []
    for c in characters:
        list.append(c.to_dict())
    return {"version": VERSION, "characters": list, "stash": stash.duplicate()}


static func from_dict(d: Dictionary, catalog: JobCatalog) -> Roster:
    var ro := Roster.new()
    if int(d.get("version", 0)) != VERSION or typeof(d.get("characters")) != TYPE_ARRAY:
        return null
    for cd in d["characters"]:
        var c := Character.from_dict(cd)
        if not catalog.has_job(c.job_id):
            return null
        ro.characters.append(c)
    if ro.characters.size() != 8:
        return null
    if d.has("stash") and typeof(d["stash"]) == TYPE_DICTIONARY:
        for k in d["stash"]:
            ro.stash[str(k)] = int(d["stash"][k])
    else:
        ro.stash = STARTER_STASH.duplicate()
    return ro



func give_item(c: Character, rules: Rules, catalog: ItemCatalog, item_id: String) -> bool:
    if int(stash.get(item_id, 0)) <= 0 or not c.add_item(rules, catalog, item_id):
        return false
    stash[item_id] = int(stash[item_id]) - 1
    return true



func take_back_item(c: Character, item_id: String) -> bool:
    if not c.remove_item(item_id):
        return false
    stash[item_id] = int(stash.get(item_id, 0)) + 1
    return true


func save(path: String = SAVE_PATH) -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify(to_dict(), "  "))
    return true



static func load_or_default(rules: Rules, catalog: JobCatalog, path: String = SAVE_PATH) -> Roster:
    if FileAccess.file_exists(path):
        var f := FileAccess.open(path, FileAccess.READ)
        if f != null:
            var json := JSON.new()
            if json.parse(f.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
                var ro := Roster.from_dict(json.data, catalog)
                if ro != null:
                    return ro
    return create_default(rules, catalog)
