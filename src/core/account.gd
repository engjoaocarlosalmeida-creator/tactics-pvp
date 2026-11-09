## Conta do jogador real: nome e sexo (editaveis uma unica vez), avatar, titulo, borda, patente por
## rank PVP e scores (partidas, abates). Salva em user://account.json.
class_name Account
extends RefCounted



const PATH := "user://account.json"
const RANKS := [["Recruta", 0], ["Soldado", 100], ["Cabo", 250], ["Sargento", 450], ["Tenente", 700], 
        ["Capitão", 1000], ["Major", 1400], ["Coronel", 1900], ["General", 2500]]
const RANK_WIN := 25
const RANK_LOSS := -10

const TITLES := {
    "novato": ["Novato", "matches", 0], 
    "veterano": ["Veterano", "matches", 10], 
    "cacador": ["Caçador de Unidades", "kills", 50], 
    "estrategista": ["Estrategista", "wins", 10], 
    "lenda": ["Lenda do Campo", "rank_points", 1000], 
}

const BORDERS := {
    "bronze": ["Bronze", Color(0.8, 0.52, 0.25), 0], 
    "prata": ["Prata", Color(0.78, 0.82, 0.9), 2], 
    "ouro": ["Ouro", Color(1.0, 0.84, 0.3), 5], 
    "ametista": ["Ametista", Color(0.72, 0.45, 0.95), 7], 
    "carmesim": ["Carmesim", Color(0.95, 0.25, 0.3), 8], 
}

var player_name := "Jogador"
var sex := "m"
var identity_edited := false
var avatar := "escudeiro_m"
var title_id := "novato"
var border_id := "bronze"
var matches := 0
var wins := 0
var losses := 0
var kills := 0
var rank_points := 0


static func create_new(rng: RandomNumberGenerator) -> Account:
    var a := Account.new()
    a.sex = "f" if rng.randf() < 0.5 else "m"
    var n := NameGenerator.generate(rng, a.sex, 50, 50)
    a.player_name = str(n["full"])
    a.avatar = "escudeiro_" + a.sex
    return a


func rank_index() -> int:
    var idx := 0
    for i in RANKS.size():
        if rank_points >= int(RANKS[i][1]):
            idx = i
    return idx


func rank_name() -> String:
    return str(RANKS[rank_index()][0])



func points_to_next_rank() -> int:
    var i := rank_index()
    return -1 if i >= RANKS.size() - 1 else int(RANKS[i + 1][1]) - rank_points



func record_match(unit_kills: int, won: bool, ranked: bool) -> void :
    matches += 1
    kills += unit_kills
    if won:
        wins += 1
    else:
        losses += 1
    if ranked:
        rank_points = maxi(0, rank_points + (RANK_WIN if won else RANK_LOSS))


func title_unlocked(id: String) -> bool:
    if not TITLES.has(id):
        return false
    var t: Array = TITLES[id]
    return int(get(str(t[1]))) >= int(t[2])


func border_unlocked(id: String) -> bool:
    return BORDERS.has(id) and rank_index() >= int(BORDERS[id][2])


func title_name() -> String:
    return str(TITLES[title_id][0]) if TITLES.has(title_id) else "Novato"


func border_color() -> Color:
    return BORDERS[border_id][1] if BORDERS.has(border_id) else Color.WHITE


func set_title(id: String) -> bool:
    if not title_unlocked(id):
        return false
    title_id = id
    return true


func set_border(id: String) -> bool:
    if not border_unlocked(id):
        return false
    border_id = id
    return true


func set_avatar(id: String) -> bool:
    var parts := id.split("_")
    if parts.size() != 2 or not JobCatalog.load_default().has_job(parts[0]) or not (parts[1] == "m" or parts[1] == "f"):
        return false
    avatar = id
    return true



func edit_identity(new_name: String, new_sex: String) -> bool:
    var n := new_name.strip_edges().substr(0, 30)
    if identity_edited or n == "" or not (new_sex == "m" or new_sex == "f"):
        return false
    player_name = n
    sex = new_sex
    identity_edited = true
    if avatar.ends_with("_m") or avatar.ends_with("_f"):
        avatar = avatar.substr(0, avatar.length() - 1) + new_sex
    return true


func to_dict() -> Dictionary:
    return {"name": player_name, "sex": sex, "edited": identity_edited, "avatar": avatar, "title": title_id, 
            "border": border_id, "matches": matches, "wins": wins, "losses": losses, "kills": kills, 
            "rank_points": rank_points}


static func from_dict(d: Dictionary) -> Account:
    var a := Account.new()
    a.player_name = str(d.get("name", "Jogador"))
    a.sex = "f" if str(d.get("sex", "m")) == "f" else "m"
    a.identity_edited = bool(d.get("edited", false))
    a.avatar = str(d.get("avatar", "escudeiro_" + a.sex))
    a.title_id = str(d.get("title", "novato"))
    a.border_id = str(d.get("border", "bronze"))
    a.matches = int(d.get("matches", 0))
    a.wins = int(d.get("wins", 0))
    a.losses = int(d.get("losses", 0))
    a.kills = int(d.get("kills", 0))
    a.rank_points = int(d.get("rank_points", 0))
    return a


func save(path: String = PATH) -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify(to_dict(), "  "))
    return true


static func load_or_create(path: String = PATH) -> Account:
    if FileAccess.file_exists(path):
        var f := FileAccess.open(path, FileAccess.READ)
        if f != null:
            var json := JSON.new()
            if json.parse(f.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
                return Account.from_dict(json.data)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var a := Account.create_new(rng)
    a.save(path)
    return a
