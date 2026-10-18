#version 330 compatibility
#include "/lib/formats.glsl"
/* RENDERTARGETS: 0 */
#include "/lib/common.glsl"
#include "/lib/sky_vary.glsl"
#include "/lib/space.glsl"
#include "/lib/shadow.glsl"
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
in vec2 texcoord;
layout(location = 0) out vec4 outColor;

const float FOG_K = 0.025;
float heightFogOD(float y0, float dy, float t){
    float a = exp(-FOG_K*(y0 - 62.0));
    if(abs(dy) < 1e-3) return a*t;
    return a*(1.0 - exp(min(-FOG_K*dy*t, 30.0)))/(FOG_K*dy);
}

void main(){
    vec2 uv = texcoord;
    vec3 col = texture(colortex0, uv).rgb;
    float d = texture(depthtex0, uv).r;
    vec3 vp = viewFromScreen(uv, d);
    vec3 dirW = normalize(worldDirFromView(vp));
    bool sky = d >= 1.0, under = isEyeInWater == 1;
    float dist = length(vp);
    float camY = cameraPosition.y;
    float skyAccess = mix(0.04, 1.0, smoothstep(0.0, 1.0, float(eyeBrightnessSmooth.y)/240.0));

    float lowSun = exp(-pow(max(sunDirW.y, 0.0)*5.0, 2.0));
    float beta = mix(0.0011, 0.0040, lowSun) + rainStrength*0.010;

    // analytic extinction + ambient in-scatter
    vec3 fog = vec3(0.0); float T = 1.0;
    if(!sky && !under){
        float od = beta*heightFogOD(camY, dirW.y, dist);
        T = exp(-od);
        vec3 fogCol = mix(skyHorizon, ambientColor/PI, 0.3)*skyAccess;
        fog = fogCol*(1.0 - T);
    }

    // ray-marched volumetric light (sun/moon shafts through leaves, terrain, water)
    vec3 shaft = vec3(0.0);
    float len = min(sky ? VL_DIST : dist, VL_DIST);
    float dt = len/float(VL_STEPS);
    float jit = ignoise(gl_FragCoord.xy);
    float mu = dot(dirW, lightDirW);
    float phase = under ? phaseHG(mu, 0.5) : mix(phaseHG(mu, 0.76), 0.25/PI, 0.35);
    vec3 tintC = under ? vec3(0.25, 0.7, 1.0) : vec3(1.0);
    float Tm = 1.0;
    float P00 = shadowProjection[0][0];
    float zPerBlock = 0.25*abs(shadowProjection[2][2]);
    for(int i = 0; i < VL_STEPS; i++){
        float t = (float(i) + jit)*dt;
        vec3 pf = dirW*t;
        float dens = under ? 0.03 : beta*0.6*exp(-FOG_K*(camY + dirW.y*t - 62.0));
        float df; vec3 sc = shadowSpace(pf, df);
        float vis = 1.0;
        if(all(lessThan(abs(sc.xy - 0.5), vec2(0.5))))
            vis = step(sc.z - 1.5*zPerBlock*2.0/(P00*float(shadowMapResolution))*df, texture(shadowtex1, sc.xy).r);
        else vis = skyAccess;
        shaft += lightColor*tintC*vis*phase*dens*dt*Tm;
        Tm *= exp(-dens*dt);
    }
    shaft *= VL_STRENGTH*(1.0 - rainStrength*0.5);

    outColor = vec4(col*T + fog + shaft, 1.0);
}
