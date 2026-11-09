## Opcoes do jogador (modo de tela, resolucao da janela, volume) em user://settings.cfg.
class_name Settings
extends RefCounted



const PATH := "user://settings.cfg"
const MODE_WINDOW := 0
const MODE_BORDERLESS := 1
const MODE_FULLSCREEN := 2
const MODE_NAMES := ["Janela", "Tela cheia em janela", "Tela cheia"]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var display_mode := MODE_BORDERLESS
var resolution := 0
var volume := 0.8


static func load_from(path: String = PATH) -> Settings:
    var s := Settings.new()
    var cfg := ConfigFile.new()
    if cfg.load(path) == OK:
        s.display_mode = clampi(int(cfg.get_value("video", "display_mode", MODE_BORDERLESS)), 0, 2)
        s.resolution = clampi(int(cfg.get_value("video", "resolution", 0)), 0, RESOLUTIONS.size() - 1)
        s.volume = clampf(float(cfg.get_value("audio", "volume", 0.8)), 0.0, 1.0)
    return s


func save(path: String = PATH) -> bool:
    var cfg := ConfigFile.new()
    cfg.set_value("video", "display_mode", display_mode)
    cfg.set_value("video", "resolution", resolution)
    cfg.set_value("audio", "volume", volume)
    return cfg.save(path) == OK



static func available_resolutions(screen: Vector2i) -> Array[int]:
    var out: Array[int] = []
    for i in RESOLUTIONS.size():
        if RESOLUTIONS[i].x <= screen.x and RESOLUTIONS[i].y <= screen.y - 60:
            out.append(i)
    if out.is_empty():
        out.append(0)
    return out



func change(key: String, delta: int = 0, screen: Vector2i = Vector2i(1920, 1080)) -> Variant:
    match key:
        "display_mode":
            display_mode = (display_mode + 1) % MODE_NAMES.size()
            return display_mode
        "resolution":
            var list := available_resolutions(screen)
            var pos := list.find(resolution)
            resolution = list[(pos + 1) % list.size()] if pos >= 0 else list[0]
            return resolution
        "volume":
            volume = clampf(snappedf(volume + 0.1 * delta, 0.1), 0.0, 1.0)
            return volume
    return null


func resolution_text() -> String:
    return "%dx%d" % [RESOLUTIONS[resolution].x, RESOLUTIONS[resolution].y]


func apply_to_window() -> void :
    if DisplayServer.get_name() == "headless":
        return
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
    match display_mode:
        MODE_FULLSCREEN:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
        MODE_BORDERLESS:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        _:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
            var screen := DisplayServer.screen_get_size()
            var list := available_resolutions(screen)
            var size := RESOLUTIONS[resolution if list.has(resolution) else list[0]]
            DisplayServer.window_set_size(size)
            DisplayServer.window_set_position(DisplayServer.screen_get_position() + (screen - size) / 2)
