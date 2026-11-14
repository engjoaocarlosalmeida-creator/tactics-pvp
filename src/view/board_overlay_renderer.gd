extends Node
class_name BoardOverlayRenderer

var game_view_ref
var hover_marker: MeshInstance3D
var click_marker: Node3D
var _mats := {}


func setup(gv) -> void:
    game_view_ref = gv
    hover_marker = MeshInstance3D.new()
    var hb := BoxMesh.new()
    var hover_size := MapGeometry.TILE_SIZE * 0.98
    hb.size = Vector3(hover_size, 0.06, hover_size)
    hover_marker.mesh = hb
    hover_marker.material_override = mat(Color(1, 1, 1, 0.3), true)
    hover_marker.visible = false
    gv.add_child(hover_marker)

    click_marker = Node3D.new()
    click_marker.visible = false
    var cm := mat(Color(1.0, 0.92, 0.25, 0.95), true)
    var marker_edge := MapGeometry.TILE_SIZE * 0.46
    var marker_length := MapGeometry.TILE_SIZE * 0.9
    var marker_thickness := MapGeometry.TILE_SIZE * 0.07
    for spec in [[Vector3(0, 0, -marker_edge), Vector3(marker_length, 0.05, marker_thickness)],
            [Vector3(0, 0, marker_edge), Vector3(marker_length, 0.05, marker_thickness)],
            [Vector3(-marker_edge, 0, 0), Vector3(marker_thickness, 0.05, marker_length)],
            [Vector3(marker_edge, 0, 0), Vector3(marker_thickness, 0.05, marker_length)]]:
        var side := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = spec[1]
        side.mesh = bm
        side.material_override = cm
        side.position = spec[0]
        click_marker.add_child(side)
    gv.add_child(click_marker)


func mat(color: Color, translucent := false) -> StandardMaterial3D:
    var key := "%s_%s" % [color.to_html(true), translucent]
    if _mats.has(key):
        return _mats[key]
    var m_std := StandardMaterial3D.new()
    m_std.albedo_color = color
    if translucent:
        m_std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m_std.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    else:
        m_std.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    _mats[key] = m_std
    return m_std


func add_marker(p: Vector2i, color: Color) -> void:
    var mi := MeshInstance3D.new()
    var box := BoxMesh.new()
    var marker_size := MapGeometry.TILE_SIZE * 0.9
    box.size = Vector3(marker_size, 0.04, marker_size)
    mi.mesh = box
    mi.material_override = mat(color, true)
    mi.position = MapGeometry.tile_pos(game_view_ref.m.map, p) + Vector3(0, 0.03, 0)
    game_view_ref.overlay_root.add_child(mi)


func add_label(p: Vector2i, text: String, color: Color, size: int, corner: float) -> Label3D:
    var l := Label3D.new()
    l.text = text
    l.modulate = color
    l.font = UITheme.bold_font
    l.font_size = size
    l.pixel_size = 0.0065
    l.outline_size = 10
    l.outline_modulate = Color(0, 0, 0, 0.9)
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = (corner == 0.0)
    var base := MapGeometry.tile_pos(game_view_ref.m.map, p)
    l.position = base + Vector3(corner, 0.12, corner)
    if corner == 0.0:
        game_view_ref.overlay_root.add_child(l)
    else:
        game_view_ref.labels_root.add_child(l)
    return l


func label_free_heights() -> int:
    var n := 0
    for c in game_view_ref.labels_root.get_children():
        if c is Label3D:
            n += 1
    return n


func update_click_marker() -> void:
    if game_view_ref.m == null or game_view_ref.selected_tile == Picking.NONE:
        click_marker.visible = false
        return
    click_marker.visible = true
    click_marker.position = MapGeometry.tile_pos(game_view_ref.m.map, game_view_ref.selected_tile) + Vector3(0, 0.08, 0)


func set_hover(p: Vector2i) -> void:
    game_view_ref.hover = p
    if p == Picking.NONE or game_view_ref.m == null:
        hover_marker.visible = false
    else:
        hover_marker.visible = true
        hover_marker.position = MapGeometry.tile_pos(game_view_ref.m.map, p) + Vector3(0, 0.06, 0)


func hide_markers() -> void:
    if hover_marker != null:
        hover_marker.visible = false
    if click_marker != null:
        click_marker.visible = false
