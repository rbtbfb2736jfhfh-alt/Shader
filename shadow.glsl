#ifndef SHADOW_GLSL
#define SHADOW_GLSL
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

vec3 shadowSpace(vec3 feet, out float df){
    vec4 sp = shadowProjection*(shadowModelView*vec4(feet, 1.0));
    df = shadowDistortFactor(sp.xy);
    sp.xy /= df; sp.z *= 0.5;
    return sp.xyz*0.5 + 0.5;
}

vec3 sampleShadow(vec3 feet, vec3 Nw, float NoL, float dist, float skyL, float rot){
    float P00 = shadowProjection[0][0];
    float zPerBlock = 0.25*abs(shadowProjection[2][2]);
    float fb = smoothstep(shadowDistance*0.82, shadowDistance*0.98, dist);
    float fallback = smoothstep(0.55, 0.95, skyL);
    if(fb >= 1.0) return vec3(fallback);

    vec3 pos = feet + Nw*(0.02 + 0.06*(1.0-NoL))*(1.0 + dist*0.015);
    float df; vec3 sc = shadowSpace(pos, df);
    if(any(greaterThan(abs(sc.xy-0.5), vec2(0.5)))) return vec3(fallback);
    fb = max(fb, smoothstep(0.80, 0.98, max(abs(sc.x-0.5), abs(sc.y-0.5))*2.0));

    float texelBlocks = 2.0/(P00*float(shadowMapResolution))*df;
    float recv = sc.z - texelBlocks*(1.2 + 2.0*(1.0-NoL))*zPerBlock;

    float res = float(shadowMapResolution);
    float searchR = 6.0/res;
    float bz = 0.0, bc = 0.0;
    for(int i = 0; i < 6; i++){
        float z = texture(shadowtex0, sc.xy + vogel(i, 6, rot)*searchR).r;
        if(z < recv){ bz += z; bc += 1.0; }
    }
    float uvR = 1.5/res;
    if(bc > 0.0){
        float blockerBlocks = (recv - bz/bc)/zPerBlock;
        float widthBlocks = blockerBlocks*0.0093*SHADOW_SOFTNESS;
        uvR = clamp(widthBlocks*0.5*P00/df, 1.5/res, 14.0/res);
    }
    float s0 = 0.0, s1 = 0.0;
    for(int i = 0; i < 12; i++){
        vec2 o = sc.xy + vogel(i, 12, rot)*uvR;
        s0 += step(recv, texture(shadowtex0, o).r);
        s1 += step(recv, texture(shadowtex1, o).r);
    }
    s0 /= 12.0; s1 /= 12.0;
    vec4 tc = texture(shadowcolor0, sc.xy);
    vec3 tint = mix(vec3(1.0), tc.rgb, tc.a);
    vec3 vis = s1*(s0 + (1.0-s0)*tint);
    return mix(vis, vec3(fallback), fb);
}
#endif
