## CAMADA VISUAL E DE ENTRADA DA PARTIDA. Desenha o MatchState (terreno em lote, personagens 3D, barras,
## ponteiro, marcadores), trata cliques/teclado, fluxos de mover/atacar com confirmacao, lado,
## movimento extra, rede e conta. Nao contem regras. Opcoes de linha de comando: --mode=local|cpu|demo
## --seed=N --shot=arquivo.png --bot-turns=N --net=host|join --ip= --port= --auto-play --quit-on-end
## --fast --report= --roster= --open=team|classes|items|account|wiki --no-splash --cam=yaw,pitch,dist
## --focus=x,z.
class_name GameView
extends Node3D


const CHARACTER_MODEL := preload("res://src/view/character_model.gd")
const GAME_CAMERA_RIG := preload("res://src/view/game_camera_rig.gd")
const GAME_VISUAL_PRESENTER := preload("res://src/view/game_visual_presenter.gd")
const MATCH_NET_BRIDGE := preload("res://src/view/match_net_bridge.gd")
const BOARD_OVERLAY_RENDERER := preload("res://src/view/board_overlay_renderer.gd")
const MATCH_INPUT_CONTROLLER := preload("res://src/view/match_input_controller.gd")
const SCREEN_ROUTER := preload("res://src/view/screen_router.gd")
const HUD_PRESENTER := preload("res://src/view/hud_presenter.gd")
const LAUNCH_ARGS := preload("res://src/core/launch_args.gd")
const TEAM_COLORS: Array[Color] = [Color(0.25, 0.55, 1.0), Color(1.0, 0.35, 0.3)]
const TEAM_NAMES: Array[String] = ["Azul", "Vermelho"]
const ALLY_COLOR := Color(0.3, 0.62, 1.0)
const ENEMY_COLOR := Color(0.95, 0.28, 0.25)

var animate := true
var test_mode := false
var save_in_test := false
var rules: Rules
var catalog: JobCatalog
var roster: Roster
var m: MatchState
enum Mode {LOCAL, VS_CPU, DEMO, ONLINE}

var mode: int = Mode.LOCAL
var match_seed: int = 1
var terrain_root: Node3D
var units_root: Node3D
var overlay_root: Node3D
var labels_root: Node3D
var overlay_renderer
var input_controller
var screen_router
var hud_presenter
var game_pause_controller: GamePauseController
var game_visual_presenter
var hud: Hud
var mode_pending := ""
var menu_wanted := true
var pending_confirm := Callable()
var screen
var net_bridge
var net: NetSession
var my_team := 0
var awaiting := false
var desync := false
var opponent_left := false
var auto_play := false
var quit_on_end := false
var quit_after_turns := 0
var report_path := ""
var roster_path := Roster.SAVE_PATH
var settings: Settings
var account: Account
var account_path := Account.PATH
var camera_pivot: Node3D
var camera: Camera3D
var camera_rig
var yaw := 45.0
var pitch := -38.0
var distance := 20.0
var hover := Picking.NONE
var selected_tile := Picking.NONE
var _focus_arg := ""
var unit_nodes := {}
var move_tiles := {}
var target_tiles := {}
var attack_area := {}
var reaction_tiles := {}
var menu_unit: Unit
var preview := {}
var busy := 0
var _t := 0.0
var _visual_generation := 0
var bot_rng := RandomNumberGenerator.new()
var cpu_wait := 0.0
var end_shown := false
var last_rewards := {}
var _prompt_hint := false
var _shot_path := ""
var _shot_frames := 0

