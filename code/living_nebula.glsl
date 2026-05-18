// living_nebula.glsl
// A time-evolving nebula that breathes, births stars, remembers the dead.
//
// Four temporal behaviours:
//   1. Breathing: density pulses with a long, slow heartbeat
//   2. Star birth: random ignitions that blast cavities and illuminate nearby gas
//   3. Shell echoes: fading ghost bubbles from past stellar deaths
//   4. Molecular cloud collapse: one dense clump slowly collapses over time
//
// This is the nebula as living organism. Time is the main parameter.

#ifdef GL_ES
precision highp float;
#endif

uniform vec2  uResolution;
uniform float uTime;
uniform float uDensityScale;
uniform float uTurbulence;
uniform float uEmission;
uniform float uDustOpacity;
uniform float uEvolutionSpeed;   // [0,1]  0=frozen  1=fast birth cycles

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

// ── Breathing ─────────────────────────────────────────────────────────────────
// Long 20-second breathing cycle
float breathScale(float t) {
    return 1.0 + 0.15 * sin(t * 0.31);
}

// ── Star birth event ──────────────────────────────────────────────────────────
// Each star birth punches a expanding cavity.  Returns how much to *subtract*
// from the local density (the blast evacuated material).
float starBirthCavity(vec3 p, float t, int idx) {
    vec3  seed     = hash3(vec3(float(idx) * 17.3, float(idx) * 5.9, float(idx) * 11.1));
    vec3  starPos  = (seed * 2.0 - 1.0) * 1.4;
    float birthTime = seed.x * (20.0 / max(uEvolutionSpeed, 0.01));
    float age      = t - birthTime;
    if (age < 0.0 || age > 15.0) return 0.0;

    float radius   = age * 0.07;                // expanding cavity
    float dist     = length(p - starPos);
    float fade     = 1.0 - smoothstep(10.0, 15.0, age);
    return smoothstep(radius, radius + 0.1, dist) < 1.0
           ? (1.0 - smoothstep(0.0, radius, dist)) * fade * 0.9
           : 0.0;
}

// ── Ghost shell (memory of past explosion) ───────────────────────────────────
float ghostShell(vec3 p, float t, int idx) {
    vec3  seed    = hash3(vec3(float(idx)*23.1, float(idx)*7.3, float(idx)*13.7));
    vec3  center  = (seed * 2.0 - 1.0) * 1.2;
    float birthT  = seed.y * (15.0 / max(uEvolutionSpeed, 0.01));
    float age     = t - birthT;
    if (age < 5.0 || age > 40.0) return 0.0;

    float r      = length(p - center);
    float rShell = 0.4 + (age - 5.0) * 0.04;
    float thick  = 0.06;
    float fade   = 1.0 - smoothstep(25.0, 40.0, age);
    float shell  = exp(-pow(r - rShell, 2.0) / (2.0*thick*thick));
    return shell * fade * 0.3;
}

// ── Collapsing clump ─────────────────────────────────────────────────────────
float collapsingClump(vec3 p, float t) {
    vec3  center = vec3(0.8, -0.3, 0.2);
    float phase  = clamp(t / (30.0 / max(uEvolutionSpeed, 0.01)), 0.0, 1.0);
    float radius = mix(0.6, 0.05, phase * phase);     // Jeans collapse: accelerates
    float dist   = length(p - center);
    return exp(-dist*dist / (radius*radius)) * mix(0.3, 2.0, phase);
}

// ── Combined density ──────────────────────────────────────────────────────────
float nebulaDensity(vec3 p, float t) {
    float bScale = breathScale(t);
    vec3  pBreath = p * bScale;

    float env   = pow(max(0.0, 1.0 - dot(p,p)*0.22), 1.4);
    float base  = fbm(pBreath * uTurbulence, uTurbulence);
    float gas   = max(0.0, base - 0.32) * env * uDensityScale;

    // Carve cavities from star births
    float cavities = 0.0;
    for (int i = 0; i < 5; i++) cavities += starBirthCavity(p, t, i);
    gas = max(0.0, gas - cavities * gas);

    // Add ghost shells
    float ghosts = 0.0;
    for (int i = 0; i < 3; i++) ghosts += ghostShell(p, t, i);

    // Add collapsing clump
    float clump = collapsingClump(p, t);

    return gas + ghosts * 0.5 + clump;
}

// ── Emission color ────────────────────────────────────────────────────────────
vec3 emitColor(vec3 p, float density, float t) {
    // Base H-alpha red
    vec3 base = vec3(0.85, 0.18, 0.12);
    // Ghost shells glow teal (O-III)
    float ghostAmt = 0.0;
    for (int i = 0; i < 3; i++) ghostAmt += ghostShell(p, t, i);
    vec3 ghost = vec3(0.1, 0.75, 0.7);
    // Collapsing clump glows warm orange-white (heating)
    float clumpAmt = clamp(collapsingClump(p, t) * 0.5, 0.0, 1.0);
    vec3 clumpColor = vec3(1.0, 0.7, 0.3);

    return mix(mix(base, ghost, clamp(ghostAmt, 0.0, 1.0)), clumpColor, clumpAmt) * density;
}

// ── Raymarcher ────────────────────────────────────────────────────────────────
const int STEPS = 80;
const float STEP_SZ = 0.055;

vec3 raymarch(vec3 ro, vec3 rd, float t) {
    vec3  color = vec3(0.0);
    float trans = 1.0;
    for (int i = 0; i < STEPS; i++) {
        vec3  p = ro + rd * (float(i)*STEP_SZ);
        float d = nebulaDensity(p, t);
        if (d > 0.001) {
            color += trans * emitColor(p, d, t) * uEmission * STEP_SZ;
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
    float evo = uTime * mix(0.05, 0.8, uEvolutionSpeed);
    float a   = uTime * 0.07;
    vec3 eye  = vec3(cos(a)*4.0, 1.2, sin(a)*4.0);
    mat3 cam  = lookAt(eye, vec3(0.0));
    vec3 rd   = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd, evo);
    color = color / (color + 1.0);
    color = pow(color, vec3(1.0/2.2));
    gl_FragColor = vec4(color, 1.0);
}
