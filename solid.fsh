#include "/lib/common.glsl"
uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
#ifdef ENTITY
uniform vec4 entityColor;
#endif
in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 vNormal;
in vec3 vWorldPos;
in float vDist;
layout(location = 0) out vec4 outNL;
layout(location = 1) out vec4 outSpec;
layout(location = 2) out vec4 outAlb;

vec2 gdx, gdy;

#ifdef TERRAIN
in vec4 vtexcoordam;
in vec3 vTsView;
in vec3 vTangent;
in vec3 vBinormal;
flat in int vBlockId;
vec2 wrapAtlas(vec2 c){ return vtexcoordam.st + fract((c - vtexcoordam.st)/vtexcoordam.pq)*vtexcoordam.pq; }
float heightAt(vec2 c){ return textureGrad(normals, wrapAtlas(c), gdx, gdy).a; }

// Parallax occlusion mapping: linear march + secant refinement, height in normal.a (LabPBR)
vec2 parallaxUV(vec2 uv, vec3 vEye, float fade){
    float layers = float(POM_STEPS);
    float layerDepth = 1.0/layers;
    vec2 delta = vEye.xy/max(vEye.z, 0.2)*POM_DEPTH*vtexcoordam.pq*fade/layers;
    vec2 cur = uv;
    float depthCur = 0.0, h = 1.0 - heightAt(cur);
    for(int i = 0; i < POM_STEPS; i++){
        if(depthCur >= h) break;
        cur -= delta;
        h = 1.0 - heightAt(cur);
        depthCur += layerDepth;
    }
    vec2 prev = cur + delta;
    float after = h - depthCur;
    float before = (1.0 - heightAt(prev)) - (depthCur - layerDepth);
    float w = clamp(after/(after - before + 1e-5), 0.0, 1.0);
    return mix(cur, prev, w);
}
#endif

void main(){
    gdx = dFdx(texcoord); gdy = dFdy(texcoord);
    vec2 uv = texcoord;
    vec3 Ng = normalize(vNormal);
    vec3 N = Ng;
    float nAO = 1.0;
    vec4 nt = vec4(0.5, 0.5, 1.0, 1.0);

#ifdef TERRAIN
#ifdef POM
    if(vDist < POM_DISTANCE){
        float fade = 1.0 - smoothstep(POM_DISTANCE*0.6, POM_DISTANCE, vDist);
        uv = wrapAtlas(parallaxUV(texcoord, normalize(-vTsView), fade));
    }
#endif
    nt = textureGrad(normals, uv, gdx, gdy);
    vec3 nts;
    nts.xy = nt.xy*2.0 - 1.0;
    nts.z = sqrt(max(1.0 - dot(nts.xy, nts.xy), 0.0));
    N = normalize(mat3(normalize(vTangent), normalize(vBinormal), Ng)*nts);
    nAO = nt.b;
#endif

    vec4 albedo = textureGrad(gtexture, uv, gdx, gdy)*vec4(glcolor.rgb, 1.0);
    if(albedo.a < 0.1) discard;
#ifdef ENTITY
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
#endif
    vec4 spec = textureGrad(specular, uv, gdx, gdy);
    float skyL = lmcoord.y, blkL = lmcoord.x;
    int matID = 0;

#ifdef TERRAIN
    if(vBlockId == 10001 || vBlockId == 10002) matID = 1;
    if(vBlockId == 10010) matID = 4;
#endif
#ifdef HAND
    matID = 5;
#endif

#ifdef TERRAIN
    // ---- rain wetness: darkening, glossy film, puddles with ripples ----
    float wetAmt = wetness*smoothstep(0.78, 0.96, lmcoord.y);
    if(wetAmt > 0.001){
        vec3 Nwg = mat3(gbufferModelViewInverse)*Ng;
        float up = smoothstep(0.55, 0.95, Nwg.y);
        int bB = int(spec.b*255.0 + 0.5);
        float poros = max(bB <= 64 ? float(bB)/64.0 : 0.0, 0.3);
        float puddle = 0.0;
#ifdef PUDDLES
        float pn = fbm2(vWorldPos.xz*0.28, 4);
        puddle = smoothstep(0.62 - 0.17*wetAmt, 0.70 - 0.17*wetAmt, pn)*up;
#endif
        albedo.rgb *= 1.0 - wetAmt*(0.32*poros + 0.28*puddle);
        float sm = spec.r;
        sm = mix(sm, max(sm, 0.55), wetAmt*up*(1.0 - puddle));
        sm = mix(sm, 0.94, puddle);
        spec.r = sm;
        N = normalize(mix(N, Ng, puddle*0.9));
        if(rainStrength > 0.05 && puddle > 0.0){
            vec2 rg = rainRipples(vWorldPos.xz);
            N = normalize(N + mat3(gbufferModelView)*vec3(rg.x, 0.0, rg.y)*puddle*rainStrength*0.45);
        }
    }
#endif

    skyL *= nAO; blkL *= nAO;
    outNL = vec4(encodeNormal(N), blkL, skyL*mix(1.0, glcolor.a, 0.6));
    outSpec = spec;
    outAlb = vec4(albedo.rgb, float(matID)/255.0);
}
