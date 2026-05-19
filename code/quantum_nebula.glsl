// quantum_nebula.glsl
// Nebula physics replaced by quantum mechanics.
// This is not a simulation of quantum cosmology — it is quantum *aesthetics*
// applied to a volumetric gas cloud.
//
// Quantum phenomena modelled:
//   1. SUPERPOSITION: gas exists in multiple density states simultaneously.
//      Observing (looking directly) collapses to a definite value.
//      Here: density function is a weighted sum of incompatible eigenstates.
//
//   2. TUNNELING: stars appear through/inside dense gas where classical
//      transmission would be zero. Exponential evanescent wave penetration.
//
//   3. ENTANGLEMENT: pairs of distant gas clumps are correlated.
//      When one flickers, the other responds instantaneously.
//      Implemented as anti-correlated density fluctuations.
//
//   4. UNCERTAINTY: the more precisely the shader knows a clump's position
//      (high-frequency detail), the less it knows its momentum (color).
//      Implemented via a Heisenberg blur on the color-density relationship.
//
//   5. WAVE FUNCTION COLLAPSE: the nebula is rendered as a continuous
//      probability cloud that "collapses" in bands across the frame
//      — the act of rendering is the measurement.
//
// The physics is invented. The aesthetics are real.

#ifdef GL_ES
precision highp float;
#endif

#define PI 3.14159265358979
#define HBAR 0.05    // effective reduced Planck constant (aesthetic parameter)

uniform vec2  uResolution;
uniform float uTime;
uniform float uDensityScale;
uniform float uTurbulence;
uniform float uEmission;
uniform float uDustOpacity;
uniform float uEvolutionSpeed;   // controls "observation rate" / collapse frequency

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

// ── Quantum wave functions: multiple eigenstates ───────────────────────────────
// Each eigenstate is a different spatial mode of the gas.
// They coexist until observation collapses to one.

// Eigenstate 1: smooth diffuse cloud (ground state — most probable)
float psi1(vec3 p, float t) {
    float env = pow(max(0.0, 1.0-dot(p,p)*0.22), 1.3);
    float base = fbm(p * uTurbulence * 0.8 + vec3(0,0,t*0.02), uTurbulence);
    return max(0.0, base - 0.32) * env;
}

// Eigenstate 2: high-frequency filamentary mode (1st excited state)
float psi2(vec3 p, float t) {
    float env = pow(max(0.0, 1.0-dot(p,p)*0.18), 0.9);
    float base = fbm(p * uTurbulence * 2.5 + vec3(t*0.05, 0, 0), uTurbulence);
    float ridge = abs(base - 0.5) * 2.0;   // emphasize sharp ridges
    return (1.0 - ridge) * env * 0.7;
}

// Eigenstate 3: shell-like mode (2nd excited state — breathing mode)
float psi3(vec3 p, float t) {
    float r = length(p);
    float phase = r * 3.0 - t * 0.3;  // outward travelling wave
    float wave = sin(phase * PI) * 0.5 + 0.5;   // envelope wave function
    float env = exp(-r * r * 0.4);
    return wave * env;
}

// ── Superposition: weighted sum of eigenstates ────────────────────────────────
// Coefficients evolve in time (unitary evolution in Hilbert space analog):
// |ψ⟩ = c1|ψ1⟩ + c2|ψ2⟩ + c3|ψ3⟩
// |ci|² give probabilities; coefficients rotate in complex plane.
float superposition(vec3 p, float t) {
    // Coefficients rotate at different frequencies (energy eigenvalues)
    float omega1 = 1.0, omega2 = 2.3, omega3 = 4.1;  // energy levels
    float c1 = 0.5 + 0.3 * cos(omega1 * t * uEvolutionSpeed * 0.1);
    float c2 = 0.35 + 0.2 * cos(omega2 * t * uEvolutionSpeed * 0.1);
    float c3 = 0.25 + 0.15 * cos(omega3 * t * uEvolutionSpeed * 0.1);
    float norm = c1 + c2 + c3;

    // Probability density |ψ|² = sum
    return (c1*psi1(p,t) + c2*psi2(p,t) + c3*psi3(p,t)) / norm;
}

