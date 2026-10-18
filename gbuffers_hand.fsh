#version 330 compatibility
#include "/lib/formats.glsl"
/* RENDERTARGETS: 0 */
#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
uniform sampler2D gtexture;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelViewInverse;
in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 vNormal;
layout(location = 0) out vec4 outColor;
void main(){
    vec4 tex = texture(gtexture, texcoord);
    if(tex.a < 0.1) discard;
    vec3 alb = toLinear(tex.rgb*glcolor.rgb);
    vec3 N = normalize(vNormal);
    mat3 mv = mat3(gbufferModelViewInverse);
    vec3 sunW = normalize(mv*sunPosition), moonW = normalize(mv*moonPosition);
    float sunVis = smoothstep(-0.08, 0.06, sunW.y);
    float moonVis = smoothstep(-0.08, 0.10, moonW.y)*(1.0 - sunVis);
    float rain = rainStrength;
    vec3 sunE = SUN_ILLUM*sunTransmittance(sunW.y)*sunVis*(1.0 - 0.9*rain);
    vec3 moonE = vec3(0.62, 0.74, 1.0)*0.085*moonVis*(1.0 - 0.8*rain);
    vec3 Lv = normalize(shadowLightPosition);
    vec3 LE = dot(normalize(mv*shadowLightPosition), sunW) > 0.5 ? sunE : moonE;
    float sky = pow(lmcoord.y, 1.5);
    vec3 ambRad = vec3(0.30, 0.38, 0.52)*sunVis*(1.0 - 0.4*rain) + vec3(0.0035, 0.0055, 0.012) + vec3(0.55, 0.72, 1.0)*0.02*moonVis;
    vec3 blockE = vec3(1.0, 0.58, 0.26)*pow(lmcoord.x, 3.2)*BLOCK_LIGHT;
    vec3 col = alb*(LE*max(dot(N, Lv), 0.0)/PI*smoothstep(0.4, 0.9, lmcoord.y) + ambRad*(0.1 + 0.9*sky) + blockE + 0.0008);
    outColor = vec4(col, tex.a);
}
