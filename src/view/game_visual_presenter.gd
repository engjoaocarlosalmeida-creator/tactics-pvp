extends Node
class_name GameVisualPresenter

signal queue_drained

const CHARACTER_MODEL := preload("res://src/view/character_model.gd")
const TEAM_COLORS: Array[Color] = [Color(0.25, 0.55, 1.0), Color(1.0, 0.35, 0.3)]
const ALLY_COLOR := Color(0.3, 0.62, 1.0)
const ENEMY_COLOR := Color(0.95, 0.28, 0.25)
const SPRITE_H := 1.8

var game_view_ref
var units_root: Node3D
var _attack_animations := {}
var _reaction_animations := {}
var _pending_defensive_reactions := {}
var float_log: Array = []
const ATTACK_ANIMATIONS := ["espadada_dentroparafora", "espadada_foraparadentro"]
const WALK_STEP_DURATION := 0.16
const ATTACK_IMPACT_RATIO := 0.55
const DEFENSIVE_REACTION_DELAY := 0.12
var _attack_animation_index := {}
var _death_animation_started := {}
var _dying_turn_snapshots := {}
var committing_unit := -1
var _visual_queue: Array[Callable] = []
var _collecting_visual_events := false

func reset_visual_state() -> void:
	_attack_animation_index.clear()
	_attack_animations.clear()
	_reaction_animations.clear()
	_pending_defensive_reactions.clear()
	_death_animation_started.clear()
	_dying_turn_snapshots.clear()


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
		turns.modulate = Color(0.05, 0.05, 0.05)
		turns.outline_modulate = Color(0.95, 0.9, 0.85, 0.85)
		turns.no_depth_test = false
		turns.visible = true
		return
	var tu: int = game_view_ref.m.turns_until(u) if u.is_alive() else -1
	turns.text = str(tu) if tu >= 0 else "+"
	turns.no_depth_test = true
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
	return c


func _on_unit_animation_finished(animation_name: StringName, unit_id: int) -> void:
	var action := str(animation_name)
	_finish_attack_animation(unit_id, action)
	_finish_reaction_animation(unit_id, action)


func _trigger_defensive_reaction_animation(unit_id: int, kind: String, generation: int = -1) -> void:
	if generation >= 0 and generation != game_view_ref._visual_generation:
		return
	match kind:
		"block":
			_play_reaction_animation(unit_id, "defend")
		"dodge":
			_play_reaction_animation(unit_id, "dodge")
		"parry":
			_play_reaction_animation(unit_id, "parry")


func _play_reaction_animation(unit_id: int, action: String) -> void:
	if not game_view_ref.animate or not game_view_ref.unit_nodes.has(unit_id):
		return
	if _death_animation_started.has(unit_id):
		return
	var node: Node3D = game_view_ref.unit_nodes[unit_id]
	var body := node.get_node_or_null("Body") as Node3D
	if body == null:
		return
	if CHARACTER_MODEL.play_animation(body, action):
		_reaction_animations[unit_id] = action


func _finish_reaction_animation(unit_id: int, action: String) -> void:
	if _reaction_animations.has(unit_id) and _reaction_animations[unit_id] == action:
		_reaction_animations.erase(unit_id)
		if not _death_animation_started.has(unit_id) and game_view_ref.unit_nodes.has(unit_id):
			CHARACTER_MODEL.play_animation(game_view_ref.unit_nodes[unit_id].get_node("Body"), "Idle")


func _finish_attack_animation(unit_id: int, action: String) -> void:
	if _attack_animations.has(unit_id) and _attack_animations[unit_id] == action:
		_attack_animations.erase(unit_id)
		if game_view_ref.unit_nodes.has(unit_id):
			CHARACTER_MODEL.play_animation(game_view_ref.unit_nodes[unit_id].get_node("Body"), "Idle")
		anim_done()


func _present_reaction_event(u: Unit, kind: String, text: String) -> void:
	if game_view_ref.camera_rig != null:
		game_view_ref.camera_rig.on_reaction(u)
	if game_view_ref.unit_nodes.has(u.id):
		_float_text(game_view_ref.unit_nodes[u.id].position, text, game_view_ref.reaction_color(kind))
		if kind in ["block", "dodge", "parry"]:
			if game_view_ref.animate:
				_pending_defensive_reactions[u.id] = kind
			else:
				_trigger_defensive_reaction_animation(u.id, kind)
	float_log.append([text, kind])
	if float_log.size() > 30:
		float_log.pop_front()
	if game_view_ref.animate and kind != "oa" and kind != "counter":
		pause_sequence(1.0)