func _ready() -> void:
	rules = Rules.load_default()
	catalog = JobCatalog.load_default()
	var args := {} if test_mode else LAUNCH_ARGS.parse_cmdline()
	if not test_mode:
		roster_path = args.get("roster", Roster.SAVE_PATH)
	roster = Roster.create_default(rules, catalog) if test_mode else Roster.load_or_default(rules, catalog, roster_path)
	settings = Settings.new() if test_mode else Settings.load_from()
	account = Account.new() if test_mode else Account.load_or_create()
	if not test_mode:
		settings.apply_to_window()
	_build_environment()

	# --- Module Integration (Step 2) ---
	# 1. Instantiate new controllers
	game_pause_controller = GamePauseController.new()
	add_child(game_pause_controller)

	camera_rig = GAME_CAMERA_RIG.new()
	camera_rig.game_view_ref = self
	camera_rig.camera_changed.connect(_update_camera)
	add_child(camera_rig)


	game_visual_presenter = GAME_VISUAL_PRESENTER.new()
	game_visual_presenter.game_view_ref = self
	game_visual_presenter.queue_drained.connect(_try_refresh)
	add_child(game_visual_presenter)
	overlay_renderer = BOARD_OVERLAY_RENDERER.new()
	add_child(overlay_renderer)
	overlay_renderer.setup(self)
	input_controller = MATCH_INPUT_CONTROLLER.new()
	add_child(input_controller)
	input_controller.setup(self)
	input_controller.command_requested.connect(_command)
	input_controller.refresh_requested.connect(_try_refresh)
	screen_router = SCREEN_ROUTER.new()
	add_child(screen_router)
	screen_router.setup(self)
	hud_presenter = HUD_PRESENTER.new()
	add_child(hud_presenter)
	hud_presenter.setup(self)
	# ---------------------------------

	hud = Hud.new()
	add_child(hud)
	net_bridge = MATCH_NET_BRIDGE.new()
	add_child(net_bridge)
	net_bridge.setup(self)
	net_bridge.command_requested.connect(_command)
	net_bridge.refresh_requested.connect(_try_refresh)
	net = net_bridge.net
	hud.popup_ctrl.menu_item_chosen.connect(choose)
	hud.confirm_ok.connect(confirm_accept)
	hud.confirm_cancel.connect(confirm_reject)
	hud.order_clicked.connect(_on_order_clicked)
	hud.overlay_ctrl.options_requested.connect(screen_router.show_options)
	hud.overlay_ctrl.option_changed.connect(screen_router.on_option_changed)
	hud.overlay_ctrl.team_requested.connect(func(): open_screen("team"))
	hud.overlay_ctrl.account_requested.connect(func(): open_screen("account"))
	hud.overlay_ctrl.wiki_requested.connect(func(): open_screen("wiki"))
	hud.splash_done.connect(func(): hud.show_menu())
	hud.overlay_ctrl.items_requested.connect(func(): open_screen("items"))
	hud.overlay_ctrl.menu_choice.connect(func(md): start_match(md))
	hud.overlay_ctrl.restart_pressed.connect(func(): _restart())
	hud.overlay_ctrl.menu_pressed.connect(func(): screen_router.show_menu())
	hud.overlay_ctrl.quit_pressed.connect(func(): get_tree().quit())
	hud.overlay_ctrl.host_requested.connect(func(): net_bridge.start_host(NetSession.DEFAULT_PORT))
	hud.overlay_ctrl.join_requested.connect(func(addr): net_bridge.start_join(addr, NetSession.DEFAULT_PORT))


	if test_mode:
		return
	LAUNCH_ARGS.apply_to_view(self, args)

func open_screen(kind: String) -> void:
	screen_router.open_screen(kind)


func close_screen() -> void:
	screen_router.close_screen()


func open_team_screen() -> void:
	screen_router.open_screen("team")


func close_team_screen() -> void:
	screen_router.close_screen()

func _restart() -> void:
	if mode == Mode.ONLINE:
		screen_router.show_menu()
	else:
		start_match(mode)


func start_match(new_mode: int, seed_value: int = -1) -> void:
	mode = new_mode
	match_seed = seed_value if seed_value >= 0 else randi() % 100000
	bot_rng.seed = match_seed
	hud.hide_overlay()
	hud.clear_log()
	var state := MatchState.create_from_characters(match_seed, rules, catalog,
			roster.team_chars(0, rules.get_int("match", "units_per_team")),
			roster.team_chars(1, rules.get_int("match", "units_per_team")))
	setup_match(state)


