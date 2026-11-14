class_name GameCameraRig
extends Node3D

var game_view_ref


func _process(delta: float) -> void:
	if game_view_ref == null or game_view_ref.m == null:
		return
	if game_view_ref._follow_timer > 0.0:
		game_view_ref._follow_timer = maxf(0.0, game_view_ref._follow_timer - delta)
		var target_pos: Vector3 = game_view_ref._actor_center()
		game_view_ref.camera_pivot.position = game_view_ref.camera_pivot.position.lerp(
				target_pos, clampf(6.0 * delta, 0.0, 1.0))


func handle_rotation_input(amount: float) -> void:
	if game_view_ref == null:
		return
	game_view_ref.yaw += amount
	game_view_ref._update_camera()


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
	game_view_ref._follow_timer = 1.1
