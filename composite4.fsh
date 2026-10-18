#version 330 compatibility
#include "/lib/formats.glsl"
/* RENDERTARGETS: 5 */
#include "/lib/common.glsl"
uniform sampler2D colortex0;
uniform sampler2D colortex5;
uniform float frameTime;
in vec2 texcoord;
layout(location = 0) out vec4 outExp;
void main(){
    if(ivec2(gl_FragCoord.xy) != ivec2(0)) discard;
    float lod = max(floor(log2(max(viewWidth, viewHeight))) - 3.0, 0.0);
    float sum = 0.0, wsum = 0.0;
    for(int y = 0; y < 6; y++){
        for(int x = 0; x < 6; x++){
            vec2 p = (vec2(x, y) + 0.5)/6.0;
            vec2 q = p - 0.5;
            float w = exp(-dot(q, q)*6.0);                     // centre-weighted metering
            float l = min(luma(textureLod(colortex0, p, lod).rgb), 40.0);
            sum += log(l + 1e-4)*w; wsum += w;
        }
    }
    float avg = exp(sum/wsum);
    float targetEV = clamp(log2(0.18/avg)*0.75, -4.0, 3.0);
    float prev = texelFetch(colortex5, ivec2(0), 0).r;
    float ev = prev;
    float first = texelFetch(colortex5, ivec2(0), 0).g;
    if(first < 0.5) ev = targetEV;                              // initialise
    else {
        float rate = targetEV < prev ? 1.6 : 0.6;               // pupils constrict faster than they dilate
        ev = mix(prev, targetEV, 1.0 - exp(-rate*frameTime));
    }
    outExp = vec4(ev, 1.0, 0.0, 1.0);
}
