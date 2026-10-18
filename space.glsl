#ifndef SPACE_GLSL
#define SPACE_GLSL
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
vec3 viewFromScreen(vec2 uv, float d){ vec4 v = gbufferProjectionInverse*vec4(vec3(uv, d)*2.0-1.0, 1.0); return v.xyz/v.w; }
vec3 screenFromView(vec3 v){ vec4 c = gbufferProjection*vec4(v, 1.0); return c.xyz/c.w*0.5+0.5; }
vec3 feetFromView(vec3 v){ return (gbufferModelViewInverse*vec4(v, 1.0)).xyz; }
vec3 worldDirFromView(vec3 d){ return mat3(gbufferModelViewInverse)*d; }
#endif
