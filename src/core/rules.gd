## Carrega data/rules.json. Todo numero de regra vem de la.
class_name Rules
extends RefCounted



const DEFAULT_PATH := "res://data/rules.json"

var data: Dictionary = {}


static func load_default() -> Rules:
    return Rules.load_from(DEFAULT_PATH)


static func load_from(path: String) -> Rules:
    var r := Rules.new()
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        push_error("Nao foi possivel abrir %s" % path)
        return r
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("JSON invalido em %s" % path)
        return r
    r.data = parsed
    return r


func get_int(section: String, key: String) -> int:
    var sec = data.get(section, {})
    if typeof(sec) != TYPE_DICTIONARY or not sec.has(key):
        return 0
    return int(sec.get(key, 0))


func get_float(section: String, key: String) -> float:
    var sec = data.get(section, {})
    if typeof(sec) != TYPE_DICTIONARY or not sec.has(key):
        return 0.0
    return float(sec.get(key, 0.0))


func get_bool(section: String, key: String) -> bool:
    var sec = data.get(section, {})
    if typeof(sec) != TYPE_DICTIONARY or not sec.has(key):
        return false
    return bool(sec.get(key, false))
