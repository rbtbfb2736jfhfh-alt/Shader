#include "/lib/sky_vary.glsl"
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelViewInverse;

void setupSky(){
    mat3 mv = mat3(gbufferModelViewInverse);
    sunDirW   = normalize(mv*sunPosition);
    moonDirW  = normalize(mv*moonPosition);
    lightDirW = normalize(mv*shadowLightPosition);
    const float camH = 400.0;
    float sunVis  = smoothstep(-0.08, 0.06, sunDirW.y);
    float moonVis = smoothstep(-0.08, 0.10, moonDirW.y)*(1.0 - sunVis);

    vec3 sCol = SUN_ILLUM*sunTransmittance(sunDirW.y)*sunVis;
    vec3 mCol = vec3(0.62, 0.74, 1.0)*0.085*moonVis;

    vec3 zen = atmosphereScatter(vec3(0,1,0), sunDirW, camH, 10);
    vec3 hor = vec3(0.0);
    float az = atan(sunDirW.z, sunDirW.x);
    for(int i = 0; i < 4; i++){
        float a = az + float(i)*1.5708;
        hor += atmosphereScatter(normalize(vec3(cos(a), 0.12, sin(a))), sunDirW, camH, 8);
    }
    hor *= 0.25;
    if(moonVis > 0.01){
        vec3 mt = vec3(0.55, 0.72, 1.0)*0.014*moonVis;
        zen += atmosphereScatter(vec3(0,1,0), moonDirW, camH, 8)*mt;
        hor += atmosphereScatter(normalize(vec3(cos(az+3.14), 0.12, sin(az+3.14))), moonDirW, camH, 8)*mt;
    }
    vec3 night = vec3(0.0009, 0.0016, 0.0042);
    zen += night; hor += night;

    float rain = rainStrength;
    vec3 amb0 = mix(hor, zen, 0.55);
    zen = mix(zen, vec3(luma(zen))*vec3(0.78,0.84,0.95), rain*0.8);
    hor = mix(hor, vec3(luma(hor))*vec3(0.80,0.85,0.94), rain*0.8);
    vec3 sRain = sCol*(1.0 - 0.9*rain);
    mCol *= (1.0 - 0.8*rain);

    sunColor = sRain; moonColor = mCol;
    lightColor = dot(lightDirW, sunDirW) > 0.5 ? sRain : mCol;
    skyZenith = zen; skyHorizon = hor;
    ambientColor = mix(amb0, mix(hor, zen, 0.55), rain*0.8)*PI*0.9 + sCol*0.05*rain;
}
