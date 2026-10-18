#version 330 compatibility
#include "/lib/formats.glsl"
/* RENDERTARGETS: 0 */
#include "/lib/common.glsl"
#include "/lib/space.glsl"
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 previousCameraPosition;
in vec2 texcoord;
layout(location = 0) out vec4 outColor;
void main(){
    vec2 uv = texcoord;
    vec3 c = texture(colortex0, uv).rgb;
    float d = texture(depthtex0, uv).r;
    if(d < 0.56){ outColor = vec4(c, 1.0); return; }
    vec3 pf = feetFromView(viewFromScreen(uv, d)) + cameraPosition - previousCameraPosition;
    vec4 pc = gbufferPreviousProjection*(gbufferPreviousModelView*vec4(pf, 1.0));
    vec2 vel = (uv - (pc.xy/pc.w*0.5 + 0.5))*MB_STRENGTH*0.5;
    float l = length(vel);
    if(l > 0.05) vel *= 0.05/l;
    float jit = ignoise(gl_FragCoord.xy);
    vec3 acc = c; float n = 1.0;
    for(int i = 1; i <= 8; i++){
        float t = (float(i) + jit)/9.0 - 0.5;
        vec2 suv = clamp(uv + vel*t*2.0, vec2(0.001), vec2(0.999));
        acc += texture(colortex0, suv).rgb; n += 1.0;
    }
    outColor = vec4(acc/n, 1.0);
}
