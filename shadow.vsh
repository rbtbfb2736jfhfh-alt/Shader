#version 330 compatibility
#include "/lib/common.glsl"
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;
uniform vec3 cameraPosition;
in vec4 mc_Entity;
in vec2 mc_midTexCoord;
out vec2 texcoord;
out vec4 glcolor;
flat out int isWater;
void main(){
    texcoord = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    int id = int(mc_Entity.x + 0.5);
    isWater = id == 10008 ? 1 : 0;
    vec4 vpos = gl_ModelViewMatrix*gl_Vertex;
    vec3 feet = (shadowModelViewInverse*vpos).xyz;
    vec3 wp = feet + cameraPosition;
    if(id == 10001) feet += windOffset(wp, 1.0, 1);
    else if(id == 10002) feet += windOffset(wp, gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0, 2);
    vec4 clip = gl_ProjectionMatrix*(shadowModelView*vec4(feet, 1.0));
    clip.xy /= shadowDistortFactor(clip.xy);
    clip.z *= 0.5;
    gl_Position = clip;
}
