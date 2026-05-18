// emotional_nebula.glsl
// Feeling drives physics. Colors break from spectral reality.
// The nebula responds to emotional parameters rather than temperature or ion state.
//
// Emotional states implemented:
//   grief     → deep purples, slow motion, heavy dust, labored collapse
//   joy       → explosive gold-magenta, rapid star ignition, open filaments
//   longing   → blue-shifted entirety, gas drifting away from viewer
//   rage      → red-orange compressed shock, violent stellar winds carving wounds
//
// These are not palette swaps — the density field *behavior* also changes.

#ifdef GL_ES
precision highp float;
#endif

uniform vec2  uResolution;
uniform float uTime;
uniform float uDensityScale;
uniform float uTurbulence;
uniform float uEmission;
uniform float uDustOpacity;
uniform float uEvolutionSpeed;

// Emotional state: encoded as a single float 0–3
//   0.0–1.0 = grief
//   1.0–2.0 = joy
//   2.0–3.0 = longing
//   3.0–4.0 = rage
// (or pass as four separate uniforms and blend — use uTime to cycle for demo)

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

// ── Emotional state cycling ───────────────────────────────────────────────────
// Cycles through grief → joy → longing → rage over 40 seconds
float emotionPhase(float t) {
    return mod(t * uEvolutionSpeed * 0.5 + t * 0.025, 4.0);
}

// ── Grief density: heavy, slow, dense — gas doesn't want to disperse ─────────
float griefDensity(vec3 p, float t) {
    float env  = pow(max(0.0, 1.0 - dot(p,p)*0.18), 2.0);    // thicker envelope
    float base = fbm(p * uTurbulence * 0.6 + vec3(0,0,t*0.02), uTurbulence); // barely moving
    return max(0.0, base - 0.25) * env * uDensityScale * 1.6;  // denser
}

// ── Joy density: explosive, expanding, full of holes ─────────────────────────
float joyDensity(vec3 p, float t) {
    float env  = pow(max(0.0, 1.0 - dot(p,p)*0.12), 0.8);    // wider spread
    float base = fbm(p * uTurbulence * 1.8 + vec3(0,0,t*0.15), uTurbulence); // fast turbulence
    float holes = fbm(p * 3.0 + vec3(t*0.2), uTurbulence);
    return max(0.0, base - 0.45) * env * uDensityScale * max(0.0, 1.0 - holes*0.8);
}

// ── Longing density: drifting away, dissolving at edges ──────────────────────
float longingDensity(vec3 p, float t) {
    vec3 drift = p - vec3(0, 0, t * 0.05);   // moving away (recession)
    float env  = pow(max(0.0, 1.0 - dot(drift,drift)*0.22), 1.2);
    float base = fbm(drift * uTurbulence, uTurbulence);
    float edge = 1.0 - smoothstep(0.5, 1.5, length(p));
    return max(0.0, base - 0.38) * env * edge * uDensityScale;
}

// ── Rage density: compressed, violent, filaments like wounds ─────────────────
float rageDensity(vec3 p, float t) {
    // Compressed flat — rage collapses the volume into a disc
    vec3  pFlat = vec3(p.x, p.y * 3.0, p.z);   // squash vertically
    float env   = pow(max(0.0, 1.0 - dot(pFlat,pFlat)*0.2), 1.5);
    float base  = fbm(p * uTurbulence * 2.5 + vec3(t*0.1, 0, 0), uTurbulence); // fast shear
    float shock = abs(fbm(p * 5.0 + vec3(t*0.3), uTurbulence) - 0.5);          // sharp filaments
    return (max(0.0, base - 0.35) + shock * 0.3) * env * uDensityScale;
}

// ── Emotional density blend ───────────────────────────────────────────────────
float nebulaDensity(vec3 p, float t, float emo) {
    float f0 = clamp(1.0 - abs(emo - 0.5), 0.0, 1.0);   // grief peak at emo=0.5
    float f1 = clamp(1.0 - abs(emo - 1.5), 0.0, 1.0);   // joy
    float f2 = clamp(1.0 - abs(emo - 2.5), 0.0, 1.0);   // longing
    float f3 = clamp(1.0 - abs(emo - 3.5), 0.0, 1.0);   // rage (wraps)

    return f0 * griefDensity(p, t)
         + f1 * joyDensity(p, t)
         + f2 * longingDensity(p, t)
         + f3 * rageDensity(p, t);
}

// ── Emotional color palettes ──────────────────────────────────────────────────
vec3 griefColor  = vec3(0.20, 0.05, 0.40);   // deep purple
vec3 joyColor    = vec3(1.00, 0.70, 0.10);   // gold-magenta
vec3 joyColor2   = vec3(0.90, 0.15, 0.80);
vec3 longingColor = vec3(0.10, 0.30, 0.90);  // deep blue
vec3 rageColor   = vec3(0.95, 0.15, 0.05);   // burning red

vec3 emitColor(vec3 p, float density, float emo) {
    float f0 = clamp(1.0 - abs(emo - 0.5), 0.0, 1.0);
    float f1 = clamp(1.0 - abs(emo - 1.5), 0.0, 1.0);
    float f2 = clamp(1.0 - abs(emo - 2.5), 0.0, 1.0);
    float f3 = clamp(1.0 - abs(emo - 3.5), 0.0, 1.0);

    vec3 joyBlend = mix(joyColor, joyColor2, fbm(p*4.0, uTurbulence));
    vec3 c = f0 * griefColor + f1 * joyBlend + f2 * longingColor + f3 * rageColor;
    return c * density;
}

// ── Raymarcher ────────────────────────────────────────────────────────────────
const int   STEPS   = 80;
const float STEP_SZ = 0.055;

vec3 raymarch(vec3 ro, vec3 rd, float t, float emo) {
    vec3  color = vec3(0.0);
    float trans = 1.0;
    float dustMult = (emo < 1.0) ? 2.0 : ((emo > 3.0) ? 1.5 : 0.7);  // grief=heavy dust

    for (int i = 0; i < STEPS; i++) {
        vec3  p = ro + rd * (float(i)*STEP_SZ);
        float d = nebulaDensity(p, t, emo);
        if (d > 0.001) {
            color += trans * emitColor(p, d, emo) * uEmission * STEP_SZ;
            trans *= exp(-d * uDustOpacity * dustMult * STEP_SZ);
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
    float emo = emotionPhase(uTime);
    float a   = uTime * 0.06;
    vec3 eye  = vec3(cos(a)*4.0, 1.0, sin(a)*4.0);
    mat3 cam  = lookAt(eye, vec3(0.0));
    vec3 rd   = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd, uTime, emo);
    color = color / (color + 1.0);
    color = pow(color, vec3(1.0/2.2));
    gl_FragColor = vec4(color, 1.0);
}