func setup_match(state: MatchState) -> void:
	_clear_world()
	end_shown = false
	last_rewards = {}
	mode_pending = ""
	menu_wanted = true
	selected_tile = Picking.NONE
	pending_confirm = Callable()
	m = state
	hud.show_game_hud(true)
	m.turn_started.connect(_on_turn_started)
	m.unit_moved.connect(_on_unit_moved)
	m.unit_hurt.connect(_on_unit_hurt)
	m.unit_died.connect(_on_unit_died)
	m.unit_dying_turn.connect(_on_unit_dying_turn)
	m.unit_expired.connect(_on_unit_expired)
	m.attack_resolved.connect(_on_attack_resolved)
	m.match_over.connect(_on_match_over)
	m.reaction_event.connect(_on_reaction_event)
	m.manual_facing_teams = _manual_teams() # quem joga escolhe o lado ao fim do turno
	m.xp_gained.connect(_on_xp_gained)
	game_visual_presenter.build_terrain()
	game_visual_presenter.build_units()
	camera_pivot.position = Vector3.ZERO
	distance = clampf(m.map.width * 1.3, 14.0, 60.0)
	if _focus_arg != "":
		var fv := _focus_arg.split(",")
		camera_pivot.position = MapGeometry.tile_pos(m.map, Vector2i(int(fv[0]), int(fv[1])))
	_update_camera()
	m.start()
	_try_refresh()


func ally_team() -> int:
	return my_team if mode == Mode.ONLINE else 0


func _sex_icon(sex: String) -> String:
	return "[img=16]res://assets/icons/sex_%s.png[/img]" % ("f" if sex == "f" else "m")


func _actor_center() -> Vector3:
	if m == null or m.active == null or not unit_nodes.has(m.active.id):
		return Vector3.ZERO
	var p: Vector3 = unit_nodes[m.active.id].position
	return Vector3(p.x, 0, p.z)


func _cycle_actor(dir: int) -> void:
	if not _human_turn() or hud.confirm_visible() or m.active.moved or m.active.acted:
		return
	var cands: Array[Unit] = [m.active]
	for o in m.ready_alternates(m.active):
		if m.has_actions(o):
			cands.append(o)
	if cands.size() < 2:
		return
	cands.sort_custom(func(a: Unit, b: Unit): return a.id < b.id)
	var nxt: Unit = cands[(cands.find(m.active) + dir + cands.size()) % cands.size()]
	menu_wanted = true
	_command({"t": "switch", "unit": m.active.id, "to": nxt.id})


func _cpu_controls(u: Unit) -> bool:
	return mode == Mode.DEMO or (mode == Mode.VS_CPU and u.team == 1)


func _input_locked(u: Unit) -> bool:
	return _cpu_controls(u) or (mode == Mode.ONLINE and (u.team != my_team or awaiting))


func _player_name(team: int) -> String:
	if mode == Mode.ONLINE:
		return "Você" if team == my_team else "Adversário"
	if mode == Mode.DEMO:
		return "Computador %s" % TEAM_NAMES[team]
	if mode == Mode.VS_CPU and team == 1:
		return "Computador"
	return "Jogador %d" % (team + 1)
func step_cpu() -> void:
	if m == null or m.is_over() or game_visual_presenter.is_busy():
		return
	if not m.pending_reaction.is_empty(): # o computador nao usa o movimento extra
		_apply_command_with_visuals({"t": "react_skip", "unit": int(m.pending_reaction["unit"])})
		return
	_apply_command_with_visuals(SimpleBot.next_command(m, bot_rng))


func _apply_command_with_visuals(cmd: Dictionary) -> Dictionary:
	game_visual_presenter.begin_collecting()
	var result := m.apply_command(cmd)
	game_visual_presenter.end_collecting()
	return result


func _command(cmd: Dictionary) -> bool:
	menu_wanted = true
	if mode != Mode.ONLINE:
		var res := _apply_command_with_visuals(cmd)
		_try_refresh()
		return res.ok
	if net.is_host:
		var res := _apply_command_with_visuals(cmd)
		if res.ok:
			net.broadcast(cmd, m.state_hash())
		_try_refresh()
		return res.ok
	awaiting = true
	net.submit(cmd)
	_try_refresh()
	return true


func _human_turn() -> bool:
	return m != null and not m.is_over() and busy == 0 and not _input_locked(m.active)


func _unit_at(p: Vector2i) -> Unit:
	for u in m.units:
		if u.is_alive() and u.pos == p:
			return u
	return null


func _menu_anchor(u: Unit) -> Vector2:
	var feet: Vector3 = unit_nodes[u.id].global_position + camera.global_transform.basis.x * 0.4
	return camera.unproject_position(feet) + Vector2(2, -4)
func _auto_menu() -> void:
	if menu_wanted and mode_pending == "" and not hud.target_panel.visible and not hud.items_panel.visible \
			and not m.awaiting_facing and m.pending_reaction.is_empty():
		hud_presenter.open_unit_menu()


