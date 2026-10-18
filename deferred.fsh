#version 330 compatibility
#include "/lib/formats.glsl"
/* RENDERTARGETS: 7 */
#include "/lib/common.glsl"
#include "/lib/sky_vary.glsl"
#include "/lib/space.glsl"
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform sampler2D colortex7;
uniform sampler2D depthtex1;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 previousCameraPosition;
in vec2 texcoord;
layout(location = 0) out vec4 outGI;

vec2 reproject(vec3 viewPos){
    vec3 pf = feetFromView(viewPos) + cameraPosition - previousCameraPosition;
    vec4 pc = gbufferPreviousProjection*(gbufferPreviousModelView*vec4(pf, 1.0));
    return pc.xy/pc.w*0.5 + 0.5;
}
bool inScreen(vec2 p){ return all(greaterThan(p, vec2(0.0))) && all(lessThan(p, vec2(1.0))); }

void main(){
    vec2 uv = texcoord, fc = gl_FragCoord.xy;
    float depth = texture(depthtex1, uv).r;
    if(depth >= 1.0){ outGI = vec4(0.0); return; }
    vec3 vp = viewFromScreen(uv, depth);
    vec4 nl = texture(colortex1, uv);
    vec3 N = decodeNormal(nl.rg);
    float skyVis = pow(smoothstep(0.0, 1.0, nl.a), 1.5);

    vec3 gi = vec3(0.0);
    for(int r = 0; r < GI_RAYS; r++){
        vec2 xi = fract(hash22(fc + 37.1*float(r)) + vec2(0.7548776662, 0.5698402910)*float(frameCounter % 256));
        vec3 dir = cosineHemisphere(N, xi);
        float jit = ignoise(fc + 13.7*float(r));
        vec3 org = vp + N*(0.03 + 0.003*length(vp));
        bool hit = false; vec3 rad = vec3(0.0); float hitT = GI_RADIUS;
        for(int i = 0; i < GI_STEPS; i++){
            float t = GI_RADIUS*pow((float(i) + jit)/float(GI_STEPS), 2.0) + 0.06;
            vec3 p = org + dir*t;
            if(p.z > -0.1) break;
            vec3 s = screenFromView(p);
            if(!inScreen(s.xy)) break;
            float sd = texture(depthtex1, s.xy).r;
            if(sd >= 1.0) continue;
            vec3 hv = viewFromScreen(s.xy, sd);
            float diff = hv.z - p.z;
            if(diff > 0.0 && diff < 0.2 + t*0.45){
                vec3 HN = decodeNormal(texture(colortex1, s.xy).rg);
                if(dot(HN, dir) > 0.1) continue;          // back-facing: pass through
                vec2 puv = reproject(hv);
                rad = inScreen(puv) ? texture(colortex4, puv).rgb : cheapSky(worldDirFromView(dir))*skyVis*0.5;
                hit = true; hitT = t; break;
            }
        }
        vec3 skyRad = cheapSky(worldDirFromView(dir))*skyVis;
        if(!hit) rad = skyRad;
        else rad = mix(rad, skyRad, smoothstep(0.75, 1.0, hitT/GI_RADIUS));
        gi += min(rad, vec3(12.0));
    }
    gi /= float(GI_RAYS);

    // temporal accumulation with depth-based disocclusion
    vec2 puv = reproject(vp);
    float cnt = 0.0; vec3 hist = vec3(0.0);
    if(inScreen(puv)){
        ivec2 ip = ivec2(puv*vec2(viewWidth, viewHeight));
        vec4 h = texelFetch(colortex7, ip, 0);
        float pd = texelFetch(colortex4, ip, 0).a;
        float cd = -vp.z;
        if(abs(pd - cd) < 0.06*cd + 0.05 && h.a > 0.0){ hist = h.rgb; cnt = h.a; }
    }
    float a = max(1.0/(cnt + 1.0), 1.0/32.0);
    vec3 outc = cnt > 0.0 ? mix(hist, gi, a) : gi;
    outGI = vec4(outc, min(cnt + 1.0, 32.0));
}
