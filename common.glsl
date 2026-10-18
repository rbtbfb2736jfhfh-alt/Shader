#ifndef COMMON_GLSL
#define COMMON_GLSL

#define PI 3.14159265359
#define TAU 6.28318530718

// ============================ OPTIONS ============================
#define GI_RAYS 2 //[1 2 3 4]
#define GI_STEPS 16 //[8 12 16 24 32]
#define GI_RADIUS 28.0 //[12.0 20.0 28.0 40.0 64.0]
#define GI_STRENGTH 1.0 //[0.5 0.75 1.0 1.25 1.5 2.0]
#define SSR_STEPS 32 //[16 24 32 48 64]
#define POM
#define POM_DEPTH 0.30 //[0.10 0.20 0.30 0.40 0.50]
#define POM_STEPS 20 //[8 12 16 20 32]
#define POM_DISTANCE 32.0 //[16.0 24.0 32.0 48.0]
#define PUDDLES
#define SHADOW_SOFTNESS 4.0 //[1.0 2.0 4.0 8.0]
#define WAVE_OCTAVES 6 //[3 4 5 6 8]
#define WAVE_HEIGHT 1.0 //[0.5 0.75 1.0 1.5 2.0]
#define CLOUD_STEPS 20 //[12 16 20 28 40]
#define CLOUD_COVERAGE 0.50 //[0.30 0.40 0.50 0.60 0.70]
#define CLOUD_ALTITUDE 260.0 //[180.0 220.0 260.0 320.0 400.0]
#define CLOUD_THICKNESS 110.0 //[70.0 110.0 160.0]
#define VL_STEPS 16 //[8 12 16 24 32]
#define VL_STRENGTH 0.8 //[0.0 0.4 0.8 1.2 1.6 2.0]
#define VL_DIST 112.0
#define DOF
#define FOCAL_LENGTH 35.0 //[24.0 35.0 50.0 85.0 135.0]
#define F_STOP 2.8 //[1.4 1.8 2.0 2.8 4.0 5.6 8.0]
#define MOTION_BLUR
#define MB_STRENGTH 0.6 //[0.2 0.4 0.6 0.8 1.0]
#define BLOOM_STRENGTH 0.10 //[0.0 0.04 0.07 0.10 0.15 0.25]
#define CHROMA_AB 0.0025 //[0.0 0.001 0.0025 0.005]
#define LENS_FLARE
#define EXPOSURE_BIAS 0.0 //[-2.0 -1.0 -0.5 0.0 0.5 1.0 2.0]
#define BLOCK_LIGHT 1.8 //[0.8 1.2 1.8 2.5 3.5]
#define EMISSION_STRENGTH 6.0 //[2.0 4.0 6.0 10.0]
#define SKY_STEPS 14

// ============================ PIPELINE CONSTANTS ============================
const bool colortex0MipmapEnabled = true;
const bool colortex4Clear = false;
const bool colortex5Clear = false;
const bool colortex7Clear = false;
const int   shadowMapResolution = 3072;
const float shadowDistance = 128.0;
const float sunPathRotation = -25.0;
const vec4  shadowcolor0ClearColor = vec4(1.0, 1.0, 1.0, 0.0);
const float wetnessHalflife = 120.0;
const float drynessHalflife = 60.0;
const float centerDepthHalflife = 0.8;

uniform float viewWidth;
uniform float viewHeight;
uniform int   frameCounter;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float wetness;

// ============================ UTILITIES ============================
float luma(vec3 c){ return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 toLinear(vec3 c){ return pow(max(c, vec3(0.0)), vec3(2.2)); }

float hash11(float p){ p = fract(p*.1031); p *= p+33.33; p *= p+p; return fract(p); }
float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx)*.1031); p3 += dot(p3, p3.yzx+33.33); return fract((p3.x+p3.y)*p3.z); }
vec2  hash22(vec2 p){ vec3 p3 = fract(vec3(p.xyx)*vec3(.1031,.1030,.0973)); p3 += dot(p3, p3.yzx+33.33); return fract((p3.xx+p3.yz)*p3.zy); }
float hash13(vec3 p3){ p3 = fract(p3*.1031); p3 += dot(p3, p3.zyx+31.32); return fract((p3.x+p3.y)*p3.z); }

float ignoise(vec2 p){
    p += 5.588238*float(frameCounter & 63);
    return fract(52.9829189*fract(dot(p, vec2(0.06711056, 0.00583715))));
}

