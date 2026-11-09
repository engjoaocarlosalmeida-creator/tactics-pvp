## Icones pequenos (acoes, itens, classes, sexo) de assets/icons.
class_name UIIcons
extends RefCounted


static var _cache := {}


static func get_icon(name: String) -> Texture2D:
    if not _cache.has(name):
        var path := "res://assets/icons/%s.png" % name
        _cache[name] = load(path) if ResourceLoader.exists(path) else null
    return _cache[name]


static func class_icon(job_id: String) -> Texture2D:
    return get_icon("class_" + job_id)
