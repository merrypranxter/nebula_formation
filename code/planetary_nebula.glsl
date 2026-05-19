// planetary_nebula.glsl
// A dying star's last exhale — concentric shells of ionized gas.
//
// Physical model:
//   - Elliptical/bipolar morphology: most PNe are not spherical.
//     Caused by binary star interaction or magnetic collimation.
//   - Multiple nested shells: fast wind (recent) + slow wind (AGB phase)
//   - Hot central star (T* ~ 50,000–200,000 K): white dwarf in formation
//     Emits He II 468 nm (blue), O III 501 nm (teal), H-alpha (red outer)
//   - Inner region: [O III] dominant (hotter, higher ionization)
//   - Outer region: H-alpha + [N II] (cooler recombination zone)
//   - Halo: very faint AGB mass-loss halo, enormous extent
//
// Real-world analogs:
//   - Helix Nebula (NGC 7293): "Eye of God" — ring structure, cometary knots
//   - Ring Nebula (M57): classic textbook ring
//   - Butterfly Nebula (NGC 6302): violent bipolar, hot white dwarf (T* > 200,000 K)
//   - Cat's Eye Nebula (NGC 6543): complex nested concentric shells + jets
//
// Parameters:
//   uBipolarStrength: [0,1] — 0=spherical, 1=fully bipolar (butterfly)
//   uShellCount:      [1,4] — number of nested shells visible
//   uTemperatureRange: drives He II / O III / H-alpha intensity ratios

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
uniform float uTemperatureRange;   // 10000–200000 K central star temperature

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
    for(int i=0;i<5;i++){ v+=a*valueNoise(p*freq); a*=0.5; freq*=2.1+t*0.05; p+=vec3(1.7,9.2,3.4); }
    return v;
}

// ── Bipolar geometry ──────────────────────────────────────────────────────────
// Ellipsoidal shells elongated along the polar axis (y).
// bipolarStrength → 0: sphere; → 1: narrow butterfly pinch
float shellRadius_polar(vec3 dir, float equatorialRadius, float bipolar) {
    // Polar-equatorial axis ratio: equatorial is pinched, polar is expanded
    // lat = angle from equatorial plane
    float lat     = abs(dir.y);
    float squeeze = mix(1.0, 0.3, bipolar);   // equatorial squeeze factor
    float r_eq    = equatorialRadius;
    float r_pol   = equatorialRadius / squeeze;
    // Ellipsoid: (x/a)² + (y/b)² = 1
    // For a ray in direction dir, solve for radius:
    float a2 = r_eq * r_eq;
    float b2 = r_pol * r_pol;
    float dxy2 = dir.x*dir.x + dir.z*dir.z;
    float dy2  = dir.y * dir.y;
    // r² ( dxy²/a² + dy²/b² ) = 1
    float denom = dxy2 / a2 + dy2 / b2;
    return denom > 0.0 ? 1.0 / sqrt(denom) : r_eq;
}

// ── Cometary knots (Helix-style) ──────────────────────────────────────────────
// Small dense radial knots at the inner edge of the main shell.
float cometaryKnots(vec3 p) {
    float knots = 0.0;
    for (int i = 0; i < 12; i++) {
        vec3 seed = hash3(vec3(float(i)*7.3, float(i)*11.1, float(i)*4.7));
        vec3 dir  = normalize(seed * 2.0 - 1.0);
        vec3 kpos = dir * 0.75;   // placed at main ring radius
        float d   = length(p - kpos);
        // Teardrop shape: dense head, fainter tail pointing outward
        vec3  toCenter = normalize(-kpos);
        float head  = exp(-d*d * 80.0);
        float tail  = exp(-length(p - kpos - toCenter*0.25) * 6.0) * 0.3;
        knots += head + tail;
    }
    return knots;
}

// ── Multi-shell density ───────────────────────────────────────────────────────
float nebulaDensity(vec3 p) {
    float r    = length(p);
    if (r < 0.001) return 0.0;
    vec3  dir  = p / r;

    float bipolar = 0.5;   // mid-range: slightly bipolar like most real PNe

    // Shell parameters (inner to outer):
    // Main bright ring + fainter outer shells + inner hot torus
    float total = 0.0;

    // 1. Inner hot torus (fast wind from final AGB or post-AGB)
    float r1 = shellRadius_polar(dir, 0.30, bipolar * 0.7);
    float t1 = exp(-pow(r - r1, 2.0) / (0.012)) * 1.6;
    total += t1;

    // 2. Main shell (primary nebula, compressed swept-up AGB wind)
    float r2 = shellRadius_polar(dir, 0.65, bipolar);
    float pert2 = fbm(dir * 3.0, uTurbulence) * 0.06;
    float t2 = exp(-pow(r - r2 - pert2, 2.0) / (0.018)) * 2.0;
    total += t2;

    // 3. Halo shell (old AGB mass loss, 2–5× outer radius)
    float r3 = shellRadius_polar(dir, 1.20, bipolar * 0.4);
    float pert3 = fbm(dir * 1.5, uTurbulence) * 0.08;
    float t3 = exp(-pow(r - r3 - pert3, 2.0) / (0.030)) * 0.6;
    total += t3;

    // 4. Cometary knots
    total += cometaryKnots(p) * 0.4;

    return total * uDensityScale;
}

