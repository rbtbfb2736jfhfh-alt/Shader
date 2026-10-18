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
    vec4 c = texture(gtexture, texcoord)*glcolor;
    if(c.a < 0.01) discard;
    float day = smoothstep(-0.12, 0.15, normalize(mat3(gbufferModelViewInverse)*sunPosition).y);
    vec3 amb = mix(vec3(0.012, 0.018, 0.04), vec3(2.0), day)*mix(1.0, 0.35, rainStrength);
    vec3 light = amb*lmcoord.y*lmcoord.y + vec3(1.0, 0.6, 0.3)*pow(lmcoord.x, 3.0)*1.8 + 0.002;
    outColor = vec4(toLinear(c.rgb)*light, c.a);
}
