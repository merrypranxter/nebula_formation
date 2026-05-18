// basic_nebula.glsl
// Fundamental volumetric raymarching through an FBM nebula density field.
// Emission + absorption (Beer-Lambert). No scattering, no stars — just cloud.
//
// Physically grounded:
//   - density ~ fractional Brownian motion (Kolmogorov turbulence)
//   - emission  = density * emissivity * color
//   - absorption = Beer-Lambert: transmittance *= exp(-density * dustOpacity * stepSize)
//   - Front-to-back alpha compositing

#ifdef GL_ES
precision highp float;
#endif

uniform vec2  uResolution;
uniform float uTime;
uniform float uDensityScale;   // [0.1, 5.0]  default 1.0
uniform float uTurbulence;     // [0.0, 3.0]  default 1.0
uniform float uEmission;       // [0.1, 5.0]  default 1.0
uniform float uDustOpacity;    // [0.0, 2.0]  default 0.5

// ── Noise primitives ────────────────────────────────────────────────────────
vec3 hash3(vec3 p) {
    p = fract(p * vec3(443.8975, 397.2973, 491.1871));
    p += dot(p, p.yxz + 19.19);
    return fract((p.xxy + p.yxx) * p.zyx);
}

float valueNoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);                       // smoothstep

    return mix(
        mix(mix(hash3(i             ).x, hash3(i + vec3(1,0,0)).x, f.x),
            mix(hash3(i + vec3(0,1,0)).x, hash3(i + vec3(1,1,0)).x, f.x), f.y),
        mix(mix(hash3(i + vec3(0,0,1)).x, hash3(i + vec3(1,0,1)).x, f.x),
            mix(hash3(i + vec3(0,1,1)).x, hash3(i + vec3(1,1,1)).x, f.x), f.y),
        f.z);
}

// Fractional Brownian Motion — 6 octaves, Kolmogorov-like frequency scaling
float fbm(vec3 p, float turbulence) {
    float value  = 0.0;
    float amplitude = 0.5;
    float freq   = 1.0;
    for (int i = 0; i < 6; i++) {
        value     += amplitude * valueNoise(p * freq);
        amplitude *= 0.5;
        freq      *= 2.0 + turbulence * 0.1;  // slight turbulence stretching
        p         += vec3(1.7, 9.2, 3.4);     // domain offset to break correlation
    }
    return value;
}

// ── Density field ────────────────────────────────────────────────────────────
// Soft-sphere envelope * FBM detail
float nebulaDensity(vec3 p) {
    float envelope = max(0.0, 1.0 - dot(p, p) * 0.25);   // sphere falloff
    envelope = pow(envelope, 1.5);
    float noise = fbm(p * uTurbulence, uTurbulence);
    noise = max(0.0, noise - 0.35);                        // threshold — peel away thin gas
    return noise * envelope * uDensityScale;
}

// Emission color: temperature-dependent, defaulting to H-alpha red
vec3 emissionColor(float density) {
    // Simple single-temperature H II region: red (H-alpha dominant)
    return vec3(0.85, 0.20, 0.15) * density;
}

// ── Ray marching ─────────────────────────────────────────────────────────────
const int   STEPS   = 64;
const float STEP_SZ = 0.06;

vec3 raymarch(vec3 ro, vec3 rd) {
    vec3  color        = vec3(0.0);
    float transmittance = 1.0;

    for (int i = 0; i < STEPS; i++) {
        vec3  p       = ro + rd * (float(i) * STEP_SZ);
        float density = nebulaDensity(p);

        if (density > 0.001) {
            // Emission contribution
            vec3 emission = emissionColor(density) * uEmission * STEP_SZ;
            color += transmittance * emission;

            // Absorption (Beer-Lambert)
            float absorption = density * uDustOpacity * STEP_SZ;
            transmittance   *= exp(-absorption);
        }

        if (transmittance < 0.01) break;   // ray fully absorbed
    }

    return color;
}

// ── Camera ────────────────────────────────────────────────────────────────────
mat3 lookAt(vec3 eye, vec3 target, vec3 up) {
    vec3 z = normalize(eye - target);
    vec3 x = normalize(cross(up, z));
    vec3 y = cross(z, x);
    return mat3(x, y, z);
}

void main() {
    vec2 uv  = (gl_FragCoord.xy - uResolution * 0.5) / uResolution.y;

    // Orbit camera slowly
    float angle = uTime * 0.1;
    vec3 eye    = vec3(cos(angle) * 3.5, 1.0, sin(angle) * 3.5);
    vec3 target = vec3(0.0);
    mat3 cam    = lookAt(eye, target, vec3(0.0, 1.0, 0.0));
    vec3 rd     = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd);

    // Tone-map (Reinhard) and gamma-correct
    color  = color / (color + 1.0);
    color  = pow(color, vec3(1.0 / 2.2));

    gl_FragColor = vec4(color, 1.0);
}
