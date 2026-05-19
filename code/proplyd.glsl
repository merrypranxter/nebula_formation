// proplyd.glsl
// Protoplanetary disk being photoevaporated by a nearby O star.
// The teardrop comet-shape is not a comet — it's a SOLAR SYSTEM BEING BORN,
// stripped to nakedness by a neighboring star's radiation.
//
// Physical model:
//   - Protostellar disk: flat dense disk, radius ~200 AU (rendered as ~0.15 in scene)
//   - Photoevaporating envelope: ionized sheath wrapped around the disk
//   - Ionization front: D-type, propagating inward, sculpting the teardrop shape
//   - Bow shock: forms upstream, cometary tail stretches downwind
//   - Central protostar: embedded point source, not yet on the main sequence
//
// Real-world analogs:
//   - Orion Nebula proplyds (HST 1994): hundreds found in Orion
//   - 182-413, 114-426, 253-1536: famous individual Orion proplyds
//   - Carina Nebula evaporating disks around young stars
//
// The rendering:
//   - Ionizing star at fixed position (simulate θ¹ Ori C equivalent)
//   - Multiple proplyds in the field, each with unique disk orientation
//   - Comet-like tails of photoevaporated gas streaming downwind

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
float valueNoise(vec3 p) {
    vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash3(i).x,hash3(i+vec3(1,0,0)).x,f.x),
                   mix(hash3(i+vec3(0,1,0)).x,hash3(i+vec3(1,1,0)).x,f.x),f.y),
               mix(mix(hash3(i+vec3(0,0,1)).x,hash3(i+vec3(1,0,1)).x,f.x),
                   mix(hash3(i+vec3(0,1,1)).x,hash3(i+vec3(1,1,1)).x,f.x),f.y),f.z);
}
float fbm(vec3 p, float t) {
    float v=0.0, a=0.5, freq=1.0;
    for(int i=0;i<5;i++){ v+=a*valueNoise(p*freq); a*=0.5; freq*=2.1; p+=vec3(1.7,9.2,3.4); }
    return v;
}

// ── Ionizing star (off-screen, source of UV radiation) ───────────────────────
vec3 ionizingStarPos() {
    return vec3(4.0, 2.0, -2.0);   // θ¹ Ori C analog: upper-left, far away
}

// ── Single proplyd density ────────────────────────────────────────────────────
// center: proplyd center position in scene
// diskNormal: orientation of the disk axis
// diskRadius, diskThick: disk geometry
// Returns density at point p.
float proplydDensity(vec3 p, vec3 center, vec3 diskNormal, float diskRadius, float diskThick) {
    vec3  q       = p - center;
    vec3  ionDir  = normalize(center - ionizingStarPos());   // toward ionizing star (from proplyd)
    // Actually: away from ionizing star = downwind direction (tail extends this way)
    vec3  windDir = normalize(center - ionizingStarPos());

    // Disk: rotate to disk frame
    vec3  qN  = dot(q, diskNormal) * diskNormal;      // normal component
    vec3  qP  = q - qN;                                // planar component
    float rPlane = length(qP);
    float zDisk  = length(qN);

    // Disk density: flat Gaussian slab
    float disk = exp(-rPlane*rPlane/(diskRadius*diskRadius)) *
                 exp(-zDisk*zDisk/(diskThick*diskThick)) * 3.0;

    // Photoevaporating envelope: teardrop pointing toward ionizing star
    // Upstream (facing star): tight bow shock
    // Downstream (away from star): elongated cometary tail
    float upstream  = dot(q, -windDir);    // positive = upstream side
    float crossDist = length(q - upstream * (-windDir));   // distance from axis

    float envRadius = diskRadius * 1.5;
    // Teardrop profile: rounder upstream, pointed downstream
    float tearFrac  = clamp(upstream / envRadius, -1.0, 1.0);  // -1=downstream, 1=upstream
    float tearWidth = envRadius * (0.6 + 0.4 * tearFrac);      // narrower downstream
    float envelope  = exp(-crossDist*crossDist / (tearWidth*tearWidth)) *
                      smoothstep(-envRadius*2.0, -envRadius*0.2, upstream);

    // Ionized sheath: H-alpha glow at teardrop surface (thin shell)
    float sheath = exp(-pow(length(q/envRadius) - 1.0, 2.0) * 30.0) * 0.5;

    // Cometary tail: fainter gas streaming away from star
    float tailLength = envRadius * 4.0;
    float tailRadius = envRadius * 0.3;
    float tailAlong  = -dot(q, windDir);  // positive = downstream
    float tailPerp   = length(q + windDir*tailAlong);
    float tail = step(0.0, tailAlong) * exp(-tailPerp*tailPerp/(tailRadius*tailRadius)) *
                 exp(-tailAlong/tailLength) * 0.4;

    float noise = fbm(p * uTurbulence * 3.0, uTurbulence) * 0.1;

    return (disk + (envelope + sheath + tail) * (1.0 + noise)) * uDensityScale;
}

