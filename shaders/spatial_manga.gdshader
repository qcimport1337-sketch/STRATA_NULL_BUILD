shader_type canvas_item;

uniform float dither_strength : hint_range(0.0, 0.18) = 0.035;
uniform float red_threshold : hint_range(0.0, 1.0) = 0.46;

float bayer4(vec2 p) {
    ivec2 q = ivec2(mod(floor(p), 4.0));
    int i = q.x + q.y * 4;
    float m[16] = float[16](0.0,8.0,2.0,10.0, 12.0,4.0,14.0,6.0, 3.0,11.0,1.0,9.0, 15.0,7.0,13.0,5.0);
    return (m[i] / 16.0) - 0.5;
}

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    float red_signal = max(c.r - max(c.g, c.b), 0.0);
    if (red_signal > red_threshold) {
        COLOR = vec4(clamp(vec3(c.r * 1.15, c.g * 0.14, c.b * 0.12), 0.0, 1.0), c.a);
        return;
    }
    float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    l += bayer4(FRAGCOORD.xy) * dither_strength;
    float bands = 4.0;
    float q = floor(clamp(l, 0.0, 0.999) * bands + 0.5) / bands;
    COLOR = vec4(vec3(q), c.a);
}
