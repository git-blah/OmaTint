#version 320 es

precision mediump float;
precision highp int;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

// E-ink panels show a handful of gray levels between dark ink and off-white paper
const float LEVELS = 16.0;
const float CONTRAST = 1.2;
// Unsharp mask keeps text crisp once colour is gone
const float SHARPEN = 0.5;
// Static paper fibre texture, strongest on bare paper and hidden under ink
const float GRAIN = 0.02;
// How much of the original colour shows through, like a muted colour e-ink panel
const float COLOUR = 0.2;
const vec3 INK = vec3(0.13, 0.13, 0.12);
const vec3 PAPER = vec3(0.93, 0.92, 0.87);

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Integer maths so the pattern holds on screens wider than mediump floats count
float bayer4(ivec2 p) {
    const float m[16] = float[16](
         0.0,  8.0,  2.0, 10.0,
        12.0,  4.0, 14.0,  6.0,
         3.0, 11.0,  1.0,  9.0,
        15.0,  7.0, 13.0,  5.0
    );
    return m[(p.x & 3) + (p.y & 3) * 4] / 16.0 - 0.5;
}

float hash(ivec2 p) {
    uint h = uint(p.x) * 1664525u ^ uint(p.y) * 1013904223u;
    h ^= h >> 16;
    h *= 2246822519u;
    h ^= h >> 13;
    return float(h & 0xffffu) / 65535.0;
}

// Fine speckle over coarser blotches reads as paper, not as screen noise
float grain(ivec2 p) {
    return mix(hash(p >> 2), hash(p), 0.5) - 0.5;
}

void main() {
    vec4 pix = texture(tex, v_texcoord);
    highp vec2 px = 1.0 / vec2(textureSize(tex, 0));
    float y = luma(pix.rgb);
    float blur = 0.25 * (
        luma(texture(tex, v_texcoord + vec2(px.x, 0.0)).rgb) +
        luma(texture(tex, v_texcoord - vec2(px.x, 0.0)).rgb) +
        luma(texture(tex, v_texcoord + vec2(0.0, px.y)).rgb) +
        luma(texture(tex, v_texcoord - vec2(0.0, px.y)).rgb));
    y += SHARPEN * (y - blur);

    ivec2 p = ivec2(gl_FragCoord.xy);
    y = clamp((y - 0.5) * CONTRAST + 0.5, 0.0, 1.0);
    y = floor(y * (LEVELS - 1.0) + 0.5 + bayer4(p)) / (LEVELS - 1.0);
    y = clamp(y, 0.0, 1.0);

    vec3 c = mix(INK, PAPER, y) * (1.0 + GRAIN * y * grain(p));
    c += COLOUR * (pix.rgb - luma(pix.rgb));
    fragColor = vec4(clamp(c, 0.0, 1.0), pix.a);
}
