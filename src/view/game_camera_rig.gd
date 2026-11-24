class_name GameCameraRig
extends Node3D

signal camera_changed

var game_view_ref
var _follow_timer := 0.0
var _rc_start := Vector2.ZERO
var _rc_dragged := false

var _cine_active := false
var _cine_pair: Array[int] = []
var _cine_target_pos := Vector3.ZERO
var _cine_target_yaw := 0.0
var _cine_target_pitch := -42.0
var _cine_target_distance := 16.0


func is_locked() -> bool:
    if game_view_ref == null or game_view_ref.game_visual_presenter == null:
        return false
    return game_view_ref.game_visual_presenter.is_busy()


func _is_same_pair(id_a: int, id_b: int) -> bool:
    if _cine_pair.is_empty():
        return false
    if id_b < 0:
        return _cine_pair.has(id_a)
    return _cine_pair.has(id_a) and _cine_pair.has(id_b)


func focus_movement(actor: Unit, destination: Vector2i) -> void:
    if game_view_ref == null or actor == null or not game_view_ref.unit_nodes.has(actor.id):
        return
    if _cine_active and _is_same_pair(actor.id, -1):
        return
    var start_pos: Vector3 = game_view_ref.unit_nodes[actor.id].position
    var end_pos: Vector3 = MapGeometry.tile_pos(game_view_ref.m.map, destination)
    _cine_active = true
    _cine_pair.assign([actor.id])
    _cine_target_pos = (start_pos + end_pos) * 0.5
    _cine_target_yaw = game_view_ref.yaw
    _cine_target_pitch = clampf(game_view_ref.pitch, -48.0, -34.0)
    var span := start_pos.distance_to(end_pos)
    _cine_target_distance = clampf(13.0 + span * 0.65, 13.0, 24.0)
    _follow_timer = 0.0


func focus_combat(attacker: Unit, target: Unit = null) -> void:
    if game_view_ref == null or attacker == null or not game_view_ref.unit_nodes.has(attacker.id):
        return
    var target_id := target.id if target != null and game_view_ref.unit_nodes.has(target.id) else -1
    if _cine_active and _is_same_pair(attacker.id, target_id):
        return
    var pos_a: Vector3 = game_view_ref.unit_nodes[attacker.id].position
    var pos_b: Vector3 = game_view_ref.unit_nodes[target_id].position if target_id >= 0 else pos_a
    _cine_active = true
    _cine_pair.assign([attacker.id, target_id] if target_id >= 0 else [attacker.id])
    _cine_target_pos = (pos_a + pos_b) * 0.5
    var diff := pos_b - pos_a
    diff.y = 0.0
    if diff.length_squared() > 0.01:
        var side_a := rad_to_deg(atan2(diff.z, -diff.x))
        var side_b := side_a + 180.0
        var cur_yaw: float = game_view_ref.yaw
        var diff_a := absf(rad_to_deg(angle_difference(deg_to_rad(cur_yaw), deg_to_rad(side_a))))
        var diff_b := absf(rad_to_deg(angle_difference(deg_to_rad(cur_yaw), deg_to_rad(side_b))))
        _cine_target_yaw = wrapf(side_a if diff_a <= diff_b else side_b, -180.0, 180.0)
    else:
        _cine_target_yaw = game_view_ref.yaw
    var separation := pos_a.distance_to(pos_b)
    _cine_target_pitch = -36.0
    _cine_target_distance = clampf(12.5 + separation * 0.85, 12.5, 25.0)
    _follow_timer = 0.0


func on_reaction(unit: Unit) -> void:
    if unit == null:
        return
    if _cine_active and _cine_pair.has(unit.id):
        return


func clear_cinematic() -> void:
    _cine_active = false
    _cine_pair.clear()


