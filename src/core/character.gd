## Personagem persistente entre partidas: atributos, bravura/fe natas, sexo fixo, nome editavel uma
## vez, dois niveis (personagem e classe), pontos livres, itens carregados.
class_name Character
extends RefCounted



const ATTRS := ["agilidade", "forca", "constituicao", "carisma", "inteligencia", "sabedoria"]
const INNATE := ["bravura", "fe"]

var id: int = 0
var display_name: String = ""
var attrs: Dictionary = {}
var bravura: int = 50
var fe: int = 50
var job_id: String = ""
var job_xp: Dictionary = {}
var attr_points: int = 0
var look: String = "m"
var items: Array[String] = []
var char_xp: int = 0
var renamed: bool = false


static func create_new(char_id: int, char_name: String, starter_job: String, rules: Rules, 
		_catalog: JobCatalog, rng: RandomNumberGenerator, sex: String = "") -> Character:
	var c := Character.new()
	c.id = char_id
	for a in ATTRS:
		c.attrs[a] = rules.get_int("attributes", "start")
	c.bravura = rng.randi_range(rules.get_int("attributes", "innate_roll_min"), 
			rules.get_int("attributes", "innate_roll_max"))
	c.fe = rng.randi_range(rules.get_int("attributes", "innate_roll_min"), 
			rules.get_int("attributes", "innate_roll_max"))
	c.look = sex if sex == "m" or sex == "f" else ("f" if rng.randf() < 0.5 else "m")
	c.display_name = char_name if char_name != "" else str(NameGenerator.generate(rng, c.look, c.bravura, c.fe)["full"])
	c.job_id = starter_job
	c.job_xp[starter_job] = 0
	return c



static func classify(value: int) -> String:
	if value > 90:
		return "muito alta"
	if value > 70:
		return "alta"
	if value >= 50:
		return "média"
	return "baixa"


func first_name() -> String:
	return display_name.get_slice(" ", 0)



func rename(new_name: String) -> bool:
	var n := new_name.strip_edges().substr(0, 30)
	if renamed or n == "":
		return false
	display_name = n
	renamed = true
	return true



func char_level(rules: Rules) -> int:
	var base := float(rules.get_int("progression", "char_xp_base"))
	return mini(1 + int(floor(sqrt(float(char_xp) / base))), rules.get_int("progression", "max_char_level"))


static func char_xp_for_level(rules: Rules, level: int) -> int:
	return rules.get_int("progression", "char_xp_base") * (level - 1) * (level - 1)



func job_level(rules: Rules, jid: String) -> int:
	var xp := int(job_xp.get(jid, 0))
	var thresholds: Array = rules.data["progression"]["job_xp_thresholds"]
	var lvl := 1
	for i in range(1, thresholds.size()):
		if xp >= int(thresholds[i]):
			lvl = i + 1
	return lvl


func max_job_level(rules: Rules) -> int:
	return rules.data["progression"]["job_xp_thresholds"].size()


func is_unlocked(rules: Rules, catalog: JobCatalog, jid: String) -> bool:
	if not catalog.has_job(jid):
		return false
	var job: Dictionary = catalog.jobs[jid]
	if job.parent == null:
		return true
	return job_level(rules, str(job.parent)) >= int(job.requires_level)


func unlocked_jobs(rules: Rules, catalog: JobCatalog) -> Array[String]:
	var out: Array[String] = []
	for jid in catalog.jobs:
		if is_unlocked(rules, catalog, str(jid)):
			out.append(str(jid))
	out.sort()
	return out



func change_job(rules: Rules, catalog: JobCatalog, jid: String) -> bool:
	if not is_unlocked(rules, catalog, jid):
		return false
	job_id = jid
	if not job_xp.has(jid):
		job_xp[jid] = 0
	return true




func add_xp(rules: Rules, catalog: JobCatalog, job_amount: int, char_amount: int = -1) -> Dictionary:
	if char_amount < 0:
		char_amount = job_amount
	var before_level := job_level(rules, job_id)
	var before_char := char_level(rules)
	var before_unlocked := unlocked_jobs(rules, catalog)
	var cap: int = int(rules.data["progression"]["job_xp_thresholds"][max_job_level(rules) - 1])
	job_xp[job_id] = mini(int(job_xp.get(job_id, 0)) + maxi(job_amount, 0), cap)
	char_xp = mini(char_xp + maxi(char_amount, 0), Character.char_xp_for_level(rules, rules.get_int("progression", "max_char_level")))
	var gained := job_level(rules, job_id) - before_level
	var gained_char := char_level(rules) - before_char
	attr_points += gained_char * rules.get_int("attributes", "points_per_char_level")
	var new_jobs: Array[String] = []
	for j in unlocked_jobs(rules, catalog):
		if not before_unlocked.has(j):
			new_jobs.append(j)
	return {"levels_gained": gained, "char_levels_gained": gained_char, "new_jobs": new_jobs}



func spend_point(rules: Rules, attr: String) -> bool:
	if not ATTRS.has(attr) or attr_points <= 0:
		return false
	if int(attrs[attr]) >= rules.get_int("attributes", "max"):
		return false
	attrs[attr] = int(attrs[attr]) + 1
	attr_points -= 1
	return true


func carry_capacity(rules: Rules) -> int:
	return Encumbrance.capacity(rules, int(attrs["forca"]))


func carry_weight(catalog: ItemCatalog) -> int:
	return Encumbrance.total_weight(catalog, items)



func add_item(rules: Rules, catalog: ItemCatalog, item_id: String) -> bool:
	if not catalog.has_item(item_id):
		return false
	if carry_weight(catalog) + catalog.weight(item_id) > Encumbrance.max_weight(rules, carry_capacity(rules)):
		return false
	items.append(item_id)
	return true


func remove_item(item_id: String) -> bool:
	var i := items.find(item_id)
	if i < 0:
		return false
	items.remove_at(i)
	return true


func to_dict() -> Dictionary:
	return {"id": id, "name": display_name, "attrs": attrs.duplicate(), "bravura": bravura, "fe": fe, 
			"job_id": job_id, "job_xp": job_xp.duplicate(), "attr_points": attr_points, "look": look, "items": items.duplicate(), 
			"char_xp": char_xp, "renamed": renamed}


static func from_dict(d: Dictionary) -> Character:
	var c := Character.new()
	c.id = int(d["id"])
	c.display_name = str(d["name"])
	for a in ATTRS:
		c.attrs[a] = int(d["attrs"][a])
	c.bravura = int(d["bravura"])
	c.fe = int(d["fe"])
	c.job_id = str(d["job_id"])
	for k in d["job_xp"]:
		c.job_xp[str(k)] = int(d["job_xp"][k])
	c.attr_points = int(d["attr_points"])
	c.look = "f" if str(d.get("look", "m")) == "f" else "m"
	for it in d.get("items", []):
		c.items.append(str(it))
	c.char_xp = int(d.get("char_xp", 0))
	c.renamed = bool(d.get("renamed", false))
	return c
