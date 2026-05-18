// supernova_shell.glsl
// Expanding spherical shock shell with Rayleigh-Taylor instabilities.
// Models the contact discontinuity between blast ejecta and swept-up ISM.
//
// Physics modelled:
//   - Sedov-Taylor blast wave: radius ∝ t^(2/5)
//   - Rayleigh-Taylor instability at contact front → mushroom cap ripples
//   - Two zones: hot thin ejecta interior + dense compressed shell rim
//   - Synchrotron-like emission at the forward shock (bright rim)
//   - Pulsar wind nebula seed (central glow) — optional

#ifdef GL_ES
precision highp float;
#endif

uniform vec2  uResolution;
uniform float uTime;
uniform float uDensityScale;
uniform float uTurbulence;
uniform float uEmission;
uniform float uDustOpacity;

// ── Noise ─────────────────────────────────────────────────────────────────────
vec3 hash3(vec3 p) {
    p = fract(p * vec3(443.8975, 397.2973, 491.1871));
    p += dot(p, p.yxz + 19.19);
    return fract((p.xxy + p.yxx) * p.zyx);
}
float valueNoise(vec3 p) {
    vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash3(i).x,hash3(i+vec3(1,0,0)).x,f.x),mix(hash3(i+vec3(0,1,0)).x,hash3(i+vec3(1,1,0)).x,f.x),f.y),
               mix(mix(hash3(i+vec3(0,0,1)).x,hash3(i+vec3(1,0,1)).x,f.x),mix(hash3(i+vec3(0,1,1)).x,hash3(i+vec3(1,1,1)).x,f.x),f.y),f.z);
}
float fbm(vec3 p, float t) {
    float v=0.0, a=0.5, freq=1.0;
    for(int i=0;i<5;i++){ v+=a*valueNoise(p*freq); a*=0.5; freq*=2.1+t*0.05; p+=vec3(3.1,1.7,4.9); }
    return v;
}

// ── Shell geometry ────────────────────────────────────────────────────────────
// Sedov radius evolves with time
float shellRadius(float t) {
    // Simplified Sedov-Taylor: r ∝ t^(2/5), normalized so r=1 at t=5
    return 0.5 + 0.8 * pow(clamp(t / 5.0, 0.0, 1.0), 0.4);
}

float shellThickness() { return 0.12; }   // compressed shell width

// Rayleigh-Taylor perturbation: wrinkles the shell surface
float rtPerturbation(vec3 dir, float t) {
    // Perturbations grow as e^(sqrt(k*g*t)), saturate to finite amplitude
    float growth = min(1.0, 0.3 * sqrt(t));
    return fbm(dir * 3.0, uTurbulence) * growth * 0.15;
}

// ── Density field ─────────────────────────────────────────────────────────────
float shellDensity(vec3 p, float t) {
    float r    = length(p);
    float rShell = shellRadius(t);
    vec3  dir  = p / max(r, 0.001);

    // Perturbed shell surface
    float pert = rtPerturbation(dir, t);
    float rInner = rShell - shellThickness() + pert;
    float rOuter = rShell + pert;

    // Dense compressed shell
    float shellMask = smoothstep(rInner - 0.03, rInner, r) *
                      (1.0 - smoothstep(rOuter, rOuter + 0.03, r));

    // Hot rarefied interior (pulsar wind nebula / shocked ejecta)
    float interior = (1.0 - smoothstep(rInner - 0.2, rInner, r)) * 0.08;

    return (shellMask * 1.5 + interior) * uDensityScale;
}

// ── Emission color ────────────────────────────────────────────────────────────
vec3 shellColor(vec3 p, float density, float t) {
    float r = length(p);
    float rS = shellRadius(t);

    // Forward shock: blue-white (hot, synchrotron-like)
    // Contact discontinuity: green-teal (O-III)
    // Interior: purple-pink (X-ray / pulsar wind)
    float rimFrac = smoothstep(rS - shellThickness(), rS + 0.05, r);
    vec3 rimColor = mix(vec3(0.1, 0.7, 0.8), vec3(0.9, 0.95, 1.0), rimFrac);

    float intFrac = 1.0 - smoothstep(0.0, rS - shellThickness(), r);
    vec3 intColor = vec3(0.5, 0.1, 0.7);    // synchrotron purple

    return mix(intColor, rimColor, clamp(r / rS, 0.0, 1.0)) * density;
}

// ── Raymarcher ────────────────────────────────────────────────────────────────
const int   STEPS   = 96;
const float STEP_SZ = 0.04;

vec3 raymarch(vec3 ro, vec3 rd, float t) {
    vec3  color = vec3(0.0);
    float trans = 1.0;

    for (int i = 0; i < STEPS; i++) {
        vec3  p = ro + rd * (float(i) * STEP_SZ);
        float d = shellDensity(p, t);

        if (d > 0.001) {
            color += trans * shellColor(p, d, t) * uEmission * STEP_SZ;
            trans *= exp(-d * uDustOpacity * STEP_SZ * 0.3);
        }
        if (trans < 0.01) break;
    }
    return color;
}

// Central pulsar glow
vec3 pulsarGlow(vec3 ro, vec3 rd) {
    vec3  toC  = -ro;
    float tHit = dot(toC, rd);
    if (tHit < 0.0) return vec3(0.0);
    vec3  closest = ro + rd * tHit;
    float r2 = dot(closest, closest);
    return vec3(0.8, 0.6, 1.0) * exp(-r2 * 200.0) * 3.0;
}

mat3 lookAt(vec3 eye, vec3 target) {
    vec3 z=normalize(eye-target), x=normalize(cross(vec3(0,1,0),z)), y=cross(z,x);
    return mat3(x,y,z);
}

void main() {
    vec2 uv  = (gl_FragCoord.xy - uResolution*0.5) / uResolution.y;
    // Advance time to show expanding shell
    float t  = mod(uTime * 0.4, 8.0) + 0.5;
    float a  = uTime * 0.06;
    vec3 eye = vec3(cos(a)*3.5, 0.8, sin(a)*3.5);
    mat3 cam = lookAt(eye, vec3(0.0));
    vec3 rd  = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd, t) + pulsarGlow(eye, rd);
    color = color / (color + 1.0);
    color = pow(color, vec3(1.0/2.2));

    gl_FragColor = vec4(color, 1.0);
}
