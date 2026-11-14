extends Node
class_name GameVisualPresenter

const CHARACTER_MODEL := preload("res://src/view/character_model.gd")
const TEAM_COLORS: Array[Color] = [Color(0.25, 0.55, 1.0), Color(1.0, 0.35, 0.3)]
const ALLY_COLOR := Color(0.3, 0.62, 1.0)
const ENEMY_COLOR := Color(0.95, 0.28, 0.25)
const SPRITE_H := 1.8

var game_view_ref
var units_root: Node3D
var _attack_animations := {}
var float_log: Array = []


func _ready():
	if game_view_ref == null or game_view_ref.m == null:
		return
	for u in game_view_ref.m.units:
		var n := Node3D.new()
		var model := CHARACTER_MODEL.create_model(TEAM_COLORS[u.team])
		if model == null:
			continue
		CHARACTER_MODEL.set_facing(model, u.facing)
		var animation_player := CHARACTER_MODEL.animation_player(model)
		animation_player.animation_finished.connect(_on_unit_animation_finished.bind(u.id))
		n.add_child(model)

		var ring := MeshInstance3D.new()
		ring.name = "Ring"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.4
		torus.outer_radius = 0.5
		ring.mesh = torus
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(1, 0.9, 0.2)
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = rmat
		ring.position.y = 0.06
		ring.visible = false
		n.add_child(ring)

		var over := Node3D.new()
		over.name = "Over"
		var back := _hp_sprite(Color(0.03, 0.04, 0.1, 0.95), 82.0, -41.0)
		back.name = "HpBack"
		over.add_child(back)
		var fill := _hp_sprite(ALLY_COLOR, 80.0, -40.0)
		fill.name = "HpFill"
		fill.render_priority = 1
		over.add_child(fill)
		var ap_back := _hp_sprite(Color(0.03, 0.04, 0.1, 0.9), 82.0, -41.0, 6, -10.0)
		ap_back.name = "ApBack"
		over.add_child(ap_back)
		var ap_fill := _hp_sprite(Color(1.0, 0.82, 0.25), 80.0, -40.0, 4, -10.0)
		ap_fill.name = "ApFill"
		ap_fill.render_priority = 1
		over.add_child(ap_fill)

		var turns := Label3D.new()
		turns.name = "Turns"
		turns.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		turns.font = UITheme.bold_font
		turns.font_size = 44
		turns.pixel_size = 0.0065
		turns.outline_size = 12
		turns.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		turns.offset = Vector2(-72, -4)
		turns.no_depth_test = true
		over.add_child(turns)

		var pointer := Label3D.new()
		pointer.name = "Pointer"
		pointer.text = "▼"
		pointer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pointer.font = UITheme.bold_font
		pointer.font_size = 64
		pointer.pixel_size = 0.0075
		pointer.modulate = Color(1.0, 0.86, 0.25)
		pointer.outline_size = 12
		pointer.offset = Vector2(0, 62)
		pointer.no_depth_test = true
		pointer.visible = false
		over.add_child(pointer)

		n.add_child(over)
		n.position = MapGeometry.tile_pos(game_view_ref.m.map, u.pos)
		game_view_ref.units_root.add_child(n)
		game_view_ref.unit_nodes[u.id] = n
		game_view_ref._update_unit_facing(u)
		_update_unit_visual(u)


func _update_unit_visual(u: Unit) -> void:
	var n: Node3D = game_view_ref.unit_nodes[u.id]
	var ally: bool = u.team == game_view_ref.ally_team()
	var col := ALLY_COLOR if ally else ENEMY_COLOR
	var fill: Sprite3D = n.get_node("Over/HpFill")
	var hp_back: Sprite3D = n.get_node("Over/HpBack")
	var ap: Sprite3D = n.get_node("Over/ApFill")
	var turns: Label3D = n.get_node("Over/Turns")
	if u.is_expired():
		fill.visible = false
		hp_back.visible = false
		ap.visible = false
		n.get_node("Over/ApBack").visible = false
		turns.visible = false
		return
	var ratio := float(u.hp) / maxf(1.0, float(u.max_hp))
	fill.region_rect = Rect2(0, 0, maxf(0.0, 80.0 * ratio), 8)
	fill.modulate = col
	fill.visible = u.hp > 0 and u.is_alive()
	hp_back.visible = fill.visible
	ap.region_rect = Rect2(0, 0, 80.0 * game_view_ref._action_remaining(u), 4)
	ap.visible = u.hp > 0
	n.get_node("Over/ApBack").visible = u.hp > 0
	if u.is_dying():
		turns.text = str(u.dying_turns)
		turns.offset = Vector2.ZERO
		turns.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		turns.font_size = 52
		turns.modulate = Color(1.0, 0.35, 0.35)
		turns.visible = true
		return
	var tu: int = game_view_ref.m.turns_until(u) if u.is_alive() else -1
	turns.text = str(tu) if tu >= 0 else "+"
	turns.modulate = col.lightened(0.35)
	turns.outline_modulate = col.darkened(0.15)
	turns.visible = u.is_alive()


