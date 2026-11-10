extends SceneTree

const SOURCES := {
    "Idle": "Arhcer_MASC_Idle.fbx",
    "walk": "Arhcer_MASC_walk.fbx",
    "jump_up": "Arhcer_MASC_jump_up.fbx",
    "jump_down": "Arhcer_MASC_jump_down.fbx",
    "espadada_dentroparafora": "Arhcer_MASC_espadada_dentroparafora.fbx",
    "espadada_foraparadentro": "Arhcer_MASC_espadada_foraparadentro.fbx",
}
const SOURCE_DIR := "res://assets/models/animations/"
const OUTPUT_PATH := "res://assets/models/character_animations.tres"


func _initialize() -> void:
    call_deferred("_build")


func _build() -> void:
    var library := AnimationLibrary.new()
    for action: String in SOURCES:
        var packed := load(SOURCE_DIR + SOURCES[action]) as PackedScene
        if packed == null:
            push_error("Nao foi possivel carregar a cena FBX para a acao " + action)
            quit(1)
            return

        var character := packed.instantiate()
        get_root().add_child(character)
        var player := character.find_child("AnimationPlayer", true, false) as AnimationPlayer
        if player == null or not player.has_animation("mixamo_com"):
            push_error("A cena FBX nao contem a animacao esperada: " + action)
            character.free()
            quit(1)
            return

        var animation := player.get_animation("mixamo_com").duplicate(true) as Animation
        animation.resource_name = action
        if action in ["Idle", "walk"]:
            animation.loop_mode = Animation.LOOP_LINEAR
        var error := library.add_animation(action, animation)
        character.free()
        if error != OK:
            push_error("Nao foi possivel adicionar a animacao " + action)
            quit(1)
            return

    var error := ResourceSaver.save(library, OUTPUT_PATH)
    if error != OK:
        push_error("Nao foi possivel salvar a biblioteca de animacoes: %s" % error)
        quit(1)
        return
    print("Animacoes salvas: ", SOURCES.keys())
    quit()
