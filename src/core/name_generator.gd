## Sorteia nome e sobrenome tradicionais (data/names.json) conforme sexo, fe e bravura.
class_name NameGenerator
extends RefCounted



const PATH := "res://data/names.json"
const REGIONS := ["sul", "norte", "asia", "europa"]
static var _data: Dictionary = {}


static func data() -> Dictionary:
    if _data.is_empty():
        var f := FileAccess.open(PATH, FileAccess.READ)
        if f != null:
            var parsed = JSON.parse_string(f.get_as_text())
            if typeof(parsed) == TYPE_DICTIONARY:
                _data = parsed
    return _data



static func weights(bravura: int, fe: int) -> Dictionary:
    return {"devoto": 1.0 + maxf(0.0, fe - 60.0) / 8.0, 
            "valente": 1.0 + maxf(0.0, bravura - 60.0) / 8.0, 
            "neutro": 3.0}


static func pick_tag(rng: RandomNumberGenerator, bravura: int, fe: int) -> String:
    var w := weights(bravura, fe)
    var total: float = w["devoto"] + w["valente"] + w["neutro"]
    var roll := rng.randf() * total
    if roll < w["devoto"]:
        return "devoto"
    if roll < w["devoto"] + w["valente"]:
        return "valente"
    return "neutro"



static func generate(rng: RandomNumberGenerator, sex: String, bravura: int, fe: int) -> Dictionary:
    var d := data()
    var tag := pick_tag(rng, bravura, fe)
    var region: String = REGIONS[rng.randi() % REGIONS.size()]
    var pool: Array = d["female" if sex == "f" else "male"][tag][region]
    var first: String = pool[rng.randi() % pool.size()]
    var surname_region: String = region if rng.randf() < 0.7 else REGIONS[rng.randi() % REGIONS.size()]
    var surnames: Array = d["surnames"][surname_region]
    var last: String = surnames[rng.randi() % surnames.size()]
    return {"first": first, "last": last, "full": "%s %s" % [first, last], "tag": tag, "region": region}