// ── Emission color: ionization zone-dependent ─────────────────────────────────
// Physical stratification (ionization parameter U decreases outward):
//   Inner: He II (T* > 50kK), highest ionization
//   Middle: O III (teal), O II
//   Outer ring: H-alpha red
//   Halo: very faint H-alpha

vec3 emitColor(vec3 p, float density) {
    float r = length(p);
    float tempNorm = clamp((uTemperatureRange - 10000.0) / 190000.0, 0.0, 1.0);

    // Inner torus: blue-violet (He II / hot continuum)
    vec3 innerCol = mix(vec3(0.15, 0.45, 0.90), vec3(0.40, 0.15, 0.85), tempNorm);

    // Main shell: teal [O III] with H-alpha red at outer edge
    float shellFrac = smoothstep(0.25, 0.70, r);
    vec3  oiiiCol   = vec3(0.05, 0.85, 0.72);    // [O III] teal
    vec3  halphaCol = vec3(0.90, 0.12, 0.10);    // H-alpha red

    // O III peaks at intermediate radius; H-alpha peaks at outer edge
    float oiiiFrac  = smoothstep(0.15, 0.50, r) * (1.0 - smoothstep(0.60, 0.80, r));
    float halFrac   = smoothstep(0.50, 0.75, r) * (1.0 - smoothstep(0.95, 1.25, r));

    vec3 col = innerCol * (1.0 - smoothstep(0.20, 0.35, r))
             + oiiiCol * oiiiFrac * (0.6 + tempNorm * 0.8)
             + halphaCol * halFrac;

    // Cometary knot heads: dense, neutral, partially shielded → red-orange [O I]
    float knotDens = cometaryKnots(p);
    col = mix(col, vec3(0.95, 0.35, 0.05), clamp(knotDens*0.3, 0.0, 0.6));

    return col * density * uEmission;
}

// ── Raymarcher ────────────────────────────────────────────────────────────────
const int   STEPS   = 96;
const float STEP_SZ = 0.04;

vec3 raymarch(vec3 ro, vec3 rd) {
    vec3  color = vec3(0.0);
    float trans = 1.0;

    for (int i = 0; i < STEPS; i++) {
        vec3  p = ro + rd * (float(i)*STEP_SZ);
        float d = nebulaDensity(p);
        if (d > 0.001) {
            color += trans * emitColor(p, d) * STEP_SZ;
            trans *= exp(-d * uDustOpacity * STEP_SZ * 0.2);  // PNe have low dust
        }
        if (trans < 0.01) break;
    }

    // Central white dwarf: hot blue point
    vec3  toWD  = -ro;
    float tHit  = dot(toWD, rd);
    if (tHit > 0.0) {
        vec3  closest = ro + rd*tHit;
        float r2 = dot(closest, closest);
        // Color depends on T*: very hot → blue-white; cooler → yellow-white
        float tNorm = clamp((uTemperatureRange - 10000.0) / 190000.0, 0.0, 1.0);
        vec3 wdColor = mix(vec3(1.0, 0.95, 0.7), vec3(0.7, 0.85, 1.0), tNorm);
        color += wdColor * exp(-r2 * 8000.0) * 4.0 * trans;
    }

    return color;
}

mat3 lookAt(vec3 eye, vec3 target) {
    vec3 z=normalize(eye-target), x=normalize(cross(vec3(0,1,0),z)), y=cross(z,x);
    return mat3(x,y,z);
}

void main() {
    vec2 uv  = (gl_FragCoord.xy - uResolution*0.5) / uResolution.y;
    // Slow tilt to reveal the bipolar lobes
    float a   = uTime * 0.05;
    float tilt = sin(uTime * 0.07) * 0.4;
    vec3 eye  = vec3(cos(a)*3.5, sin(tilt)*1.5 + 0.5, sin(a)*3.5);
    mat3 cam  = lookAt(eye, vec3(0.0));
    vec3 rd   = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd);
    color = color / (color + 1.0);
    color = pow(color, vec3(1.0/2.2));
    gl_FragColor = vec4(color, 1.0);
}
