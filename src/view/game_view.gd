class_name GameView extends Node

enum Mode { MOVE, ACTION, TARGET, FACING }

var distance: float = 20.0
var yaw: float = 0.0
var pitch: float = -45.0
var _rc_start: Vector2 = Vector2.ZERO
var _rc_dragged: bool = false
var m = null
var screen = null
var net = null
var _hover = null

func _ready() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		_show_pause_menu()
		get_viewport().set_input_as_handled()
		return

	if m != null and m.awaiting_facing and screen == null and event is InputEventKey and event.pressed and not event.echo \
	and _owner_human(m.active) and not event.shift_pressed:
		var sd := Vector2.ZERO
		match event.keycode:
			KEY_LEFT, KEY_A: sd = Vector2(-1, 0)
			KEY_RIGHT, KEY_D: sd = Vector2(1, 0)
			KEY_UP, KEY_W: sd = Vector2(0, -1)
			KEY_DOWN, KEY_S: sd = Vector2(0, 1)
			KEY_ENTER, KEY_SPACE, KEY_ESCAPE:
				cancel_all()
				return
		if sd != Vector2.ZERO:
			_command({"t": "face", "unit": m.active.id, "dir": _dir_from_screen(sd)})
			return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE\
	and m == null and screen == null and net != null and not net.active:
		_show_menu()
		return

	if m == null or screen != null:
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				_rc_start = event.position
				_rc_dragged = false
			MOUSE_BUTTON_LEFT:
				var p := pick_at(event.position)
				if p != null:
					click_tile(p, event.position)
				else:
					cancel_all()
			MOUSE_BUTTON_WHEEL_UP:
				distance = clampf(distance - 2.0, 8.0, 60.0)
				_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = clampf(distance + 2.0, 8.0, 60.0)
				_update_camera()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not _rc_dragged:
			cancel_all()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			if event.position.distance_to(_rc_start) > 6.0:
				_rc_dragged = true
				yaw -= event.relative.x * 0.3
				pitch = clampf(pitch - event.relative.y * 0.2, -80.0, -25.0)
				_update_camera()
		else:
			set_hover(pick_at(event.position))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.shift_pressed and (event.keycode == KEY_RIGHT or event.keycode == KEY_LEFT):
			_cycle_actor(1 if event.keycode == KEY_RIGHT else -1)
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			wait()
		elif event.keycode == KEY_ESCAPE:
			cancel_all()

func _show_pause_menu():
	get_tree().paused = true
	var menu = load("res://scenes/UI/PauseMenu.tscn").instantiate()
	add_child(menu)

func _owner_human(unit): return true
func _command(cmd): pass
func _dir_from_screen(v): return 0
func _show_menu(): pass
func cancel_all(): pass
func pick_at(pos: Vector2): return null
func click_tile(p, pos: Vector2): pass
func _update_camera(): pass
func set_hover(p): _hover = p
func _cycle_actor(dir): pass
func wait(): pass

static func reaction_color(type) -> Color: return Color.WHITE