func build_units() -> void:
	for u in game_view_ref.m.units:
		var n := Node3D.new()
		var model := CHARACTER_MODEL.create_model(TEAM_COLORS[u.team], u.job_id)
		if model == null:
			continue
		CHARACTER_MODEL.set_facing(model, u.facing)
		var animation_player := CHARACTER_MODEL.animation_player(model)
		animation_player.animation_finished.connect(_on_unit_animation_finished.bind(u.id))
		n.add_child(model)
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
		var mat: StandardMaterial3D = game_view_ref.overlay_renderer.mat(colors[key])
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
			over.global_position = n.global_position + Vector3(0, 0.78, 0)
		else:
			over.global_position = n.global_position + Vector3(0, SPRITE_H * 0.5, 0) + up * (SPRITE_H * 0.5 + 0.14)
		var pointer: Label3D = over.get_node("Pointer")
		if pointer.visible:
			pointer.offset.y = 62.0 + sin(game_view_ref._t * 5.0) * 7.0

func _present_unit_moved(u: Unit, path: Array, destination: Vector2i, facing: Vector2i) -> void:
	if game_view_ref.camera_rig != null:
		game_view_ref.camera_rig.focus_movement(u, destination)
	var n: Node3D = game_view_ref.unit_nodes[u.id]
	CHARACTER_MODEL.set_facing(n.get_node("Body"), facing)
	if committing_unit == u.id or not game_view_ref.animate or path.is_empty():
		n.position = MapGeometry.tile_pos(game_view_ref.m.map, destination)
		CHARACTER_MODEL.play_animation(n.get_node("Body"), "Idle")
		return

	_animate_unit_path(u, path)


func _animate_unit_path(u: Unit, path: Array, on_finished := Callable()) -> void:
	var node: Node3D = game_view_ref.unit_nodes[u.id]
	var body: Node3D = node.get_node("Body")
	var previous := Vector2i(
			roundi(node.position.x / MapGeometry.TILE_SIZE + float(game_view_ref.m.map.width) / 2.0 - 0.5),
			roundi(node.position.z / MapGeometry.TILE_SIZE + float(game_view_ref.m.map.depth) / 2.0 - 0.5))
	game_view_ref.busy += 1
	var tw := create_tween()
	for point in path:
		var step: Vector2i = point
		var height_delta: int = game_view_ref.m.map.height_at(step) - game_view_ref.m.map.height_at(previous)
		var action := CHARACTER_MODEL.locomotion_action(height_delta)
		var duration := WALK_STEP_DURATION
		if height_delta != 0:
			duration = clampf(CHARACTER_MODEL.animation_duration(body, action) * 0.3, 0.3, 0.65)
		var direction := step - previous
		tw.tween_callback(_face_unit_for_step.bind(u.id, direction))
		tw.tween_callback(_play_unit_animation.bind(u.id, action, duration))
		tw.tween_property(node, "position", MapGeometry.tile_pos(game_view_ref.m.map, step), duration)
		previous = step
	tw.tween_callback(_finish_unit_movement.bind(u.id))
	tw.finished.connect(func():
		game_view_ref.busy = maxi(0, game_view_ref.busy - 1)
		if on_finished.is_valid():
			on_finished.call()
		drain_queue())


func _face_unit_for_step(unit_id: int, direction: Vector2i) -> void:
	if game_view_ref.unit_nodes.has(unit_id):
		CHARACTER_MODEL.set_facing(game_view_ref.unit_nodes[unit_id].get_node("Body"), direction)


func _play_unit_animation(unit_id: int, action: String, duration: float) -> void:
	if game_view_ref.unit_nodes.has(unit_id):
		_reaction_animations.erase(unit_id)
		var attack_action := str(_attack_animations.get(unit_id, ""))
		if attack_action != "" and attack_action != action:
			_finish_attack_animation(unit_id, attack_action)
		CHARACTER_MODEL.play_animation(game_view_ref.unit_nodes[unit_id].get_node("Body"), action, duration)


