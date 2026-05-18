// dust_and_stars.glsl
// Nebula with embedded point-light stars, dust lanes, and scattered light.
//
// Rendering model (in order):
//   1. Stars:   each is a point-light that scatters off nearby dust (in-scattering)
//               and contributes direct bloom.
//   2. Gas:     emission nebula as in basic_nebula — H-alpha red/teal.
//   3. Dust:    separate, darker density field.  Absorbs gas light AND star light.
//               Dust scattering: Henyey-Greenstein phase function.
//
// Physical notes:
//   - Dust-to-gas ratio ≈ 1:100 by mass (ISM standard)
//   - Henyey-Greenstein g ≈ 0.6 for interstellar dust (forward-scattering)
//   - Dust reddening: shorter wavelengths scatter more (Rayleigh component)

#ifdef GL_ES
precision highp float;
#endif

uniform vec2  uResolution;
uniform float uTime;
uniform float uDensityScale;
uniform float uTurbulence;
uniform float uEmission;
uniform float uDustOpacity;
uniform int   uStarCount;        // [0, 50]

// ── Noise ─────────────────────────────────────────────────────────────────────
vec3 hash3(vec3 p) {
    p = fract(p * vec3(443.8975, 397.2973, 491.1871));
    p += dot(p, p.yxz + 19.19);
    return fract((p.xxy + p.yxx) * p.zyx);
}
float valueNoise(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(mix(hash3(i).x,           hash3(i+vec3(1,0,0)).x,f.x),
                   mix(hash3(i+vec3(0,1,0)).x,hash3(i+vec3(1,1,0)).x,f.x),f.y),
               mix(mix(hash3(i+vec3(0,0,1)).x,hash3(i+vec3(1,0,1)).x,f.x),
                   mix(hash3(i+vec3(0,1,1)).x,hash3(i+vec3(1,1,1)).x,f.x),f.y),f.z);
}
float fbm(vec3 p, float t) {
    float v=0.0, a=0.5, freq=1.0;
    for(int i=0;i<6;i++){ v+=a*valueNoise(p*freq); a*=0.5; freq*=2.0+t*0.1; p+=vec3(1.7,9.2,3.4); }
    return v;
}

// ── Gas density (H-alpha emission) ────────────────────────────────────────────
float gasDensity(vec3 p) {
    float env  = pow(max(0.0, 1.0 - dot(p,p)*0.25), 1.5);
    float base = fbm(p*uTurbulence, uTurbulence);
    return max(0.0, base - 0.35) * env * uDensityScale;
}

// ── Dust density (more filamentary, offset from gas slightly) ─────────────────
float dustDensity(vec3 p) {
    float env  = pow(max(0.0, 1.0 - dot(p,p)*0.22), 1.2);
    float base = fbm(p*uTurbulence*1.3 + vec3(2.5, 4.1, -1.7), uTurbulence);
    // Dust-to-gas ratio ~1:100; model as 0.01 fraction of density scale
    return max(0.0, base - 0.40) * env * uDensityScale * 0.15;
}

// ── Henyey-Greenstein phase function ─────────────────────────────────────────
// g = 0 → isotropic,  g > 0 → forward scattering
float henyeyGreenstein(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * 3.14159 * pow(1.0 + g2 - 2.0*g*cosTheta, 1.5));
}

// ── Star positions (deterministic from hash) ──────────────────────────────────
vec3 starPos(int idx) {
    vec3 h = hash3(vec3(float(idx) * 7.39, float(idx) * 3.17, float(idx) * 11.93));
    return (h * 2.0 - 1.0) * 1.6;    // scatter inside nebula volume
}

vec3 starColor(int idx) {
    vec3 h = hash3(vec3(float(idx) * 13.7, float(idx) * 5.3, float(idx) * 9.1));
    // Mix between hot blue-white and warm yellow-white
    return mix(vec3(0.7, 0.85, 1.0), vec3(1.0, 0.95, 0.7), h.x);
}

// ── In-scattering from all stars at sample point p ────────────────────────────
vec3 starInScatter(vec3 p, vec3 rd, float dustD) {
    if (dustD < 0.001) return vec3(0.0);
    vec3 scattered = vec3(0.0);
    for (int i = 0; i < 50; i++) {
        if (i >= uStarCount) break;
        vec3 sp  = starPos(i);
        vec3 toS = sp - p;
        float d2 = dot(toS, toS);
        if (d2 < 0.001) continue;
        vec3  dir      = toS / sqrt(d2);
        float cosTheta = dot(rd, dir);
        float phase    = henyeyGreenstein(cosTheta, 0.6);
        float falloff  = 1.0 / (1.0 + d2 * 4.0);
        scattered += starColor(i) * phase * falloff * dustD * 0.3;
    }
    return scattered;
}

// ── Raymarcher ────────────────────────────────────────────────────────────────
const int   STEPS   = 80;
const float STEP_SZ = 0.055;

vec3 raymarch(vec3 ro, vec3 rd) {
    vec3  color        = vec3(0.0);
    float transmittance = 1.0;

    for (int i = 0; i < STEPS; i++) {
        vec3  p    = ro + rd * (float(i) * STEP_SZ);
        float gasD  = gasDensity(p);
        float dustD = dustDensity(p);
        float totalD = gasD + dustD;

        if (totalD > 0.001) {
            // Gas emission (H-alpha red / O-III teal blend)
            vec3 gasColor = mix(vec3(0.9, 0.15, 0.1), vec3(0.1, 0.8, 0.75), clamp(gasD*0.5,0.0,1.0));
            color += transmittance * gasColor * gasD * uEmission * STEP_SZ;

            // Dust in-scattered starlight
            color += transmittance * starInScatter(p, rd, dustD) * STEP_SZ;

            // Total absorption (dust dominates)
            transmittance *= exp(-(dustD * uDustOpacity + gasD * 0.1) * STEP_SZ);
        }
        if (transmittance < 0.01) break;
    }

    // Direct star bloom (background)
    for (int i = 0; i < 50; i++) {
        if (i >= uStarCount) break;
        vec3  sp   = starPos(i);
        vec3  toS  = sp - ro;
        float tHit = dot(toS, rd);
        if (tHit < 0.0) continue;
        vec3  closest = ro + rd * tHit - sp;
        float r2      = dot(closest, closest);
        float bloom   = exp(-r2 * 8000.0);          // tight bloom
        color += starColor(i) * bloom * 1.5 * transmittance;
    }

    return color;
}

// ── Camera ────────────────────────────────────────────────────────────────────
mat3 lookAt(vec3 eye, vec3 target) {
    vec3 z = normalize(eye - target);
    vec3 x = normalize(cross(vec3(0,1,0), z));
    vec3 y = cross(z, x);
    return mat3(x, y, z);
}

void main() {
    vec2 uv  = (gl_FragCoord.xy - uResolution * 0.5) / uResolution.y;
    float a  = uTime * 0.07;
    vec3 eye = vec3(cos(a)*4.0, 1.5, sin(a)*4.0);
    mat3 cam = lookAt(eye, vec3(0.0));
    vec3 rd  = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd);
    color  = color / (color + 1.0);
    color  = pow(color, vec3(1.0/2.2));

    gl_FragColor = vec4(color, 1.0);
}
