// bipolar_nebula.glsl
// Herbig-Haro jets and bipolar outflow nebula.
// The birth scream of a star: supersonic jets punching through the parent cloud.
//
// Physical model:
//   - Central protostar (Class I/II YSO): embedded in dense envelope
//   - Bipolar jets: collimated supersonic flows (v ~ 100–500 km/s)
//     ejected along rotation axis of the accretion disk
//   - Herbig-Haro objects: dense knots of shocked gas where jet hits ISM
//     HH objects glow in H-alpha, [O I], [S II] (shock diagnostics)
//   - Outflow lobes: swept-up molecular gas, cavity walls
//   - Accretion disk shadow: dark cone-shaped shadow in the outflow lobes
//
// Real-world analogs:
//   - HH 30 (Taurus): textbook bipolar jet with visible disk edge-on
//   - L1551 IRS5: class I protostar with prominent bipolar outflow
//   - HH 211: very young protostar, pristine jet structure
//   - Butterfly Nebula (HH24 complex): multiple jets in one region
//
// The aesthetics: two cones of ionized gas punching outward from a hidden star,
// the jet knots like beads on a string, the cavity walls glowing with
// scattered protostellar light.

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
uniform float uEvolutionSpeed;   // jet propagation speed

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
    for(int i=0;i<5;i++){ v+=a*valueNoise(p*freq); a*=0.5; freq*=2.0+t*0.1; p+=vec3(1.7,9.2,3.4); }
    return v;
}

// ── Jet axis (tilted slightly from y-axis for interest) ───────────────────────
vec3 jetAxis = normalize(vec3(0.15, 1.0, 0.05));

// ── Jet beam density ──────────────────────────────────────────────────────────
// The jet is a thin column of shocked ionized gas.
// Width increases with distance from source (jet entrains material).
// Side: along the jet axis direction (positive/negative = two lobes).
float jetBeam(vec3 p, float t, float side) {
    float along = dot(p, jetAxis) * side;    // positive = this lobe
    if (along < 0.0) return 0.0;

    // Jet propagates outward with time
    float maxReach = 1.0 + t * uEvolutionSpeed * 0.4;
    if (along > maxReach) return 0.0;

    // Jet opening angle: ~5–10° for real HH jets
    float perpDist = length(p - along * jetAxis);
    float radius   = 0.04 + along * 0.03;   // slight opening
    float beam = exp(-perpDist*perpDist/(radius*radius));

    // Jet brightness: decreases with distance (spreading + energy loss)
    float distFade = exp(-along * 0.3);

    // Internal knot structure: Kelvin-Helmholtz instability → periodic brightening
    float knots = 0.5 + 0.5 * sin(along * 8.0 - t * uEvolutionSpeed * 3.0);
    knots = smoothstep(0.3, 0.7, knots);    // sharp bright knots

    return beam * distFade * (0.5 + knots * 0.8) * uDensityScale;
}

// ── Herbig-Haro terminal bow shock ────────────────────────────────────────────
// Where the jet hits the ambient cloud: a bow shock.
// Bowl-shaped, bright, glows in [O I] and H-alpha (low-velocity shock).
float hhBowShock(vec3 p, float t, float side) {
    float along = dot(p, jetAxis) * side;
    float reach = 0.8 + t * uEvolutionSpeed * 0.35;   // shock propagates outward

    // Bow shock center
    vec3 shockCenter = jetAxis * reach * side;
    vec3 rel = p - shockCenter;

    // Bowl shape: parabolic surface opening upstream
    float perpDist = length(rel - dot(rel, jetAxis)*jetAxis);
    float axialDist = dot(rel, jetAxis) * side;   // positive = downstream
    float paraboloid = perpDist*perpDist - axialDist * 0.5;

    float shockSurf = exp(-paraboloid*paraboloid * 50.0);
    float upstreamOnly = step(-0.1, -axialDist);   // upstream bowl
    return shockSurf * upstreamOnly * 0.8 * uDensityScale;
}

// ── Outflow cavity walls ──────────────────────────────────────────────────────
// The jet sweeps out a cone-shaped cavity in the parent envelope.
// The cavity walls glow in scattered protostellar light and H-alpha.
float cavityWall(vec3 p) {
    float along = abs(dot(p, jetAxis));
    float perpDist = length(p - along * jetAxis * sign(dot(p, jetAxis)));

    // Cavity opening angle ~30–40°
    float halfAngle = 0.55;   // radians
    float coneRadius = along * tan(halfAngle);

    // Dense cavity wall: ring around the cone surface
    float wall = exp(-pow(perpDist - coneRadius, 2.0) / (0.08 * 0.08));

    // Limit to inside the parent envelope
    float envFade = exp(-dot(p,p) * 0.25);

    // Texture: molecular gas clumps on cavity wall
    float clumps = fbm(p * uTurbulence * 2.0, uTurbulence) * 0.3;

    return (wall + clumps * wall * 0.5) * envFade * uDensityScale * 0.4;
}

