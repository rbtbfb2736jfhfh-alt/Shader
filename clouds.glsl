#ifndef CLOUDS_GLSL
#define CLOUDS_GLSL
#define CLOUD_SIGMA 0.060

float cloudDensity(vec3 p, bool detail){
    float h = (p.y - CLOUD_ALTITUDE)/CLOUD_THICKNESS;
    if(h < 0.0 || h > 1.0) return 0.0;
    vec3 q = (p + vec3(1.6, 0.0, 0.8)*frameTimeCounter)*0.0045;
    float base = fbm3(q*vec3(1.0, 1.6, 1.0), 4);
    float prof = smoothstep(0.0, 0.12, h)*smoothstep(1.0, 0.55, h);
    float cov = clamp(CLOUD_COVERAGE + rainStrength*0.28, 0.0, 0.95);
    float thr = mix(0.62, 0.30, cov);
    float d = smoothstep(thr, thr + 0.18, base*prof);
    if(detail && d > 0.0) d = clamp(d - fbm3(q*5.3, 2)*0.30*d, 0.0, 1.0);
    return d;
}

float cloudLightOD(vec3 p, vec3 L){
    float od = 0.0, sl = CLOUD_THICKNESS*0.12;
    for(int i = 0; i < 4; i++){
        p += L*sl;
        od += cloudDensity(p, false)*sl;
        sl *= 1.8;
    }
    return od*CLOUD_SIGMA;
}

vec4 volumetricClouds(vec3 ro, vec3 rd, vec3 L, vec3 Lcol, vec3 ambRad, vec3 horizonCol, float jitter){
    float base = CLOUD_ALTITUDE, top = CLOUD_ALTITUDE + CLOUD_THICKNESS;
    if(abs(rd.y) < 1e-4) return vec4(0.0, 0.0, 0.0, 1.0);
    float ta = (base - ro.y)/rd.y, tb = (top - ro.y)/rd.y;
    float t0 = max(min(ta, tb), 0.0), t1 = max(ta, tb);
    if(t1 <= 0.0) return vec4(0.0, 0.0, 0.0, 1.0);
    t1 = min(t1, t0 + 9000.0);
    float dt = (t1 - t0)/float(CLOUD_STEPS);
    float mu = dot(rd, L);
    float T = 1.0; vec3 S = vec3(0.0);
    for(int i = 0; i < CLOUD_STEPS; i++){
        float t = t0 + (float(i) + jitter)*dt;
        vec3 p = ro + rd*t;
        float d = cloudDensity(p, true);
        if(d > 0.003){
            float st = d*CLOUD_SIGMA;
            float od = cloudLightOD(p, L);
            float h = clamp((p.y - base)/CLOUD_THICKNESS, 0.0, 1.0);
            vec3 E = vec3(0.0);
            float a = 1.0, b = 1.0, c = 1.0;
            for(int k = 0; k < 3; k++){
                float ph = mix(phaseHG(mu, 0.8*c), phaseHG(mu, -0.35*c), 0.25);
                E += Lcol*exp(-od*a)*ph*b;
                a *= 0.5; b *= 0.5; c *= 0.55;
            }
            E += Lcol*phaseHG(mu, 0.93)*0.06*exp(-od*0.35);
            vec3 Lin = E + ambRad*(0.35 + 0.65*h);
            float dT = exp(-st*dt);
            S += T*(1.0 - dT)*Lin;
            T *= dT;
            if(T < 0.02) break;
        }
    }
    float fade = exp(-t0*0.00022);
    T = mix(1.0, T, fade);
    S = mix(horizonCol*(1.0 - T), S, fade);
    return vec4(S, T);
}
#endif
