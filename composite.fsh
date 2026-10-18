#version 330 compatibility
#include "/lib/formats.glsl"
/* RENDERTARGETS: 0 */
#include "/lib/common.glsl"
#include "/lib/sky_vary.glsl"
#include "/lib/space.glsl"
#include "/lib/pbr.glsl"
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
in vec2 texcoord;
layout(location = 0) out vec4 outColor;

// ---- screen-space ray march in view space (exponential steps + binary refine) ----
bool traceScreen(vec3 org, vec3 dir, float jitter, out vec2 hitUV){
    float tPrev = 0.0;
    for(int i = 0; i < SSR_STEPS; i++){
        float t = 0.25*pow(1.2, float(i) + jitter);
        vec3 p = org + dir*t;
        if(p.z > -0.05) return false;
        vec3 s = screenFromView(p);
        if(any(lessThan(s.xy, vec2(0.0))) || any(greaterThan(s.xy, vec2(1.0)))) return false;
        float sd = texture(depthtex1, s.xy).r;
        if(sd < 1.0){
            float diff = viewFromScreen(s.xy, sd).z - p.z;
            if(diff > 0.0 && diff < max(0.2, (t - tPrev)*1.6)){
                vec3 lo = org + dir*tPrev, hi = p;
                for(int k = 0; k < 6; k++){
                    vec3 mid = (lo + hi)*0.5;
                    vec3 sm = screenFromView(mid);
                    float dm = texture(depthtex1, sm.xy).r;
                    if(mid.z < viewFromScreen(sm.xy, dm).z) hi = mid; else lo = mid;
                }
                hitUV = screenFromView(hi).xy;
                return true;
            }
        }
        tPrev = t;
    }
    return false;
}

vec3 reflectionColor(vec3 vp, vec3 N, vec3 V, float rough, float alpha, float skyL, float noise){
    vec3 R = reflect(-V, N);
    if(rough > 0.02){
        vec2 xi = fract(hash22(gl_FragCoord.xy) + vec2(0.7548776662, 0.5698402910)*float(frameCounter % 256));
        vec3 H = sampleGGX(N, xi, alpha);
        R = reflect(-V, H);
        if(dot(R, N) < 0.0) R = reflect(-V, N);
    }
    vec3 skyC = cheapSky(worldDirFromView(R))*smoothstep(0.25, 0.95, skyL);
    vec2 huv;
    vec3 org = vp + N*(0.03 + 0.004*length(vp));
    if(traceScreen(org, R, noise, huv)){
        vec2 e = min(huv, 1.0 - huv);
        float edge = smoothstep(0.0, 0.08, min(e.x, e.y));
        vec3 hc = textureLod(colortex0, huv, rough*5.0).rgb;
        return mix(skyC, hc, edge);
    }
    return skyC;
}

