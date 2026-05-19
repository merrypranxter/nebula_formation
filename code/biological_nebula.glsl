// biological_nebula.glsl
// The nebula as living body. Astrophysics as anatomy.
//
// Four anatomical modes, blended by uBioMode [0–4]:
//   0–1: LUNGS — alveolar gas-dust interface, branching bronchial filaments
//   1–2: BRAIN — neural-like molecular gas filaments, synaptic star ignitions
//   2–3: WOMB  — Bok globules as eggs, protostars as embryos in amniotic gas
//   3–4: CORPSE — supernova remnant as exploded organ, scattered viscera of a dead star
//
// The physics is real. The interpretation is biological.
// Every filament is a nerve. Every collapse is a breath. Every explosion is a death.
// You are looking at the interior of something that was, almost, alive.
//
// "The nebula retains its physics. We supply the body."

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
uniform float uEvolutionSpeed;   // [0,1]
// uBioMode cycles automatically with uTime; expose via uEvolutionSpeed to control speed.

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
    for(int i=0;i<7;i++){ v+=a*valueNoise(p*freq); a*=0.5; freq*=2.0+t*0.08; p+=vec3(1.7,9.2,3.4); }
    return v;
}

// ── Lung density: alveolar sacs — hollow spheres packed in fractal foam ────────
// Visually: clusters of thin-walled spherical voids in dense gas.
// Physical analog: the foam of a reflection nebula / molecular cloud interface.
float lungDensity(vec3 p, float t) {
    float breathPhase = sin(t * 0.3) * 0.5 + 0.5;   // breathing: 0=exhale, 1=inhale

    // Base gas
    float env  = pow(max(0.0, 1.0 - dot(p,p)*0.20), 1.3);
    float base = fbm(p * uTurbulence * 0.9 + vec3(0,0,t*0.03), uTurbulence);
    float gas  = max(0.0, base - 0.30) * env * uDensityScale;

    // Alveolar voids: anti-spheres subtracted from the gas field
    // Place many small voids using hash-seeded positions
    float voids = 0.0;
    for (int i = 0; i < 12; i++) {
        vec3 seed = hash3(vec3(float(i)*7.1, float(i)*3.3, float(i)*11.9));
        vec3 center = (seed * 2.0 - 1.0) * 1.3;
        float r = 0.08 + seed.z * 0.15;
        float scale = mix(0.9, 1.1, breathPhase);   // expand/contract with breath
        float dist = length(p - center) / (r * scale);
        // Thin wall: high density at shell, zero inside
        float wall  = exp(-pow(dist - 1.0, 2.0) * 30.0) * 0.8;
        float inner = 1.0 - smoothstep(0.85, 1.0, dist);
        voids += wall;
        gas   = max(0.0, gas - inner * gas * 0.9);
    }

    // Bronchial tubes: cylindrical filaments converging to center
    float tubes = 0.0;
    for (int i = 0; i < 6; i++) {
        vec3 seed = hash3(vec3(float(i)*13.7, float(i)*5.9, float(i)*2.3));
        vec3 dir  = normalize(seed * 2.0 - 1.0);
        float along = dot(p, dir);
        float perp  = length(p - along * dir);
        float radius = 0.04 + 0.06 * abs(along);   // tube flares outward
        tubes += exp(-perp * perp / (radius * radius)) * smoothstep(0.0, 0.3, abs(along)) * 0.5;
    }

    return (gas + voids * 0.3 + tubes * 0.4) * uDensityScale;
}

