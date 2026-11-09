## Catalogo de classes (data/jobs.json): arvore, bonus, atributo do ataque, requisitos de desbloqueio.
class_name JobCatalog
extends RefCounted



const DEFAULT_PATH := "res://data/jobs.json"
const MOD_KEYS := ["hp", "atk", "defense", "speed", "move", "jump", "range"]

var jobs: Dictionary = {}


static func load_default() -> JobCatalog:
    var c := JobCatalog.new()
    var f := FileAccess.open(DEFAULT_PATH, FileAccess.READ)
    if f == null:
        push_error("Nao foi possivel abrir %s" % DEFAULT_PATH)
        return c
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        c.jobs = parsed
    else:
        push_error("JSON invalido em %s" % DEFAULT_PATH)
    return c


func has_job(job_id: String) -> bool:
    return jobs.has(job_id)


func job_name(job_id: String) -> String:
    return str(jobs[job_id].name)


func mods(job_id: String) -> Dictionary:
    return jobs[job_id].mods


func starters() -> Array[String]:
    var out: Array[String] = []
    for id in jobs:
        if jobs[id].parent == null:
            out.append(str(id))
    out.sort()
    return out


func children(job_id: String) -> Array[String]:
    var out: Array[String] = []
    for id in jobs:
        if jobs[id].parent == job_id:
            out.append(str(id))
    out.sort()
    return out
