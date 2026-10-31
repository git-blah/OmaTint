#version 320 es

precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

// Roughly a 3400K lamp: green drops along with blue, so the tint reads amber, not yellow
const vec3 WARM = vec3(1.0, 0.76, 0.54);

void main() {
    vec4 pix = texture(tex, v_texcoord);
    fragColor = vec4(pix.rgb * WARM, pix.a);
}
