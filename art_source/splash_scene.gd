## Abertura animada do jogo (tela de titulo). Cena 2D em camadas, toda desenhada por codigo (sem
## imagens): ceu ao entardecer, sol com raios, montanhas e ruinas, arena isometrica, dois guerreiros
## que correm um contra o outro e se chocam no centro (impacto: congelada, flash, tremor, faiscas,
## onda na arena) e o titulo que cai sobre a cena. Depois fica em loop esperando uma tecla.
## Primeira tecla durante a abertura = pula para o final; tecla no final = saida (exit_done).
class_name SplashScene
extends Control


signal exit_done

const W := 1920.0
const H := 1080.0
const BLUE := Color(0.25, 0.55, 1.0)
const RED := Color(1.0, 0.35, 0.3)
const INK := Color(0.022, 0.026, 0.065)

const T_FIGHTERS := 2.0
const T_CREEP := 2.5
const T_DASH := 3.1
const T_IMPACT := 3.75
const T_SETTLED := 5.2
const OUTRO_TIME := 0.6
const CLASH_P := Vector2(0.0, 262.0)
const FLOOR_C := Vector2(0.0, 438.0)
const FEET_Y := 432.0
const UNIT := 38.0
const SUN_C := Vector2(0.0, -20.0)
const GRID_N := 13
const TILE_W := 130.0
const TILE_H := 65.0
const GRID_ORIGIN := Vector2(0.0, 440.0)

enum Phase {INTRO, IDLE, OUTRO}