func _float_text(pos: Vector3, text: String, color: Color, font_size := 34, duration := 1.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.font = UITheme.body_font
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.008
	l.font_size = font_size
	l.outline_size = 9
	game_view_ref.overlay_root.add_child(l)
	l.position = pos + Vector3(0, SPRITE_H + 0.35, 0)
	if game_view_ref.animate:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(l, "position:y", l.position.y + 0.7, duration)
		tw.tween_property(l, "modulate:a", 0.0, duration)
		tw.chain().tween_callback(l.queue_free)
	else:
		l.queue_free()


func _hp_sprite(color: Color, width_px: float, offset_x: float, height := 8, off_y := 0.0) -> Sprite3D:
	var s := Sprite3D.new()
	var img := Image.create(84, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	s.texture = ImageTexture.create_from_image(img)
	s.pixel_size = 0.01
	s.centered = false
	s.offset = Vector2(offset_x, off_y)
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, width_px, height)
	s.modulate = color
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	return s


func _tile_color(p: Vector2i) -> Color:
	var map: BattleMap = game_view_ref.m.map
	var c: Color
	match map.kind_at(p):
		BattleMap.Kind.SLIPPERY:
			c = Color(0.42, 0.72, 0.88)
		BattleMap.Kind.BLOCKED:
			c = Color(0.28, 0.28, 0.33)
		_:
			var t := float(map.height_at(p)) / maxf(1.0, float(game_view_ref.rules.get_int("map", "max_height")))
			c = Color(0.25, 0.5, 0.28).lerp(Color(0.8, 0.7, 0.48), t)
	if (p.x + p.y) % 2 == 0:
		c = c.darkened(0.06)
	return c


func _on_unit_animation_finished(animation_name: StringName, unit_id: int) -> void:
	_finish_attack_animation(unit_id, str(animation_name))


func _finish_attack_animation(unit_id: int, action: String) -> void:
	if _attack_animations.has(unit_id) and _attack_animations[unit_id] == action:
		_attack_animations.erase(unit_id)
		if game_view_ref.unit_nodes.has(unit_id):
			CHARACTER_MODEL.play_animation(game_view_ref.unit_nodes[unit_id].get_node("Body"), "Idle")
		game_view_ref._anim_done()


func _present_reaction_event(u: Unit, kind: String, text: String) -> void:
	if game_view_ref.unit_nodes.has(u.id):
		_float_text(game_view_ref.unit_nodes[u.id].position, text, game_view_ref.reaction_color(kind))
	float_log.append([text, kind])
	if float_log.size() > 30:
		float_log.pop_front()
	if game_view_ref.animate:
		game_view_ref._pause_visual_sequence(1.0)

func build_units() -> void:
	for u in game_view_ref.m.units:
		var n := Node3D.new()
		var model := CHARACTER_MODEL.create_model(TEAM_COLORS[u.team])
		if model == null:
			continue
		CHARACTER_MODEL.set_facing(model, u.facing)
		var animation_player := CHARACTER_MODEL.animation_player(model)
		animation_player.animation_finished.connect(_on_unit_animation_finished.bind(u.id))
		n.add_child(model)
		var ring := MeshInstance3D.new()
		ring.name = "Ring"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.4
		torus.outer_radius = 0.5
		ring.mesh = torus
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(1, 0.9, 0.2)
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = rmat
		ring.position.y = 0.06
		ring.visible = false
		n.add_child(ring)
		var over := Node3D.new()
		over.name = "Over"
		var back := _hp_sprite(Color(0.03, 0.04, 0.1, 0.95), 82.0, -41.0)
		back.name = "HpBack"
		over.add_child(back)
		var fill := _hp_sprite(ALLY_COLOR, 80.0, -40.0)
		fill.name = "HpFill"
		fill.render_priority = 1
		over.add_child(fill)
		var ap_back := _hp_sprite(Color(0.03, 0.04, 0.1, 0.9), 82.0, -41.0, 6, -10.0)
		ap_back.name = "ApBack"
		over.add_child(ap_back)
		var ap_fill := _hp_sprite(Color(1.0, 0.82, 0.25), 80.0, -40.0, 4, -10.0)
		ap_fill.name = "ApFill"
		ap_fill.render_priority = 1
		over.add_child(ap_fill)
		var turns := Label3D.new()
		turns.name = "Turns"
		turns.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		turns.font = UITheme.bold_font
		turns.font_size = 44
		turns.pixel_size = 0.0065
		turns.outline_size = 12
		turns.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		turns.offset = Vector2(-72, -4)
		turns.no_depth_test = true
		over.add_child(turns)
		var pointer := Label3D.new()
		pointer.name = "Pointer"
		pointer.text = "▼"
		pointer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pointer.font = UITheme.bold_font
		pointer.font_size = 64
		pointer.pixel_size = 0.0075
		pointer.modulate = Color(1.0, 0.86, 0.25)
		pointer.outline_size = 12
		pointer.offset = Vector2(0, 62)
		pointer.no_depth_test = true
		pointer.visible = false
		over.add_child(pointer)
		n.add_child(over)
		n.position = MapGeometry.tile_pos(game_view_ref.m.map, u.pos)
		game_view_ref.units_root.add_child(n)
		game_view_ref.unit_nodes[u.id] = n
		game_view_ref._update_unit_facing(u)
		_update_unit_visual(u)

func build_terrain() -> void:
	var map: BattleMap = game_view_ref.m.map
	var batches := {}
	var colors := {}
	for z in map.depth:
		for x in map.width:
			var p := Vector2i(x, z)
			var color := _tile_color(p)
			var key := color.to_html(false)
			if not batches.has(key):
				var new_batch := SurfaceTool.new()
				new_batch.begin(Mesh.PRIMITIVE_TRIANGLES)
				batches[key] = new_batch
				colors[key] = color
			var c := MapGeometry.center_xz(map, p)
			var batch_surface: SurfaceTool = batches[key]
			if map.kind_at(p) == BattleMap.Kind.SLIPPERY and map.slope_dir(p) != Vector2i.ZERO:
				batch_surface.append_from(MapGeometry.slope_mesh(map, p), 0, Transform3D(Basis.IDENTITY, Vector3(c.x, 0, c.y)))
			else:
				var top := MapGeometry.column_top(map, p)
				var box := BoxMesh.new()
				box.size = Vector3(MapGeometry.TILE_SIZE, top, MapGeometry.TILE_SIZE)
				batch_surface.append_from(box, 0, Transform3D(Basis.IDENTITY, Vector3(c.x, top / 2.0, c.y)))
	var mesh := ArrayMesh.new()
	for key in batches:
		var completed_batch: SurfaceTool = batches[key]
		completed_batch.commit(mesh)
		var mat: StandardMaterial3D = game_view_ref._mat(colors[key])
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	game_view_ref.terrain_root.add_child(mi)


func update_overheads() -> void:
	var up: Vector3 = game_view_ref.camera.global_transform.basis.y
	for id in game_view_ref.unit_nodes:
		var n: Node3D = game_view_ref.unit_nodes[id]
		var over: Node3D = n.get_node("Over")
		var u = game_view_ref.m.unit_by_id(int(id))
		if u != null and u.is_dying():
			over.global_position = n.global_position + Vector3(0, 0.35, 0)
		else:
			over.global_position = n.global_position + Vector3(0, SPRITE_H * 0.5, 0) + up * (SPRITE_H * 0.5 + 0.14)
		var pointer: Label3D = over.get_node("Pointer")
		if pointer.visible:
			pointer.offset.y = 62.0 + sin(game_view_ref._t * 5.0) * 7.0
