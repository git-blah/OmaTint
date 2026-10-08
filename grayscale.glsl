#version 320 es        
precision highp float;   

in vec2 v_texcoord;      
uniform sampler2D tex;  
out vec4 fragColor;      

void main() {
    vec4 col = texture(tex, v_texcoord);
    float gray = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
    col.rgb = vec3(gray);
    fragColor = col;                      
}