const POST_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float aberration = 0.0012;
uniform float vignette = 0.6;
uniform float grain = 0.04;
uniform float fade = 0.0;
uniform float flash = 0.0;
uniform float time_s = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r = dot(d, d);
	vec2 off = d * aberration * (1.0 + r * 5.0);
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5236;
		vec2 dir = vec2(cos(a), sin(a));
		glow += max(texture(screen_tex, uv + dir * 0.006).rgb - 0.55, 0.0);
		glow += max(texture(screen_tex, uv + dir * 0.016).rgb - 0.55, 0.0) * 0.8;
	}
	col += glow * 0.075;
	col = clamp(col, 0.0, 1.0);
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.35);
	col *= 1.0 - smoothstep(0.12, 0.8, r * 1.7) * vignette;
	float n = fract(sin(dot(uv * vec2(1920.0, 1080.0) + time_s * vec2(37.0, 91.0), vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;
	col = mix(col, vec3(1.0), flash);
	col *= 1.0 - fade;
	COLOR = vec4(col, 1.0);
}
"""

const TITLE_SHADER := """
shader_type canvas_item;
uniform vec2 box = vec2(100.0, 100.0);
uniform float sweep = -1.0;
uniform float heat = 0.0;
varying vec2 vp;

void vertex() {
	vp = VERTEX;
}

void fragment() {
	float g = clamp(vp.y / box.y, 0.0, 1.0);
	vec3 top = vec3(1.0, 0.97, 0.80);
	vec3 mid = vec3(0.98, 0.74, 0.28);
	vec3 low = vec3(0.55, 0.28, 0.08);
	vec3 refl = vec3(1.0, 0.80, 0.40);
	vec3 c = g < 0.54 ? mix(top, mid, g / 0.54) : mix(low, refl, pow((g - 0.54) / 0.46, 1.4));
	float band = smoothstep(0.08, 0.0, abs(vp.x / box.x - sweep + (vp.y / box.y) * 0.3));
	c += vec3(1.0, 0.95, 0.8) * band * 0.8;
	c += vec3(0.5, 0.3, 0.1) * heat;
	float fill = step(0.5, COLOR.r);
	COLOR.rgb = mix(COLOR.rgb, c, fill);
}
"""


## Camada de desenho (uma por Control): o painter pinta nela. Aditiva = brilhos.
class Layer extends Control:
	var painter := Callable()

	func _init(additive := false) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		if additive:
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			material = m

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


var _t := 0.0
var _clock := 0.0
var _phase := Phase.INTRO
var _outro_t := 0.0
var _exit_sent := false
var _hold := 0.0
var _flash := 0.0
var _shake_amp := 0.0
var _shake := Vector2.ZERO
var _cam := Vector2.ZERO
var _zoom := 1.0
var _impacted := false
var _sparks: Array = []
var _embers: Array = []
var _spark_acc := 0.0
var _ember_acc := 0.0
var _rng := RandomNumberGenerator.new()
var _stars: Array = []
var _ridges: Array = []
var _towers: Array = []
var _tiles: Array = []
var _lines: Array = []
var _soft_tex: GradientTexture2D
var _arena_mesh: ArrayMesh
var _layers: Array = []
var _title1: Label
var _title2: Label
var _prompt: Label
var _post: ColorRect
var _post_mat: ShaderMaterial
var _title_mat1: ShaderMaterial
var _title_mat2: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	UITheme.get_theme()
	_rng.seed = 20260
	_make_soft_tex()
	_build_world()
	_add_layer(false, _paint_sky)
	_add_layer(true, _paint_glow)
	_add_layer(false, _paint_land)
	_add_layer(true, _paint_fx)
	_make_labels()
	_add_layer(false, _paint_ui)
	_make_post()
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility)
	_layout()
	_restart()
	set_process(is_visible_in_tree())


func _on_visibility() -> void:
	var on := is_visible_in_tree()
	set_process(on)
	if on:
		_restart()


func _make_soft_tex() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0)])
	_soft_tex = GradientTexture2D.new()
	_soft_tex.gradient = g
	_soft_tex.fill = GradientTexture2D.FILL_RADIAL
	_soft_tex.fill_from = Vector2(0.5, 0.5)
	_soft_tex.fill_to = Vector2(1.0, 0.5)
	_soft_tex.width = 256
	_soft_tex.height = 256


func _glow(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	ci.draw_texture_rect(_soft_tex, Rect2(center - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)), false, col)


func _add_layer(additive: bool, painter: Callable) -> void:
	var l := Layer.new(additive)
	l.painter = painter
	add_child(l)
	_layers.append(l)


# ---------------------------------------------------------------- controle

## Reinicia a abertura do zero.
func _restart() -> void:
	_t = 0.0
	_clock = 0.0
	_phase = Phase.INTRO
	_outro_t = 0.0
	_exit_sent = false
	_hold = 0.0
	_flash = 0.0
	_shake_amp = 0.0
	_impacted = false
	_sparks.clear()
	_embers.clear()
	_arena_mesh = null
	for i in 45:
		_spawn_ember(true)
	advance(0.0)


## Uma tecla/clique: durante a abertura pula para o final; no final comeca a saida.
func press() -> void:
	match _phase:
		Phase.INTRO:
			_t = maxf(_t, T_SETTLED + 0.2)
			_impacted = true
			_hold = 0.0
			_sparks.clear()
			_flash = 0.7
			_shake_amp = 14.0
			_phase = Phase.IDLE
		Phase.IDLE:
			_phase = Phase.OUTRO
			_outro_t = 0.0
			_flash = 0.45
			_shake_amp = 10.0


func is_intro_playing() -> bool:
	return _phase == Phase.INTRO


## Avanca a animacao (tambem usado pelos testes com passo fixo).
func advance(dt: float) -> void:
	_clock += dt
	var sim := dt
	if _hold > 0.0:
		_hold -= dt
		sim = 0.0
	if sim > 0.0:
		_t += sim
	if _phase == Phase.INTRO and _t >= T_SETTLED:
		_phase = Phase.IDLE
	if _phase == Phase.OUTRO:
		_outro_t += dt
		if _outro_t >= OUTRO_TIME and not _exit_sent:
			_exit_sent = true
			exit_done.emit()
	if not _impacted and _t >= T_IMPACT:
		_impacted = true
		_hold = 0.09
		_flash = 1.0
		_shake_amp = 30.0
		_burst_sparks(180)
	_update_particles(sim)
	_flash = maxf(0.0, _flash - dt * 3.2)
	_shake_amp *= exp(-dt * 7.0)
	_shake = Vector2(sin(_clock * 93.0), cos(_clock * 77.0 + 1.3)) * _shake_amp
	_update_camera(dt)
	_update_ui()
	for l in _layers:
		l.queue_redraw()


func _process(delta: float) -> void:
	advance(minf(delta, 0.05))


func _update_camera(dt: float) -> void:
	var k := clampf(_t / T_IMPACT, 0.0, 1.0)
	var base := lerpf(1.16, 1.0, _ease_out(k))
	var ti := _t - T_IMPACT
	var punch := 0.0
	if ti > 0.0:
		punch = 0.05 * exp(-ti * 7.0)
	var outro := 0.0
	if _phase == Phase.OUTRO:
		var o := clampf(_outro_t / OUTRO_TIME, 0.0, 1.0)
		outro = 0.22 * o * o
	_zoom = base + punch + outro
	var m := get_local_mouse_position()
	var target := Vector2.ZERO
	if size.x > 1.0 and size.y > 1.0:
		target = Vector2(clampf(m.x / size.x - 0.5, -0.5, 0.5), clampf(m.y / size.y - 0.5, -0.5, 0.5)) * -2.0
	_cam = _cam.lerp(target, 1.0 - exp(-dt * 3.0))


# ---------------------------------------------------------------- construcao

func _build_world() -> void:
	for i in 70:
		_stars.append({"p": Vector2(_rng.randf_range(-2400.0, 2400.0), _rng.randf_range(-900.0, -140.0)),
				"r": _rng.randf_range(0.7, 1.9), "sp": _rng.randf_range(0.6, 2.4), "ph": _rng.randf_range(0.0, TAU)})
	_ridges = [
		{"pts": _ridge_points(11, 118.0, 210.0, 0.0017, 0.30), "col": Color(0.55, 0.24, 0.42), "rim": Color(1.0, 0.62, 0.34), "depth": 6.0},
		{"pts": _ridge_points(23, 168.0, 160.0, 0.0023, 0.40), "col": Color(0.25, 0.13, 0.33), "rim": Color(0.95, 0.5, 0.35), "depth": 12.0},
		{"pts": _ridge_points(37, 236.0, 120.0, 0.0031, 0.55), "col": Color(0.10, 0.08, 0.22), "rim": Color(0.6, 0.35, 0.5), "depth": 20.0},
	]
	for r in _ridges:
		_bake_ridge(r)
	_towers = [
		{"x": - 640.0, "w": 86.0, "h": 190.0, "kind": 0}, {"x": - 560.0, "w": 50.0, "h": 280.0, "kind": 1},
		{"x": - 730.0, "w": 60.0, "h": 120.0, "kind": 0}, {"x": 560.0, "w": 78.0, "h": 170.0, "kind": 0},
		{"x": 640.0, "w": 46.0, "h": 250.0, "kind": 1}, {"x": 700.0, "w": 40.0, "h": 110.0, "kind": 2},
	]
	for j in GRID_N:
		for i in GRID_N:
			var r := _rng.randf()
			var h := 0
			if r > 0.86:
				h = 2
			elif r > 0.62:
				h = 1
			if absi(i - j) <= 1 and absi(i + j - (GRID_N - 1)) <= 2:
				h = 0
			_tiles.append({"i": i, "j": j, "h": h, "c": _tile_center(i, j)})
	_tiles.sort_custom(func(a, b): return a.i + a.j < b.i + b.j or (a.i + a.j == b.i + b.j and a.i < b.i))
	for i in 44:
		_lines.append({"a": _rng.randf_range(0.0, TAU), "r0": _rng.randf_range(90.0, 220.0),
				"len": _rng.randf_range(500.0, 1500.0), "w": _rng.randf_range(0.012, 0.05)})


## Malha do preenchimento e cores do brilho da crista, calculadas uma vez (evita triangular todo quadro).
func _bake_ridge(r: Dictionary) -> void:
	var pts: PackedVector2Array = r.pts
	var verts := PackedVector2Array()
	for k in range(0, pts.size() - 1):
		var a := pts[k]
		var b := pts[k + 1]
		var a2 := Vector2(a.x, 1500.0)
		var b2 := Vector2(b.x, 1500.0)
		verts.append_array(PackedVector2Array([a, b, b2, a, b2, a2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	r["mesh"] = mesh
	var rim: Color = r.rim
	var cols := PackedColorArray()
	for k in pts.size():
		var near_sun := exp(-pow(pts[k].x / 520.0, 2.0))
		cols.append(Color(rim.r, rim.g, rim.b, (0.15 + 0.85 * near_sun) * 0.8))
	r["rim_cols"] = cols


func _ridge_points(seed_v: int, base_y: float, amp: float, freq: float, valley: float) -> PackedVector2Array:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_octaves = 4
	n.frequency = freq
	var pts := PackedVector2Array()
	var x := -2400.0
	while x <= 2400.0:
		var v := n.get_noise_1d(x) * 0.5 + 0.5
		var damp := lerpf(valley, 1.0, smoothstep(0.0, 760.0, absf(x)))
		pts.append(Vector2(x, base_y - v * amp * damp))
		x += 20.0
	return pts


func _ridge_y(pts: PackedVector2Array, x: float) -> float:
	var i := clampi(int((x + 2400.0) / 20.0), 0, pts.size() - 1)
	return pts[i].y


func _tile_center(i: int, j: int) -> Vector2:
	return GRID_ORIGIN + Vector2(float(i - j) * TILE_W * 0.5, float(i + j - (GRID_N - 1)) * TILE_H * 0.5)


func _make_labels() -> void:
	_title_mat1 = _title_material()
	_title_mat2 = _title_material()
	_title1 = _make_title("TACTICS", _title_mat1)
	_title2 = _make_title("PVP", _title_mat2)
	_prompt = Label.new()
	_prompt.name = "PressAnyKey"
	_prompt.text = "Pressione qualquer tecla para iniciar"
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_theme_font_override("font", UITheme.bold_font)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	_prompt.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.08, 1.0))
	_prompt.modulate.a = 0.0
	add_child(_prompt)


func _title_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = TITLE_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _make_title(text: String, mat: ShaderMaterial) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.material = mat
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.02))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.visible = false
	add_child(l)
	return l


func _make_post() -> void:
	var sh := Shader.new()
	sh.code = POST_SHADER
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = sh
	_post = ColorRect.new()
	_post.name = "Post"
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post.material = _post_mat
	add_child(_post)


func _base_scale() -> float:
	return size.y / H


func _layout() -> void:
	if _title1 == null:
		return
	var s := _base_scale()
	_title1.add_theme_font_override("font", UITheme.title_font)
	_title1.add_theme_font_size_override("font_size", maxi(8, int(176.0 * s)))
	_title1.add_theme_constant_override("outline_size", int(16.0 * s))
	var fv := FontVariation.new()
	fv.base_font = UITheme.title_font
	fv.spacing_glyph = int(44.0 * s)
	_title2.add_theme_font_override("font", fv)
	_title2.add_theme_font_size_override("font_size", maxi(8, int(104.0 * s)))
	_title2.add_theme_constant_override("outline_size", int(12.0 * s))
	_prompt.add_theme_font_size_override("font_size", maxi(8, int(27.0 * s)))
	_prompt.add_theme_constant_override("outline_size", int(12.0 * s))
	for l in [_title1, _title2, _prompt]:
		l.reset_size()
	_title_mat1.set_shader_parameter("box", _title1.size)
	_title_mat2.set_shader_parameter("box", _title2.size)


# ---------------------------------------------------------------- utilidades

static func _ease_out(k: float) -> float:
	var q := 1.0 - clampf(k, 0.0, 1.0)
	return 1.0 - q * q * q


func _s() -> float:
	return _base_scale() * _zoom


func _xf(ci: CanvasItem, depth: float) -> Transform2D:
	var s := _s()
	var origin := size * 0.5 + _shake + _cam * depth * _base_scale()
	var t := Transform2D(Vector2(s, 0.0), Vector2(0.0, s), origin)
	ci.draw_set_transform_matrix(t)
	return t


func _ex() -> float:
	return size.x * 0.5 / _s() + 140.0


func _ey() -> float:
	return size.y * 0.5 / _s() + 140.0


func _vgrad(ci: CanvasItem, x0: float, x1: float, y0: float, y1: float, c0: Color, c1: Color) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
			PackedColorArray([c0, c0, c1, c1]))


func _blob(ci: CanvasItem, _base: Transform2D, center: Vector2, rx: float, ry: float, col: Color, steps := 8) -> void:
	_glow(ci, center, rx, ry, Color(col.r, col.g, col.b, clampf(col.a * float(steps) * 0.7, 0.0, 1.0)))


func _sun_pos() -> Vector2:
	var rise := _ease_out(clampf((_t - 0.5) / 2.2, 0.0, 1.0))
	return Vector2(SUN_C.x, SUN_C.y + (1.0 - rise) * 240.0)


func _impact_time() -> float:
	return _t - T_IMPACT


# ---------------------------------------------------------------- ceu

func _paint_sky(ci: CanvasItem) -> void:
	var base := _xf(ci, 0.0)
	var ex := _ex()
	var ey := _ey()
	var c0 := Color(0.022, 0.03, 0.105)
	var c1 := Color(0.11, 0.08, 0.28)
	var c2 := Color(0.52, 0.19, 0.40)
	var c3 := Color(1.0, 0.58, 0.30)
	var c4 := Color(0.30, 0.13, 0.28)
	_vgrad(ci, -ex, ex, -ey, -320.0, c0, c1)
	_vgrad(ci, -ex, ex, -320.0, -40.0, c1, c2)
	_vgrad(ci, -ex, ex, -40.0, 120.0, c2, c3)
	_vgrad(ci, -ex, ex, 120.0, ey, c3, c4)
	_xf(ci, 2.0)
	for s in _stars:
		var p: Vector2 = s.p
		var fade := clampf((-60.0 - p.y) / 420.0, 0.0, 1.0)
		var tw := 0.55 + 0.45 * sin(_clock * float(s.sp) + float(s.ph))
		ci.draw_circle(p, float(s.r), Color(1.0, 0.97, 0.9, 0.85 * tw * fade))
	_xf(ci, 3.0)
	var sp := _sun_pos()
	ci.draw_circle(sp, 176.0, Color(1.0, 0.74, 0.46))
	ci.draw_circle(sp, 132.0, Color(1.0, 0.86, 0.62))
	ci.draw_circle(sp, 84.0, Color(1.0, 0.95, 0.80))
	ci.draw_set_transform_matrix(base)


func _paint_glow(ci: CanvasItem) -> void:
	_xf(ci, 3.0)
	var sp := _sun_pos()
	var rise := _ease_out(clampf((_t - 0.4) / 2.2, 0.0, 1.0))
	var boost := 1.0
	var ti := _impact_time()
	if ti > 0.0:
		boost += 1.2 * exp(-ti * 2.2)
	var gl_a := (0.3 + 0.7 * rise) * boost
	_glow(ci, sp, 1250.0, 1250.0, Color(1.0, 0.5, 0.24, clampf(0.22 * gl_a, 0.0, 1.0)))
	_glow(ci, sp, 520.0, 520.0, Color(1.0, 0.62, 0.3, clampf(0.35 * gl_a, 0.0, 1.0)))
	for k in 18:
		var a := -PI * 0.5 + (float(k) - 8.5) * 0.19 + sin(_clock * 0.25 + float(k) * 1.7) * 0.025
		var spread := 0.032 + 0.014 * sin(float(k) * 2.3)
		var pa := sp + Vector2(cos(a - spread), sin(a - spread)) * 2600.0
		var pb := sp + Vector2(cos(a + spread), sin(a + spread)) * 2600.0
		var ca := 0.13 * rise * boost * (0.6 + 0.4 * sin(_clock * 0.8 + float(k)))
		ci.draw_polygon(PackedVector2Array([sp, pa, pb]),
				PackedColorArray([Color(1.0, 0.72, 0.42, ca), Color(1.0, 0.6, 0.35, 0.0), Color(1.0, 0.6, 0.35, 0.0)]))
	var sigil := _ease_out(clampf((_t - 1.8) / 1.6, 0.0, 1.0))
	if sigil > 0.0:
		var c := Vector2(0.0, -70.0)
		var pulse := 1.0 + 1.4 * exp(-maxf(ti, 0.0) * 3.0) if ti > 0.0 else 1.0
		var col := Color(1.0, 0.86, 0.58, 0.30 * sigil * pulse)
		var rot := _clock * 0.06
		var r1 := 300.0 * (0.85 + 0.15 * sigil)
		ci.draw_arc(c, r1, 0.0, TAU, 160, col, 2.0, true)
		ci.draw_arc(c, r1 + 14.0, 0.0, TAU, 160, Color(col.r, col.g, col.b, col.a * 0.6), 1.2, true)
		ci.draw_arc(c, r1 * 1.55, 0.0, TAU, 200, Color(col.r, col.g, col.b, col.a * 0.45), 1.5, true)
		for k in 96:
			var a := rot + float(k) / 96.0 * TAU
			var long := k % 8 == 0
			var l0 := r1 + 14.0
			var l1 := l0 + (26.0 if long else 9.0)
			var d := Vector2(cos(a), sin(a))
			ci.draw_line(c + d * l0, c + d * l1, Color(col.r, col.g, col.b, col.a * (1.0 if long else 0.55)), 2.0 if long else 1.2)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------- terra, ruinas, arena, guerreiros

func _paint_land(ci: CanvasItem) -> void:
	var ex := _ex()
	var ey := _ey()
	var sun := _sun_pos()
	var mist_col := Color(0.95, 0.5, 0.4, 0.035)
	for idx in _ridges.size():
		var r: Dictionary = _ridges[idx]
		var base := _xf(ci, float(r.depth))
		var pts: PackedVector2Array = r.pts
		ci.draw_mesh(r.mesh, null, Transform2D.IDENTITY, r.col)
		ci.draw_polyline_colors(pts, r.rim_cols, 2.5, true)
		if idx == 1:
			_paint_towers(ci, pts)
		var drift := _clock * (6.0 + 5.0 * float(idx))
		for k in 6:
			var x := fposmod(float(k) * 760.0 + drift + float(idx) * 311.0, 4800.0) - 2400.0
			var y := float(pts[clampi(int((x + 2400.0) / 20.0), 0, pts.size() - 1)].y) + 26.0
			_blob(ci, base, Vector2(x, y), 620.0, 56.0, mist_col, 8)
		ci.draw_set_transform_matrix(base)
	_paint_arena(ci)
	_paint_fighters(ci)
	var fb := _xf(ci, 20.0)
	_blob(ci, fb, Vector2(0.0, 40.0), 1100.0, 90.0, Color(0.96, 0.52, 0.36, 0.05), 8)
	_vgrad(ci, -ex, ex, ey - 140.0, ey + 40.0, Color(0.03, 0.03, 0.09, 0.0), Color(0.03, 0.03, 0.09, 0.85))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _paint_towers(ci: CanvasItem, pts: PackedVector2Array) -> void:
	var dark := Color(0.17, 0.09, 0.26)
	for tw in _towers:
		var x: float = tw.x
		var w: float = tw.w
		var h: float = tw.h
		var by := _ridge_y(pts, x) + 8.0
		var poly := PackedVector2Array()
		poly.append(Vector2(x - w * 0.5, by))
		poly.append(Vector2(x - w * 0.5, by - h))
		if int(tw.kind) == 1:
			poly.append(Vector2(x - w * 0.62, by - h))
			poly.append(Vector2(x, by - h - w * 1.7))
			poly.append(Vector2(x + w * 0.62, by - h))
		elif int(tw.kind) == 2:
			poly.append(Vector2(x - w * 0.1, by - h - 16.0))
			poly.append(Vector2(x + w * 0.5, by - h + 30.0))
		else:
			var n := 4
			var mw := w / float(n * 2 - 1)
			for k in n * 2 - 1:
				var up := k % 2 == 0
				var xa := x - w * 0.5 + mw * float(k)
				poly.append(Vector2(xa, by - h - (14.0 if up else 0.0)))
				poly.append(Vector2(xa + mw, by - h - (14.0 if up else 0.0)))
		poly.append(Vector2(x + w * 0.5, by - h))
		poly.append(Vector2(x + w * 0.5, by))
		ci.draw_colored_polygon(poly, dark)
		var lit := 0.55 + 0.45 * sin(_clock * 1.7 + x * 0.013)
		if int(tw.kind) != 2:
			ci.draw_rect(Rect2(x - 4.0, by - h * 0.62, 8.0, 15.0), Color(1.0, 0.72, 0.32, 0.8 * lit))
			ci.draw_rect(Rect2(x - 4.0, by - h * 0.32, 8.0, 15.0), Color(1.0, 0.72, 0.32, 0.55 * lit))
	var wall := PackedVector2Array([Vector2(-760.0, _ridge_y(pts, -760.0) + 8.0), Vector2(-760.0, _ridge_y(pts, -760.0) - 70.0),
			Vector2(-520.0, _ridge_y(pts, -520.0) - 90.0), Vector2(-520.0, _ridge_y(pts, -520.0) + 8.0)])
	ci.draw_colored_polygon(wall, dark)


func _paint_arena(ci: CanvasItem) -> void:
	var base := _xf(ci, 22.0)
	var ti := _impact_time()
	if ti > 3.2:
		if _arena_mesh == null:
			_bake_arena()
		ci.draw_mesh(_arena_mesh, null)
		ci.draw_set_transform_matrix(base)
		return
	for t in _tiles:
		_arena_tile(ci, t, ti, false, null)
	ci.draw_set_transform_matrix(base)


## Quando a onda do impacto passou, a arena fica parada: vira uma malha unica (poucas chamadas por quadro).
func _bake_arena() -> void:
	var sink := {"v": PackedVector2Array(), "c": PackedColorArray()}
	for t in _tiles:
		_arena_tile(null, t, 10.0, true, sink)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = sink.v
	arrays[Mesh.ARRAY_COLOR] = sink.c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_arena_mesh = mesh


func _emit_poly(ci: CanvasItem, sink: Variant, pts: Array, col: Color) -> void:
	if sink == null:
		ci.draw_colored_polygon(PackedVector2Array(pts), col)
		return
	for k in range(1, pts.size() - 1):
		sink.v.append(pts[0])
		sink.v.append(pts[k])
		sink.v.append(pts[k + 1])
		sink.c.append(col)
		sink.c.append(col)
		sink.c.append(col)


func _emit_lines(ci: CanvasItem, sink: Variant, pts: Array, col: Color, width: float) -> void:
	if sink == null:
		ci.draw_polyline(PackedVector2Array(pts), col, width, true)
		return
	var hw := width * 0.5
	for k in range(0, pts.size() - 1):
		var p0: Vector2 = pts[k]
		var p1: Vector2 = pts[k + 1]
		var n := (p1 - p0).orthogonal().normalized() * hw
		var q: Array = [p0 - n, p0 + n, p1 + n, p1 - n]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for ix in tri:
				sink.v.append(q[ix])
				sink.c.append(col)


func _arena_tile(ci: CanvasItem, t: Dictionary, ti: float, bake: bool, sink: Variant) -> void:
	var i: int = t.i
	var j: int = t.j
	var c: Vector2 = t.c
	var k := 1.0
	var delay := 0.0
	var dist := Vector2(c.x - FLOOR_C.x, (c.y - FLOOR_C.y) * 2.0).length()
	if not bake:
		delay = 0.9 + dist * 0.0016
		k = _ease_out(clampf((_t - delay) / 0.75, 0.0, 1.0))
		if k <= 0.0:
			return
	if c.y > 640.0:
		return
	var wave := 0.0
	if ti > 0.0 and ti < 3.2:
		wave = exp(-pow((dist - ti * 950.0) / 100.0, 2.0)) * exp(-ti * 1.5)
	var hh := float(t.h) * 13.0 + wave * 28.0
	var y := c.y + (1.0 - k) * 150.0 - hh
	var depth := 22.0 + float(t.h) * 13.0 + wave * 28.0
	var zone := float(i - j)
	var side_col := BLUE if zone < 0.0 else RED
	var zone_k := clampf((absf(zone) - 3.0) / 3.0, 0.0, 1.0)
	var haze := clampf((c.y - 50.0) / 300.0, 0.0, 1.0)
	var alpha := k * (0.35 + 0.65 * haze)
	var top := Color(0.13, 0.14, 0.27)
	if wave > 0.001:
		top = top.lerp(Color(0.36, 0.30, 0.34), wave * 0.8)
	if zone_k > 0.0:
		top = top.lerp(side_col * 0.55, zone_k * 0.22)
	top.a = alpha
	var hw := TILE_W * 0.5
	var hh2 := TILE_H * 0.5
	var pt := Vector2(c.x, y - hh2)
	var pr := Vector2(c.x + hw, y)
	var pb := Vector2(c.x, y + hh2)
	var pl := Vector2(c.x - hw, y)
	var dv := Vector2(0.0, depth)
	_emit_poly(ci, sink, [pl, pb, pb + dv, pl + dv], Color(top.r * 0.5, top.g * 0.5, top.b * 0.55, alpha))
	_emit_poly(ci, sink, [pb, pr, pr + dv, pb + dv], Color(top.r * 0.34, top.g * 0.34, top.b * 0.4, alpha))
	_emit_poly(ci, sink, [pt, pr, pb, pl], top)
	var shimmer := 0.5 if bake else 0.5 + 0.5 * sin(_clock * 1.3 - float(i + j) * 0.55)
	var ea := (0.20 + 0.18 * shimmer + wave * 1.4) * alpha
	var ecol := Color(0.75, 0.82, 1.0, ea)
	if zone_k > 0.0:
		ecol = ecol.lerp(Color(side_col.r, side_col.g, side_col.b, ea * 1.6), zone_k)
	if wave > 0.01:
		ecol = ecol.lerp(Color(1.0, 0.85, 0.55, clampf(ea * 1.5, 0.0, 1.0)), clampf(wave * 1.5, 0.0, 1.0))
	_emit_lines(ci, sink, [pt, pr, pb, pl, pt], ecol, 1.6)
	if zone_k > 0.99 and absi(i + j - (GRID_N - 1)) <= 3:
		var q := 0.38
		_emit_lines(ci, sink, [pt * 0.62 + c * q, pr * 0.62 + c * q, pb * 0.62 + c * q, pl * 0.62 + c * q, pt * 0.62 + c * q],
				Color(side_col.r, side_col.g, side_col.b, 0.45 * alpha), 1.4)


func _fighter_state(side: float) -> Dictionary:
	var t := _t
	var x := 640.0
	var p := 0.0
	var speed := 0.0
	var vis := clampf((t - T_FIGHTERS) / 0.6, 0.0, 1.0)
	var x_creep := 540.0
	var x_hit := 120.0
	var x_lock := 250.0
	if t < T_CREEP:
		x = 640.0
	elif t < T_DASH:
		var k := (t - T_CREEP) / (T_DASH - T_CREEP)
		x = lerpf(640.0, x_creep, k)
		p = 0.1 * k
	elif t < T_IMPACT:
		var k2 := (t - T_DASH) / (T_IMPACT - T_DASH)
		x = lerpf(x_creep, x_hit, k2 * k2)
		p = lerpf(0.1, 1.0, smoothstep(0.0, 0.75, k2))
		speed = k2
	else:
		var k3 := clampf((t - T_IMPACT) / 0.45, 0.0, 1.0)
		x = lerpf(x_hit, x_lock, _ease_out(k3))
		p = 1.0 - 0.1 * k3
		x += sin(_clock * 70.0) * 2.5 * (1.0 - k3) * side
	return {"x": x, "p": p, "speed": speed, "vis": vis}


func _paint_fighters(ci: CanvasItem) -> void:
	var base := _xf(ci, 26.0)
	for side in [-1.0, 1.0]:
		var st := _fighter_state(side)
		if float(st.vis) <= 0.0:
			continue
		var dir: float = - side
		var feet := Vector2(side * float(st.x), FEET_Y)
		var vis: float = st.vis
		var rim := BLUE if side < 0.0 else RED
		var glow := 0.0
		if _impact_time() > 0.0:
			glow = exp(-_impact_time() * 2.0)
		rim = rim.lightened(0.25 + 0.5 * glow)
		var speed: float = st.speed
		if speed > 0.05:
			for g in 5:
				var back := float(g + 1) * 34.0 * speed
				var ga := 0.10 * vis * (1.0 - float(g) / 5.0) * speed
				_fighter_pass(ci, feet + Vector2(-dir * back, 0.0), dir, float(st.p), side < 0.0,
						Color(rim.r, rim.g, rim.b, ga), Vector2.ZERO, speed)
		_fighter_pass(ci, feet, dir, float(st.p), side < 0.0, Color(rim.r, rim.g, rim.b, vis), Vector2(dir * 3.2, -2.2), speed)
		_fighter_pass(ci, feet, dir, float(st.p), side < 0.0, Color(INK.r, INK.g, INK.b, vis), Vector2.ZERO, speed)
		_fighter_pass(ci, feet, dir, float(st.p), side < 0.0, Color(1.0, 1.0, 1.0, vis), Vector2.ZERO, speed, true)
	ci.draw_set_transform_matrix(base)


func _wp(feet: Vector2, dir: float, v: Vector2) -> Vector2:
	return feet + Vector2(v.x * dir * UNIT, v.y * UNIT)


func _limb(ci: CanvasItem, a: Vector2, b: Vector2, wd: float, col: Color) -> void:
	ci.draw_line(a, b, col, wd * UNIT, true)
	ci.draw_circle(a, wd * UNIT * 0.5, col)
	ci.draw_circle(b, wd * UNIT * 0.5, col)


func _poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(p)
	ci.draw_colored_polygon(arr, col)


## Para formas animadas (capa, pluma): se a forma se cruzar, usa o fecho convexo em vez de dar erro.
func _poly_safe(ci: CanvasItem, pts: Array, col: Color) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(p)
	if Geometry2D.triangulate_polygon(arr).is_empty():
		arr = Geometry2D.convex_hull(arr)
		if arr.size() < 3:
			return
	ci.draw_colored_polygon(arr, col)


## Silhueta de um guerreiro. knight: cavaleiro (espada e escudo, azul); senao lanceiro encapuzado.
## p: 0 = guarda, 1 = golpe estendido ate o ponto do choque. acc: so os detalhes claros (armadura, aco).
func _fighter_pass(ci: CanvasItem, feet: Vector2, dir: float, p: float, knight: bool, col: Color,
		off: Vector2, speed: float, acc := false) -> void:
	var f := feet + off
	var breath := sin(_clock * 2.2 + dir) * 0.05
	var lean := 0.35 + 0.65 * p
	var crouch := 0.0 if knight else 0.5
	var H := Vector2(0.2 + 0.5 * lean, -4.1 + crouch + breath)
	var S := H + Vector2(0.9 * lean + 0.1, -2.7)
	var head := S + Vector2(0.3 + 0.15 * lean, -1.3)
	var drag := 1.0 + speed * 1.5
	var wave := sin(_clock * 5.0 + dir * 2.0)
	var hip_f := H + Vector2(0.3, 0.0)
	var hip_b := H + Vector2(-0.2, 0.0)
	var foot_f := Vector2(2.3 + 0.7 * p, 0.0)
	var foot_b := Vector2(-2.3 - 0.5 * p, 0.0)
	var knee_f := H + Vector2(1.55 + 0.4 * p, 1.5 + crouch * 0.2)
	var knee_b := hip_b.lerp(foot_b, 0.52) + Vector2(0.1, -0.15)
	# arma e bracos (pontos)
	var hand := Vector2.ZERO
	var elbow := Vector2.ZERO
	var rear := Vector2.ZERO
	var front := Vector2.ZERO
	var weapon_dir := Vector2.ZERO
	var weapon_from := Vector2.ZERO
	var weapon_tip := Vector2.ZERO
	if knight:
		hand = (S + Vector2(-0.3, -2.0)).lerp(S + Vector2(1.9, 0.25), p)
		elbow = S + (hand - S) * 0.5 + Vector2(-0.3, 0.9)
		weapon_from = _wp(f, dir, hand)
		var aim := _world_clash(feet, weapon_from) - weapon_from
		weapon_dir = Vector2(0.35 * dir, -0.94).lerp(aim.normalized(), p).normalized()
		weapon_tip = weapon_from + weapon_dir * UNIT * 5.4
	else:
		rear = (S + Vector2(0.1, 1.5)).lerp(H + Vector2(0.45, -0.35), p)
		front = rear + Vector2(1.9 + 0.3 * p, -0.35)
		weapon_from = _wp(f, dir, rear)
		var aim2 := _world_clash(feet, weapon_from) - weapon_from
		weapon_dir = Vector2(0.06 * dir, -1.0).lerp(aim2.normalized(), p).normalized()
		weapon_tip = weapon_from + weapon_dir * UNIT * 5.8
	var sh_hand := S + Vector2(1.7 + 0.2 * p, 0.8)
	var sc := _wp(f, dir, sh_hand + Vector2(0.4, 0.1))
	var shield: Array = [sc + Vector2(-0.1 * dir, -1.8) * UNIT, sc + Vector2(0.95 * dir, -1.05) * UNIT,
			sc + Vector2(0.8 * dir, 0.6) * UNIT, sc + Vector2(0.05 * dir, 2.1) * UNIT,
			sc + Vector2(-0.75 * dir, 0.6) * UNIT, sc + Vector2(-0.85 * dir, -1.05) * UNIT]
	if acc:
		_fighter_accents(ci, f, dir, knight, S, H, head, shield, sc, weapon_from, weapon_tip, drag, wave, col)
		return
	# capa
	var cape_w := 2.0 if knight else 3.0
	var cape_l := 4.6 if knight else 5.6
	var cape: Array = [_wp(f, dir, S + Vector2(-0.3, -0.05)), _wp(f, dir, S + Vector2(0.4, 0.2)),
			_wp(f, dir, S + Vector2(-0.3 - cape_w * 0.25 * drag + wave * 0.12, cape_l)),
			_wp(f, dir, S + Vector2(-1.2 - cape_w * drag + wave * 0.35, cape_l * 0.88 - (0.0 if knight else 0.5 * absf(wave)))),
			_wp(f, dir, S + Vector2(-0.8 - cape_w * 0.45 * drag - wave * 0.2, cape_l * 0.5))]
	_poly_safe(ci, cape, col)
	# pernas
	_limb(ci, _wp(f, dir, hip_b), _wp(f, dir, knee_b), 0.95, col)
	_limb(ci, _wp(f, dir, knee_b), _wp(f, dir, foot_b + Vector2(0.0, -0.2)), 0.74, col)
	_limb(ci, _wp(f, dir, hip_f), _wp(f, dir, knee_f), 1.0, col)
	_limb(ci, _wp(f, dir, knee_f), _wp(f, dir, foot_f + Vector2(0.0, -0.2)), 0.78, col)
	for ft in [foot_f, foot_b]:
		_poly(ci, [_wp(f, dir, ft + Vector2(-0.4, -0.55)), _wp(f, dir, ft + Vector2(0.85, -0.45)),
				_wp(f, dir, ft + Vector2(1.05, 0.0)), _wp(f, dir, ft + Vector2(-0.45, 0.0))], col)
	# tronco (ombros largos, cintura estreita) e saia
	_poly(ci, [_wp(f, dir, H + Vector2(-0.62, 0.1)), _wp(f, dir, S + Vector2(-0.95, -0.1)),
			_wp(f, dir, S + Vector2(0.05, -0.45)), _wp(f, dir, S + Vector2(1.0, -0.05)), _wp(f, dir, H + Vector2(0.68, 0.1))], col)
	_poly(ci, [_wp(f, dir, H + Vector2(-0.75, 0.0)), _wp(f, dir, H + Vector2(0.8, 0.0)),
			_wp(f, dir, H + Vector2(1.3 + 0.3 * p, 1.9)), _wp(f, dir, H + Vector2(-1.3, 2.0 + 0.15 * wave))], col)
	# pescoco e cabeca
	_limb(ci, _wp(f, dir, S + Vector2(0.1, -0.3)), _wp(f, dir, head + Vector2(-0.05, 0.3)), 0.5, col)
	ci.draw_circle(_wp(f, dir, head), 0.68 * UNIT, col)
	if knight:
		var plume: Array = [_wp(f, dir, head + Vector2(-0.1, -0.55)),
				_wp(f, dir, head + Vector2(-1.6 * drag, -1.15 + wave * 0.2)),
				_wp(f, dir, head + Vector2(-2.5 * drag, -0.35 + wave * 0.35)),
				_wp(f, dir, head + Vector2(-0.5, 0.05))]
		_poly_safe(ci, plume, col)
		_poly(ci, [_wp(f, dir, head + Vector2(-0.7, -0.3)), _wp(f, dir, head + Vector2(0.0, -1.0)),
				_wp(f, dir, head + Vector2(0.7, -0.25)), _wp(f, dir, head + Vector2(0.55, 0.62)),
				_wp(f, dir, head + Vector2(-0.55, 0.62))], col)
	else:
		_poly(ci, [_wp(f, dir, head + Vector2(0.6, -0.5)), _wp(f, dir, head + Vector2(0.0, -1.25)),
				_wp(f, dir, head + Vector2(-1.3 * drag, 0.2)), _wp(f, dir, head + Vector2(-0.95, 1.05)),
				_wp(f, dir, head + Vector2(0.1, 0.85))], col)
	# bracos e armas
	var sh_back := S + Vector2(-0.2, 0.1)
	if knight:
		_limb(ci, _wp(f, dir, sh_back), _wp(f, dir, elbow), 0.66, col)
		_limb(ci, _wp(f, dir, elbow), weapon_from, 0.58, col)
		var perp := Vector2(-weapon_dir.y, weapon_dir.x)
		ci.draw_polygon(PackedVector2Array([weapon_from + perp * 0.2 * UNIT, weapon_tip, weapon_from - perp * 0.2 * UNIT]),
				PackedColorArray([col, col, col]))
		ci.draw_line(weapon_from - perp * 0.75 * UNIT, weapon_from + perp * 0.75 * UNIT, col, 0.26 * UNIT, true)
		ci.draw_circle(weapon_from - weapon_dir * 0.4 * UNIT, 0.22 * UNIT, col)
		var elb2 := S + Vector2(1.0, 1.4)
		_limb(ci, _wp(f, dir, S + Vector2(0.25, 0.2)), _wp(f, dir, elb2), 0.66, col)
		_limb(ci, _wp(f, dir, elb2), _wp(f, dir, sh_hand), 0.58, col)
		_poly(ci, shield, col)
	else:
		var el_r := S + Vector2(-0.4, 1.9)
		var el_f := S + Vector2(1.3, 1.2)
		_limb(ci, _wp(f, dir, sh_back), _wp(f, dir, el_r), 0.6, col)
		_limb(ci, _wp(f, dir, el_r), _wp(f, dir, rear), 0.54, col)
		_limb(ci, _wp(f, dir, S + Vector2(0.3, 0.2)), _wp(f, dir, el_f), 0.6, col)
		_limb(ci, _wp(f, dir, el_f), _wp(f, dir, front), 0.54, col)
		var perp2 := Vector2(-weapon_dir.y, weapon_dir.x)
		var shaft_back := weapon_from - weapon_dir * UNIT * 2.4
		ci.draw_line(shaft_back, weapon_tip, col, 0.24 * UNIT, true)
		ci.draw_polygon(PackedVector2Array([weapon_tip - weapon_dir * UNIT * 0.3, weapon_tip + perp2 * 0.42 * UNIT + weapon_dir * UNIT * 0.5,
				weapon_tip + weapon_dir * UNIT * 1.7, weapon_tip - perp2 * 0.42 * UNIT + weapon_dir * UNIT * 0.5]),
				PackedColorArray([col, col, col, col]))


## Detalhes claros por cima da silhueta escura (armadura, faixa, brilho do aco): evitam o visual de mancha.
func _fighter_accents(ci: CanvasItem, f: Vector2, dir: float, knight: bool, S: Vector2, H: Vector2, head: Vector2,
		shield: Array, sc: Vector2, w_from: Vector2, w_tip: Vector2, drag: float, wave: float, base: Color) -> void:
	var a := base.a
	var trim := Color(0.34, 0.52, 0.95, 0.75 * a) if knight else Color(0.95, 0.38, 0.32, 0.75 * a)
	var steel := Color(0.88, 0.94, 1.0, 0.95 * a)
	ci.draw_arc(_wp(f, dir, S + Vector2(0.2, 0.05)), 0.56 * UNIT, 0.0, TAU, 20, trim, 1.6, true)
	ci.draw_line(_wp(f, dir, H + Vector2(-0.68, 0.12)), _wp(f, dir, H + Vector2(0.74, 0.12)), trim, 0.16 * UNIT, true)
	if knight:
		var pts := PackedVector2Array(shield)
		pts.append(shield[0])
		ci.draw_polyline(pts, trim, 1.8, true)
		ci.draw_circle(sc, 0.2 * UNIT, trim)
		ci.draw_line(_wp(f, dir, head + Vector2(0.05, 0.1)), _wp(f, dir, head + Vector2(0.62, 0.1)), trim, 1.6, true)
		ci.draw_line(w_from, w_tip, steel, 2.2, true)
	else:
		var sash := PackedVector2Array([_wp(f, dir, H + Vector2(-0.6, -0.05)), _wp(f, dir, H + Vector2(-0.6, 0.3)),
				_wp(f, dir, H + Vector2(-2.1 * drag, 0.6 + wave * 0.35)), _wp(f, dir, H + Vector2(-2.2 * drag, 0.1 + wave * 0.3))])
		ci.draw_colored_polygon(sash, Color(0.8, 0.22, 0.2, 0.9 * a))
		ci.draw_line(_wp(f, dir, head + Vector2(0.5, -0.45)), _wp(f, dir, head + Vector2(-1.0 * drag, 0.3)), trim, 1.6, true)
		ci.draw_line(w_tip - (w_tip - w_from).normalized() * UNIT * 1.2, w_tip, steel, 2.4, true)


## Ponto do choque no mundo, ligeiramente ajustado para o golpe cruzar em X.
func _world_clash(feet: Vector2, hand_world: Vector2) -> Vector2:
	var above := hand_world.y < CLASH_P.y
	return CLASH_P + Vector2(0.0, 18.0 if above else -18.0) + Vector2(0.0, 0.0 * feet.x)


# ---------------------------------------------------------------- particulas

func _spawn_ember(anywhere: bool) -> void:
	var ex := _ex() if size.x > 1.0 else 1000.0
	var ey := _ey() if size.y > 1.0 else 600.0
	var x := _rng.randf_range(-ex, ex)
	var y := _rng.randf_range(-ey * 0.4, ey) if anywhere else ey + 20.0
	var r := _rng.randf()
	var col := Color(1.0, 0.62, 0.26)
	if r > 0.85:
		col = BLUE.lightened(0.3) if x < 0.0 else RED.lightened(0.3)
	var life := _rng.randf_range(4.0, 9.0)
	_embers.append({"p": Vector2(x, y), "v": Vector2(_rng.randf_range(-12.0, 22.0), -_rng.randf_range(30.0, 95.0)),
			"life": life if not anywhere else _rng.randf_range(0.5, life), "max": life, "r": _rng.randf_range(1.2, 3.4),
			"col": col, "ph": _rng.randf_range(0.0, TAU)})


func _burst_sparks(n: int) -> void:
	for i in n:
		var a := _rng.randf_range(-PI, 0.0) if _rng.randf() < 0.75 else _rng.randf_range(0.0, PI)
		var sp := _rng.randf_range(260.0, 1250.0)
		var life := _rng.randf_range(0.5, 1.5)
		_sparks.append({"p": CLASH_P + Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-12.0, 12.0)),
				"v": Vector2(cos(a), sin(a)) * sp, "life": life, "max": life})


func _update_particles(dt: float) -> void:
	if dt <= 0.0:
		return
	_ember_acc += dt * 15.0
	while _ember_acc >= 1.0:
		_ember_acc -= 1.0
		_spawn_ember(false)
	var alive: Array = []
	for e in _embers:
		e.life = float(e.life) - dt
		if float(e.life) <= 0.0:
			continue
		var v: Vector2 = e.v
		v.x += sin(_clock * 0.9 + float(e.ph)) * 18.0 * dt
		e.v = v
		e.p = Vector2(e.p) + v * dt
		alive.append(e)
	_embers = alive
	if _impacted and _t > T_IMPACT + 0.3:
		_spark_acc += dt * 16.0
		while _spark_acc >= 1.0:
			_spark_acc -= 1.0
			var a := _rng.randf_range(-PI * 0.95, -PI * 0.05)
			var life := _rng.randf_range(0.4, 1.1)
			_sparks.append({"p": CLASH_P + Vector2(_rng.randf_range(-8.0, 8.0), 0.0),
					"v": Vector2(cos(a), sin(a)) * _rng.randf_range(120.0, 520.0), "life": life, "max": life})
	var keep: Array = []
	for s in _sparks:
		s.life = float(s.life) - dt
		if float(s.life) <= 0.0:
			continue
		var v2: Vector2 = s.v
		v2.y += 950.0 * dt
		v2 *= (1.0 - 0.9 * dt)
		s.v = v2
		s.p = Vector2(s.p) + v2 * dt
		keep.append(s)
	_sparks = keep


# ---------------------------------------------------------------- efeitos aditivos

func _paint_fx(ci: CanvasItem) -> void:
	var base := _xf(ci, 24.0)
	var ti := _impact_time()
	var haze := 0.0
	if ti > 0.0:
		haze = exp(-ti * 1.8)
	# brilho quente do sol sobre as montanhas
	_blob(ci, base, Vector2(0.0, 60.0), 900.0, 150.0, Color(1.0, 0.5, 0.25, 0.018 * (0.5 + 0.5 * _ease_out(clampf(_t / 3.0, 0.0, 1.0)))), 9)
	# ondas no chao
	if ti > 0.0:
		var squash := base * Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 0.5), FLOOR_C)
		ci.draw_set_transform_matrix(squash)
		for r in 3:
			var tt := ti - float(r) * 0.08
			if tt <= 0.0:
				continue
			var rad := tt * (1050.0 - 130.0 * float(r))
			var a := exp(-tt * 1.7) * (0.9 - 0.2 * float(r))
			ci.draw_arc(Vector2.ZERO, rad, 0.0, TAU, 160, Color(1.0, 0.82, 0.5, a), 7.0 - 2.0 * float(r), true)
			ci.draw_arc(Vector2.ZERO, rad * 0.97, 0.0, TAU, 160, Color(1.0, 0.5, 0.3, a * 0.5), 18.0, true)
		ci.draw_set_transform_matrix(base)
	# linhas de impacto e rastro de luz horizontal
	if ti > 0.0 and ti < 0.45:
		var la := 1.0 - ti / 0.45
		for l in _lines:
			var a: float = l.a
			var d := Vector2(cos(a), sin(a))
			var n := Vector2(-d.y, d.x)
			var r0: float = float(l.r0) + ti * 500.0
			var r1: float = r0 + float(l.len) * (0.4 + ti * 2.0)
			var wd: float = float(l.w)
			ci.draw_polygon(PackedVector2Array([CLASH_P + d * r0 + n * r0 * wd * 0.3, CLASH_P + d * r1, CLASH_P + d * r0 - n * r0 * wd * 0.3]),
					PackedColorArray([Color(1.0, 0.95, 0.85, 0.55 * la), Color(1.0, 0.8, 0.55, 0.0), Color(1.0, 0.95, 0.85, 0.55 * la)]))
	if ti > -0.15:
		var flare := 0.0
		if ti > 0.0:
			flare = exp(-ti * 2.6)
		else:
			flare = clampf(1.0 + ti / 0.15, 0.0, 1.0) * 0.4
		var fw := 1500.0 * flare
		var fh := 11.0 * (0.4 + flare)
		ci.draw_polygon(PackedVector2Array([CLASH_P + Vector2(-fw, 0.0), CLASH_P + Vector2(0.0, -fh), CLASH_P + Vector2(fw, 0.0), CLASH_P + Vector2(0.0, fh)]),
				PackedColorArray([Color(1.0, 0.7, 0.4, 0.0), Color(1.0, 0.95, 0.8, 0.9 * flare), Color(1.0, 0.7, 0.4, 0.0), Color(1.0, 0.95, 0.8, 0.9 * flare)]))
		var gl := 120.0 * flare + (50.0 + 12.0 * sin(_clock * 17.0)) * (1.0 if ti > 0.0 else 0.0)
		_glow(ci, CLASH_P, gl * 1.3, gl * 1.3, Color(1.0, 0.8, 0.5, 0.75))
		_star(ci, CLASH_P, gl * 1.6, Color(1.0, 0.96, 0.85, 0.9))
	# brasas
	for e in _embers:
		var fade := clampf(float(e.life) / 1.2, 0.0, 1.0) * clampf((float(e.max) - float(e.life)) / 0.8, 0.0, 1.0)
		var fl := 0.65 + 0.35 * sin(_clock * 7.0 + float(e.ph))
		var c: Color = e.col
		ci.draw_circle(e.p, float(e.r), Color(c.r, c.g, c.b, 0.9 * fade * fl))
	# faiscas
	for s in _sparks:
		var k := float(s.life) / float(s.max)
		var v: Vector2 = s.v
		var tail: Vector2 = Vector2(s.p) - v * 0.028
		ci.draw_line(tail, s.p, Color(1.0, 0.72 + 0.25 * k, 0.35 + 0.4 * k, clampf(k * 1.6, 0.0, 1.0)), 1.0 + 2.6 * k, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r < 2.0:
		return
	var tr := col
	tr.a = 0.0
	for k in 2:
		var a := float(k) * PI * 0.5 + 0.0
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		ci.draw_polygon(PackedVector2Array([c + d * r, c + n * r * 0.07, c - d * r, c - n * r * 0.07]),
				PackedColorArray([tr, col, tr, col]))


# ---------------------------------------------------------------- interface (titulo, barras, pos)

func _paint_ui(ci: CanvasItem) -> void:
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	var s := _base_scale()
	var bars := 1.0 - _ease_out(clampf((_t - 0.4) / 1.8, 0.0, 1.0))
	if bars > 0.001:
		var bh := 140.0 * s * bars
		ci.draw_rect(Rect2(0.0, 0.0, size.x, bh), Color.BLACK)
		ci.draw_rect(Rect2(0.0, size.y - bh, size.x, bh), Color.BLACK)
	var ti := _impact_time()
	if ti > 0.2 and _title2.visible:
		var a := clampf((ti - 0.2) / 0.4, 0.0, 1.0)
		var c := size * 0.5 + Vector2(0.0, -62.0 * s) + _shake * 0.6
		var half := (_title2.size.x * 0.5 + 40.0 * s)
		var y := c.y + _title2.size.y * 0.0
		var col := Color(1.0, 0.82, 0.45, 0.8 * a)
		var len := 330.0 * s * _ease_out(a)
		for sgn in [-1.0, 1.0]:
			var x0: float = c.x + sgn * half
			ci.draw_line(Vector2(x0, y), Vector2(x0 + sgn * len, y), col, 2.0 * s, true)
			var dx: float = x0 + sgn * len + sgn * 12.0 * s
			var dm := 6.0 * s
			ci.draw_colored_polygon(PackedVector2Array([Vector2(dx, y - dm), Vector2(dx + dm, y), Vector2(dx, y + dm), Vector2(dx - dm, y)]), col)


func _update_ui() -> void:
	if _post_mat == null:
		return
	var s := _base_scale()
	var ti := _impact_time()
	var fade := 1.0 - smoothstep(0.0, 1.3, _t)
	var out_k := 0.0
	if _phase == Phase.OUTRO:
		out_k = clampf((_outro_t - 0.15) / (OUTRO_TIME - 0.15), 0.0, 1.0)
	_post_mat.set_shader_parameter("fade", maxf(fade, out_k))
	_post_mat.set_shader_parameter("flash", _flash * _flash * 0.9)
	_post_mat.set_shader_parameter("aberration", 0.0012 + _shake_amp * 0.00028 + _flash * 0.004)
	_post_mat.set_shader_parameter("time_s", fposmod(_clock, 100.0))
	# titulo: cai com escala grande, assenta com um leve tremor
	var shown := ti >= 0.0
	_title1.visible = shown
	_title2.visible = ti >= 0.12
	var base_c := size * 0.5
	var sweep := -0.5
	if _t > T_IMPACT + 1.4:
		sweep = fposmod((_clock - 1.0) / 4.2, 1.0) * 2.2 - 0.6
	for idx in 2:
		var l := _title1 if idx == 0 else _title2
		var tt := ti - (0.0 if idx == 0 else 0.12)
		if tt < 0.0:
			continue
		var k := clampf(tt / 0.26, 0.0, 1.0)
		var sc := 1.0 + 0.85 * pow(1.0 - _ease_out(k), 1.0)
		var settle := exp(-tt * 4.0)
		l.modulate.a = clampf(tt / 0.06, 0.0, 1.0)
		l.pivot_offset = l.size * 0.5
		l.scale = Vector2(sc, sc) * (1.0 + 0.03 * settle)
		var cy := -232.0 if idx == 0 else -62.0
		if idx == 1:
			cy = -52.0
		l.position = base_c + Vector2(0.0, cy * s) + _shake * 0.6 - l.size * 0.5
		var mat := _title_mat1 if idx == 0 else _title_mat2
		mat.set_shader_parameter("sweep", sweep)
		mat.set_shader_parameter("heat", 0.5 * settle)
	var pa := 0.0
	if _phase == Phase.IDLE and _t > T_IMPACT + 1.0:
		pa = 0.45 + 0.55 * (0.5 + 0.5 * sin(_clock * 3.2))
		pa *= clampf((_t - (T_IMPACT + 1.0)) / 0.6, 0.0, 1.0)
	elif _phase == Phase.OUTRO:
		pa = 0.0
	_prompt.modulate.a = pa
	_prompt.position = Vector2((size.x - _prompt.size.x) * 0.5, size.y - 62.0 * s)