// ── Dense envelope (the molecular cloud the protostar is embedded in) ─────────
float envelope(vec3 p) {
    float r   = length(p);
    float env = exp(-r*r*0.5);   // concentrated at center
    float base = fbm(p * uTurbulence * 1.5, uTurbulence);

    // Shadow cone: the disk blocks light in equatorial direction
    float equatorial = abs(dot(p, jetAxis));
    float diskShadow = 1.0 - exp(-equatorial*equatorial * 20.0); // dark at equator

    return max(0.0, base - 0.38) * env * diskShadow * uDensityScale * 0.6;
}

// ── Combined density ──────────────────────────────────────────────────────────
float nebulaDensity(vec3 p, float t) {
    float d = envelope(p);
    d += jetBeam(p, t, 1.0);     // upper jet lobe
    d += jetBeam(p, t, -1.0);    // lower jet lobe
    d += hhBowShock(p, t, 1.0);
    d += hhBowShock(p, t, -1.0);
    d += cavityWall(p);
    return d;
}

// ── Emission color ────────────────────────────────────────────────────────────
vec3 emitColor(vec3 p, float density, float t) {
    float along = dot(p, jetAxis);

    // Jet beam: bright blue-white + H-alpha (fast shock, high ionization)
    float j1  = jetBeam(p, t, 1.0) + jetBeam(p, t, -1.0);
    vec3  jCol = mix(vec3(0.7, 0.85, 1.0), vec3(0.9, 0.2, 0.15), 0.3);  // blue-white jet + H-alpha

    // HH bow shocks: H-alpha dominant + [O I] + [S II] (lower ionization at flanks)
    float hs  = hhBowShock(p, t, 1.0) + hhBowShock(p, t, -1.0);
    vec3  hCol = mix(vec3(0.85, 0.12, 0.08), vec3(0.80, 0.30, 0.05), 0.5);  // H-alpha + [O I]

    // Cavity walls: warm scattered protostellar light (near-IR + red)
    float cw  = cavityWall(p);
    vec3  cCol = vec3(0.70, 0.40, 0.15);   // warm orange-red: heated dust + scattered light

    // Envelope: cold molecular gas, very little optical emission
    // But the PDR at the cavity surface glows faintly in H2 fluorescence → olive-gold
    float env = envelope(p);
    vec3  eCol = vec3(0.40, 0.35, 0.10);

    // Normalize contributions
    float total = j1 + hs + cw + env + 0.001;
    vec3  col   = (j1*jCol + hs*hCol + cw*cCol + env*eCol) / total;

    return col * density * uEmission;
}

// ── Raymarcher ────────────────────────────────────────────────────────────────
const int   STEPS   = 96;
const float STEP_SZ = 0.045;

vec3 raymarch(vec3 ro, vec3 rd, float t) {
    vec3  color = vec3(0.0);
    float trans = 1.0;
    for (int i = 0; i < STEPS; i++) {
        vec3  p = ro + rd * (float(i)*STEP_SZ);
        float d = nebulaDensity(p, t);
        if (d > 0.001) {
            color += trans * emitColor(p, d, t) * STEP_SZ;
            trans *= exp(-d * uDustOpacity * STEP_SZ);
        }
        if (trans < 0.01) break;
    }

    // Central protostar glow (embedded, reddened)
    vec3  toPS = -ro;
    float tHit = dot(toPS, rd);
    if (tHit > 0.0) {
        vec3  cp = ro + rd*tHit;
        float r2 = dot(cp, cp);
        // Protostar: warm orange-red (reddened by dust envelope)
        color += vec3(0.9, 0.4, 0.1) * exp(-r2 * 2000.0) * trans * 1.5;
    }

    return color;
}

mat3 lookAt(vec3 eye, vec3 target) {
    vec3 z=normalize(eye-target), x=normalize(cross(vec3(0,1,0),z)), y=cross(z,x);
    return mat3(x,y,z);
}

void main() {
    vec2 uv  = (gl_FragCoord.xy - uResolution*0.5) / uResolution.y;
    float t  = uTime * mix(0.1, 1.0, uEvolutionSpeed);
    // Slight tilt to see both jet lobes and disk geometry
    float a  = uTime * 0.05;
    vec3 eye = vec3(cos(a)*3.5, 0.3 + sin(uTime*0.06)*0.5, sin(a)*3.5);
    mat3 cam = lookAt(eye, vec3(0.0));
    vec3 rd  = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd, t);
    color = color / (color + 1.0);
    color = pow(color, vec3(1.0/2.2));
    gl_FragColor = vec4(color, 1.0);
}
