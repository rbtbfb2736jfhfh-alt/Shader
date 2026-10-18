#include "/lib/common.glsl"
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
#ifdef TERRAIN
in vec4 mc_Entity;
in vec2 mc_midTexCoord;
in vec4 at_tangent;
out vec4 vtexcoordam;
out vec3 vTsView;
out vec3 vTangent;
out vec3 vBinormal;
flat out int vBlockId;
#endif
out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 vNormal;
out vec3 vWorldPos;
out float vDist;
void main(){
    texcoord = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    lmcoord = clamp(((gl_TextureMatrix[1]*gl_MultiTexCoord1).xy - 0.0313)*1.067, 0.0, 1.0);
    glcolor = gl_Color;
    vec4 vpos = gl_ModelViewMatrix*gl_Vertex;
    vec3 feet = (gbufferModelViewInverse*vpos).xyz;
    vec3 nrm = normalize(gl_NormalMatrix*gl_Normal);
#ifdef TERRAIN
    int id = int(mc_Entity.x + 0.5);
    vBlockId = id;
    vec3 wp = feet + cameraPosition;
    if(id == 10001) feet += windOffset(wp, 1.0, 1);
    else if(id == 10002) feet += windOffset(wp, gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0, 2);
    vpos = gbufferModelView*vec4(feet, 1.0);

    vec2 midcoord = (gl_TextureMatrix[0]*vec4(mc_midTexCoord, 0.0, 1.0)).st;
    vec2 d = texcoord - midcoord;
    vtexcoordam.pq = abs(d)*2.0;
    vtexcoordam.st = min(texcoord, midcoord - d);

    vec3 T = normalize(gl_NormalMatrix*at_tangent.xyz);
    vec3 B = cross(T, nrm)*at_tangent.w;
    vTangent = T; vBinormal = B;
    vTsView = vec3(dot(vpos.xyz, T), dot(vpos.xyz, B), dot(vpos.xyz, nrm));
#endif
    vNormal = nrm;
    vWorldPos = feet + cameraPosition;
    vDist = length(vpos.xyz);
    gl_Position = gl_ProjectionMatrix*vpos;
}
