## Peso carregado x forca: capacidade, penalidade de movimento e limite maximo de carga.
class_name Encumbrance
extends RefCounted





static func capacity(rules: Rules, forca: int) -> int:
    return rules.get_int("items", "capacity_base") + rules.get_int("items", "capacity_per_forca") * forca


static func total_weight(catalog: ItemCatalog, item_ids: Array) -> int:
    var w := 0
    for id in item_ids:
        w += catalog.weight(str(id))
    return w


static func move_penalty(rules: Rules, cap: int, weight: int) -> int:
    var free := cap * rules.get_float("items", "free_fraction")
    if weight <= free:
        return 0
    return int(ceil((weight - free) / (cap * rules.get_float("items", "step_fraction"))))


static func max_weight(rules: Rules, cap: int) -> int:
    return int(floor(cap * rules.get_float("items", "max_overload")))
