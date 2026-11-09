## Sprites e retratos das classes (arte final: Aprendiz, Arqueiro, Escudeiro, Lutador; provisoria: as
## outras 4).
class_name JobArt
extends RefCounted




const FINAL_ART := ["aprendiz", "arqueiro", "escudeiro", "lutador"]
static var _cache := {}


static func has_own_art(job_id: String) -> bool:
    return FINAL_ART.has(job_id)


static func is_provisional(job_id: String) -> bool:
    return not FINAL_ART.has(job_id)


static func _load(kind: String, job_id: String, look: String) -> Texture2D:
    var jid := job_id if job_id != "" else "escudeiro"
    var path := "res://assets/classes/%s_%s_%s.png" % [jid, "f" if look == "f" else "m", kind]
    if not _cache.has(path):
        _cache[path] = load(path) if ResourceLoader.exists(path) else null
    return _cache[path]


static func body(job_id: String, look: String) -> Texture2D:
    return _load("body", job_id, look)


static func face(job_id: String, look: String) -> Texture2D:
    return _load("face", job_id, look)
