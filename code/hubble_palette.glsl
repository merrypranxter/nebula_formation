// hubble_palette.glsl
// Classic "Hubble palette" false-color astronomy rendering.
//
// Three narrowband channels independently raymarched, then remapped:
//   S-II  (672 nm, sulfur)   → RED   channel
//   H-α   (656 nm, hydrogen) → GREEN channel
//   O-III (501 nm, oxygen)   → BLUE  channel
//
// This is the SHO (Sulfur-Hydrogen-Oxygen) mapping used in many iconic
// Hubble/Webb images. The result: teal ionized regions (O-III heavy),
// golden transition zones, magenta/pink H-alpha filaments.
//
// Physical note: real narrowband images use exposure times of hours per
// channel; the brightness ratios here are artistically calibrated.

#ifdef GL_ES
precision highp float;
#endif

uniform vec2  uResolution;
uniform float uTime;
uniform float uDensityScale;
uniform float uTurbulence;
uniform float uEmission;
uniform float uDustOpacity;
uniform float uTemperatureRange;   // 3000 – 50000 K; drives ion ratios

// ── Shared noise ─────────────────────────────────────────────────────────────
vec3 hash3(vec3 p) {
    p = fract(p * vec3(443.8975, 397.2973, 491.1871));
    p += dot(p, p.yxz + 19.19);
    return fract((p.xxy + p.yxx) * p.zyx);
}

float valueNoise(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(hash3(i             ).x, hash3(i+vec3(1,0,0)).x, f.x),
            mix(hash3(i+vec3(0,1,0)).x, hash3(i+vec3(1,1,0)).x, f.x), f.y),
        mix(mix(hash3(i+vec3(0,0,1)).x, hash3(i+vec3(1,0,1)).x, f.x),
            mix(hash3(i+vec3(0,1,1)).x, hash3(i+vec3(1,1,1)).x, f.x), f.y), f.z);
}

float fbm(vec3 p, float t) {
    float v = 0.0, a = 0.5, freq = 1.0;
    for (int i = 0; i < 6; i++) {
        v += a * valueNoise(p * freq);
        a *= 0.5; freq *= 2.0 + t * 0.1;
        p += vec3(1.7, 9.2, 3.4);
    }
    return v;
}

// ── Per-channel density fields ────────────────────────────────────────────────
// Each ion traces a slightly different spatial structure:
//   H-α   follows the bulk ionized gas (moderate density)
//   O-III concentrates in hotter, lower-density "skin" of ionization front
//   S-II  peaks just inside the ionization front (PDR layer)

float envelopeSphere(vec3 p) {
    return pow(max(0.0, 1.0 - dot(p,p) * 0.22), 1.4);
}

float densityHalpha(vec3 p) {
    float env  = envelopeSphere(p);
    float base = fbm(p * uTurbulence, uTurbulence);
    return max(0.0, base - 0.3) * env * uDensityScale;
}

float densityOIII(vec3 p) {
    // Hotter region: brighter where density is lower (ionization parameter)
    float env  = envelopeSphere(p);
    float base = fbm(p * uTurbulence + vec3(5.1, 2.3, 7.8), uTurbulence);
    float d    = max(0.0, base - 0.38) * env * uDensityScale;
    // O-III enhanced at outer/hotter shell
    float r    = length(p);
    float shellBoost = smoothstep(0.0, 1.0, r) * (1.0 - smoothstep(1.2, 2.0, r));
    return d * (0.5 + shellBoost * 1.5);
}

float densitySII(vec3 p) {
    // S-II peaks in PDR (photo-dissociation region) — just inside dense rim
    float env  = envelopeSphere(p);
    float base = fbm(p * uTurbulence + vec3(3.3, 6.1, 1.9), uTurbulence);
    float d    = max(0.0, base - 0.42) * env * uDensityScale;
    return d * 0.8;
}

// ── Raymarcher for one channel ────────────────────────────────────────────────
const int   STEPS   = 80;
const float STEP_SZ = 0.05;

float marchChannel(vec3 ro, vec3 rd, int channel) {
    float intensity     = 0.0;
    float transmittance = 1.0;

    for (int i = 0; i < STEPS; i++) {
        vec3  p = ro + rd * (float(i) * STEP_SZ);
        float d;
        if (channel == 0) d = densityHalpha(p);
        else if (channel == 1) d = densityOIII(p);
        else                   d = densitySII(p);

        if (d > 0.001) {
            intensity     += transmittance * d * uEmission * STEP_SZ;
            transmittance *= exp(-d * uDustOpacity * STEP_SZ);
        }
        if (transmittance < 0.01) break;
    }
    return intensity;
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
    float a  = uTime * 0.08;
    vec3 eye = vec3(cos(a)*3.8, 1.2, sin(a)*3.8);
    mat3 cam = lookAt(eye, vec3(0.0));
    vec3 rd  = normalize(cam * vec3(uv, -1.5));

    // March each narrowband channel
    float sii   = marchChannel(eye, rd, 2);
    float halpha = marchChannel(eye, rd, 0);
    float oiii  = marchChannel(eye, rd, 1);

    // SHO → RGB mapping (Hubble palette)
    vec3 color = vec3(sii, halpha, oiii);

    // Temperature-driven hue shift: high temperature → more O-III (blue-teal boost)
    float tempNorm = clamp((uTemperatureRange - 3000.0) / 47000.0, 0.0, 1.0);
    color.b += oiii * tempNorm * 0.4;
    color.g += halpha * (1.0 - tempNorm) * 0.3;

    // Tone-map + gamma
    color = color / (color + 1.0);
    color = pow(color, vec3(1.0 / 2.2));

    gl_FragColor = vec4(color, 1.0);
}