// ── Brain density: neural filaments, branching synaptic knots ─────────────────
// Physical analog: cosmic web filaments of molecular gas; dense clumps at nodes.
float brainDensity(vec3 p, float t) {
    float env  = pow(max(0.0, 1.0 - dot(p,p)*0.22), 1.2);

    // High-contrast filamentary FBM — emphasize ridges
    float n1 = fbm(p * uTurbulence * 1.2 + vec3(t*0.02, 0, 0), uTurbulence);
    float n2 = fbm(p * uTurbulence * 2.4 + vec3(0, t*0.015, 0), uTurbulence + 0.3);
    float ridge = abs(n1 - 0.5) * 2.0;   // sharp ridges where fbm = 0.5
    float fila  = exp(-ridge * ridge * 20.0) * 0.7;

    // Synaptic nodes: bright dense points at filament intersections
    float synapse = 0.0;
    for (int i = 0; i < 8; i++) {
        vec3 seed = hash3(vec3(float(i)*17.3, float(i)*6.1, float(i)*9.7));
        vec3 pos  = (seed * 2.0 - 1.0) * 1.2;
        float d   = length(p - pos);
        // Synaptic "firing": occasional bright pulses
        float fire = step(0.97, hash3(vec3(float(i), t*uEvolutionSpeed*2.0, 0.0)).x);
        synapse += (exp(-d*d*15.0) * 0.8 + exp(-d*d*60.0) * fire * 2.0);
    }

    float base = max(0.0, n2 - 0.38) * env;
    return (base + fila * env * 0.5 + synapse * 0.3) * uDensityScale;
}

// ── Womb density: amniotic gas + Bok globule embryos ─────────────────────────
// Physical analog: dense molecular clumps (Bok globules) gestating protostars.
// The surrounding gas is the "amniotic fluid" — warm, ionized, transparent.
float wombDensity(vec3 p, float t) {
    float env  = pow(max(0.0, 1.0 - dot(p,p)*0.18), 1.0);

    // Amniotic gas: warm diffuse envelope
    float amniotic = fbm(p * uTurbulence * 0.7 + vec3(t*0.02, t*0.01, 0), uTurbulence);
    float gas = max(0.0, amniotic - 0.32) * env * 0.6;

    // Bok globule eggs: dense dark spheres at random positions
    float eggs = 0.0;
    for (int i = 0; i < 5; i++) {
        vec3 seed = hash3(vec3(float(i)*23.1, float(i)*8.7, float(i)*5.3));
        vec3 pos  = (seed * 2.0 - 1.0) * 1.0;
        float phase = clamp(t * uEvolutionSpeed * 0.03, 0.0, 1.0);
        float r = mix(0.18, 0.06, phase * phase);  // collapsing over time
        float d = length(p - pos);
        // Dense Bok globule
        eggs += exp(-d*d / (r*r)) * 2.5 * mix(1.0, 0.3, phase);
        // Inner protostar forming: bright core when collapsed
        float protostar = exp(-d*d * 200.0) * phase * 3.0;
        eggs += protostar;
    }

    return (gas + eggs) * uDensityScale;
}

// ── Corpse density: supernova remnant as exploded organ ───────────────────────
// Physical analog: Cassiopeia A, Crab Nebula interior.
// Shredded structure, radial filaments, clumped "organ" remnants.
float corpseDensity(vec3 p, float t) {
    float r  = length(p);
    float age = mix(2.0, 6.0, clamp(t * uEvolutionSpeed * 0.05, 0.0, 1.0));

    // Expanding shell radius (Sedov-Taylor: r ∝ t^0.4)
    float rShell = 0.3 + 0.7 * pow(clamp(age / 6.0, 0.0, 1.0), 0.4);
    vec3  dir    = p / max(r, 0.001);

    // Rayleigh-Taylor fingers: wrinkle the shell
    float rt = fbm(dir * 4.0, uTurbulence * 1.5) * 0.2;
    float shell = exp(-pow(r - rShell - rt, 2.0) / (0.015));

    // Interior: shredded "organs" — dense clumps of ejecta
    float clumps = 0.0;
    for (int i = 0; i < 7; i++) {
        vec3 seed = hash3(vec3(float(i)*11.7, float(i)*4.3, float(i)*8.9));
        // Ejecta moves outward with time
        vec3 pos  = normalize(seed * 2.0 - 1.0) * rShell * (0.3 + seed.z * 0.5);
        float cr  = 0.05 + seed.x * 0.1;
        clumps   += exp(-dot(p-pos, p-pos) / (cr*cr)) * 1.5;
    }

    // Hot thin interior glow (pulsar wind / synchrotron)
    float interior = (1.0 - smoothstep(0.0, rShell - 0.1, r)) * 0.15;

    return (shell * 1.8 + clumps + interior) * uDensityScale;
}

