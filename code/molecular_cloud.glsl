// molecular_cloud.glsl
// The cold dark womb before the star. The beginning before the beginning.
//
// Physical model:
//   - Temperature: 10–30 K (molecule emission in microwave/radio, invisible optically)
//   - Visual appearance: opaque silhouette + self-luminous only at far-infrared
//     In optical: dark. We show the cloud outlined by background stellar/ionized light.
//   - Filamentary structure: the most striking feature of modern molecular cloud
//     observations (Herschel: ALL molecular clouds are filamentary)
//   - Filament width: ~0.1 pc (roughly constant — physical origin debated)
//   - Dense cores: embedded at filament intersections ("hubs and filaments" model)
//   - Tracer: CO emission (cold molecular gas) → we use olive-green for CO
//   - FIR dust emission: warm (~30K) grains glow in far-IR → orange-yellow when visible
//   - Self-gravity: filaments collapse preferentially along their length
//     (Jeans mass along filament << filament mass → bead-on-a-string fragmentation)
//
// Real-world analogs:
//   - Taurus molecular cloud: nearest (140 pc), classic striated filaments
//   - Rho Ophiuchi: active star formation, dense cores
//   - IC 5146 (Cocoon Nebula filaments): textbook Herschel filamentary view
//   - Perseus molecular cloud: multiple embedded star-forming clumps
//
// Rendering mode:
//   We render the cloud in "false-color molecular emission" mode:
//   CO J=1→0 line (2.6mm, microwave) → mapped to olive-green
//   Dust FIR (250–500 μm) → mapped to orange-amber
//   Dense core (N(H2) > 10^22 cm^-2) → deep red (about to form a star)

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

// Kolmogorov FBM: persistence = 0.63 (H=1/3), not standard 0.5
// This gives the correct power spectrum for supersonic turbulence.
float fbmKolmogorov(vec3 p, int octaves) {
    float v=0.0, a=1.0, freq=1.0, norm=0.0;
    for(int i=0;i<8;i++){
        if(i>=octaves) break;
        v    += a * valueNoise(p*freq);
        norm += a;
        a    *= 0.63;   // Kolmogorov: amplitude ∝ k^(-5/6) per octave
                         // 2^(-2/3) ≈ 0.630 (H=1/3 Kolmogorov Hurst exponent)
        freq *= 2.0;
        p    += vec3(1.7, 9.2, 3.4);
    }
    return v / norm;
}

// ── Filamentary structure ─────────────────────────────────────────────────────
// Filaments emerge from the velocity field: material flows along magnetic field lines
// into overdense ridges. We approximate them as sharp ridges of an FBM.
float filamentDensity(vec3 p) {
    // Warp space slightly to create elongated structures
    vec3 pw = p + vec3(
        fbmKolmogorov(p * 0.5 + vec3(10.1, 5.3, 2.7), 3) * 0.3,
        fbmKolmogorov(p * 0.5 + vec3(3.3, 8.7, 4.1), 3) * 0.3,
        fbmKolmogorov(p * 0.5 + vec3(6.7, 1.9, 9.3), 3) * 0.3
    );

    // Ridgeline FBM: take the magnitude of the gradient → sharp ridges
    float f1 = fbmKolmogorov(pw * uTurbulence, 6);
    float f2 = fbmKolmogorov(pw * uTurbulence + vec3(1.7,9.2,3.4), 6);

    // Sharp ridges appear where two FBM values cross → filaments
    float ridge = 1.0 - abs(f1 - f2) * 2.5;
    ridge = max(0.0, ridge);
    ridge = pow(ridge, 3.0);   // sharpen

    return ridge;
}

