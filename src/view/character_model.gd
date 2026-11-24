extends RefCounted
const DEFAULT_MODEL_PATH := "res://assets/models/animations/Arhcer_MASC_Idle.fbx"
const CLASS_MODELS := { "aprendiz:f": "res://assets/models/animations/aprendiz_f_Idle.fbx" }
const CLASS_SCALES := { "aprendiz:f": 2.0 }
const CLASS_TEXTURES := { "aprendiz:f": "res://assets/models/animations/aprendiz_f_Idle_0.png" }
const DEFAULT_ANIMATIONS_PATH := "res://assets/models/character_animations.tres"
const ANIMATIONS_PATH := DEFAULT_ANIMATIONS_PATH
const CLASS_ANIMATIONS := { "aprendiz:f": "res://assets/models/aprendiz_f_animations.tres" }
const SKULL_PATH := "res://assets/models/skull.glb"
const CHARACTER_TEXTURE: Texture2D = preload("res://assets/models/Ranger_ranger_texture.png")
const MODEL_SCALE := 76.5
const KNEE_HEIGHT := 0.38
const BLUE_TEAM_COLOR := Color(0.25, 0.55, 1.0)
const RED_TEAM_COLOR := Color(1.0, 0.35, 0.3)
const OUTLINE_SHADER: Shader = preload("res://assets/shaders/team_outline.gdshader")
static var _packed_scenes := {}
static var _animation_libraries := {}
static var _glb_animation_libraries := {}
static func team_color(team: int) -> Color:
	return BLUE_TEAM_COLOR if team == 0 else RED_TEAM_COLOR
static func _build_glb_animation_library(base_lib: AnimationLibrary, skel_rel_path: String) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for anim_name in base_lib.get_animation_list():
		var dup := base_lib.get_animation(anim_name).duplicate(true) as Animation
		for t_idx in dup.get_track_count():
			var old_path := str(dup.track_get_path(t_idx))
			var colon := old_path.find(":")
			if colon >= 0:
				dup.track_set_path(t_idx, NodePath(skel_rel_path.replace("|.glb", "") + old_path.substr(colon)))
			if dup.track_get_type(t_idx) == Animation.TYPE_POSITION_3D:
				for k_idx in dup.track_get_key_count(t_idx):
					if skel_rel_path.ends_with("|.glb"): if skel_rel_path.ends_with("|.glb"): if skel_rel_path.ends_with("|.glb"): dup.track_set_key_value(t_idx, k_idx, dup.track_get_key_value(t_idx, k_idx) * 0.01)
		lib.add_animation(anim_name, dup)
	return lib
