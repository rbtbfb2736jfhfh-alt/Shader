#ifndef PBR_GLSL
#define PBR_GLSL
struct Material { vec3 albedo; vec3 F0; float rough; float alpha; float metal; float sss; float emissive; float porosity; };

vec3 metalF0(int i){
    if(i == 230) return vec3(0.56, 0.57, 0.58);
    if(i == 231) return vec3(1.00, 0.71, 0.29);
    if(i == 232) return vec3(0.91, 0.92, 0.92);
    if(i == 233) return vec3(0.55, 0.56, 0.55);
    if(i == 234) return vec3(0.95, 0.64, 0.54);
    if(i == 235) return vec3(0.63, 0.63, 0.64);
    if(i == 236) return vec3(0.67, 0.64, 0.60);
    return vec3(0.95, 0.93, 0.88);
}

Material decodeMaterial(vec4 alb, vec4 spec, int matID){
    Material m;
    m.albedo = toLinear(alb.rgb);
    m.rough = pow(1.0 - spec.r, 2.0);
    m.alpha = max(m.rough, 0.01);
    int g = int(spec.g*255.0 + 0.5);
    m.metal = g >= 230 ? 1.0 : 0.0;
    if(g >= 230) m.F0 = (g >= 255) ? m.albedo : metalF0(min(g, 237));
    else         m.F0 = vec3(max(float(g)/255.0, 0.02));
    int b = int(spec.b*255.0 + 0.5);
    m.porosity = b <= 64 ? float(b)/64.0 : 0.0;
    m.sss = b > 64 ? float(b-65)/190.0 : 0.0;
    int a = int(spec.a*255.0 + 0.5);
    m.emissive = a < 255 ? float(a)/254.0 : 0.0;
    if(matID == 1) m.sss = max(m.sss, 0.55);
    if(matID == 4) m.emissive = max(m.emissive, 0.7);
    return m;
}

float D_GGX(float NoH, float a){ float a2 = a*a; float d = NoH*NoH*(a2-1.0)+1.0; return a2/(PI*d*d); }
float V_SmithGGX(float NoV, float NoL, float a){
    float a2 = a*a;
    float gv = NoL*sqrt(NoV*NoV*(1.0-a2)+a2);
    float gl = NoV*sqrt(NoL*NoL*(1.0-a2)+a2);
    return 0.5/max(gv+gl, 1e-5);
}
vec3 F_Schlick(vec3 F0, float c){ return F0 + (1.0-F0)*pow(1.0-c, 5.0); }
vec3 F_SchlickRough(vec3 F0, float c, float rough){ return F0 + (max(vec3(1.0-rough), F0) - F0)*pow(1.0-c, 5.0); }
#endif
