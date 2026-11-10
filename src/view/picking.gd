## Escolha da casa sob o mouse por raio (DDA na grade, sem fisica).
class_name Picking
extends RefCounted


const NONE := Vector2i(-1, -1)



static func ray_box(origin: Vector3, dir: Vector3, bmin: Vector3, bmax: Vector3) -> float:
    var tmin := 0.0
    var tmax := INF
    for axis in 3:
        var o: float = origin[axis]
        var d: float = dir[axis]
        if absf(d) < 1e-09:
            if o < bmin[axis] or o > bmax[axis]:
                return -1.0
        else:
            var t1: float = (bmin[axis] - o) / d
            var t2: float = (bmax[axis] - o) / d
            if t1 > t2:
                var tmp := t1
                t1 = t2
                t2 = tmp
            tmin = maxf(tmin, t1)
            tmax = minf(tmax, t2)
            if tmin > tmax:
                return -1.0
    return tmin




static func pick_tile(map: BattleMap, origin: Vector3, dir: Vector3) -> Vector2i:
    var grid_origin := Vector3(
            origin.x / MapGeometry.TILE_SIZE + map.width / 2.0,
            origin.y,
            origin.z / MapGeometry.TILE_SIZE + map.depth / 2.0)
    var grid_dir := Vector3(
            dir.x / MapGeometry.TILE_SIZE,
            dir.y,
            dir.z / MapGeometry.TILE_SIZE)

    var top := MapGeometry.top_y(map, Vector2i.ZERO) + 20.0
    var t0 := 0.0
    var t1 := 1000.0
    for axis in 3:
        var o: float = [grid_origin.x, grid_origin.y, grid_origin.z][axis]
        var d: float = [grid_dir.x, grid_dir.y, grid_dir.z][axis]
        var lo := 0.0
        var hi: float = [float(map.width), top, float(map.depth)][axis]
        if absf(d) < 1e-09:
            if o < lo or o > hi:
                return NONE
        else:
            var ta := (lo - o) / d
            var tb := (hi - o) / d
            if ta > tb:
                var tmp := ta
                ta = tb
                tb = tmp
            t0 = maxf(t0, ta)
            t1 = minf(t1, tb)
            if t0 > t1:
                return NONE
    var px := grid_origin.x + grid_dir.x * (t0 + 0.0001)
    var pz := grid_origin.z + grid_dir.z * (t0 + 0.0001)
    var cx := clampi(int(floor(px)), 0, map.width - 1)
    var cz := clampi(int(floor(pz)), 0, map.depth - 1)
    var step_x := 1 if dir.x > 0 else -1
    var step_z := 1 if dir.z > 0 else -1
    var tdx := absf(1.0 / grid_dir.x) if absf(grid_dir.x) > 1e-09 else INF
    var tdz := absf(1.0 / grid_dir.z) if absf(grid_dir.z) > 1e-09 else INF
    var next_x := (cx + (1 if step_x > 0 else 0) - grid_origin.x) / grid_dir.x \
            if absf(grid_dir.x) > 1e-09 else INF
    var next_z := (cz + (1 if step_z > 0 else 0) - grid_origin.z) / grid_dir.z \
            if absf(grid_dir.z) > 1e-09 else INF
    while cx >= 0 and cz >= 0 and cx < map.width and cz < map.depth:
        var p := Vector2i(cx, cz)
        var c := MapGeometry.center_xz(map, p)
        var half_tile := MapGeometry.TILE_SIZE * 0.5
        var t := ray_box(origin, dir,
                Vector3(c.x - half_tile, 0.0, c.y - half_tile),
                Vector3(c.x + half_tile, MapGeometry.column_top(map, p), c.y + half_tile))
        if t >= 0.0:
            return NONE if map.is_blocked(p) else p
        if next_x < next_z:
            if next_x > t1:
                break
            cx += step_x
            next_x += tdx
        else:
            if next_z > t1:
                break
            cz += step_z
            next_z += tdz
    return NONE