// ── Combined bio density ──────────────────────────────────────────────────────
float bioPhase(float t) {
    // Each mode lasts 10 seconds, transitions over 2s
    return mod(t * mix(0.05, 0.3, uEvolutionSpeed), 4.0);
}

float nebulaDensity(vec3 p, float t, float mode) {
    float f0 = clamp(1.0 - abs(mode - 0.5), 0.0, 1.0);   // lungs  0–1
    float f1 = clamp(1.0 - abs(mode - 1.5), 0.0, 1.0);   // brain  1–2
    float f2 = clamp(1.0 - abs(mode - 2.5), 0.0, 1.0);   // womb   2–3
    float f3 = clamp(1.0 - abs(mode - 3.5), 0.0, 1.0);   // corpse 3–4
    return f0*lungDensity(p,t) + f1*brainDensity(p,t) + f2*wombDensity(p,t) + f3*corpseDensity(p,t);
}

// ── Emission color by mode ────────────────────────────────────────────────────
vec3 lungColor    = vec3(0.90, 0.50, 0.40);   // warm pink-red: oxygenated tissue
vec3 brainColor   = vec3(0.40, 0.70, 0.90);   // electric blue-white: neural activity
vec3 brainSynapse = vec3(1.00, 0.95, 0.60);   // gold synapse flash
vec3 wombColor    = vec3(0.70, 0.30, 0.60);   // deep rose-violet: amniotic
vec3 embryoColor  = vec3(1.00, 0.80, 0.40);   // warm amber: protostar embryo
vec3 corpseColor  = vec3(0.80, 0.20, 0.10);   // arterial red: scattered ejecta
vec3 corpseSynch  = vec3(0.50, 0.20, 0.90);   // synchrotron purple interior

vec3 emitColor(vec3 p, float density, float t, float mode) {
    float f0 = clamp(1.0 - abs(mode - 0.5), 0.0, 1.0);
    float f1 = clamp(1.0 - abs(mode - 1.5), 0.0, 1.0);
    float f2 = clamp(1.0 - abs(mode - 2.5), 0.0, 1.0);
    float f3 = clamp(1.0 - abs(mode - 3.5), 0.0, 1.0);

    // Per-mode color mix
    float r = length(p);
    vec3 lung  = mix(lungColor, vec3(0.6, 0.15, 0.1), clamp(r*0.5, 0.0, 1.0));
    vec3 brain = mix(brainColor, brainSynapse, clamp(fbm(p*5.0+t*0.1, uTurbulence)-0.4,0.0,1.0)*2.0);
    vec3 womb  = mix(wombColor, embryoColor, clamp(density*0.3, 0.0, 1.0));
    vec3 corpse= mix(corpseColor, corpseSynch, clamp(1.0 - r*1.5, 0.0, 1.0));

    vec3 c = f0*lung + f1*brain + f2*womb + f3*corpse;
    return c * density * uEmission;
}

// ── Raymarcher ────────────────────────────────────────────────────────────────
const int   STEPS   = 88;
const float STEP_SZ = 0.05;

vec3 raymarch(vec3 ro, vec3 rd, float t, float mode) {
    vec3  color = vec3(0.0);
    float trans = 1.0;
    for (int i = 0; i < STEPS; i++) {
        vec3  p = ro + rd * (float(i)*STEP_SZ);
        float d = nebulaDensity(p, t, mode);
        if (d > 0.001) {
            color += trans * emitColor(p, d, t, mode) * STEP_SZ;
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
    vec2 uv   = (gl_FragCoord.xy - uResolution*0.5) / uResolution.y;
    float mode = bioPhase(uTime);
    float a   = uTime * 0.05;
    vec3 eye  = vec3(cos(a)*4.2, 0.8 + sin(uTime*0.11)*0.4, sin(a)*4.2);
    mat3 cam  = lookAt(eye, vec3(0.0));
    vec3 rd   = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd, uTime, mode);
    color = color / (color + 1.0);
    color = pow(color, vec3(1.0/2.2));
    gl_FragColor = vec4(color, 1.0);
}
