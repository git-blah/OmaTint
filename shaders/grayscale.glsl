#version 320 es

precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 pix = texture(tex, v_texcoord);
    float y = dot(pix.rgb, vec3(0.2126, 0.7152, 0.0722));
    fragColor = vec4(vec3(y), pix.a);
}
