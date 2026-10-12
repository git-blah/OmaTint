#version 320 es

#ifndef INTENSITY
#define INTENSITY 1.0
#endif

precision highp float;   

in vec2 v_texcoord;      
uniform sampler2D tex;  
out vec4 fragColor;      

void main() {
    vec4 col = texture(tex, v_texcoord);
    float gray = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
    col.rgb = mix(col.rgb,vec3(gray), INTENSITY);
    fragColor = col;                      
}
