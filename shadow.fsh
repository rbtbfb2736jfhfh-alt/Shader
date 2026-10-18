#version 330 compatibility
#include "/lib/formats.glsl"
#include "/lib/common.glsl"
uniform sampler2D gtexture;
in vec2 texcoord;
in vec4 glcolor;
flat in int isWater;
layout(location = 0) out vec4 outColor;
void main(){
    vec4 c = texture(gtexture, texcoord)*glcolor;
    if(c.a < 0.1) discard;
    if(isWater == 1) c = vec4(0.28, 0.58, 0.78, 0.55);
    outColor = c;
}
