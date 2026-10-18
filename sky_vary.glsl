#ifndef SKY_VARY_GLSL
#define SKY_VARY_GLSL
#include "/lib/atmosphere.glsl"
#ifdef VSH
#define VARY out
#else
#define VARY in
#endif
VARY vec3 sunDirW;
VARY vec3 moonDirW;
VARY vec3 lightDirW;
VARY vec3 sunColor;
VARY vec3 moonColor;
VARY vec3 lightColor;
VARY vec3 skyZenith;
VARY vec3 skyHorizon;
VARY vec3 ambientColor;

#ifndef VSH
vec3 cheapSky(vec3 dir){
    float h = dir.y;
    vec3 c = mix(skyHorizon, skyZenith, pow(clamp(h, 0.0, 1.0), 0.5));
    c = mix(c, skyHorizon*0.45, smoothstep(0.0, -0.25, h));
    float mu = dot(dir, sunDirW);
    c += sunColor*0.12*phaseHG(mu, 0.8)*(1.0 - clamp(h,0.0,1.0)*0.7);
    c += moonColor*0.03*phaseHG(dot(dir, moonDirW), 0.7);
    return c;
}
#endif
#endif
