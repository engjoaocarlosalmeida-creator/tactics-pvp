class_name GameCameraRig
extends Node3D

signal camera_changed

var game_view_ref
var _follow_timer := 0.0
var _rc_start := Vector2.ZERO
var _rc_dragged := false


func _process(delta: float) -> void:
	if game_view_ref == null or game_view_ref.m == null:
		return
	if not game_view_ref.test_mode and game_view_ref.screen == null:
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
	if _follow_timer > 0.0:
		_follow_timer = maxf(0.0, _follow_timer - delta)
		var target_pos: Vector3 = game_view_ref._actor_center()
		game_view_ref.camera_pivot.position = game_view_ref.camera_pivot.position.lerp(
				target_pos, clampf(6.0 * delta, 0.0, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	if game_view_ref == null or game_view_ref.m == null or game_view_ref.screen != null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_rc_start = event.position
				_rc_dragged = false
			elif _rc_dragged:
				get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			game_view_ref.distance = clampf(game_view_ref.distance - 2.0, 8.0, 60.0)
			camera_changed.emit()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			game_view_ref.distance = clampf(game_view_ref.distance + 2.0, 8.0, 60.0)
			camera_changed.emit()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		if event.position.distance_to(_rc_start) > 6.0:
			_rc_dragged = true
		game_view_ref.yaw -= event.relative.x * 0.3
		game_view_ref.pitch = clampf(game_view_ref.pitch - event.relative.y * 0.2, -80.0, -25.0)
		camera_changed.emit()

func handle_rotation_input(amount: float) -> void:
	if game_view_ref == null:
		return
	game_view_ref.yaw += amount
	camera_changed.emit()


func handle_movement_input(mv: Vector3) -> void:
	if game_view_ref == null or game_view_ref.camera_pivot == null:
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
	if game_view_ref == null:
		return
	_follow_timer = 1.1