func _process(delta: float) -> void:
    if game_view_ref == null or game_view_ref.m == null:
        return
    var locked := is_locked()
    if not locked and not game_view_ref.test_mode and game_view_ref.screen == null:
        var shift := Input.is_key_pressed(KEY_SHIFT)
        var rot := 0.0
        if Input.is_key_pressed(KEY_Q):
            rot += 1.0
        if Input.is_key_pressed(KEY_E):
            rot -= 1.0
        var mv := Vector3.ZERO
        if not shift:
            if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
                mv.z -= 1
            if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
                mv.z += 1
            if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
                mv.x -= 1
            if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
                mv.x += 1
        if rot != 0.0:
            handle_rotation_input(rot * 90.0 * delta)
        if mv != Vector3.ZERO:
            handle_movement_input(mv)
        if (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER)) and game_view_ref.m.active != null:
            trigger_follow()
    if locked and _cine_active:
        var weight := clampf(6.5 * delta, 0.0, 1.0)
        game_view_ref.camera_pivot.position = game_view_ref.camera_pivot.position.lerp(_cine_target_pos, weight)
        game_view_ref.yaw = rad_to_deg(lerp_angle(deg_to_rad(game_view_ref.yaw), deg_to_rad(_cine_target_yaw), weight))
        game_view_ref.pitch = lerpf(game_view_ref.pitch, _cine_target_pitch, weight)
        game_view_ref.distance = lerpf(game_view_ref.distance, _cine_target_distance, weight)
        camera_changed.emit()
    elif _follow_timer > 0.0:
        _follow_timer = maxf(0.0, _follow_timer - delta)
        var target_pos: Vector3 = game_view_ref._actor_center()
        game_view_ref.camera_pivot.position = game_view_ref.camera_pivot.position.lerp(
                target_pos, clampf(6.0 * delta, 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
    if game_view_ref == null or game_view_ref.m == null or game_view_ref.screen != null:
        return
    if is_locked():
        return
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            if event.pressed:
                _rc_start = event.position
                _rc_dragged = false
            elif _rc_dragged:
                get_viewport().set_input_as_handled()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            if (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
                game_view_ref.yaw += 15.0
            else:
                game_view_ref.distance = clampf(game_view_ref.distance - 2.0, 8.0, 60.0)
            camera_changed.emit()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            if (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
                game_view_ref.yaw -= 15.0
            else:
                game_view_ref.distance = clampf(game_view_ref.distance + 2.0, 8.0, 60.0)
            camera_changed.emit()
    elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
        if event.position.distance_to(_rc_start) > 6.0:
            _rc_dragged = true
        game_view_ref.yaw -= event.relative.x * 0.3
        game_view_ref.pitch = clampf(game_view_ref.pitch - event.relative.y * 0.2, -80.0, -25.0)
        camera_changed.emit()


func handle_rotation_input(amount: float) -> void:
    if game_view_ref == null or is_locked():
        return
    game_view_ref.yaw += amount
    camera_changed.emit()


func handle_movement_input(mv: Vector3) -> void:
    if game_view_ref == null or game_view_ref.camera_pivot == null or is_locked():
        return
    var delta := get_process_delta_time()
    var yaw_rad := deg_to_rad(game_view_ref.yaw)
    var forward := Vector3(-sin(yaw_rad), 0.0, -cos(yaw_rad))
    var right := Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad))
    var dir := (right * mv.x - forward * mv.z).normalized()
    var speed := clampf(game_view_ref.distance * 0.85, 10.0, 35.0)
    var next_pos: Vector3 = game_view_ref.camera_pivot.position + dir * speed * delta
    var limit: Vector3 = game_view_ref._pan_limit()
    next_pos.x = clampf(next_pos.x, -limit.x, limit.x)
    next_pos.z = clampf(next_pos.z, -limit.z, limit.z)
    game_view_ref.camera_pivot.position = next_pos


func trigger_follow(_pos = null) -> void:
    if game_view_ref == null or is_locked():
        return
    _follow_timer = 1.1
