extends SceneTree

const LIBRARIES := {
    "res://assets/models/character_animations.tres": {
        "Idle": "Arhcer_MASC_Idle.fbx",
        "walk": "Arhcer_MASC_walk.fbx",
        "jump_up": "Arhcer_MASC_jump_up.fbx",
        "jump_down": "Arhcer_MASC_jump_down.fbx",
        "espadada_dentroparafora": "Arhcer_MASC_espadada_dentroparafora.fbx",
        "espadada_foraparadentro": "Arhcer_MASC_espadada_foraparadentro.fbx",
        "death_forward": "Arhcer_MASC_Forward_Death.fbx",
        "death_back": "Arhcer_MASC_Back_death.fbx",
        "defend": "Arhcer_MASC_Defend.fbx",
        "dodge": "Arhcer_MASC_Dodge.fbx",
        "parry": "Arhcer_MASC_Parry.fbx",
        "impact": "Arhcer_MASC_Impact.fbx",
    },
    "res://assets/models/aprendiz_f_animations.tres": {
        "Idle": "aprendiz_f_Idle.fbx",
        "walk": "aprendiz_f_walk.fbx",
        "jump_up": "aprendiz_f_jump_up.fbx",
        "jump_down": "aprendiz_f_jump_Down.fbx",
        "espadada_dentroparafora": "aprendiz_f_espadada.fbx",
        "espadada_foraparadentro": "aprendiz_f_espadada.fbx",
        "death_forward": "aprendiz_f_death.fbx",
        "death_back": "aprendiz_f_death.fbx",
        "defend": "aprendiz_f_defend.fbx",
        "dodge": "aprendiz_f_dodge.fbx",
        "parry": "aprendiz_f_parry.fbx",
        "impact": "aprendiz_f_impact.fbx",
    },
}
const SOURCE_DIR := "res://assets/models/animations/"


func _initialize() -> void:
    call_deferred("_build")


func _build() -> void:
    for output_path: String in LIBRARIES:
        var sources: Dictionary = LIBRARIES[output_path]
        var library := AnimationLibrary.new()
        var idle_hips_y := NAN
        for action: String in sources:
            var packed := load(SOURCE_DIR + sources[action]) as PackedScene
            if packed == null:
                push_error("Nao foi possivel carregar a cena FBX para a acao " + action + " em " + output_path)
                quit(1)
                return

            var character := packed.instantiate()
            get_root().add_child(character)
            var player := character.find_child("AnimationPlayer", true, false) as AnimationPlayer
            var anim_key := ""
            if player != null:
                if player.has_animation("mixamo_com"):
                    anim_key = "mixamo_com"
                else:
                    for candidate: String in player.get_animation_list():
                        if candidate != "RESET":
                            anim_key = candidate
                            break
            if player == null or anim_key == "":
                push_error("A cena FBX nao contem nenhuma animacao valida: " + action)
                character.free()
                quit(1)
                return

            var animation := player.get_animation(anim_key).duplicate(true) as Animation
            animation.resource_name = action
            if action in ["Idle", "walk"]:
                animation.loop_mode = Animation.LOOP_LINEAR
            if action == "Idle": idle_hips_y = _get_hips_start_y(animation)
            elif not is_nan(idle_hips_y): _rebase_hips_y(animation, idle_hips_y)
            elif action in ["jump_up", "jump_down", "death_forward", "death_back", "defend", "dodge", "parry", "impact", "espadada_dentroparafora", "espadada_foraparadentro"]: _remove_horizontal_root_motion(animation)
            if action in ["jump_up", "jump_down", "death_forward", "death_back", "defend", "dodge", "parry", "impact", "espadada_dentroparafora", "espadada_foraparadentro"]:
                _remove_horizontal_root_motion(animation)
            if not is_nan(idle_hips_y): _rebase_hips_y(animation, idle_hips_y)
            var add_animation_error := library.add_animation(action, animation)
            character.free()
            if add_animation_error != OK:
                push_error("Nao foi possivel adicionar a animacao " + action)
                quit(1)
                return

        var save_error := ResourceSaver.save(library, output_path)
        if save_error != OK:
            push_error("Nao foi possivel salvar a biblioteca de animacoes: %s" % save_error)
            quit(1)
            return
        print("[OK] Biblioteca salva: ", output_path, " -> ", sources.keys())
    quit()


func _remove_horizontal_root_motion(animation: Animation) -> void:
    for track in animation.get_track_count():
        if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
            continue
        if not str(animation.track_get_path(track)).ends_with(":mixamorig_Hips"):
            continue
        var key_count := animation.track_get_key_count(track)
        if key_count == 0:
            continue
        var initial_position: Vector3 = animation.track_get_key_value(track, 0)
        for key in key_count:
            var position: Vector3 = animation.track_get_key_value(track, key)
            position.x = initial_position.x
            position.z = initial_position.z
            animation.track_set_key_value(track, key, position)

func _get_hips_start_y(animation: Animation) -> float:
    for track in animation.get_track_count():
        if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and str(animation.track_get_path(track)).ends_with(":mixamorig_Hips"):
            if animation.track_get_key_count(track) > 0:
                return animation.track_get_key_value(track, 0).y
    return NAN

func _rebase_hips_y(animation: Animation, target_y: float) -> void:
    for track in animation.get_track_count():
        if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and str(animation.track_get_path(track)).ends_with(":mixamorig_Hips"):
            var kc := animation.track_get_key_count(track)
            if kc == 0: return
            var src_y: float = animation.track_get_key_value(track, 0).y
            var ratio := (target_y / src_y) if absf(src_y) > 0.00001 else 1.0
            for k in kc:
                var pos: Vector3 = animation.track_get_key_value(track, k)
                pos.y = target_y + (pos.y - src_y)
                animation.track_set_key_value(track, k, pos)



