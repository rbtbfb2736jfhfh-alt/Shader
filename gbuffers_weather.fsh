#version 330 compatibility
#include "/lib/formats.glsl"
/* RENDERTARGETS: 0 */
#include "/lib/common.glsl"
uniform sampler2D gtexture;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;
in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
layout(location = 0) out vec4 outColor;
void main(){
    vec4 c = texture(gtexture, texcoord);
    if(c.a < 0.02) discard;
    float day = smoothstep(-0.12, 0.15, normalize(mat3(gbufferModelViewInverse)*sunPosition).y);
    vec3 col = vec3(0.7, 0.78, 0.9)*mix(0.02, 0.9, day)*lmcoord.y;
    outColor = vec4(col, c.a*0.45);
}
