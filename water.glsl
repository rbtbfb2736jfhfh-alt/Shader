#ifndef WATER_GLSL
#define WATER_GLSL
void waveParams(int i, int n, out vec2 d, out float k, out float A, out float Q, out float w){
    float fi = float(i);
    float ang = fi*2.39996 + 0.8 + 0.55*sin(fi*1.7);
    d = vec2(cos(ang), sin(ang));
    float wl = 22.0*pow(0.58, fi);
    k = TAU/wl;
    w = sqrt(9.81*k)*0.6;
    A = wl*0.0085*WAVE_HEIGHT;
    Q = 0.7/(k*A*float(n));
}
float gerstner(vec2 p, float t, int n, out vec3 normal){
    vec2 q = p;
    for(int it = 0; it < 2; it++){
        vec2 disp = vec2(0.0);
        for(int i = 0; i < n; i++){
            vec2 d; float k, A, Q, w; waveParams(i, n, d, k, A, Q, w);
            disp += d*(Q*A*cos(k*dot(d, q) - w*t + float(i)*1.7));
        }
        q = p - disp;
    }
    float h = 0.0, nx = 0.0, nz = 0.0, ny = 0.0;
    for(int i = 0; i < n; i++){
        vec2 d; float k, A, Q, w; waveParams(i, n, d, k, A, Q, w);
        float ph = k*dot(d, q) - w*t + float(i)*1.7;
        float s = sin(ph), c = cos(ph);
        h += A*s; nx += d.x*k*A*c; nz += d.y*k*A*c; ny += Q*k*A*s;
    }
    normal = normalize(vec3(-nx, 1.0 - ny, -nz));
    return h;
}
#endif
