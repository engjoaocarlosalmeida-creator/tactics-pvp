shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform vec4 outline_color : source_color;
uniform float outline_width = 0.02;

void vertex() {
    VERTEX += NORMAL * outline_width;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}