// ── Entangled pair density ────────────────────────────────────────────────────
// Two clumps separated by vector d_entangle.
// When clump A is dense, clump B is thin (anti-correlated entanglement).
float entangledPairs(vec3 p, float t) {
    float pairs = 0.0;
    for (int i = 0; i < 4; i++) {
        vec3 seed = hash3(vec3(float(i)*17.3, float(i)*5.1, float(i)*9.7));
        vec3 posA = (seed * 2.0 - 1.0) * 1.2;
        vec3 posB = -posA * 0.8;  // entangled partner: opposite side, slightly closer

        float dA = length(p - posA);
        float dB = length(p - posB);

        // Flickering: entangled pairs correlate. When A is "measured" bright, B dims.
        float phi = hash3(vec3(float(i), t*uEvolutionSpeed*0.3, 0.0)).x * 2.0 * PI;
        float stateA = 0.5 + 0.5 * cos(phi);         // 0=dim, 1=bright
        float stateB = 1.0 - stateA;                  // anti-correlated

        float rA = 0.12 + seed.x * 0.08;
        float rB = 0.10 + seed.y * 0.07;
        pairs += exp(-dA*dA/(rA*rA)) * stateA;
        pairs += exp(-dB*dB/(rB*rB)) * stateB;
    }
    return pairs;
}

// ── Tunneling star: appears THROUGH opaque gas (quantum tunneling) ────────────
// In quantum mechanics, a particle can tunnel through a classically forbidden
// barrier with probability ∝ exp(-2κd) where κ = sqrt(2m(V-E))/ħ
// Here: star light penetrates dense gas beyond classical Beer-Lambert cutoff.
float tunnelingLight(vec3 p, vec3 ro, vec3 rd, float cloudDensity) {
    // Classical transmittance would be nearly zero for dense gas.
    // Quantum tunneling adds a small but nonzero transmission.
    float kappa = cloudDensity * 5.0 / HBAR;   // effective barrier
    float depth = length(p - ro) * 0.1;
    float tunnel = exp(-2.0 * kappa * depth * HBAR);   // evanescent wave
    return tunnel * 0.3;
}

// ── Wave function collapse: bands of definite state sweep the frame ───────────
// The "measurement" propagates across the scene at finite speed.
float collapseFactor(vec3 p, float t) {
    // Collapse wavefront propagates outward from a point
    float freq = 0.5 + uEvolutionSpeed * 2.0;
    float wavefront = sin(length(p) * 3.0 - t * freq);
    // Where wavefront > threshold: "measured" → classical density
    // Where below: quantum superposition
    return smoothstep(-0.2, 0.2, wavefront);
}

// ── Combined density ──────────────────────────────────────────────────────────
float nebulaDensity(vec3 p, float t) {
    float quantum  = superposition(p, t);
    float entangle = entangledPairs(p, t);
    float collapse = collapseFactor(p, t);

    // "Measured" (collapsed) regions: definite state = eigenstate 1 (most probable)
    float classical = psi1(p, t);

    // Interpolate between quantum superposition and classical collapse
    float d = mix(quantum, classical, collapse) + entangle * 0.4;
    return d * uDensityScale;
}

// ── Color: Heisenberg uncertainty — position vs momentum (color) ───────────────
// High-frequency (well-localized) regions → uncertain color (spectral noise)
// Low-frequency (delocalized) regions → definite color (pure H-alpha)
vec3 emitColor(vec3 p, float density, float t) {
    // Position certainty: how sharp is the density gradient here?
    float dpdx = abs(nebulaDensity(p+vec3(0.05,0,0),t) - nebulaDensity(p-vec3(0.05,0,0),t));
    float dpdy = abs(nebulaDensity(p+vec3(0,0.05,0),t) - nebulaDensity(p-vec3(0,0.05,0),t));
    float dpdz = abs(nebulaDensity(p+vec3(0,0,0.05),t) - nebulaDensity(p-vec3(0,0,0.05),t));
    float gradMag = length(vec3(dpdx, dpdy, dpdz));  // "position certainty"

    // Heisenberg: position certain → color uncertain (spectrally noisy / rainbow)
    float deltaP = gradMag * 10.0;   // position certainty
    float deltaC = HBAR / max(deltaP, HBAR);  // color uncertainty

    // Base color: quantum probability cloud → blue-violet (probability = potential)
    vec3 baseCol = vec3(0.20, 0.10, 0.85);    // probability density: deep blue

    // Entanglement correlation: anti-correlated pairs glow in complementary colors
    float ent = entangledPairs(p, t);
    vec3 entColor = vec3(0.90, 0.10, 0.60);   // magenta: entangled ghost

    // Tunneling: faint eerie glow in classically forbidden zones
    vec3 tunnelColor = vec3(0.10, 0.95, 0.80);  // teal: evanescent wave

    // Collapse: eigenstate colors
    float col = collapseFactor(p, t);
    vec3  classCol = vec3(0.85, 0.15, 0.10);    // H-alpha red: collapsed state

    // Uncertainty smears color:
    vec3 noise3 = hash3(p * 10.0 + t) * 2.0 - 1.0;  // quantum color noise
    vec3 uncertainColor = mix(baseCol, baseCol + noise3, clamp(deltaC, 0.0, 1.0));

    vec3 color = mix(uncertainColor, classCol, col);
    color = mix(color, entColor, clamp(ent, 0.0, 1.0));

    return color * density * uEmission;
}

