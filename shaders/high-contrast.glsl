#version 320 es

precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

// S-curve strength: 1.0 gives ~1.5x midtone contrast while easing into black and white
const float STRENGTH = 1.0;
const float SATURATION = 1.2;

void main() {
    vec4 pix = texture(tex, v_texcoord);
    vec3 c = mix(pix.rgb, smoothstep(0.0, 1.0, pix.rgb), STRENGTH);
    float y = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(y), c, SATURATION);
    fragColor = vec4(clamp(c, 0.0, 1.0), pix.a);
}
