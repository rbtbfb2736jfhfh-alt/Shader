#version 330 compatibility
#include "/lib/formats.glsl"
/* RENDERTARGETS: 0 */
#include "/lib/common.glsl"
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform float centerDepthSmooth;
uniform float near;
uniform float far;
in vec2 texcoord;
layout(location = 0) out vec4 outColor;

#define BLADES 7.0
#define MAX_COC 12.0
float linDepth(float d){ return (2.0*near*far)/(far + near - (d*2.0 - 1.0)*(far - near)); }

// thin-lens circle of confusion on a 36 mm sensor, returned as RADIUS in pixels
float cocRadius(float dist, float focus){
    float f = FOCAL_LENGTH*0.001;
    float c = (f*f/(F_STOP*max(focus - f, 1e-3)))*abs(dist - focus)/max(dist, 1e-3);
    return min(c/0.036*viewWidth*0.5, MAX_COC);
}

void main(){
    vec2 uv = texcoord;
    vec2 res = vec2(viewWidth, viewHeight);
    vec3 c0 = texture(colortex0, uv).rgb;
    float d0 = texture(depthtex0, uv).r;
    if(d0 < 0.56){ outColor = vec4(c0, 1.0); return; }   // hand stays sharp
    float focus = linDepth(centerDepthSmooth);
    float cocC = cocRadius(linDepth(d0), focus);

    const int N = 36;
    float rot = ignoise(gl_FragCoord.xy)*TAU;
    vec3 acc = c0; float ws = 1.0;
    for(int i = 0; i < N; i++){
        vec2 p = vogel(i, N, rot);
        float r = length(p), th = atan(p.y, p.x);
        float seg = TAU/BLADES;
        float poly = cos(PI/BLADES)/cos(mod(th, seg) - PI/BLADES);
        vec2 o = p*poly*MAX_COC;
        float len = length(o);
        vec2 suv = uv + o/res;
        float sd = texture(depthtex0, suv).r;
        float sc = sd < 0.56 ? 0.0 : cocRadius(linDepth(sd), focus);
        float w = clamp(sc - len + 1.0, 0.0, 1.0);
        vec3 s = texture(colortex0, suv).rgb;
        w *= 1.0 + min(luma(s), 40.0)*0.12;   // highlights -> bokeh balls
        acc += s*w; ws += w;
    }
    outColor = vec4(acc/ws, 1.0);
}