func click_tile(p: Vector2i, screen_pos: Vector2 = Vector2(40, 40)) -> bool:
	return input_controller.click_tile(p, screen_pos)


func confirm_accept() -> void:
	input_controller.confirm_accept()


func confirm_reject() -> void:
	input_controller.confirm_reject()

func _approach_tile(u: Unit, t: Unit) -> Vector2i:
	if m.can_hit(u, t):
		return u.pos
	var best := Picking.NONE
	var best_key := 1000000
	for p in move_tiles:
		if m.tile_in_range_from(u, p, t.pos):
			var info: Dictionary = move_tiles[p]
			var key: int = int(info.cost) * 100 + int(info.damage)
			if key < best_key:
				best_key = key
				best = p
	return best


func _do_attack_approach(t: Unit) -> void:
	var u := m.active
	var dest := _approach_tile(u, t)
	var cmds: Array = []
	if dest != Picking.NONE and dest != u.pos:
		cmds.append({"t": "move", "unit": u.id, "x": dest.x, "y": dest.y})
	cmds.append({"t": "attack", "unit": u.id, "target": t.id})
	_run_commands(cmds)


func _run_commands(cmds: Array) -> bool:
	var first: Dictionary = cmds[0]
	var rest := cmds.slice(1)
	if mode == Mode.ONLINE and not net.is_host:
		net_bridge.queue_commands(rest)
		return _command(first)
	var ok := _command(first)
	for c in rest:
		if not ok:
			break
		ok = _command(c)
	return ok


func _move_text(u: Unit, p: Vector2i) -> String:
	var info: Dictionary = move_tiles[p]
	var t := "Mover [b]%s[/b] para a casa (%d, %d)?\nCusto de movimento: %d" % [u.display_name, p.x, p.y, info.cost]
	if info.damage > 0:
		t += "\n[color=#ffaa33]Queda: perde %d de vida[/color]" % info.damage
	return t


func _attack_text(u: Unit, t: Unit) -> String:
	return "Atacar [b]%s[/b] com Ataque básico?\nDano previsto: %d" % [t.display_name, m.attack_damage(u, t)]


var menu_ctx_unit: Unit


func _choose_base(id: String) -> bool:
	if m == null or m.is_over():
		return false
	if id == "items_close":
		hud.hide_items_window()
		menu_wanted = true
		_try_refresh()
		return true
	if id == "t_close":
		hud.hide_target_window()
		menu_wanted = true
		_try_refresh()
		return true
	if id == "t_attack":
		var t := menu_ctx_unit
		if t == null or not _human_turn() or m.active.acted:
			return false
		var dest := _approach_tile(m.active, t)
		if dest == Picking.NONE:
			return false
		hud.hide_target_window()
		var text := _attack_text(m.active, t)
		if dest != m.active.pos:
			text += "\nO personagem se move até a casa (%d, %d) antes de atacar." % [dest.x, dest.y]
		input_controller.ask_confirm(text, func(): _do_attack_approach(t))
		return true
	if not _human_turn():
		return false
	var act := m.active
	if id == "items":
		hud.hide_context_menu()
		hud_presenter.open_items_window(act)
		return true
	if id == "move_mode":
		if move_tiles.is_empty():
			return false
		hud.hide_context_menu()
		mode_pending = "move"
		hud.set_hint("Escolha uma casa azul para mover (Esc ou botão direito cancela)")
		_try_refresh()
		return true
	if id.begins_with("skill_"):
		if act.acted:
			return false
		hud.hide_context_menu()
		mode_pending = "attack"
		hud.set_hint("Escolha uma casa marcada para atacar (Esc ou botão direito cancela)")
		_try_refresh()
		return true
	if id == "end_turn":
		input_controller.ask_confirm("Esperar e passar o turno de [b]%s[/b]?" % act.display_name, func(): _command({"t": "wait", "unit": act.id}))
		return true
	return false


func _ask_switch(to_id: int) -> bool:
	var act := m.active
	var to := m.unit_by_id(to_id)
	if to == null or act.moved or act.acted or not m.ready_alternates(act).has(to):
		return false
	input_controller.ask_confirm("Alternar para [b]%s[/b]?\n(%s ainda não gastou ações)" % [to.display_name, act.display_name],
			func(): _command({"t": "switch", "unit": act.id, "to": to_id}))
	return true


