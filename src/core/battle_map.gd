## Mapa 3D em grade: altura e tipo de cada casa (normal, escorregadia com inclinacao, bloqueada). Dados
## puros, sem visual.
class_name BattleMap
extends RefCounted



enum Kind{NORMAL, SLIPPERY, BLOCKED}

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var width: int
var depth: int
var heights := PackedInt32Array()
var kinds := PackedInt32Array()
var slopes := PackedInt32Array()


func _init(w: int = 1, d: int = 1) -> void :
    width = w
    depth = d
    heights.resize(w * d)
    kinds.resize(w * d)
    slopes.resize(w * d)
    slopes.fill(-1)


func idx(p: Vector2i) -> int:
    return p.y * width + p.x


func in_bounds(p: Vector2i) -> bool:
    return p.x >= 0 and p.y >= 0 and p.x < width and p.y < depth


func height_at(p: Vector2i) -> int:
    return heights[idx(p)]


func kind_at(p: Vector2i) -> int:
    return kinds[idx(p)]


func is_blocked(p: Vector2i) -> bool:
    return kinds[idx(p)] == Kind.BLOCKED


func set_tile(p: Vector2i, h: int, k: int = Kind.NORMAL, slope: int = -1) -> void :
    heights[idx(p)] = h
    kinds[idx(p)] = k
    slopes[idx(p)] = slope



func slope_dir(p: Vector2i) -> Vector2i:
    var i := slopes[idx(p)]
    return DIRS[i] if i >= 0 and kinds[idx(p)] == Kind.SLIPPERY else Vector2i.ZERO



func rotated(p: Vector2i) -> Vector2i:
    return Vector2i(width - 1 - p.x, depth - 1 - p.y)
