#version 330 compatibility
#include "/lib/formats.glsl"
/* RENDERTARGETS: 1,2,3,6 */
#include "/lib/common.glsl"
#include "/lib/water.glsl"
uniform sampler2D gtexture;
uniform mat4 gbufferModelView;
in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 vNormal;
in vec3 vWorldPos;
in vec3 vViewPos;
flat in int matType;
layout(location = 0) out vec4 outNL;
layout(location = 1) out vec4 outSpec;
layout(location = 2) out vec4 outAlb;
layout(location = 3) out vec4 outTr;
void main(){
    vec4 tex = texture(gtexture, texcoord)*glcolor;
    vec3 N; vec4 spec; vec4 tr;
    if(matType == 2){
        vec3 wn;
        gerstner(vWorldPos.xz, frameTimeCounter, WAVE_OCTAVES, wn);
        vec2 fine = vec2(vnoise2(vWorldPos.xz*7.0 + frameTimeCounter*0.6), vnoise2(vWorldPos.xz*7.0 - frameTimeCounter*0.5 + 31.0)) - 0.5;
        wn.xz += fine*0.05;
        if(rainStrength > 0.05) wn.xz += rainRipples(vWorldPos.xz)*0.12*rainStrength;
        N = normalize(mat3(gbufferModelView)*normalize(wn));
        spec = vec4(0.92, 5.0/255.0, 0.0, 1.0);
        tr = vec4(glcolor.rgb, 0.5);
    } else {
        if(tex.a < 0.02) discard;
        N = normalize(vNormal);
        spec = vec4(0.90, 10.0/255.0, 0.0, 1.0);
        tr = tex;
    }
    if(dot(N, vViewPos) > 0.0) N = -N;
    outNL = vec4(encodeNormal(N), lmcoord.x, lmcoord.y);
    outSpec = spec;
    outAlb = vec4(0.0, 0.0, 0.0, float(matType)/255.0);
    outTr = tr;
}
