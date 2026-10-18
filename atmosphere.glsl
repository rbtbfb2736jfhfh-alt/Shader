#ifndef ATMOSPHERE_GLSL
#define ATMOSPHERE_GLSL
const float R_PLANET = 6371e3;
const float R_ATMOS  = 6471e3;
const vec3  BETA_R   = vec3(5.5e-6, 13.0e-6, 22.4e-6);
const float BETA_M   = 21e-6;
const float H_R = 8e3;
const float H_M = 1.2e3;
const float G_MIE = 0.76;
const float SUN_INTENSITY = 22.0;
const float SUN_ILLUM = 6.0;

vec2 rsi(vec3 r0, vec3 rd, float sr){
    float b = dot(rd, r0), c = dot(r0, r0) - sr*sr, d = b*b - c;
    if(d < 0.0) return vec2(1e12, -1e12);
    d = sqrt(d);
    return vec2(-b-d, -b+d);
}
float phaseR(float mu){ return 3.0/(16.0*PI)*(1.0+mu*mu); }
float phaseMie(float mu, float g){ float g2 = g*g; return 3.0/(8.0*PI)*((1.0-g2)*(1.0+mu*mu))/((2.0+g2)*pow(1.0+g2-2.0*g*mu, 1.5)); }
float phaseHG(float mu, float g){ float g2 = g*g; return (1.0-g2)/(4.0*PI*pow(max(1.0+g2-2.0*g*mu, 1e-4), 1.5)); }

vec3 atmosphereScatter(vec3 rd, vec3 sunDir, float camH, int vSteps){
    vec3 ro = vec3(0.0, R_PLANET + camH, 0.0);
    vec2 pa = rsi(ro, rd, R_ATMOS);
    if(pa.x > pa.y) return vec3(0.0);
    float tmax = pa.y;
    vec2 pp = rsi(ro, rd, R_PLANET);
    if(pp.x > 0.0 && pp.x < pp.y) tmax = min(tmax, pp.x);
    float tmin = max(pa.x, 0.0);
    float ds = (tmax - tmin)/float(vSteps);
    float mu = dot(rd, sunDir);
    float pR = phaseR(mu), pM = phaseMie(mu, G_MIE);
    vec3 sumR = vec3(0.0), sumM = vec3(0.0);
    float odR = 0.0, odM = 0.0;
    float t = tmin + ds*0.5;
    for(int i = 0; i < vSteps; i++){
        vec3 pos = ro + rd*t;
        float h = length(pos) - R_PLANET;
        float dR = exp(-h/H_R)*ds, dM = exp(-h/H_M)*ds;
        odR += dR; odM += dM;
        float ls = rsi(pos, sunDir, R_ATMOS).y/5.0;
        float lR = 0.0, lM = 0.0; bool lit = true;
        for(int j = 0; j < 5; j++){
            vec3 lp = pos + sunDir*ls*(float(j)+0.5);
            float lh = length(lp) - R_PLANET;
            if(lh < 0.0){ lit = false; break; }
            lR += exp(-lh/H_R)*ls; lM += exp(-lh/H_M)*ls;
        }
        if(lit){
            vec3 att = exp(-(BETA_R*(odR+lR) + BETA_M*1.1*(odM+lM)));
            sumR += dR*att; sumM += dM*att;
        }
        t += ds;
    }
    return SUN_INTENSITY*(pR*BETA_R*sumR + pM*BETA_M*sumM);
}

vec3 sunTransmittance(float mu){
    mu = max(mu, -0.09);
    float am = 1.0/(mu + 0.50572*pow(96.07995 - degrees(acos(mu)), -1.6364));
    vec3 tau = (BETA_R*H_R + BETA_M*1.1*H_M)*am;
    return exp(-tau);
}

vec3 starField(vec3 dir){
    vec3 p = dir*220.0, id = floor(p), f = fract(p) - 0.5;
    float h = hash13(id);
    if(h < 0.9965) return vec3(0.0);
    vec3 off = vec3(hash13(id+7.1), hash13(id+13.7), hash13(id+3.3)) - 0.5;
    float s = smoothstep(0.22, 0.0, length(f - off*0.6));
    float mag = pow(hash13(id+1.7), 3.0);
    vec3 tint = mix(vec3(1.0,0.75,0.6), vec3(0.65,0.8,1.0), hash13(id+9.1));
    return tint*s*(0.25 + mag*2.5)*(0.8 + 0.2*sin(frameTimeCounter*3.0 + h*200.0));
}
#endif
