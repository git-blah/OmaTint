#version 320 es

precision highp float;   

in vec2 v_texcoord;      
uniform sampler2D tex;  
out vec4 fragColor;      

void main() {
    vec4 col = texture(tex, v_texcoord);
    vec3 warm = col.rgb * vec3(1.12, 1.03, 0.78);
    col.rgb = warm;
    fragColor = col;                      
}
