#version 330 compatibility
#include "/lib/formats.glsl"
/* RENDERTARGETS: 0,4 */
#include "/lib/common.glsl"
#include "/lib/sky_vary.glsl"
#include "/lib/space.glsl"
#include "/lib/pbr.glsl"
#include "/lib/shadow.glsl"
#include "/lib/clouds.glsl"
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex7;
uniform sampler2D depthtex1;
uniform vec3 shadowLightPosition;
uniform float near;
uniform float far;
in vec2 texcoord;
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outHist;

float linearZ(float d){ return (2.0*near*far)/(far + near - (d*2.0 - 1.0)*(far - near)); }

vec3 renderSky(vec3 dir, vec2 fc){
    float sunUp = smoothstep(-0.08, 0.06, sunDirW.y);
    float moonUp = smoothstep(-0.08, 0.10, moonDirW.y)*(1.0 - sunUp);
    vec3 sky = atmosphereScatter(dir, sunDirW, 400.0, SKY_STEPS);
    if(moonUp > 0.01) sky += atmosphereScatter(dir, moonDirW, 400.0, 10)*0.014*vec3(0.55, 0.72, 1.0)*moonUp;
    sky += vec3(0.0009, 0.0016, 0.0042);
    float rain = rainStrength;
    sky = mix(sky, vec3(luma(sky))*vec3(0.78, 0.84, 0.95), rain*0.8);

    if(dir.y > -0.02){
        float aboveH = smoothstep(0.0, 0.2, dir.y);
        sky += starField(dir)*(1.0 - sunUp)*(1.0 - rain)*aboveH;
        float sa = acos(clamp(dot(dir, sunDirW), -1.0, 1.0));
        sky += sunColor/SUN_ILLUM*30.0*(1.0 - smoothstep(0.0075, 0.0095, sa));
        float ma = acos(clamp(dot(dir, moonDirW), -1.0, 1.0));
        float md = 1.0 - smoothstep(0.0115, 0.0125, ma);
        if(md > 0.0){
            float cr = vnoise(dir*70.0)*0.5 + vnoise(dir*160.0)*0.3 + 0.2;
            sky += vec3(0.78, 0.86, 1.0)*2.0*md*(0.55 + 0.45*cr)*moonUp*(1.0 - rain);
        }
    }
    sky = mix(sky, skyHorizon*0.6, smoothstep(0.0, -0.12, dir.y));
    vec4 cl = volumetricClouds(cameraPosition, dir, lightDirW, lightColor, ambientColor/PI, skyHorizon, ignoise(fc));
    return sky*cl.a + cl.rgb;
}

void main(){
    vec2 uv = texcoord; vec2 fc = gl_FragCoord.xy;
    float depth = texture(depthtex1, uv).r;
    vec3 vp = viewFromScreen(uv, depth);
    vec3 dirW = normalize(worldDirFromView(vp));

    if(depth >= 1.0){
        vec3 sky = renderSky(dirW, fc);
        outColor = vec4(sky, 1.0);
        outHist = vec4(min(sky, vec3(30.0)), 1e4);
        return;
    }

    vec4 nl = texture(colortex1, uv);
    vec3 N = decodeNormal(nl.rg);
    float blkL = nl.b, skyL = nl.a;
    vec4 albT = texture(colortex3, uv);
    Material m = decodeMaterial(albT, texture(colortex2, uv), int(albT.a*255.0 + 0.5));

    vec3 V = -normalize(vp);
    vec3 Lv = normalize(shadowLightPosition);
    float NoL = dot(N, Lv);
    float NoV = max(dot(N, V), 1e-3);
    vec3 feet = feetFromView(vp);
    vec3 Nw = worldDirFromView(N);
    float dist = length(vp);

    // ---- direct light ----
    float wrap = max((NoL + m.sss)/(1.0 + m.sss), 0.0);
    vec3 shadow = vec3(0.0);
    if(wrap > 0.001) shadow = sampleShadow(feet, Nw, max(NoL, 0.05), dist, skyL, ignoise(fc)*TAU);
    vec3 direct = lightColor*wrap*shadow;

    vec3 specular = vec3(0.0);
    if(NoL > 0.0){
        vec3 H = normalize(Lv + V);
        float NoH = max(dot(N, H), 0.0), VoH = max(dot(V, H), 0.0);
        vec3 F = F_Schlick(m.F0, VoH);
        specular = D_GGX(NoH, m.alpha)*V_SmithGGX(NoV, NoL, m.alpha)*F*lightColor*NoL*shadow;
    }

    // ---- GI: bilateral 5x5 spatial filter over temporally accumulated SSRT ----
    float cd = linearZ(depth);
    float cnt = texelFetch(colortex7, ivec2(fc), 0).a;
    int stride = cnt < 6.0 ? 2 : 1;
    vec3 gAcc = vec3(0.0); float gW = 0.0;
    ivec2 maxP = ivec2(viewWidth, viewHeight) - 1;
    for(int y = -2; y <= 2; y++){
        for(int x = -2; x <= 2; x++){
            ivec2 ip = clamp(ivec2(fc) + ivec2(x, y)*stride, ivec2(0), maxP);
            float sd = texelFetch(depthtex1, ip, 0).r;
            if(sd >= 1.0) continue;
            vec3 sn = decodeNormal(texelFetch(colortex1, ip, 0).rg);
            float wz = exp(-abs(linearZ(sd) - cd)/(0.03*cd + 0.02)*2.0);
            float wn = pow(max(dot(N, sn), 0.0), 16.0);
            float ws = exp(-float(x*x + y*y)*0.2);
            float w = wz*wn*ws;
            gAcc += texelFetch(colortex7, ip, 0).rgb*w; gW += w;
        }
    }
    vec3 gi = gW > 1e-4 ? gAcc/gW : texelFetch(colortex7, ivec2(fc), 0).rgb;
    gi *= GI_STRENGTH;
    // analytic sky-ambient floor (lightmap-driven) so occluded areas never go black
    float skyW = pow(smoothstep(0.0, 1.0, skyL), 1.5);
    vec3 ambFloor = ambientColor/PI*0.5*skyW*mix(0.55, 1.0, Nw.y*0.5 + 0.5);
    gi = max(gi, ambFloor);

    vec3 diffAlb = m.albedo*(1.0 - m.metal);
    vec3 blockE = vec3(1.0, 0.58, 0.26)*pow(blkL, 3.2)*BLOCK_LIGHT;
    vec3 col = diffAlb*(direct/PI + gi + blockE + 0.0008) + specular + m.albedo*m.emissive*EMISSION_STRENGTH;

    outColor = vec4(col, 1.0);
    outHist = vec4(min(col, vec3(30.0)), -vp.z);
}
