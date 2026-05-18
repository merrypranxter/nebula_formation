// sacred_nebula.glsl
// The nebula as religious architecture.
//
// Pillars of Creation    → Cathedral columns
// Ionization front skin  → Stained glass light
// Dense Bok globules     → Gargoyles / grotesques at column tops
// Intercolumnar gas      → Rose window: golden ratio spiral overlay
// H-alpha glow           → Candlelight / votive ambiance
// Dark dust lanes        → Flying buttresses
//
// Sacred geometry overlay driven by uSacredOverlay [0,1]:
//   At 0: pure nebula physics
//   At 1: golden-ratio spirals, Fibonacci filaments, divine proportions
//
// "The universe is a temple and we are the stained glass."

#ifdef GL_ES
precision highp float;
#endif

#define PI  3.14159265358979
#define PHI 1.61803398875      // golden ratio

uniform vec2  uResolution;
uniform float uTime;
uniform float uDensityScale;
uniform float uTurbulence;
uniform float uEmission;
uniform float uDustOpacity;
uniform float uSacredOverlay;   // [0,1]

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

// ── Pillar density (Pillars of Creation style columns) ────────────────────────
float pillarDensity(vec3 p) {
    // Three pillars along xz at cathedral positions
    vec2 pillarPos[3];
    pillarPos[0] = vec2(-0.8, 0.0);
    pillarPos[1] = vec2( 0.4, 0.6);
    pillarPos[2] = vec2( 0.6,-0.7);

    float d = 0.0;
    for (int i = 0; i < 3; i++) {
        vec2  xz     = p.xz - pillarPos[i];
        float radial = length(xz);

        // Pillar: tall vertical column, wider at base
        float baseWidth  = 0.2 + max(0.0, -p.y) * 0.15;   // flared base
        float topWidth   = 0.05;
        float height     = 2.5;
        float width      = mix(topWidth, baseWidth, clamp((-p.y) / height, 0.0, 1.0));

        float column = smoothstep(width + 0.1, width, radial);

        // Globule at top: dense dark knot
        vec3 globulePos = vec3(pillarPos[i].x, 1.8, pillarPos[i].y);
        float globule   = exp(-dot(p - globulePos, p - globulePos) * 5.0) * 2.0;

        // FBM texture along the pillar surface
        float surf = fbm(p * uTurbulence * 1.5, uTurbulence) * 0.4;

        d += (column + globule + surf * column) * uDensityScale;
    }
    return d;
}

// ── Intercolumnar gas (H II region between pillars) ───────────────────────────
float gasHalo(vec3 p) {
    float env = pow(max(0.0, 1.0 - dot(p,p)*0.15), 1.2);
    float base = fbm(p * uTurbulence * 0.8, uTurbulence);
    // Reduce where pillars are (gas ionized away)
    float pillar = min(1.0, pillarDensity(p) * 2.0);
    return max(0.0, base - 0.38) * env * (1.0 - pillar * 0.7) * uDensityScale * 0.6;
}

// ── Golden spiral overlay (sacred geometry) ───────────────────────────────────
float goldenSpiralField(vec3 p) {
    // Project to 2D (xz plane), compute golden spiral density
    vec2 q      = p.xz;
    float r     = length(q);
    float theta = atan(q.y, q.x);

    // Fibonacci spiral: θ = ln(r) / ln(φ)
    float spiralTheta = log(max(r, 0.001)) / log(PHI);
    float angDiff     = mod(abs(theta - spiralTheta), 2.0*PI);
    angDiff           = min(angDiff, 2.0*PI - angDiff);

    // Soft line along the spiral
    float spiral = exp(-angDiff * angDiff * 10.0) * exp(-abs(p.y) * 2.0);

    // Radial falloff: spiral fades at large r
    spiral *= exp(-r * 0.5);

    return spiral;
}

// ── Combined density ──────────────────────────────────────────────────────────
float nebulaDensity(vec3 p) {
    return pillarDensity(p) + gasHalo(p);
}

// ── Emission color ────────────────────────────────────────────────────────────
vec3 emitColor(vec3 p, float density, float sacredAmt) {
    // Pillar regions: dark red (H-alpha, dense, shadowed)
    // Gas halo: teal-gold (stained glass: O-III + continuum)
    // Globule tops: almost dark — silhouetted against glow

    float pillar = clamp(pillarDensity(p) / (density + 0.001), 0.0, 1.0);
    vec3  pillarCol = vec3(0.5, 0.08, 0.05);   // dark red pillar body
    vec3  haloCol   = vec3(0.85, 0.55, 0.15);  // golden halo (stained glass)
    vec3  rimCol    = vec3(0.2, 0.8, 0.7);     // teal ionization front rim

    // Rim lighting at pillar edge — bright where gas meets ionization front
    float rimWidth = 0.08;
    float rim = 0.0;
    for (int i = 0; i < 3; i++) {
        vec2 pillarPos = (i==0) ? vec2(-0.8,0.0) : (i==1 ? vec2(0.4,0.6) : vec2(0.6,-0.7));
        float radial = length(p.xz - pillarPos);
        float width  = 0.2 + max(0.0, -p.y) * 0.1;
        rim += exp(-pow(radial - width, 2.0) / (rimWidth*rimWidth));
    }
    rim = clamp(rim, 0.0, 1.0);

    vec3 baseColor = mix(haloCol, mix(pillarCol, rimCol, rim), pillar);

    // Sacred overlay: golden spiral becomes luminous filigree
    float sacred = goldenSpiralField(p) * sacredAmt;
    vec3  sacredColor = vec3(1.0, 0.92, 0.5) * sacred * 2.0;

    return (baseColor * density + sacredColor) * uEmission;
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
            color += trans * emitColor(p, d, uSacredOverlay) * STEP_SZ;
            trans *= exp(-d * uDustOpacity * STEP_SZ);
        }
        if (trans < 0.01) break;
    }

    // Sacred spiral glow in empty space (sacred geometry as radiant light)
    if (uSacredOverlay > 0.01) {
        for (int i = 0; i < STEPS; i++) {
            vec3  p = ro + rd * (float(i)*STEP_SZ);
            float s = goldenSpiralField(p) * uSacredOverlay * 0.05;
            color += s * vec3(1.0, 0.9, 0.6) * STEP_SZ;
        }
    }

    return color;
}

mat3 lookAt(vec3 eye, vec3 target) {
    vec3 z=normalize(eye-target), x=normalize(cross(vec3(0,1,0),z)), y=cross(z,x);
    return mat3(x,y,z);
}

void main() {
    vec2 uv  = (gl_FragCoord.xy - uResolution*0.5) / uResolution.y;
    // Slow reverent orbit
    float a  = uTime * 0.04;
    vec3 eye = vec3(cos(a)*4.5, 0.8 + sin(uTime*0.07)*0.3, sin(a)*4.5);
    mat3 cam = lookAt(eye, vec3(0.0, 0.3, 0.0));
    vec3 rd  = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd);
    color = color / (color + 1.0);
    color = pow(color, vec3(1.0/2.2));
    gl_FragColor = vec4(color, 1.0);
}