float vnoise2(vec2 p){
    vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash12(i), hash12(i+vec2(1,0)), f.x), mix(hash12(i+vec2(0,1)), hash12(i+vec2(1,1)), f.x), f.y);
}
float vnoise(vec3 p){
    vec3 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(mix(hash13(i),               hash13(i+vec3(1,0,0)), f.x),
                   mix(hash13(i+vec3(0,1,0)),   hash13(i+vec3(1,1,0)), f.x), f.y),
               mix(mix(hash13(i+vec3(0,0,1)),   hash13(i+vec3(1,0,1)), f.x),
                   mix(hash13(i+vec3(0,1,1)),   hash13(i+vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm2(vec2 p, int oct){
    float a = 0.5, s = 0.0, n = 0.0;
    for(int i = 0; i < oct; i++){ s += a*vnoise2(p); n += a; p = p*2.03 + 11.7; a *= 0.5; }
    return s/n;
}
float fbm3(vec3 p, int oct){
    float a = 0.5, s = 0.0, n = 0.0;
    for(int i = 0; i < oct; i++){ s += a*vnoise(p); n += a; p = p*2.02 + 7.3; a *= 0.5; }
    return s/n;
}

vec2 vogel(int i, int n, float phi){
    float r = sqrt((float(i)+0.5)/float(n));
    float th = float(i)*2.39996323 + phi;
    return r*vec2(cos(th), sin(th));
}

vec3 cosineHemisphere(vec3 n, vec2 xi){
    float phi = TAU*xi.x, ct = sqrt(1.0-xi.y), st = sqrt(xi.y);
    vec3 h = vec3(cos(phi)*st, sin(phi)*st, ct);
    vec3 up = abs(n.z) < 0.999 ? vec3(0,0,1) : vec3(1,0,0);
    vec3 t = normalize(cross(up, n)); vec3 b = cross(n, t);
    return normalize(t*h.x + b*h.y + n*h.z);
}
vec3 sampleGGX(vec3 n, vec2 xi, float a){
    float phi = TAU*xi.x;
    float ct = sqrt((1.0-xi.y)/(1.0+(a*a-1.0)*xi.y));
    float st = sqrt(max(1.0-ct*ct, 0.0));
    vec3 h = vec3(cos(phi)*st, sin(phi)*st, ct);
    vec3 up = abs(n.z) < 0.999 ? vec3(0,0,1) : vec3(1,0,0);
    vec3 t = normalize(cross(up, n)); vec3 b = cross(n, t);
    return normalize(t*h.x + b*h.y + n*h.z);
}

vec2 encodeNormal(vec3 n){
    n /= (abs(n.x)+abs(n.y)+abs(n.z));
    vec2 e = n.xy;
    if(n.z < 0.0) e = (1.0-abs(e.yx))*vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
    return e*0.5+0.5;
}
vec3 decodeNormal(vec2 f){
    f = f*2.0-1.0;
    vec3 n = vec3(f, 1.0-abs(f.x)-abs(f.y));
    float t = max(-n.z, 0.0);
    n.x += n.x >= 0.0 ? -t : t;
    n.y += n.y >= 0.0 ? -t : t;
    return normalize(n);
}

float shadowDistortFactor(vec2 xy){ return length(xy)*0.85 + 0.15; }

vec3 windOffset(vec3 wp, float top, int type){
    float t = frameTimeCounter;
    vec2 w = vec2(sin(t*1.7 + wp.x*0.9 + wp.z*0.6), cos(t*1.3 + wp.z*0.8 - wp.x*0.5));
    float gust = 0.6 + 0.4*sin(t*0.45 + wp.x*0.07 + wp.z*0.05);
    float amp = (type == 1 ? 0.03 : 0.065*top) * gust * (1.0 + rainStrength*1.5);
    return vec3(w.x*amp, type == 1 ? sin(t*2.1 + wp.x + wp.z)*0.012 : 0.0, w.y*amp);
}

vec2 rainRipples(vec2 p){
    vec2 g = vec2(0.0);
    for(int l = 0; l < 2; l++){
        vec2 q = p*(2.2 + float(l)*1.7) + float(l)*17.3;
        vec2 cell = floor(q), f = fract(q);
        vec2 c = hash22(cell)*0.6 + 0.2;
        float t = fract(frameTimeCounter*(0.9 + 0.25*hash12(cell+3.1)) + hash12(cell));
        vec2 dv = f - c; float d = length(dv), R = t*0.5;
        float w = exp(-pow((d-R)*18.0, 2.0))*(1.0-t)*(1.0-t);
        g += normalize(dv + 1e-4)*w*sin((d-R)*55.0);
    }
    return g;
}

vec3 acesTonemap(vec3 c){
    const mat3 IN  = mat3(0.59719,0.07600,0.02840, 0.35458,0.90834,0.13383, 0.04823,0.01566,0.83777);
    const mat3 OUT = mat3(1.60475,-0.10208,-0.00327, -0.53108,1.10813,-0.07276, -0.07367,-0.00605,1.07602);
    c = IN*c;
    vec3 a = c*(c+0.0245786) - 0.000090537;
    vec3 b = c*(0.983729*c+0.4329510) + 0.238081;
    return clamp(OUT*(a/b), 0.0, 1.0);
}
#endif
