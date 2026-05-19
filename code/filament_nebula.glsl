// filament_nebula.glsl
// The cosmic web at molecular cloud scale.
// Self-similar filamentary structure — the skeleton of the ISM.
//
// Physical model:
//   - Herschel Space Observatory revealed that ALL star-forming molecular clouds
//     are dominated by networks of filaments. This was the defining discovery of
//     Herschel (2009–2013).
//   - Filament widths: ~0.1 pc (astonishingly constant across cloud masses)
//     Debated physical origin: could be sonic scale of turbulence, or Alfvén
//     wave dissipation scale, or ambipolar diffusion scale.
//   - Velocity field: material flows ALONG filaments toward dense hubs,
//     and filaments flow transversely toward a higher-order ridge.
//     "rivers of gas" model (Kirk et al. 2013, Palmeirim et al. 2013)
//   - The ISM web is self-similar: filaments beget sub-filaments beget fibers
//
// The rendering goal: show this cascading hierarchy of filamentary structure
// with physically motivated colors and density profiles.
// Make the observer feel the invisible skeleton of the galaxy's star factory.
//
// Technical approach:
//   - Multi-scale filaments: large (main filament), medium (sub-filament), fine (fiber)
//   - Each scale uses a different noise ridge-finder
//   - Accretion flows: ambient gas funneling toward filament spines
//   - Hub-filament junctions: the densest points, where cores form

#ifdef GL_ES
precision highp float;
#endif

#define PI 3.14159265358979

uniform vec2  uResolution;
uniform float uTime;
uniform float uDensityScale;
uniform float uTurbulence;
uniform float uEmission;
uniform float uDustOpacity;
uniform float uEvolutionSpeed;

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

// Kolmogorov FBM
float fbmK(vec3 p, int oct, float lac) {
    float v=0.0, a=1.0, freq=1.0, norm=0.0;
    for(int i=0;i<8;i++){
        if(i>=oct) break;
        v    += a*valueNoise(p*freq);
        norm += a;
        a    *= 0.63;
        freq *= lac;
        p    += vec3(1.7, 9.2, 3.4);
    }
    return v/norm;
}

// ── Ridge extractor ───────────────────────────────────────────────────────────
// Finds ridges in an FBM field — these are the filament spines.
// Method: where the field is locally maximal in the transverse direction.
// Approximation: high |∇f| near f = local max → use smoothstep of |f - 0.5|
float ridgeDensity(vec3 p, float scale, float offset, float sharpness) {
    vec3 pn = p * scale + offset;
    float f = fbmK(pn * uTurbulence, 6, 2.0);
    float ridge = 1.0 - abs(f - 0.55) / 0.45;
    return pow(max(0.0, ridge), sharpness);
}

// ── Multi-scale filament density ──────────────────────────────────────────────
float filamentDensity(vec3 p) {
    // Large-scale main filament (~1 pc width in scene)
    float main = ridgeDensity(p, 0.8, 0.0, 4.0) * 1.2;

    // Sub-filaments: at half the scale, seeded differently
    float sub  = ridgeDensity(p, 1.8, 1.7, 3.0) * 0.7;

    // Fibers: finest scale, highest spatial frequency
    float fiber = ridgeDensity(p, 4.0, 3.3, 2.5) * 0.35;

    return (main + sub + fiber);
}

// ── Hub detection: dense junction of multiple filaments ───────────────────────
// Hubs appear where main filament density is high AND sub-filament is high
float hubDensity(vec3 p) {
    float f1 = ridgeDensity(p, 0.8, 0.0, 4.0);
    float f2 = ridgeDensity(p, 1.8, 1.7, 3.0);
    // Hub: both high → multiplicative enhancement
    return f1 * f2 * 3.0;
}

// ── Accretion flow field ──────────────────────────────────────────────────────
// Matter flows perpendicular to filament, toward the spine.
// This creates a transverse velocity gradient visible as striations in dust polarization.
// We show it as faint perpendicular density streaks pointing toward the spine.
float accretionStreaks(vec3 p) {
    // Direction perpendicular to main filament (gradient of filament density)
    float h = 0.02;
    float fx = ridgeDensity(p+vec3(h,0,0), 0.8, 0.0, 4.0) - ridgeDensity(p-vec3(h,0,0), 0.8, 0.0, 4.0);
    float fy = ridgeDensity(p+vec3(0,h,0), 0.8, 0.0, 4.0) - ridgeDensity(p-vec3(0,h,0), 0.8, 0.0, 4.0);
    float fz = ridgeDensity(p+vec3(0,0,h), 0.8, 0.0, 4.0) - ridgeDensity(p-vec3(0,0,h), 0.8, 0.0, 4.0);
    vec3 grad = vec3(fx, fy, fz) / (2.0 * h);
    float gradMag = length(grad);

    // Accretion streaks: elongated along gradient direction, faint
    float streakAlong = dot(p, normalize(grad + vec3(0.001)));
    float streak = fbmK(p * uTurbulence * 2.5 + vec3(0, uTime*uEvolutionSpeed*0.01, 0), 3, 2.0);
    return max(0.0, streak - 0.50) * gradMag * 0.5;
}

