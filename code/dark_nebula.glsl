// dark_nebula.glsl
// Pure absorption: cold molecular gas that blocks all light behind it.
// The silhouette is the nebula. The absence is the form.
//
// Physical model:
//   - Dense cold gas (T ~ 10–30 K): thermal emission negligible in optical
//   - Heavy dust extinction: A_V can reach 10–100 magnitudes (nothing gets through)
//   - Background: crowded starfield + diffuse ionized H II glow beyond the cloud
//   - Bok globules: isolated dense spherical cores where stars are forming in secret
//   - Boundary: sharpest edge in astronomy — dust grains act like a brick wall
//
// The art: you don't render what's there. You render what's absent.
// Every dark region IS the nebula. The bright gas glowing around it is the context.
//
// Real-world analogs:
//   - Horsehead Nebula (Barnard 33): dark pillar against IC 434 H II glow
//   - Barnard 68: isolated Bok globule, spherical, completely opaque center
//   - Coalsack Nebula: dark patch in Milky Way — no detail, just absence
//   - Rho Ophiuchi cloud complex: dark tendrils against starfield
//
// "The darkness is not empty. It is overfull. Too much matter to let light pass."

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

// ── Noise ─────────────────────────────────────────────────────────────────────
vec3 hash3(vec3 p) {
    p = fract(p * vec3(443.8975, 397.2973, 491.1871));
    p += dot(p, p.yxz + 19.19);
    return fract((p.xxy + p.yxx) * p.zyx);
}
float hash1(float n) { return fract(sin(n) * 43758.5453); }
float valueNoise(vec3 p) {
    vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash3(i).x,hash3(i+vec3(1,0,0)).x,f.x),
                   mix(hash3(i+vec3(0,1,0)).x,hash3(i+vec3(1,1,0)).x,f.x),f.y),
               mix(mix(hash3(i+vec3(0,0,1)).x,hash3(i+vec3(1,0,1)).x,f.x),
                   mix(hash3(i+vec3(0,1,1)).x,hash3(i+vec3(1,1,1)).x,f.x),f.y),f.z);
}
float fbm(vec3 p, float t) {
    float v=0.0, a=0.5, freq=1.0;
    for(int i=0;i<7;i++){ v+=a*valueNoise(p*freq); a*=0.5; freq*=2.0+t*0.1; p+=vec3(1.7,9.2,3.4); }
    return v;
}

// ── Background: H II region glow + stellar field ──────────────────────────────
// The dark nebula sits IN FRONT of a glowing background.
// This is what gets blocked.

float bgGasDensity(vec3 p) {
    // H II region behind the cloud — shifted along -z
    vec3 pb = p + vec3(0.0, 0.0, -1.5);
    float env  = pow(max(0.0, 1.0 - dot(pb,pb)*0.12), 1.0);
    float base = fbm(pb * uTurbulence * 0.8 + vec3(4.1, 2.3, 0.0), uTurbulence);
    return max(0.0, base - 0.30) * env;
}

// ── Dark cloud density ────────────────────────────────────────────────────────
// Horsehead-style: a dense pillar rising from a larger cloud base.
float cloudDensity(vec3 p) {
    // Main body: broad dark base cloud (occupies z > 0 half-space mostly)
    float env  = pow(max(0.0, 1.0 - dot(p*vec3(1,1,0.5), p*vec3(1,1,0.5))*0.20), 1.2);
    float base = fbm(p * uTurbulence * 1.2, uTurbulence);
    float d    = max(0.0, base - 0.30) * env * uDensityScale;

    // Horsehead-like protrusion: tall vertical pillar
    vec2  xz    = p.xz - vec2(0.0, 0.1);
    float pillarR = 0.18;
    float pillarH = 2.0;
    float radial  = length(xz);
    float column  = smoothstep(pillarR + 0.1, pillarR, radial) * smoothstep(-pillarH, -pillarH*0.5, p.y);
    float notch   = 1.0 - smoothstep(0.9, 1.5, p.y);   // top of pillar
    // Texture the pillar surface
    float surf    = fbm(p*uTurbulence*2.0, uTurbulence) * 0.4;
    d += (column + surf*column) * notch * uDensityScale * 1.5;

    return d;
}

// ── Bok globule: isolated, spherical, utterly opaque core ─────────────────────
float bokGlobule(vec3 p, vec3 center, float radius) {
    float d = length(p - center);
    return exp(-d*d / (radius*radius)) * 4.0 * uDensityScale;
}

