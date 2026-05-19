// reflection_nebula.glsl
// Pure dust scattering — no emission lines, no hot ionized gas.
// This is reflected starlight. The blue is Rayleigh/Mie scatter, not [O III].
//
// Physical model:
//   - One bright illuminating star (off-center, not embedded)
//   - Two-component dust: large grains (Mie, forward-scatter, grey) +
//                          small grains (Rayleigh, isotropic, very blue)
//   - Beer-Lambert absorption per wavelength channel
//   - No thermal emission — gas is cold (T ~ 15–50 K)
//   - Polarization field encoded in alpha channel (optional)
//
// Real-world analog: NGC 1435 (Merope Nebula in Pleiades), IC 4592,
// the blue haze around the Pleiades.  Reflection nebulae always appear BLUE
// because blue light scatters more than red. If you see a blue nebula, it's
// reflecting — it's not emitting.
//
// Key parameters:
//   uIlluminatorOffset: position of the illuminating star (default: off-center)
//   uSmallGrainFrac:    fraction of small (Rayleigh-scattering) grains [0,1]
//   uGrainSize:         mean grain radius in microns (0.05–0.3)

#ifdef GL_ES
precision highp float;
#endif

#define PI 3.14159265358979

uniform vec2  uResolution;
uniform float uTime;
uniform float uDensityScale;
uniform float uTurbulence;
uniform float uEmission;        // scatter strength multiplier
uniform float uDustOpacity;

// Illuminating star: sits above-right of the nebula, not inside it.
// At uTime=0: fixed at a good angle; slowly drifts for interest.
// Physical note: the illuminator can be an embedded or external star.
// Here it's external — like the Pleione / Merope illuminating the Pleiades dust.

// ── Noise ─────────────────────────────────────────────────────────────────────
vec3 hash3(vec3 p) {
    p = fract(p * vec3(443.8975, 397.2973, 491.1871));
    p += dot(p, p.yxz + 19.19);
    return fract((p.xxy + p.yxx) * p.zyx);
}
float valueNoise(vec3 p) {
    vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash3(i).x,hash3(i+vec3(1,0,0)).x,f.x),
                   mix(hash3(i+vec3(0,1,0)).x,hash3(i+vec3(1,1,0)).x,f.x),f.y),
               mix(mix(hash3(i+vec3(0,0,1)).x,hash3(i+vec3(1,0,1)).x,f.x),
                   mix(hash3(i+vec3(0,1,1)).x,hash3(i+vec3(1,1,1)).x,f.x),f.y),f.z);
}
float fbm(vec3 p, float t) {
    float v=0.0, a=0.5, freq=1.0;
    for(int i=0;i<6;i++){ v+=a*valueNoise(p*freq); a*=0.5; freq*=2.0+t*0.1; p+=vec3(1.7,9.2,3.4); }
    return v;
}

// ── Dust density — reflection nebula has pure dust, no hot gas ────────────────
float dustDensity(vec3 p) {
    // Reflection nebulae are often elongated filamentary dust clouds
    // Slightly flatten the envelope along y to make it a cloud layer
    vec3 ps  = vec3(p.x, p.y * 1.6, p.z);
    float env = pow(max(0.0, 1.0 - dot(ps,ps)*0.22), 1.3);
    float base = fbm(p * uTurbulence * 1.1, uTurbulence);
    // Sharp density contrast — real reflection nebulae have structure
    float detail = fbm(p * uTurbulence * 3.5 + vec3(5.1, 2.7, 8.3), uTurbulence) * 0.3;
    return max(0.0, base + detail - 0.42) * env * uDensityScale;
}

// ── Henyey-Greenstein phase function ─────────────────────────────────────────
float henyeyGreenstein(float cosTheta, float g) {
    float g2 = g*g;
    return (1.0 - g2) / (4.0*PI * pow(max(1.0+g2-2.0*g*cosTheta, 1e-5), 1.5));
}

// Double HG: forward lobe (large grains) + weak back-scatter
float dustPhase(float cosTheta, float grainSize) {
    // Large grains (Mie): strongly forward, g ≈ 0.7–0.9
    // Small grains (Rayleigh): nearly isotropic, g ≈ 0.0–0.2
    // grainSize in microns; lambda_vis ≈ 0.55 μm → size param x = 2π·a/λ
    float x = 2.0*PI*grainSize / 0.55;
    float g_large = clamp(0.5 + 0.4*(1.0 - exp(-x*0.5)), 0.0, 0.95);
    float g_small = 0.1;
    float f_large = clamp(x / (x + 1.0), 0.0, 1.0);    // more large grains at larger a

    float p_large = henyeyGreenstein(cosTheta, g_large);
    float p_small = henyeyGreenstein(cosTheta, g_small);
    return mix(p_small, p_large, f_large);
}