static func create_model(outline_color: Color, job_id: String = "", sex: String = "") -> Node3D:
	var base_id := job_id.to_lower().strip_edges()
	var key := base_id + (":" + sex.to_lower().strip_edges() if sex != "" else "")
	var model_path: String = CLASS_MODELS.get(key, CLASS_MODELS.get(base_id, DEFAULT_MODEL_PATH))
	var anim_path: String = CLASS_ANIMATIONS.get(key, CLASS_ANIMATIONS.get(base_id, DEFAULT_ANIMATIONS_PATH))
	if not ResourceLoader.exists(model_path):
		model_path = DEFAULT_MODEL_PATH
		anim_path = DEFAULT_ANIMATIONS_PATH
	var is_custom_glb := model_path.ends_with(".glb")
	var use_legacy_ranger_tex := model_path == DEFAULT_MODEL_PATH
	var tex_path: String = CLASS_TEXTURES.get(key, CLASS_TEXTURES.get(base_id, ""))
	var custom_tex: Texture2D = load(tex_path) as Texture2D if tex_path != "" else (CHARACTER_TEXTURE if use_legacy_ranger_tex else null)
	if not _packed_scenes.has(model_path):
		var resource = load(model_path)
		if not resource is PackedScene:
			push_error("O modelo 3D nao foi importado como uma cena: " + model_path)
			return null
		_packed_scenes[model_path] = resource
	var model := (_packed_scenes[model_path] as PackedScene).instantiate() as Node3D
	if model == null:
		push_error("A cena do personagem nao possui uma raiz Node3D.")
		return null
	if not _animation_libraries.has(anim_path):
		_animation_libraries[anim_path] = load(anim_path) as AnimationLibrary
	var base_lib: AnimationLibrary = _animation_libraries[anim_path]
	if base_lib == null:
		push_error("A biblioteca de animacoes nao foi encontrada: " + anim_path)
		model.free()
		return null
	var player := animation_player(model)
	var lib_to_use := base_lib
	var skels_all := model.find_children("*", "Skeleton3D", true, false)
	if not skels_all.is_empty():
		var skels := skels_all
		if not skels.is_empty():
			var skel := skels.front() as Skeleton3D
			if player == null:
				player = AnimationPlayer.new()
				player.name = "AnimationPlayer"
				model.add_child(player)
			player.root_node = NodePath("..")
			var rel_skel := str(model.get_path_to(skel))
			var root_n := player.get_node(player.root_node)
			rel_skel = str(root_n.get_path_to(skel))
			rel_skel = str(root_n.get_path_to(skel))
			rel_skel = str(root_n.get_path_to(skel))
			var glb_key := anim_path + "|" + rel_skel + ("|.glb" if is_custom_glb else "") + ("|.glb" if is_custom_glb else "") + ("|.glb" if is_custom_glb else "")
			if not _glb_animation_libraries.has(glb_key):
				_glb_animation_libraries[glb_key] = _build_glb_animation_library(base_lib, rel_skel + ("|.glb" if is_custom_glb else ""))
			lib_to_use = _glb_animation_libraries[glb_key]
	if player == null:
		push_error("O modelo 3D nao possui um AnimationPlayer.")
		model.free()
		return null
	var has_embedded := is_custom_glb and player.has_animation("Idle") and player.has_animation("walk")
	if not has_embedded:
		if player.has_animation_library(""):
			player.remove_animation_library("")
		player.add_animation_library("", lib_to_use)
	model.name = "Body"
	model.scale = Vector3.ONE * float(CLASS_SCALES.get(key, CLASS_SCALES.get(base_id, MODEL_SCALE if use_legacy_ranger_tex else 1.0)))
	_apply_outline(model, outline_color, custom_tex, 0.00025 if use_legacy_ranger_tex else 0.0045)
	player.play("Idle")
	return model

static func create_skull(outline_color: Color) -> Node3D:
	var resource := load(SKULL_PATH)
	if not resource is PackedScene:
		push_error("O modelo da caveira nao foi importado como uma cena: " + SKULL_PATH)
		return null
	var skull := resource.instantiate() as Node3D
	if skull == null:
		push_error("A cena da caveira nao possui uma raiz Node3D.")
		return null
	skull.name = "Skull"
	skull.scale = Vector3.ONE * 0.5
	_apply_outline(skull, outline_color, null, 0.00025)
	return skull


static func animation_player(model: Node3D) -> AnimationPlayer:
	return model.find_child("AnimationPlayer", true, false) as AnimationPlayer


static func play_animation(model: Node3D, action: String, duration := 0.0) -> bool:
	var player := animation_player(model)
	if player == null or not player.has_animation(action):
		push_error("Animacao nao encontrada no modelo: " + action)
		return false
	if player.current_animation == action and player.is_playing():
		return true

	player.speed_scale = 1.0
	if duration > 0.0:
		var animation := player.get_animation(action)
		player.speed_scale = animation.length / duration
	player.play(action, 0.12)
	return true


static func animation_duration(model: Node3D, action: String) -> float:
	var player := animation_player(model)
	if player == null or not player.has_animation(action):
		push_error("Animacao nao encontrada no modelo: " + action)
		return 0.0
	return player.get_animation(action).length


