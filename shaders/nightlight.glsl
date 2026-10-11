#version 320 es        
precision highp float;   

in vec2 v_texcoord;      
uniform sampler2D tex;  
out vec4 fragColor;      

void main() {
    vec4 col = texture(tex, v_texcoord);
    col.rgb = vec3(col.r *= 1.12,col.g *= 1.03,col.b *= 0.78);
    fragColor = col*0.9;                      
}