void main(){
    vec2 uv = texcoord;
    vec3 scene = texture(colortex0, uv).rgb;
    float d0 = texture(depthtex0, uv).r, d1 = texture(depthtex1, uv).r;
    vec3 vp0 = viewFromScreen(uv, d0);
    vec4 tr = texture(colortex6, uv);
    vec4 nl = texture(colortex1, uv);
    vec3 N = decodeNormal(nl.rg);
    float blkL = nl.b, skyL = nl.a;
    vec4 spec = texture(colortex2, uv);
    vec4 albT = texture(colortex3, uv);
    int matID = int(albT.a*255.0 + 0.5);
    vec3 V = -normalize(vp0);
    float NoV = clamp(dot(N, V), 0.0, 1.0);
    float noise = ignoise(gl_FragCoord.xy);
    bool isHand = d0 < 0.56;
    bool trans = tr.a > 0.002 && d0 < 1.0 && !isHand;
    bool under = isEyeInWater == 1;
    float eyeSky = float(eyeBrightnessSmooth.y)/240.0;

    if(trans){
        bool water = matID == 2;
        vec3 tint = toLinear(tr.rgb);
        vec3 upV = normalize(mat3(gbufferModelView)*vec3(0.0, 1.0, 0.0));
        vec2 ruv = uv;
        if(water){
            vec2 off = (N - upV).xy*0.08/(1.0 + length(vp0)*0.03);
            ruv = clamp(uv + clamp(off, vec2(-0.05), vec2(0.05)), vec2(0.001), vec2(0.999));
        }
        float d1r = texture(depthtex1, ruv).r;
        if(d1r < d0){ ruv = uv; d1r = d1; }
        vec3 behind = texture(colortex0, ruv).rgb;
        vec3 vp1 = viewFromScreen(ruv, d1r);
        float skyW = smoothstep(0.3, 1.0, skyL);

        if(water){
            float thick = under ? 0.0 : min(distance(vp0, vp1), 96.0);
            vec3 sigA = vec3(0.45, 0.09, 0.045) + (1.0 - tint)*0.25;
            vec3 sigS = vec3(0.06)*(0.3 + tint*0.7);
            vec3 sigT = sigA + sigS;
            vec3 T = exp(-sigT*thick);
            vec3 Ew = ambientColor*0.45*skyW + lightColor*clamp(lightDirW.y, 0.0, 1.0)*0.8*skyW
                    + vec3(1.0, 0.58, 0.26)*pow(blkL, 3.2)*BLOCK_LIGHT*PI*0.5;
            vec3 col = behind*T + (sigS/sigT)*(1.0 - T)*Ew/PI;

            // shoreline / intersection foam
            if(!under){
                vec3 wp = feetFromView(vp0) + cameraPosition;
                float floorY = (feetFromView(vp1) + cameraPosition).y;
                float depthY = wp.y - floorY;
                float fn = fbm2(wp.xz*1.7 + frameTimeCounter*vec2(0.12, 0.08), 3);
                float foam = smoothstep(0.55, 0.05, depthY + (fn - 0.5)*0.55)*step(d1r, 0.9999);
                vec3 foamCol = 0.8*(ambientColor*skyW + lightColor*clamp(lightDirW.y, 0.0, 1.0)*skyW)/PI;
                col = mix(col, foamCol, foam*0.85);
            }

            if(!under){
                float rough = pow(1.0 - spec.r, 2.0), alpha = max(rough, 0.01);
                vec3 refl = reflectionColor(vp0, N, V, rough, alpha, skyL, noise);
                float F = 0.02 + 0.98*pow(1.0 - NoV, 5.0);
                col = mix(col, refl, F);
                // analytic sun/moon glint
                vec3 Lv = normalize(mat3(gbufferModelView)*lightDirW);
                float NoL = max(dot(N, Lv), 0.0);
                vec3 H = normalize(Lv + V);
                float a = max(alpha, 0.02);
                float sp = D_GGX(max(dot(N, H), 0.0), a)*V_SmithGGX(NoV, NoL, a)*F_Schlick(vec3(0.02), max(dot(V, H), 0.0)).x*NoL;
                col += lightColor*min(sp, 60.0)*skyW;
            }
            scene = col;
        } else {
            // glass / ice / stained glass
            vec3 amb = (ambientColor*skyW*0.35 + vec3(1.0, 0.58, 0.26)*pow(blkL, 3.2)*BLOCK_LIGHT)/PI;
            vec3 col = behind*mix(vec3(1.0), tint, tr.a) + tint*tr.a*amb*0.5;
            float rough = pow(1.0 - spec.r, 2.0), alpha = max(rough, 0.01);
            vec3 refl = reflectionColor(vp0, N, V, rough, alpha, skyL, noise);
            float F = 0.04 + 0.96*pow(1.0 - NoV, 5.0);
            scene = mix(col, refl, F);
        }
    } else if(d1 < 1.0 && !isHand && spec.r > 0.12 && matID != 2 && matID != 3){
        // reflections on opaque PBR surfaces (smooth metals, wet ground, puddles)
        Material m = decodeMaterial(albT, spec, matID);
        if(m.rough < 0.6){
            vec3 refl = reflectionColor(vp0, N, V, m.rough, m.alpha, skyL, noise);
            vec3 F = F_SchlickRough(m.F0, NoV, m.rough);
            scene = scene*(1.0 - (m.metal > 0.5 ? 0.0 : luma(F))) + refl*F;
        }
    }

    // ---- underwater: extinction + in-scatter over the whole view ----
    if(under){
        float dist = d0 >= 1.0 ? 96.0 : min(length(vp0), 96.0);
        vec3 sigA = vec3(0.45, 0.09, 0.045), sigS = vec3(0.015, 0.05, 0.08), sigT = sigA + sigS;
        vec3 T = exp(-sigT*dist);
        vec3 E = (lightColor*max(lightDirW.y, 0.15)*0.6 + ambientColor*0.5)*max(eyeSky, 0.3) + 0.02;
        scene = scene*T + (sigS/sigT)*(1.0 - T)*E/PI;
    }
    outColor = vec4(scene, 1.0);
}