// ── Total opacity density: cloud + Bok globules ────────────────────────────────
float totalOpacity(vec3 p) {
    float d = cloudDensity(p);
    // Three Bok globules at different positions
    d += bokGlobule(p, vec3( 0.8,  0.4, 0.0), 0.16);
    d += bokGlobule(p, vec3(-0.7, -0.2, 0.1), 0.12);
    d += bokGlobule(p, vec3( 0.3, -0.6, 0.2), 0.10);
    return d;
}

// ── Background star field ─────────────────────────────────────────────────────
// Stars are placed at z = -3 (well behind the cloud). They are attenuated
// by the dust column in front of them.
vec3 starFieldBackground(vec3 ro, vec3 rd, float transmission) {
    vec3 stars = vec3(0.0);
    // Place ~40 background stars
    for (int i = 0; i < 40; i++) {
        vec3 seed = hash3(vec3(float(i)*7.3, float(i)*11.1, float(i)*4.7));
        // Star at z=-3 plane
        vec3 sp   = vec3((seed.x*2.0-1.0)*3.0, (seed.y*2.0-1.0)*3.0, -3.0);
        vec3 toS  = sp - ro;
        float tHit= dot(toS, rd);
        if (tHit < 0.0) continue;
        vec3  closest = ro + rd*tHit - sp;
        float r2      = dot(closest, closest);
        float bloom   = exp(-r2 * 10000.0);
        vec3  sColor  = mix(vec3(0.8, 0.9, 1.0), vec3(1.0, 0.9, 0.7), seed.z);
        float brightness = 0.3 + seed.x * 2.0;
        stars += sColor * bloom * brightness * transmission;
    }
    return stars;
}

// ── Raymarcher ────────────────────────────────────────────────────────────────
const int   STEPS   = 96;
const float STEP_SZ = 0.05;

vec3 raymarch(vec3 ro, vec3 rd) {
    vec3  color = vec3(0.0);
    float trans = 1.0;

    // Background H II glow (integrated separately — behind everything)
    float bgIntensity = 0.0;
    float bgTrans = 1.0;

    for (int i = 0; i < STEPS; i++) {
        vec3  p    = ro + rd * (float(i)*STEP_SZ);

        // Background H II emission (only where cloud doesn't block)
        float bgD  = bgGasDensity(p);
        if (bgD > 0.001) {
            float bgEmit = bgD * uEmission * STEP_SZ * 0.8;
            // H-alpha red glow of background H II region
            color += bgTrans * vec3(0.85, 0.14, 0.10) * bgEmit * trans;
        }

        // Dark cloud extinction
        float cloudD = totalOpacity(p);
        if (cloudD > 0.001) {
            // Cloud emits nothing optically (T=10K) — pure absorption
            float extinction = cloudD * uDustOpacity * STEP_SZ * 2.0;
            trans *= exp(-extinction);
        }

        bgTrans *= exp(-bgD * 0.5 * STEP_SZ);
        if (trans < 0.005) break;
    }

    // Star field: attenuated by cloud dust column
    color += starFieldBackground(ro, rd, trans);

    // Faint rim lighting: ionization front just touching cloud edge
    // The cloud boundary facing the H II region has a faint warm glow
    // (photo-dissociation region: warm neutral gas)
    // This is a subtle touch: a thin warm orange-gold line at the cloud edge.
    // Handled implicitly by the H-alpha background bleeding around the silhouette.

    return color;
}

mat3 lookAt(vec3 eye, vec3 target) {
    vec3 z=normalize(eye-target), x=normalize(cross(vec3(0,1,0),z)), y=cross(z,x);
    return mat3(x,y,z);
}

void main() {
    vec2 uv  = (gl_FragCoord.xy - uResolution*0.5) / uResolution.y;
    // Mostly static view: dark nebulae move on geological timescales
    float a  = uTime * 0.03;
    vec3 eye = vec3(cos(a)*3.8, 0.3 + sin(uTime*0.04)*0.2, sin(a)*3.8);
    mat3 cam = lookAt(eye, vec3(0.0, 0.0, 0.0));
    vec3 rd  = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd);
    color = color / (color + 1.0);
    color = pow(color, vec3(1.0/2.2));
    gl_FragColor = vec4(color, 1.0);
}
