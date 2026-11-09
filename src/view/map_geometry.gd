## Conversao casa<->mundo 3D e malha da rampa escorregadia.
class_name MapGeometry
extends RefCounted


const TILE_H := 0.5
const ROCK_EXTRA := 1.0
const SLOPE_DROP := 0.45


static func top_y(map: BattleMap, p: Vector2i) -> float:
    return (map.height_at(p) + 1) * TILE_H


static func column_top(map: BattleMap, p: Vector2i) -> float:
    return top_y(map, p) + (ROCK_EXTRA if map.is_blocked(p) else 0.0)


static func center_xz(map: BattleMap, p: Vector2i) -> Vector2:
    return Vector2(p.x + 0.5 - map.width / 2.0, p.y + 0.5 - map.depth / 2.0)



static func tile_pos(map: BattleMap, p: Vector2i) -> Vector3:
    var c := center_xz(map, p)
    var y := top_y(map, p)
    if map.kind_at(p) == BattleMap.Kind.SLIPPERY and map.slope_dir(p) != Vector2i.ZERO:
        y -= SLOPE_DROP * 0.5
    return Vector3(c.x, y, c.y)



static func slope_mesh(map: BattleMap, p: Vector2i) -> ArrayMesh:
    var top := top_y(map, p)
    var d := map.slope_dir(p)
    var half := 0.5

    var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
    var h := []
    for c in corners:
        var low: bool = (d.x != 0 and int(c.x) == d.x) or (d.y != 0 and int(c.y) == d.y)
        h.append(top - (SLOPE_DROP if low else 0.0))
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_smooth_group(-1)
    var top_v: Array[Vector3] = []
    var base_v: Array[Vector3] = []
    for i in 4:
        top_v.append(Vector3(corners[i].x * half, h[i], corners[i].y * half))
        base_v.append(Vector3(corners[i].x * half, 0.0, corners[i].y * half))

    for idx in [0, 1, 2, 0, 2, 3]:
        st.add_vertex(top_v[idx])

    for i in 4:
        var j := (i + 1) % 4
        for v in [base_v[i], base_v[j], top_v[j], base_v[i], top_v[j], top_v[i]]:
            st.add_vertex(v)
    st.generate_normals()
    return st.commit()