func _finish_unit_movement(unit_id: int) -> void:
	if game_view_ref.unit_nodes.has(unit_id):
		CHARACTER_MODEL.play_animation(game_view_ref.unit_nodes[unit_id].get_node("Body"), "Idle")


func _present_attack_resolved(attacker: Unit, facing: Vector2i, target: Unit = null,
		damage: int = 0, target_hp_before: int = 0) -> void:
	if game_view_ref.camera_rig != null:
		game_view_ref.camera_rig.focus_combat(attacker, target)
	if not game_view_ref.animate or not game_view_ref.unit_nodes.has(attacker.id):
		return
	if _attack_animations.has(attacker.id):
		_attack_animations.erase(attacker.id)
		game_view_ref.busy = maxi(0, game_view_ref.busy - 1)

	var index := int(_attack_animation_index.get(attacker.id, 0))
	var action: String = ATTACK_ANIMATIONS[index % ATTACK_ANIMATIONS.size()]
	_attack_animation_index[attacker.id] = index + 1
	var node: Node3D = game_view_ref.unit_nodes[attacker.id]
	CHARACTER_MODEL.set_facing(node.get_node("Body"), facing)
	if not CHARACTER_MODEL.play_animation(node.get_node("Body"), action):
		return

	_attack_animations[attacker.id] = action
	game_view_ref.busy += 1
	var duration := CHARACTER_MODEL.animation_duration(node.get_node("Body"), action)
	if target != null and _pending_defensive_reactions.has(target.id):
		var reaction_kind := str(_pending_defensive_reactions[target.id])
		_pending_defensive_reactions.erase(target.id)
		get_tree().create_timer(DEFENSIVE_REACTION_DELAY).timeout.connect(
				_trigger_defensive_reaction_animation.bind(
						target.id, reaction_kind, game_view_ref._visual_generation))
	if target != null and damage > 0:
		var impact_delay := duration * ATTACK_IMPACT_RATIO
		get_tree().create_timer(impact_delay).timeout.connect(
				_present_attack_impact.bind(
						target, damage, target_hp_before, game_view_ref._visual_generation))
	get_tree().create_timer(duration + 0.25).timeout.connect(
			_finish_attack_animation.bind(attacker.id, action))


func _present_attack_impact(target: Unit, damage: int, hp_before_hit: int,
		generation: int = -1) -> void:
	if (generation >= 0 and generation != game_view_ref._visual_generation) \
			or damage <= 0 or not game_view_ref.unit_nodes.has(target.id):
		return
	var hp_after_hit := maxi(0, hp_before_hit - damage)
	var node: Node3D = game_view_ref.unit_nodes[target.id]
	var hp_fill: Sprite3D = node.get_node("Over/HpFill")
	hp_fill.region_rect = Rect2(
			0, 0, maxf(0.0, 80.0 * float(hp_after_hit) / maxf(1.0, float(target.max_hp))), 8)
	hp_fill.visible = hp_after_hit > 0
	node.get_node("Over/HpBack").visible = hp_after_hit > 0
	game_view_ref.hud.add_log("%s perde %d de vida (ataque)" % [target.display_name, damage])

	var damage_ratio := float(damage) / maxf(1.0, float(target.max_hp))
	var damage_size := 32 + roundi(clampf(damage_ratio, 0.0, 1.5) * 18.0)
	_float_text(node.position, "-%d" % damage, Color(1, 0.4, 0.3), damage_size, 0.6)
	var body := node.get_node_or_null("Body") as Node3D
	if body != null:
		CHARACTER_MODEL.flash(body, create_tween())

	if hp_after_hit == 0:
		_start_death_animation(target, int(_dying_turn_snapshots.get(
				target.id, target.dying_turns)))
	else:
		_play_reaction_animation(target.id, "impact")