// ── Dense core density (at filament intersections) ────────────────────────────
float coreDensity(vec3 p) {
    float cores = 0.0;
    // 6 dense cores at quasi-random positions within the cloud
    for (int i = 0; i < 6; i++) {
        vec3 seed = hash3(vec3(float(i)*13.7, float(i)*5.1, float(i)*9.3));
        vec3 pos  = (seed * 2.0 - 1.0) * 1.1;
        float r   = 0.08 + seed.x * 0.06;

        // Core contracts slowly (Jeans collapse)
        float t = uTime * uEvolutionSpeed * 0.01;
        float contractFactor = max(0.5, 1.0 - t * 0.1);
        float d = length(p - pos) / (r * contractFactor);

        // Dense core profile: Plummer-like: ρ ∝ (1 + (r/r0)²)^(-5/2)
        cores += 1.0 / pow(1.0 + d*d, 2.5) * 1.5;
    }
    return cores;
}

// ── Broad cloud envelope ──────────────────────────────────────────────────────
float cloudEnvelope(vec3 p) {
    float env  = pow(max(0.0, 1.0 - dot(p,p)*0.18), 1.1);
    float base = fbmKolmogorov(p * uTurbulence * 0.6, 4);
    return max(0.0, base - 0.28) * env;
}

// ── Combined density ──────────────────────────────────────────────────────────
float nebulaDensity(vec3 p) {
    float env   = cloudEnvelope(p);
    float fila  = filamentDensity(p) * pow(max(0.0, 1.0 - dot(p,p)*0.2), 1.0);
    float cores = coreDensity(p) * pow(max(0.0, 1.0 - dot(p,p)*0.25), 1.2);
    return (env + fila * 1.2 + cores) * uDensityScale;
}

// ── Column density proxy (for color mapping) ──────────────────────────────────
// In real observations: column density N(H2) traced by dust FIR emission.
// High N → orange/red (warm dense core); moderate N → green (CO envelope)
float columnProxy(vec3 p) {
    // Sum density along a short path segment for local column density proxy
    float n = 0.0;
    for (int i = -2; i <= 2; i++) {
        n += nebulaDensity(p + float(i)*vec3(0,0,0.1));
    }
    return n * 0.2;
}

// ── Emission color (false-color molecular emission) ───────────────────────────
// False-color key (following Herschel convention):
//   Cold diffuse envelope (CO J=1→0): olive-green/teal
//   Warm dense filaments (dust 160μm): orange
//   Very dense cores (250μm / N2H+): deep red → protostellar birth orange
vec3 emitColor(vec3 p, float density) {
    float col = clamp(columnProxy(p), 0.0, 1.0);
    float coreAmt = clamp(coreDensity(p) * 0.5, 0.0, 1.0);
    float filaAmt = clamp(filamentDensity(p), 0.0, 1.0);

    // Cold diffuse CO: olive teal
    vec3 coColor   = vec3(0.25, 0.55, 0.30);
    // Warm filament dust: orange
    vec3 filaColor = vec3(0.80, 0.45, 0.10);
    // Dense core: deep red (prestellar) → warm amber (protostellar)
    float t = uTime * uEvolutionSpeed * 0.02;
    vec3 coreColor = mix(vec3(0.65, 0.10, 0.10), vec3(1.00, 0.60, 0.10),
                         clamp(t, 0.0, 1.0));

    vec3 col3 = mix(coColor, filaColor, filaAmt);
    col3 = mix(col3, coreColor, coreAmt);

    return col3 * density * uEmission;
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
    // Very slow rotation: molecular clouds move slowly
    float a  = uTime * 0.04;
    vec3 eye = vec3(cos(a)*4.0, 0.8, sin(a)*4.0);
    mat3 cam = lookAt(eye, vec3(0.0));
    vec3 rd  = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd);

    // Slight amber/olive tint to the background — the diffuse CO emission field
    color += vec3(0.03, 0.04, 0.01) * (1.0 - dot(color, vec3(0.299, 0.587, 0.114)));

    color = color / (color + 1.0);
    color = pow(color, vec3(1.0/2.2));
    gl_FragColor = vec4(color, 1.0);
}
