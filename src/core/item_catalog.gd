## Catalogo de itens (data/items.json): nome, peso, tipo, icone. Os 8 itens atuais sao exemplos sem
## efeitos.
class_name ItemCatalog
extends RefCounted


const PATH := "res://data/items.json"
static var _default: ItemCatalog

var items: Dictionary = {}


static func get_default() -> ItemCatalog:
    if _default == null:
        _default = ItemCatalog.new()
        var f := FileAccess.open(PATH, FileAccess.READ)
        if f != null:
            var parsed = JSON.parse_string(f.get_as_text())
            if typeof(parsed) == TYPE_DICTIONARY:
                _default.items = parsed
    return _default


func has_item(id: String) -> bool:
    return items.has(id)


func item_name(id: String) -> String:
    return str(items[id].name) if items.has(id) else id


func weight(id: String) -> int:
    return int(items[id].weight) if items.has(id) else 0


func kind(id: String) -> String:
    return str(items[id].get("kind", "")) if items.has(id) else ""


func icon(id: String) -> String:
    return str(items[id].get("icon", "items")) if items.has(id) else "items"


func ids() -> Array[String]:
    var out: Array[String] = []
    for k in items:
        out.append(str(k))
    out.sort()
    return out