func _on_order_clicked(unit_id: int) -> void:
	if _human_turn() and not hud.confirm_visible():
		_ask_switch(unit_id)


func cancel_all() -> void:
	input_controller.cancel_all()


func wait() -> void:
	input_controller.wait()

func _write_report() -> void:
	if report_path == "":
		return
	var xp := 0
	for cid in last_rewards:
		xp += int(last_rewards[cid].xp)
	var d := {"mode": mode, "my_team": my_team, "winner": m.winner if m != null else -9,
			"turns": m.turn_serial if m != null else 0, "hash": m.state_hash() if m != null else 0,
			"desync": desync, "opponent_left": opponent_left, "xp": xp}
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()


func _on_turn_started(u: Unit) -> void:
	game_visual_presenter.queue_action(Callable(game_visual_presenter, "present_turn_started").bind(u))


func _on_unit_moved(u: Unit, path: Array) -> void:
	game_visual_presenter.queue_action(Callable(game_visual_presenter, "_present_unit_moved").bind(
			u, path.duplicate(), u.pos, u.facing))


func _on_attack_resolved(attacker: Unit, _target: Unit, _tile: Vector2i, _damage: int) -> void:
	var target_hp_before := _target.hp if _target != null else 0
	game_visual_presenter.queue_action(Callable(game_visual_presenter, "_present_attack_resolved").bind(
			attacker, attacker.facing, _target, _damage, target_hp_before))


func _on_unit_hurt(u: Unit, amount: int, reason: String) -> void:
	game_visual_presenter.queue_action(Callable(game_visual_presenter, "_present_unit_hurt").bind(u, amount, reason, u.hp))


func _on_unit_died(u: Unit) -> void:
	game_visual_presenter._dying_turn_snapshots[u.id] = u.dying_turns
	game_visual_presenter.queue_action(Callable(game_visual_presenter, "_present_unit_died").bind(u, u.dying_turns))


func _on_unit_dying_turn(u: Unit, turns_left: int) -> void:
	game_visual_presenter.queue_action(Callable(game_visual_presenter, "_present_unit_dying_turn").bind(u, turns_left))


func _on_unit_expired(u: Unit) -> void:
	game_visual_presenter.queue_action(Callable(game_visual_presenter, "_present_unit_expired").bind(u))


func _on_xp_gained(u: Unit, job_xp: int, char_xp: int, flag: int) -> void:
	game_visual_presenter.queue_action(Callable(game_visual_presenter, "_present_xp_gained").bind(u, job_xp, char_xp, flag))

func _on_match_over(_winner: int) -> void:
	pass


func _try_refresh() -> void:
	if game_visual_presenter.is_busy() or m == null:
		return
	_refresh()
