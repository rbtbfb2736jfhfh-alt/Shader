#version 330 compatibility
#include "/lib/formats.glsl"
#include "/lib/common.glsl"
uniform sampler2D colortex0;
uniform sampler2D colortex5;
in vec2 texcoord;
layout(location = 0) out vec4 outColor;

vec3 bloomGather(vec2 uv){
    vec3 b = vec3(0.0); float ws = 0.0;
    for(int i = 2; i <= 7; i++){
        float w = exp2(-0.35*float(i - 2));
        vec2 px = exp2(float(i))/vec2(viewWidth, viewHeight);
        vec3 s = textureLod(colortex0, uv, float(i)).rgb*2.0
               + textureLod(colortex0, uv + vec2( px.x, 0.0)*0.5, float(i)).rgb
               + textureLod(colortex0, uv + vec2(-px.x, 0.0)*0.5, float(i)).rgb
               + textureLod(colortex0, uv + vec2(0.0,  px.y)*0.5, float(i)).rgb
               + textureLod(colortex0, uv + vec2(0.0, -px.y)*0.5, float(i)).rgb;
        b += s/6.0*w; ws += w;
    }
    return b/ws;
}

void main(){
    vec2 uv = texcoord;
    vec2 d = uv - 0.5;
    float ev = texelFetch(colortex5, ivec2(0), 0).r + EXPOSURE_BIAS;
    float exposure = exp2(ev);

    // chromatic aberration (radial)
    float ca = CHROMA_AB*length(d)*2.0;
    vec3 hdr = vec3(texture(colortex0, uv - d*ca).r, texture(colortex0, uv).g, texture(colortex0, uv + d*ca).b);

    hdr += bloomGather(uv)*BLOOM_STRENGTH;

#ifdef LENS_FLARE
    vec3 flare = vec3(0.0);
    vec2 toC = -d;
    for(int i = 1; i <= 4; i++){
        vec2 gu = uv + toC*(0.35*float(i));
        float edge = smoothstep(0.5, 0.2, length(gu - 0.5));
        vec3 s = textureLod(colortex0, gu, 3.0).rgb*exposure;
        vec3 tint = 0.5 + 0.5*cos(TAU*(float(i)*0.17 + vec3(0.0, 0.33, 0.67)));
        flare += max(s - 2.0, 0.0)*tint*edge/float(i);
    }
    hdr += flare*0.015/exposure;
#endif

    vec3 col = hdr*exposure;

    // natural (cos^4) vignette
    float r = length(d)*1.6;
    col *= pow(cos(atan(r)), 4.0);

    col = acesTonemap(col);
    col = mix(vec3(luma(col)), col, 1.06);                      // slight saturation recovery after ACES
    col = pow(col, vec3(1.0/2.2));
    col += (hash12(gl_FragCoord.xy + float(frameCounter)) - 0.5)*(1.5/255.0)
         + (hash12(gl_FragCoord.xy*1.7 + float(frameCounter)) - 0.5)*0.01*(1.0 - luma(col));  // dither + grain
    outColor = vec4(col, 1.0);
}