// ── Background H II region gas ────────────────────────────────────────────────
float backgroundGas(vec3 p) {
    float env  = pow(max(0.0, 1.0 - dot(p,p)*0.12), 0.8);
    float base = fbm(p * uTurbulence * 0.7, uTurbulence);
    return max(0.0, base - 0.35) * env * uDensityScale * 0.4;
}

// ── Scene: 4 proplyds at different positions and orientations ─────────────────
float sceneDensity(vec3 p) {
    float d = backgroundGas(p);

    // Proplyd 1: nearly face-on disk, center of scene
    d += proplydDensity(p, vec3(0.0, 0.0, 0.0),
                        normalize(vec3(0.1, 1.0, 0.1)), 0.18, 0.04);

    // Proplyd 2: edge-on disk, upper right
    d += proplydDensity(p, vec3(0.8, 0.5, -0.3),
                        normalize(vec3(1.0, 0.0, 0.2)), 0.14, 0.03);

    // Proplyd 3: tilted, lower left
    d += proplydDensity(p, vec3(-0.7, -0.4, 0.2),
                        normalize(vec3(0.3, 0.8, -0.5)), 0.16, 0.035);

    // Proplyd 4: small, bottom
    d += proplydDensity(p, vec3(0.2, -0.8, 0.1),
                        normalize(vec3(-0.2, 0.9, 0.3)), 0.10, 0.025);

    return d;
}

// ── Emission color ────────────────────────────────────────────────────────────
vec3 emitColor(vec3 p, float density) {
    vec3 starPos  = ionizingStarPos();
    float distStar = length(p - starPos);
    float ionParam = 1.0 / (1.0 + distStar * distStar * 0.3);   // higher near star

    // Sheath / envelope: bright H-alpha + [O III] from ionized gas
    vec3 ionizedCol = mix(vec3(0.85, 0.12, 0.10),    // H-alpha (outer)
                          vec3(0.05, 0.80, 0.70),     // [O III] (hotter, near star)
                          clamp(ionParam * 3.0, 0.0, 1.0));

    // Disk interior: dark (opaque) + inner heating by protostar (warm orange)
    float nearCenter = 0.0;
    // Check proximity to each proplyd center
    vec3 centers[4];
    centers[0] = vec3(0.0, 0.0, 0.0);
    centers[1] = vec3(0.8, 0.5, -0.3);
    centers[2] = vec3(-0.7, -0.4, 0.2);
    centers[3] = vec3(0.2, -0.8, 0.1);
    for (int i = 0; i < 4; i++) {
        float d = length(p - centers[i]);
        nearCenter += exp(-d*d * 50.0);
    }
    vec3 diskCol = mix(ionizedCol, vec3(1.0, 0.6, 0.2), clamp(nearCenter, 0.0, 1.0));

    // Tail: blue-shifted? Not in emission — tail is just swept H-alpha
    return diskCol * density * uEmission;
}

// ── Raymarcher ────────────────────────────────────────────────────────────────
const int   STEPS   = 80;
const float STEP_SZ = 0.05;

vec3 raymarch(vec3 ro, vec3 rd) {
    vec3  color = vec3(0.0);
    float trans = 1.0;
    for (int i = 0; i < STEPS; i++) {
        vec3  p = ro + rd * (float(i)*STEP_SZ);
        float d = sceneDensity(p);
        if (d > 0.001) {
            color += trans * emitColor(p, d) * STEP_SZ;
            trans *= exp(-d * uDustOpacity * STEP_SZ);
        }
        if (trans < 0.01) break;
    }

    // Background star field + ionizing star
    vec3  toStar = ionizingStarPos() - ro;
    float tHit   = dot(toStar, rd);
    if (tHit > 0.0) {
        vec3  closest = ro + rd*tHit - ionizingStarPos();
        float r2      = dot(closest, closest);
        // O star: blue-white, very bright
        color += vec3(0.75, 0.88, 1.0) * exp(-r2 * 3000.0) * 5.0 * trans;
    }

    return color;
}

mat3 lookAt(vec3 eye, vec3 target) {
    vec3 z=normalize(eye-target), x=normalize(cross(vec3(0,1,0),z)), y=cross(z,x);
    return mat3(x,y,z);
}

void main() {
    vec2 uv  = (gl_FragCoord.xy - uResolution*0.5) / uResolution.y;
    float a  = uTime * 0.05;
    vec3 eye = vec3(cos(a)*3.5, 0.8 + sin(uTime*0.08)*0.3, sin(a)*3.5);
    mat3 cam = lookAt(eye, vec3(0.0));
    vec3 rd  = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarch(eye, rd);
    color = color / (color + 1.0);
    color = pow(color, vec3(1.0/2.2));
    gl_FragColor = vec4(color, 1.0);
}