// ── Raymarcher ────────────────────────────────────────────────────────────────
const int   STEPS   = 80;
const float STEP_SZ = 0.055;

vec3 raymarch(vec3 ro, vec3 rd, float t) {
    vec3  color = vec3(0.0);
    float trans = 1.0;

    for (int i = 0; i < STEPS; i++) {
        vec3  p = ro + rd * (float(i)*STEP_SZ);
        float d = nebulaDensity(p, t);

        if (d > 0.001) {
            // Quantum tunneling contribution
            float tunnel = tunnelingLight(p, ro, rd, d);
            vec3  tunnelGlow = vec3(0.05, 0.80, 0.85) * tunnel * 0.5;

            color += trans * (emitColor(p, d, t) + tunnelGlow) * STEP_SZ;

            // Absorption: slightly uncertain (smeared) — Heisenberg
            float absorp = d * uDustOpacity * STEP_SZ;
            float absUncertain = absorp * (1.0 + HBAR * valueNoise(p * 5.0));
            trans *= exp(-absUncertain);
        }
        if (trans < 0.01) break;
    }

    // "Quantum flash" stars: tunneling starlight appearing from nowhere
    for (int i = 0; i < 6; i++) {
        vec3 seed = hash3(vec3(float(i)*7.3, float(i)*3.1, 0.0));
        // Star position fluctuates (position uncertainty)
        vec3 sp   = (seed * 2.0 - 1.0) * 1.5;
        float posUncert = HBAR * 2.0;
        sp += hash3(sp + vec3(t*uEvolutionSpeed)).xyz * posUncert;

        vec3  toS  = sp - ro;
        float tHit = dot(toS, rd);
        if (tHit < 0.0) continue;
        vec3  closest = ro + rd*tHit - sp;
        float r2      = dot(closest, closest);
        // Star can be in multiple positions simultaneously (spread bloom)
        float bloom1  = exp(-r2 * 6000.0);
        float bloom2  = exp(-r2 * 200.0) * 0.1;  // delocalized ghost
        vec3  sColor  = mix(vec3(0.4, 0.7, 1.0), vec3(1.0, 0.5, 0.9), seed.z);
        color += sColor * (bloom1 + bloom2) * trans;
    }

    return color;
}

mat3 lookAt(vec3 eye, vec3 target) {
    vec3 z=normalize(eye-target), x=normalize(cross(vec3(0,1,0),z)), y=cross(z,x);
    return mat3(x,y,z);
}

void main() {
    vec2 uv   = (gl_FragCoord.xy - uResolution*0.5) / uResolution.y;
    float t   = uTime * mix(0.5, 2.0, uEvolutionSpeed);
    float a   = uTime * 0.07;
    vec3 eye  = vec3(cos(a)*4.0, 0.8, sin(a)*4.0);
    mat3 cam  = lookAt(eye, vec3(0.0));
    vec3 rd   = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd, t);

    // Slight blue bias for the whole quantum rendering — probability space is cold
    color += vec3(0.0, 0.01, 0.03);

    color = color / (color + 1.0);
    color = pow(color, vec3(1.0/2.2));
    gl_FragColor = vec4(color, 1.0);
}
