# src/view/game_camera_rig.gd
class_name GameCameraRig
extends Node3D

# Core camera components (kept accessible for testing if necessary)
var camera_pivot: Node3D
var camera: Camera3D

# Camera state variables
var yaw: float = 30.0
var pitch: float = -55.0
var distance: float = 32.0
var follow_timer: float = 0.0

# Dependencies provided by game_view.gd
var battle_map_dirs: Array = []
var map_geometry: Node = null # Adjust type if MapGeometry is a class/singleton
var picking: Node = null # Adjust type if Picking is a class/singleton

# Signal/Callback placeholders (will be connected/used by game_view.gd)
signal _camera_focus_requested(tile: Vector2i)

# --- Initialization and Configuration ---

func _ready() -> void:
	# Setup the pivot and camera based on initial settings
	camera_pivot = Node3D.new()
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.fov = 45
	camera_pivot.add_child(camera)
	camera.current = true
	_update_camera()

# --- Camera Management ---

# Updates the camera's rotation and position based on internal state
func _update_camera() -> void:
	camera_pivot.rotation_degrees = Vector3(pitch, yaw, 0)
	camera.position = Vector3(0, 0, distance)

# Updates camera position when following a specific unit/target
func follow_position(target_position: Vector3, follow_speed: float = 6.0) -> void:
	follow_timer = 1.1
	# Assumes target_position is calculated elsewhere (e.g., _actor_center in game_view.gd)
	camera_pivot.position = camera_pivot.position.lerp(target_position, clampf(follow_speed * get_process_delta_time(), 0.0, 1.0))

# Applies a specific camera configuration (e.g., from CLI arguments)
func apply_cli_cam(new_yaw: float, new_pitch: float, new_distance: float) -> void:
	yaw = new_yaw
	pitch = new_pitch
	distance = new_distance
	_update_camera()

# Calculates the tile position based on a screen point (Raycasting substitute)
func pick_at(screen_pos: Vector2) -> Vector2i:
	var o := camera.project_ray_origin(screen_pos)
	var d := camera.project_ray_normal(screen_pos)
	return _pick_tile(o, d)

# Converts screen directional movement (sd) into map direction index
func dir_from_screen(screen_direction: Vector2) -> int:
	var fwd := Vector3(-camera.global_transform.basis.z.x, 0, -camera.global_transform.basis.z.z).normalized()
	var rgt := Vector3(camera.global_transform.basis.x.x, 0, camera.global_transform.basis.x.z).normalized()
	var w := rgt * screen_direction.x + fwd * (-screen_direction.y)
	var best: int = 0
	var best_dot: float = -10.0
	
	# Uses the battle_map_dirs provided by game_view.gd
	if battle_map_dirs.is_empty():
		return 0
		
	for i in range(battle_map_dirs.size()):
		var dot: float = w.x * battle_map_dirs[i].x + w.z * battle_map_dirs[i].y
		if dot > best_dot:
			best_dot = dot
			best = i
	return best

# --- Public Delegation Methods ---

# Allows game_view.gd to specify a tile to focus on (e.g., for character selection/action context)
func set_focus_tile(target_tile: Vector2i, tile_pos: Vector3) -> void:
	# Set the pivot position to focus on the tile
	if map_geometry:
		camera_pivot.position = map_geometry.tile_pos(battle_map_dirs, target_tile) + Vector3(0, 0, 0)
	
	if picking:
		camera_pivot.position = picking.pick_tile(target_tile)
		
	_update_camera()
	_camera_focus_requested.emit(target_tile)

# Helper function that replaces pick_at() logic (must be copied from game_view.gd)
# NOTE: The actual implementation of this relies on game_view.gd's context (m.map)
func _pick_tile(_origin: Vector3, _direction: Vector3) -> Vector2i:
	# This function CANNOT be fully implemented here without the MatchState (m) context.
	# It must be handled by game_view.gd or passed a reference to the MatchState object.
	# For now, I leave a stub. The calling script must ensure this dependency is handled.
	return Vector2i.ZERO