// ── Dense prestellar cores at hub junctions ────────────────────────────────────
float protostellarCores(vec3 p) {
    float cores = 0.0;
    for (int i = 0; i < 4; i++) {
        vec3 seed = hash3(vec3(float(i)*13.7, float(i)*5.1, float(i)*9.3));
        // Place cores where hub density is highest (heuristic positions)
        vec3 pos  = (seed * 2.0 - 1.0) * 0.8;
        float r   = 0.06 + seed.x * 0.05;
        float d   = length(p - pos);
        // Plummer-Bonnell profile for a prestellar core:
        // ρ(r) = ρ0 / (1 + (r/r0)^2)^2
        cores += 1.0 / pow(1.0 + (d/r)*(d/r), 2.0) * 1.2;
    }
    return cores;
}

// ── Combined density ──────────────────────────────────────────────────────────
float nebulaDensity(vec3 p) {
    float env   = pow(max(0.0, 1.0 - dot(p,p)*0.18), 1.2);
    float fila  = filamentDensity(p) * env;
    float hub   = hubDensity(p) * env;
    float accrn = accretionStreaks(p) * env;
    float cores = protostellarCores(p) * env;

    return (fila + hub + accrn + cores) * uDensityScale;
}

// ── Emission color ────────────────────────────────────────────────────────────
// Filament color palette following Herschel three-band composite convention:
//   Fine fibers (cold):   blue-green (250 μm, Herschel SPIRE)
//   Main filaments (warm): orange-red (160 μm, Herschel PACS)
//   Dense cores (hot):    yellow-white (70 μm, Herschel PACS)
vec3 emitColor(vec3 p, float density) {
    float f0 = ridgeDensity(p, 0.8, 0.0, 4.0);    // main
    float f1 = ridgeDensity(p, 1.8, 1.7, 3.0);   // sub
    float f2 = ridgeDensity(p, 4.0, 3.3, 2.5);   // fiber
    float hub = hubDensity(p);
    float core = protostellarCores(p);

    vec3 fiberCol = vec3(0.15, 0.55, 0.65);    // cold: blue-teal (250μm)
    vec3 subCol   = vec3(0.60, 0.40, 0.10);    // warm: orange (160μm)
    vec3 mainCol  = vec3(0.80, 0.25, 0.05);    // hot: red-orange (100μm)
    vec3 hubCol   = vec3(0.95, 0.60, 0.05);    // hub: golden-orange
    vec3 coreCol  = vec3(1.00, 0.90, 0.60);    // protostar: warm white-yellow

    vec3 col = fiberCol * f2 + subCol * f1 + mainCol * f0 + hubCol * hub * 0.3 + coreCol * core * 0.5;
    col /= max(f0 + f1 + f2 + hub*0.3 + core*0.5, 0.001);   // normalize

    return col * density * uEmission;
}

// ── Raymarcher ────────────────────────────────────────────────────────────────
const int   STEPS   = 80;
const float STEP_SZ = 0.055;

vec3 raymarch(vec3 ro, vec3 rd) {
    vec3  color = vec3(0.0);
    float trans = 1.0;
    for (int i = 0; i < STEPS; i++) {
        vec3  p = ro + rd * (float(i)*STEP_SZ);
        float d = nebulaDensity(p);
        if (d > 0.001) {
            color += trans * emitColor(p, d) * STEP_SZ;
            trans *= exp(-d * uDustOpacity * STEP_SZ);
        }
        if (trans < 0.01) break;
    }
    return color;
}

mat3 lookAt(vec3 eye, vec3 target) {
    vec3 z=normalize(eye-target), x=normalize(cross(vec3(0,1,0),z)), y=cross(z,x);
    return mat3(x,y,z);
}

void main() {
    vec2 uv  = (gl_FragCoord.xy - uResolution*0.5) / uResolution.y;
    float a  = uTime * 0.04;
    vec3 eye = vec3(cos(a)*4.0, 1.0, sin(a)*4.0);
    mat3 cam = lookAt(eye, vec3(0.0));
    vec3 rd  = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd);
    color = color / (color + 1.0);
    color = pow(color, vec3(1.0/2.2));
    gl_FragColor = vec4(color, 1.0);
}