func _start_death_animation(u: Unit, turns_left: int) -> void:
	if _death_animation_started.has(u.id) or not game_view_ref.animate or not game_view_ref.unit_nodes.has(u.id):
		return
	var node: Node3D = game_view_ref.unit_nodes[u.id]
	var body := node.get_node_or_null("Body") as Node3D
	if body == null:
		return
	var action := "death_forward" if randi_range(0, 1) == 0 else "death_back"
	if not CHARACTER_MODEL.play_animation(body, action):
		return
	_death_animation_started[u.id] = action
	_show_dying_status(u, turns_left)
	game_view_ref.hud.add_log("%s caiu e está morrendo (%d turnos)." % [u.display_name, turns_left])
	game_view_ref.busy += 1
	var duration := CHARACTER_MODEL.animation_duration(body, action)
	get_tree().create_timer(duration + 0.25).timeout.connect(
			_anim_done_for_generation.bind(game_view_ref._visual_generation))


func _anim_done_for_generation(generation: int) -> void:
	if generation == game_view_ref._visual_generation:
		anim_done()


func _present_unit_hurt(u: Unit, amount: int, reason: String, hp_after_hit: int) -> void:
	var cause := "queda" if reason == "fall" else "ataque"
	var hp_fill: Sprite3D = game_view_ref.unit_nodes[u.id].get_node("Over/HpFill")
	var ratio := float(hp_after_hit) / maxf(1.0, float(u.max_hp))
	hp_fill.region_rect = Rect2(0, 0, maxf(0.0, 80.0 * ratio), 8)
	hp_fill.visible = hp_after_hit > 0
	game_view_ref.unit_nodes[u.id].get_node("Over/HpBack").visible = hp_after_hit > 0
	if reason == "attack" and game_view_ref.animate:
		return
	game_view_ref.hud.add_log("%s perde %d de vida (%s)" % [u.display_name, amount, cause])
	var node: Node3D = game_view_ref.unit_nodes[u.id]
	var damage_ratio := float(amount) / maxf(1.0, float(u.max_hp))
	var damage_size := 32 + roundi(clampf(damage_ratio, 0.0, 1.5) * 18.0)
	_float_text(node.position, "-%d" % amount, Color(1, 0.4, 0.3), damage_size, 0.6)
	if game_view_ref.animate:
		var body := node.get_node_or_null("Body") as Node3D
		if body != null:
			CHARACTER_MODEL.flash(body, create_tween())
		if u.is_dying():
			_start_death_animation(u, int(_dying_turn_snapshots.get(u.id, u.dying_turns)))
		pause_sequence(0.6)


func _present_unit_died(u: Unit, turns_left: int) -> void:
	if _death_animation_started.has(u.id):
		return
	game_view_ref.hud.add_log("%s caiu e está morrendo (%d turnos)." % [u.display_name, turns_left])
	_show_dying_status(u, turns_left)
	if not game_view_ref.animate:
		return
	_start_death_animation(u, turns_left)


func _present_unit_dying_turn(u: Unit, turns_left: int) -> void:
	if turns_left <= 0:
		game_view_ref.hud.add_log("%s não resistiu aos ferimentos." % u.display_name)
		if game_view_ref.animate:
			pause_sequence(0.25)
		return
	game_view_ref.hud.add_log("%s continua morrendo (%d turnos)." % [u.display_name, turns_left])
	_show_dying_status(u, turns_left)
	if game_view_ref.animate:
		_shake_dying_counter(u.id)
		pause_sequence(0.4)


func _shake_dying_counter(unit_id: int) -> void:
	if not game_view_ref.unit_nodes.has(unit_id):
		return
	var turns: Label3D = game_view_ref.unit_nodes[unit_id].get_node_or_null("Over/Turns")
	if turns == null or not turns.visible:
		return
	var base_offset := turns.offset
	var tw := create_tween()
	tw.tween_property(turns, "offset", base_offset + Vector2(-9.0, 0.0), 0.05)
	tw.tween_property(turns, "offset", base_offset + Vector2(9.0, 0.0), 0.05)
	tw.tween_property(turns, "offset", base_offset + Vector2(-6.0, 0.0), 0.05)
	tw.tween_property(turns, "offset", base_offset + Vector2(6.0, 0.0), 0.05)
	tw.tween_property(turns, "offset", base_offset, 0.05)


func _show_dying_status(u: Unit, turns_left: int) -> void:
	var node: Node3D = game_view_ref.unit_nodes[u.id]
	var hp_fill: Sprite3D = node.get_node("Over/HpFill")
	hp_fill.visible = false
	node.get_node("Over/ApFill").visible = false
	node.get_node("Over/ApBack").visible = false
	var turns: Label3D = node.get_node("Over/Turns")
	turns.text = str(turns_left)
	turns.offset = Vector2.ZERO
	turns.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turns.font_size = 52
	turns.modulate = Color(0.05, 0.05, 0.05)
	turns.outline_modulate = Color(0.95, 0.9, 0.85, 0.85)
	turns.no_depth_test = false
	turns.visible = true