func _refresh() -> void:
	for c in overlay_root.get_children():
		overlay_root.remove_child(c)
		c.queue_free()
	move_tiles.clear()
	target_tiles.clear()
	attack_area.clear()
	reaction_tiles.clear()
	for u in m.units:
		game_visual_presenter._update_unit_visual(u)
		_update_unit_facing(u)
		unit_nodes[u.id].get_node("Over/Pointer").visible = false
	if m.is_over():
		hud.hide_popups()
		hud.set_hint("")
		hud.clear_unit_info()
		hud.set_order_items([])
		hud_presenter.show_end()
		return
	var u := m.active
	var human := not _input_locked(u)
	var prompt := ""
	if not m.pending_reaction.is_empty(): # movimento extra (esquiva com dano enorme): usar na hora ou cancelar
		var o := m.pending_unit()
		if o != null and _owner_human(o):
			var saved := o.move_left
			o.move_left = int(m.pending_reaction["budget"])
			var reach_r := m.reachable_for(o)
			o.move_left = saved
			for p in reach_r:
				if reach_r[p].can_stop and p != o.pos:
					reaction_tiles[p] = reach_r[p]
			prompt = "Movimento extra! Escolha uma casa verde (Esc ou botão direito cancela)"
		hud.hide_popups()
	elif m.awaiting_facing and _owner_human(u):
		prompt = "Escolha para que lado o personagem fica virado: clique numa casa vizinha ou use as setas (Enter mantém)"
		hud.hide_popups()
	elif not human:
		mode_pending = ""
		hud.hide_popups()
		hud.set_hint("")
	else:
		unit_nodes[u.id].get_node("Over/Pointer").visible = true
		if mode_pending != "attack" and not u.down:
			var reach := m.reachable_for(u)
			for p in reach:
				if reach[p].can_stop and p != u.pos:
					move_tiles[p] = reach[p]
		if not u.acted and mode_pending != "move":
			for t in m.targets_for(u):
				target_tiles[t.pos] = t
		if mode_pending == "attack" and not u.acted:
			for p in m.attack_tiles(u):
				attack_area[p] = true
	if prompt != "":
		hud.set_hint(prompt)
		_prompt_hint = true
	elif _prompt_hint:
		hud.set_hint("")
		_prompt_hint = false
	for p in move_tiles:
		var info: Dictionary = move_tiles[p]
		overlay_renderer.add_marker(p, Color(1.0, 0.6, 0.1, 0.5) if info.damage > 0 else Color(0.2, 0.55, 1.0, 0.5))
	for p in attack_area:
		overlay_renderer.add_marker(p, Color(1.0, 0.25, 0.2, 0.32))
	for p in target_tiles:
		overlay_renderer.add_marker(p, Color(1.0, 0.15, 0.15, 0.6))
	for p in reaction_tiles:
		overlay_renderer.add_marker(p, Color(0.3, 1.0, 0.45, 0.5))
	if m.awaiting_facing and _owner_human(u):
		for d in BattleMap.DIRS:
			if m.map.in_bounds(u.pos + d):
				overlay_renderer.add_marker(u.pos + d, Color(0.3, 1.0, 0.45, 0.45))
	hud_presenter.update_hud()
	if human:
		_auto_menu()


func _job_name(u: Unit) -> String:
	return catalog.job_name(u.job_id) if catalog.has_job(u.job_id) else "-"


func _build_environment() -> void:
	if not test_mode:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.09, 0.1, 0.15)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.75, 0.8, 0.9)
		env.ambient_light_energy = 0.4
		var we := WorldEnvironment.new()
		we.environment = env
		add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-55, -35, 0)
		sun.light_energy = 0.9
		sun.shadow_enabled = true
		add_child(sun)
	terrain_root = Node3D.new()
	add_child(terrain_root)
	labels_root = Node3D.new()
	add_child(labels_root)
	units_root = Node3D.new()
	add_child(units_root)
	overlay_root = Node3D.new()
	add_child(overlay_root)
	camera_pivot = Node3D.new()
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.fov = 45
	camera_pivot.add_child(camera)
	camera.current = true
	if camera_rig != null:
		_update_camera()


func _clear_world() -> void:
	_visual_generation += 1
	for root in [terrain_root, units_root, overlay_root, labels_root]:
		for c in root.get_children():
			root.remove_child(c)
			c.queue_free()
	unit_nodes.clear()
	game_visual_presenter.reset_visual_state()
	game_visual_presenter.clear_queue()
	move_tiles.clear()
	target_tiles.clear()
	overlay_renderer.hide_markers()
	selected_tile = Picking.NONE
	busy = 0


func _action_remaining(u: Unit) -> float:
	var cost := m.turns.turn_cost(u.moved, u.acted) if u == m.active and (u.moved or u.acted) else 0
	return clampf(float(u.ct - cost) / float(m.turns.threshold), 0.0, 1.0)


func _pan_limit() -> Vector3:
	var half := float(m.map.width) / 2.0 if m != null else 9.0
	return Vector3(half, 0, half)


func _update_camera() -> void:
	camera_pivot.rotation_degrees = Vector3(pitch, yaw, 0)
	camera.position = Vector3(0, 0, distance)

func pick_at(screen_pos: Vector2) -> Vector2i:
	if m == null:
		return Picking.NONE
	var o := camera.project_ray_origin(screen_pos)
	var d := camera.project_ray_normal(screen_pos)
	return Picking.pick_tile(m.map, o, d)
func _process(delta: float) -> void:
	_t += delta
	if m != null:
		game_visual_presenter.update_overheads()

	if test_mode:
		return


	if m != null and hud.context_panel.visible and menu_unit != null and unit_nodes.has(menu_unit.id):
		hud.move_context_menu(_menu_anchor(menu_unit), get_viewport().get_visible_rect().size)

	if m != null and not m.is_over() and busy == 0 and (_cpu_controls(m.active) or _cpu_owns_reaction()):
		cpu_wait += delta
		if cpu_wait >= 0.7:
			cpu_wait = 0.0
			step_cpu()

	if auto_play and mode == Mode.ONLINE and m != null and not m.is_over() and busy == 0 \
