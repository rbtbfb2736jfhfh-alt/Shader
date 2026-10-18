#version 330 compatibility
#include "/lib/common.glsl"
#include "/lib/water.glsl"
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
in vec4 mc_Entity;
out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 vNormal;
out vec3 vWorldPos;
out vec3 vViewPos;
flat out int matType;
void main(){
    texcoord = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    lmcoord = clamp(((gl_TextureMatrix[1]*gl_MultiTexCoord1).xy - 0.0313)*1.067, 0.0, 1.0);
    glcolor = gl_Color;
    vec4 vpos = gl_ModelViewMatrix*gl_Vertex;
    vec3 feet = (gbufferModelViewInverse*vpos).xyz;
    int id = int(mc_Entity.x + 0.5);
    matType = id == 10008 ? 2 : 3;
    if(matType == 2 && gl_Normal.y > 0.5){
        vec3 dummy;
        feet.y += gerstner(feet.xz + cameraPosition.xz, frameTimeCounter, 3, dummy)*0.5;
    }
    vWorldPos = feet + cameraPosition;
    vpos = gbufferModelView*vec4(feet, 1.0);
    vViewPos = vpos.xyz;
    vNormal = normalize(gl_NormalMatrix*gl_Normal);
    gl_Position = gl_ProjectionMatrix*vpos;
}
