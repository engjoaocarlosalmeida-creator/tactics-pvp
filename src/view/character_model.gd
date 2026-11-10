extends RefCounted

const MODEL_PATH := "res://assets/models/animations/Arhcer_MASC_Idle.fbx"
const ANIMATIONS_PATH := "res://assets/models/character_animations.tres"
const MODEL_SCALE := 85.0
const BLUE_TEAM_COLOR := Color(0.25, 0.55, 1.0)
const RED_TEAM_COLOR := Color(1.0, 0.35, 0.3)
const OUTLINE_SHADER: Shader = preload("res://assets/shaders/team_outline.gdshader")

static var _packed_scene: PackedScene
static var _animation_library: AnimationLibrary


static func team_color(team: int) -> Color:
    return BLUE_TEAM_COLOR if team == 0 else RED_TEAM_COLOR


static func create_model(outline_color: Color) -> Node3D:
    if _packed_scene == null:
        var resource = load(MODEL_PATH)
        if not resource is PackedScene:
            push_error("O modelo 3D do Ranger nao foi importado como uma cena: " + MODEL_PATH)
            return null
        _packed_scene = resource

    var model := _packed_scene.instantiate() as Node3D
    if model == null:
        push_error("A cena do Ranger nao possui uma raiz Node3D.")
        return null

    var player := animation_player(model)
    if player == null:
        push_error("O modelo 3D nao possui um AnimationPlayer.")
        model.free()
        return null
    if _animation_library == null:
        _animation_library = load(ANIMATIONS_PATH) as AnimationLibrary
    if _animation_library == null:
        push_error("A biblioteca de animacoes nao foi encontrada: " + ANIMATIONS_PATH)
        model.free()
        return null
    if player.has_animation_library(""):
        player.remove_animation_library("")
    player.add_animation_library("", _animation_library)

    model.name = "Body"
    model.scale = Vector3.ONE * MODEL_SCALE
    _apply_outline(model, outline_color)
    player.play("Idle")
    return model


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


static func create_preview(outline_color: Color, size: Vector2i) -> SubViewportContainer:
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

    var model := create_model(outline_color)
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


static func _apply_outline(model: Node3D, outline_color: Color) -> void:
    var outline_material := ShaderMaterial.new()
    outline_material.shader = OUTLINE_SHADER
    outline_material.set_shader_parameter("outline_color", outline_color)
    outline_material.set_shader_parameter("outline_width", 0.00025)

    for node in model.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh == null:
            continue
        for surface in mesh_instance.mesh.get_surface_count():
            var original_material := mesh_instance.get_active_material(surface)
            if original_material == null:
                continue
            var material := original_material.duplicate() as Material
            material.next_pass = outline_material
            mesh_instance.set_surface_override_material(surface, material)