and not awaiting and _auto_actor_is_me():
		_command(SimpleBot.next_command(m, bot_rng))

	if quit_after_turns > 0 and m != null and m.turn_serial >= quit_after_turns:
		get_tree().quit()
	if _shot_path != "":
		_shot_frames += 1
		if _shot_frames == 12:
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot_path)
			get_tree().quit()


# ---------------------------------------------------------------- lado, reacoes e movimento extra

func _manual_teams() -> Array:
	match mode:
		Mode.LOCAL, Mode.ONLINE:
			return [0, 1]
		Mode.VS_CPU:
			return [0]
	return []


## O jogador (e nao o computador nem o adversario online) controla esta unidade?
func _owner_human(u: Unit) -> bool:
	if _cpu_controls(u):
		return false
	return mode != Mode.ONLINE or u.team == my_team


func _cpu_owns_reaction() -> bool:
	var o := m.pending_unit() if m != null else null
	return o != null and _cpu_controls(o)


func _auto_actor_is_me() -> bool:
	if not m.pending_reaction.is_empty():
		var o := m.pending_unit()
		return o != null and o.team == my_team
	return m.active.team == my_team


## O cliente (time 1) pode mandar comando agora? (e a vez dele, ou o movimento extra pendente e dele)
func _client_may_act() -> bool:
	if m == null or m.is_over():
		return false
	if not m.pending_reaction.is_empty():
		var o := m.pending_unit()
		return o != null and o.team == 1
	return m.active.team == 1


static func reaction_color(kind: String) -> Color:
	match kind:
		"dodge", "extra_move":
			return Color(0.35, 0.9, 0.45) # esquiva: verde
		"parry":
			return Color(1.0, 0.9, 0.3) # parry: amarelo
		"block", "fall":
			return Color(0.65, 0.42, 0.2) # bloqueio: marrom
		"counter":
			return Color(1.0, 0.85, 0.35)
		"oa":
			return Color(1.0, 0.6, 0.35)
	return Color(1, 1, 1)


## Reacoes aparecem so com o nome e o feito (o jogo nao explica as regras na tela).
func _on_reaction_event(u: Unit, kind: String, text: String) -> void:
	game_visual_presenter.queue_action(Callable(game_visual_presenter, "_present_reaction_event").bind(u, kind, text))


func _update_unit_facing(u: Unit) -> void:
	var node: Node3D = unit_nodes[u.id]
	var model := node.get_node_or_null("Body") as Node3D
	if model != null:
		CHARACTER_MODEL.set_facing(model, u.facing)


## 0 = clique normal; 1 = tratado; -1 = tratado e ignorado.
func _click_special(p: Vector2i) -> int:
	if not m.pending_reaction.is_empty():
		var o := m.pending_unit()
		if o != null and _owner_human(o) and reaction_tiles.has(p):
			_command({"t": "react_move", "unit": o.id, "x": p.x, "y": p.y})
			return 1
		return -1
	if m.awaiting_facing:
		var u := m.active
		var d := p - u.pos
		if _owner_human(u) and absi(d.x) + absi(d.y) == 1:
			_command({"t": "face", "unit": u.id, "dir": BattleMap.DIRS.find(d)})
			return 1
		return -1
	return 0


## Seta da tela -> direcao do mapa (conforme a camera).
func _dir_from_screen(sd: Vector2) -> int:
	var fwd := Vector3(-camera.global_transform.basis.z.x, 0, -camera.global_transform.basis.z.z).normalized()
	var rgt := Vector3(camera.global_transform.basis.x.x, 0, camera.global_transform.basis.x.z).normalized()
	var w := rgt * sd.x + fwd * (-sd.y)
	var best := 0
	var best_dot := -10.0
	for i in BattleMap.DIRS.size():
		var dot := w.x * BattleMap.DIRS[i].x + w.z * BattleMap.DIRS[i].y
		if dot > best_dot:
			best_dot = dot
			best = i
	return best


func choose(id: String) -> bool:
	return input_controller.choose(id)
