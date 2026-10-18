#define VSH
#include "/lib/common.glsl"
#include "/lib/sky_vertex.glsl"
out vec2 texcoord;
void main(){
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.xy;
    setupSky();
}