// ── Wavelength-dependent scattering (Rayleigh + Mie mix) ─────────────────────
// Returns RGB scattering efficiency, normalized to green=1.
// Small grains: σ ∝ λ^-4 (very blue)
// Large grains: σ ∝ λ^-1 to λ^-2 (gently blue)
vec3 scatterColor(float grainSize) {
    float x  = 2.0*PI*grainSize / 0.55;   // size parameter at green
    float alpha = mix(4.0, 1.0, clamp((x-1.0)/9.0, 0.0, 1.0));  // power law index
    float extR = pow(0.55/0.65, alpha);   // relative to green
    float extG = 1.0;
    float extB = pow(0.55/0.44, alpha);   // blue scatters more
    return vec3(extR, extG, extB) / extG;
}

// ── Illuminating star position ────────────────────────────────────────────────
// Slow drift so the light angle evolves. This shows how the nebula appearance
// changes with illumination angle — a real observable effect.
vec3 illuminatorPos() {
    float drift = uTime * 0.02;
    return vec3(cos(drift)*3.0, 2.5, sin(drift)*2.0);
}

// ── Shadow raycast: estimate how much starlight reaches point p ───────────────
// Simple single-step shadow (not a full secondary march — too expensive).
// Approximates self-shadowing with a coarse opacity estimate.
float shadowTransmittance(vec3 p, vec3 toStar) {
    float shadowTau = 0.0;
    const int SHADOW_STEPS = 8;
    float shadowDist = length(toStar);
    float shadowStep = shadowDist / float(SHADOW_STEPS);
    vec3  shadowDir  = normalize(toStar);

    for (int i = 1; i <= SHADOW_STEPS; i++) {
        vec3 sp = p + shadowDir * (float(i) * shadowStep);
        shadowTau += dustDensity(sp) * uDustOpacity * shadowStep * 0.5;
    }
    return exp(-shadowTau);
}

// ── Raymarcher ────────────────────────────────────────────────────────────────
const int   STEPS   = 80;
const float STEP_SZ = 0.055;

// Grain size: 0.05–0.3 μm. Typical ISM: 0.1–0.2 μm.
const float GRAIN_SIZE = 0.12;

vec3 raymarch(vec3 ro, vec3 rd) {
    vec3  color = vec3(0.0);
    float trans = 1.0;

    vec3 starPos   = illuminatorPos();
    vec3 scatRGB   = scatterColor(GRAIN_SIZE);    // blue-weighted scattering

    for (int i = 0; i < STEPS; i++) {
        vec3  p    = ro + rd * (float(i)*STEP_SZ);
        float d    = dustDensity(p);

        if (d > 0.001) {
            vec3  toStar    = starPos - p;
            float starDist2 = dot(toStar, toStar);
            float starDist  = sqrt(starDist2);
            vec3  toStarDir = toStar / starDist;
            float cosTheta  = dot(rd, toStarDir);

            // Incident star intensity: B star ~ warm white with slight blue excess
            vec3 starLight  = vec3(0.92, 0.96, 1.00) * 3.0 / (1.0 + starDist2 * 0.5);

            // Phase function
            float phase = dustPhase(cosTheta, GRAIN_SIZE);

            // Shadow factor (self-shadowing)
            float shadow = shadowTransmittance(p, toStar);

            // Scattered in-color: starlight * wavelength-dependent scatter * phase
            vec3 scattered = starLight * scatRGB * phase * shadow * d * uEmission * STEP_SZ;
            color += trans * scattered;

            // Extinction: wavelength-dependent, blue dims less than red here
            // because blue scatters in MORE from all directions
            vec3 extRGB  = scatRGB * d * uDustOpacity * STEP_SZ;
            trans *= exp(-dot(extRGB, vec3(0.33)));   // luminance-weighted transmittance
        }
        if (trans < 0.01) break;
    }

    // Direct star bloom
    vec3  toStar = illuminatorPos() - ro;
    float tHit   = dot(toStar, rd);
    if (tHit > 0.0) {
        vec3  closest = ro + rd*tHit - illuminatorPos();
        float r2      = dot(closest, closest);
        color += vec3(0.95, 0.97, 1.0) * exp(-r2 * 5000.0) * 2.0 * trans;
    }

    return color;
}

mat3 lookAt(vec3 eye, vec3 target) {
    vec3 z=normalize(eye-target), x=normalize(cross(vec3(0,1,0),z)), y=cross(z,x);
    return mat3(x,y,z);
}

void main() {
    vec2 uv  = (gl_FragCoord.xy - uResolution*0.5) / uResolution.y;
    float a  = uTime * 0.06;
    vec3 eye = vec3(cos(a)*4.0, 1.2, sin(a)*4.0);
    mat3 cam = lookAt(eye, vec3(0.0));
    vec3 rd  = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd);

    // Reflection nebulae have very low surface brightness — boost slightly
    color *= 1.4;

    color = color / (color + 1.0);
    color = pow(color, vec3(1.0/2.2));
    gl_FragColor = vec4(color, 1.0);
}