func _present_unit_expired(u: Unit) -> void:
	var node: Node3D = game_view_ref.unit_nodes[u.id]
	var body := node.get_node_or_null("Body") as Node3D
	if body != null:
		node.remove_child(body)
		body.queue_free()
	var skull := CHARACTER_MODEL.create_skull(CHARACTER_MODEL.team_color(u.team))
	if skull != null:
		node.add_child(skull)
	node.get_node("Over/HpFill").visible = false
	node.get_node("Over/ApFill").visible = false
	node.get_node("Over/ApBack").visible = false
	node.get_node("Over/Turns").visible = false


func _present_xp_gained(u: Unit, job_xp: int, char_xp: int, flag: int) -> void:
	var res := Progression.apply_xp(game_view_ref.rules, game_view_ref.catalog, game_view_ref.roster.by_id(), u, job_xp, char_xp)
	if res.is_empty():
		return
	var cid := u.character_id
	var acc: Dictionary = game_view_ref.last_rewards.get(cid, {"xp": 0, "job_xp": 0, "levels_gained": 0, "char_levels_gained": 0, "new_jobs": []})
	acc.xp += char_xp
	acc.job_xp += job_xp
	acc.levels_gained += int(res.levels_gained)
	acc.char_levels_gained += int(res.char_levels_gained)
	for nj in res.new_jobs:
		acc.new_jobs.append(nj)
	game_view_ref.last_rewards[cid] = acc
	var arrow := " ▲" if flag > 0 else (" ▼" if flag < 0 else "")
	_float_text(game_view_ref.unit_nodes[u.id].position, "+%d XP%s" % [char_xp, arrow], Color(1, 0.9, 0.45) if flag >= 0 else Color(1, 0.55, 0.45))
	if res.char_levels_gained > 0:
		var ch: Character = game_view_ref.roster.by_id()[cid]
		game_view_ref.hud.add_log("%s subiu para o nível %d!" % [ch.first_name(), ch.char_level(game_view_ref.rules)])
	if res.levels_gained > 0:
		var ch2: Character = game_view_ref.roster.by_id()[cid]
		game_view_ref.hud.add_log("%s: classe nível %d!" % [ch2.first_name(), ch2.job_level(game_view_ref.rules, ch2.job_id)])
	game_view_ref.screen_router.save_roster()
	if game_view_ref.animate:
		pause_sequence(1.0)

func clear_queue() -> void:
	_visual_queue.clear()
	_collecting_visual_events = false


func begin_collecting() -> void:
	_collecting_visual_events = true


func end_collecting() -> void:
	_collecting_visual_events = false
	drain_queue()


func is_busy() -> bool:
	return game_view_ref.busy > 0 or not _visual_queue.is_empty() or _collecting_visual_events


func queue_action(action: Callable) -> void:
	_visual_queue.append(action)
	if not _collecting_visual_events:
		drain_queue()


func drain_queue() -> void:
	if _collecting_visual_events or game_view_ref.busy > 0:
		return
	while not _visual_queue.is_empty() and game_view_ref.busy == 0:
		var action: Callable = _visual_queue.pop_front()
		action.call()
	if _visual_queue.is_empty() and game_view_ref.busy == 0:
		if game_view_ref.camera_rig != null:
			game_view_ref.camera_rig.clear_cinematic()
		queue_drained.emit()


func pause_sequence(duration: float) -> void:
	game_view_ref.busy += 1
	get_tree().create_timer(duration).timeout.connect(anim_done)


func anim_done() -> void:
	game_view_ref.busy = maxi(0, game_view_ref.busy - 1)
	drain_queue()


func present_turn_started(u: Unit) -> void:
	var gv = game_view_ref
	gv.mode_pending = ""
	gv.menu_wanted = true
	gv.hud.set_hint("")
	gv.hud.add_log("Vez de %s (%s)" % [u.short_name(), gv._player_name(u.team)])
	gv.camera_rig.trigger_follow()