static func locomotion_action(height_delta: int, step_height: float = 0.35) -> String:
	var world_dy := float(height_delta) * step_height
	if absf(world_dy) >= KNEE_HEIGHT:
		return "jump_up" if height_delta > 0 else "jump_down"
	return "walk"

static func apply_step_foot_ik(model: Node3D, step_dy: float, progress: float) -> void:
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty(): return
	var skel := skels.front() as Skeleton3D
	var s := maxf(model.scale.y, 0.001)
	var stride := sin(clampf(progress, 0.0, 1.0) * PI)
	var hips_idx := skel.find_bone("mixamorig_Hips")
	if hips_idx >= 0:
		var base_p := skel.get_bone_rest(hips_idx).origin
		var shift := (-step_dy * 0.5 * (1.0 - progress) if step_dy > 0.0 else step_dy * 0.5 * progress) / s
		skel.set_bone_pose_position(hips_idx, base_p + Vector3(0.0, shift, 0.0))
	var lead_up := skel.find_bone("mixamorig_LeftUpLeg" if step_dy > 0.0 else "mixamorig_RightUpLeg")
	var lead_leg := skel.find_bone("mixamorig_LeftLeg" if step_dy > 0.0 else "mixamorig_RightLeg")
	var bend := clampf(absf(step_dy) / KNEE_HEIGHT, 0.0, 1.0) * 0.55 * stride
	if lead_up >= 0:
		skel.set_bone_pose_rotation(lead_up, skel.get_bone_pose_rotation(lead_up) * Quaternion(Vector3.RIGHT, -bend))
	if lead_leg >= 0:
		skel.set_bone_pose_rotation(lead_leg, skel.get_bone_pose_rotation(lead_leg) * Quaternion(Vector3.RIGHT, bend * 1.35))

static func clear_step_foot_ik(model: Node3D) -> void:
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		(skels.front() as Skeleton3D).reset_bone_poses()


static func set_facing(model: Node3D, facing: Vector2i) -> void:
	if facing != Vector2i.ZERO:
		model.rotation.y = atan2(float(facing.x), float(facing.y))


static func create_preview(outline_color: Color, size: Vector2i, job_id: String = "") -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.custom_minimum_size = Vector2(size)

	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(viewport)

	var world := Node3D.new()
	viewport.add_child(world)

	var model := create_model(outline_color, job_id)
	if model == null:
		container.queue_free()
		return container
	set_facing(model, Vector2i(0, 1))
	world.add_child(model)

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color(0.68, 0.7, 0.78)
	environment_resource.ambient_light_energy = 0.8
	environment.environment = environment_resource
	world.add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	light.light_energy = 1.1
	world.add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.3, 4.0)
	camera.fov = 38.0
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 1.12, 0.0), Vector3.UP)
	camera.current = true
	return container


static func flash(model: Node3D, tween: Tween) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if material == null:
				continue
			var original_color := material.albedo_color
			material.albedo_color = Color(1.0, 0.35, 0.35, original_color.a)
			tween.tween_property(material, "albedo_color", original_color, 0.3)


static func _apply_outline(model: Node3D, outline_color: Color,
		override_tex: Texture2D = null, outline_w := 0.00025) -> void:
	var outline_material := ShaderMaterial.new()
	outline_material.shader = OUTLINE_SHADER
	outline_material.set_shader_parameter("outline_color", outline_color)
	outline_material.set_shader_parameter("outline_width", outline_w)

	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var original_material := mesh_instance.get_active_material(surface)
			if original_material == null:
				continue
			var material := original_material.duplicate() as Material
			if material is StandardMaterial3D:
				if override_tex != null:
					material.albedo_texture = override_tex
				if override_tex != CHARACTER_TEXTURE:
					material.albedo_color = Color.WHITE
					material.roughness = 1.0
					material.metallic = 0.0
					material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			material.next_pass = outline_material
			mesh_instance.set_surface_override_material(surface, material)
