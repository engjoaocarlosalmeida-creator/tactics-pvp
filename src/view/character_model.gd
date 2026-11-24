extends RefCounted

const DEFAULT_MODEL_PATH := "res://assets/models/animations/Arhcer_MASC_Idle.fbx"
const CLASS_MODELS := {
    "aprendiz": "res://assets/classes/textured_mesh_autofix_facerepair_rigged.glb",
    "aprendiz:f": "res://assets/classes/textured_mesh_autofix_facerepair_rigged.glb",
}
const ANIMATIONS_PATH := "res://assets/models/character_animations.tres"
const SKULL_PATH := "res://assets/models/skull.glb"
const CHARACTER_TEXTURE: Texture2D = preload("res://assets/models/Ranger_ranger_texture.png")
const MODEL_SCALE := 76.5
const BLUE_TEAM_COLOR := Color(0.25, 0.55, 1.0)
const RED_TEAM_COLOR := Color(1.0, 0.35, 0.3)
const OUTLINE_SHADER: Shader = preload("res://assets/shaders/team_outline.gdshader")

static var _packed_scenes := {}
static var _animation_library: AnimationLibrary
static var _glb_animation_library: AnimationLibrary


static func team_color(team: int) -> Color:
    return BLUE_TEAM_COLOR if team == 0 else RED_TEAM_COLOR


static func _build_glb_animation_library(base_lib: AnimationLibrary, skel_rel_path: String) -> AnimationLibrary:
    var lib := AnimationLibrary.new()
    for anim_name in base_lib.get_animation_list():
        var src := base_lib.get_animation(anim_name)
        var dup := src.duplicate(true) as Animation
        for t_idx in dup.get_track_count():
            var old_path := str(dup.track_get_path(t_idx))
            var colon := old_path.find(":")
            if colon >= 0:
                var bone_sub := old_path.substr(colon)
                dup.track_set_path(t_idx, NodePath(skel_rel_path + bone_sub))
            if dup.track_get_type(t_idx) == Animation.TYPE_POSITION_3D:
                for k_idx in dup.track_get_key_count(t_idx):
                    var val: Vector3 = dup.track_get_key_value(t_idx, k_idx)
                    dup.track_set_key_value(t_idx, k_idx, val * 0.01)
        lib.add_animation(anim_name, dup)
    return lib


static func create_model(outline_color: Color, job_id: String = "", sex: String = "") -> Node3D:
    var base_id := job_id.to_lower().strip_edges()
    var key := base_id + (":" + sex.to_lower().strip_edges() if sex != "" else "")
    var model_path: String = CLASS_MODELS.get(key, CLASS_MODELS.get(base_id, DEFAULT_MODEL_PATH))
    if not ResourceLoader.exists(model_path):
        model_path = DEFAULT_MODEL_PATH
    var is_custom_glb := model_path != DEFAULT_MODEL_PATH

    if not _packed_scenes.has(model_path):
        var resource = load(model_path)
        if not resource is PackedScene:
            push_error("O modelo 3D nao foi importado como uma cena: " + model_path)
            return null
        _packed_scenes[model_path] = resource

    var packed: PackedScene = _packed_scenes[model_path]
    var model := packed.instantiate() as Node3D
    if model == null:
        push_error("A cena do personagem nao possui uma raiz Node3D.")
        return null

    if _animation_library == null:
        _animation_library = load(ANIMATIONS_PATH) as AnimationLibrary
    if _animation_library == null:
        push_error("A biblioteca de animacoes nao foi encontrada: " + ANIMATIONS_PATH)
        model.free()
        return null

    var player := animation_player(model)
    var lib_to_use := _animation_library

    if is_custom_glb:
        var skels := model.find_children("*", "Skeleton3D", true, false)
        var skel: Skeleton3D = null
        if not skels.is_empty():
            skel = skels.front() as Skeleton3D
        if skel != null:
            if player == null:
                player = AnimationPlayer.new()
                player.name = "AnimationPlayer"
                model.add_child(player)
            player.root_node = NodePath("..")
            var rel_skel := str(model.get_path_to(skel))
            if _glb_animation_library == null:
                _glb_animation_library = _build_glb_animation_library(_animation_library, rel_skel)
            lib_to_use = _glb_animation_library

    if player == null:
        push_error("O modelo 3D nao possui um AnimationPlayer.")
        model.free()
        return null

    var has_embedded := is_custom_glb and player != null and player.has_animation("Idle") and player.has_animation("walk")
    if not has_embedded:
        if player.has_animation_library(""):
            player.remove_animation_library("")
        player.add_animation_library("", lib_to_use)

    model.name = "Body"
    model.scale = Vector3.ONE * (1.0 if is_custom_glb else MODEL_SCALE)
    _apply_outline(model, outline_color, not is_custom_glb, 0.019 if is_custom_glb else 0.00025)
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
    _apply_outline(skull, outline_color, false, 0.00025)
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


static func locomotion_action(height_delta: int) -> String:
    if height_delta > 0:
        return "jump_up"
    if height_delta < 0:
        return "jump_down"
    return "walk"


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
        replace_texture := true, outline_w := 0.00025) -> void:
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
                if replace_texture:
                    material.albedo_texture = CHARACTER_TEXTURE
                else:
                    material.albedo_color = Color.WHITE
                    material.roughness = 1.0
                    material.metallic = 0.0
                    material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
            material.next_pass = outline_material
            mesh_instance.set_surface_override_material(surface, material)

