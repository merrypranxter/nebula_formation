// glitch_nebula.glsl
// The Hubble image as corrupted data. Truth and artifact become indistinguishable.
//
// Glitch types layered:
//   1. Cosmic ray hits → bright single-pixel vertical streaks
//   2. CCD column bleeding → saturated vertical bleed from bright stars
//   3. JPEG block artifacts → 8x8 DCT compression blocks overlaid
//   4. Banding / readout noise → horizontal scan lines
//   5. Bit-flip distortion → random XOR-like color inversion patches
//   6. Transmission packet loss → rectangular black dropout regions
//
// The "real" nebula underneath is a standard volumetric H II region.
// At uGlitchAmount = 0 it's pristine; at 1.0 it's all artifact.

#ifdef GL_ES
precision highp float;
#endif

uniform vec2  uResolution;
uniform float uTime;
uniform float uDensityScale;
uniform float uTurbulence;
uniform float uEmission;
uniform float uDustOpacity;
uniform float uGlitchAmount;   // [0,1]

// ── Noise ─────────────────────────────────────────────────────────────────────
vec3 hash3(vec3 p) {
    p = fract(p * vec3(443.8975, 397.2973, 491.1871));
    p += dot(p, p.yxz + 19.19);
    return fract((p.xxy + p.yxx) * p.zyx);
}
float hash1(float n) { return fract(sin(n) * 43758.5453123); }

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

// ── Base nebula (same as basic_nebula) ────────────────────────────────────────
float nebulaDensity(vec3 p) {
    float env  = pow(max(0.0, 1.0 - dot(p,p)*0.25), 1.5);
    float base = fbm(p*uTurbulence, uTurbulence);
    return max(0.0, base - 0.35) * env * uDensityScale;
}

const int STEPS = 64;
const float STEP_SZ = 0.06;

vec3 raymarcher(vec3 ro, vec3 rd) {
    vec3  color = vec3(0.0);
    float trans = 1.0;
    for (int i = 0; i < STEPS; i++) {
        vec3  p = ro + rd * (float(i)*STEP_SZ);
        float d = nebulaDensity(p);
        if (d > 0.001) {
            vec3 emit = mix(vec3(0.85,0.2,0.15), vec3(0.1,0.75,0.7), d*0.5) * d;
            color += trans * emit * uEmission * STEP_SZ;
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

// ── Glitch functions ──────────────────────────────────────────────────────────

// 1. Cosmic ray: bright vertical streak at random x column, sparse
float cosmicRay(vec2 fragCoord) {
    float g = uGlitchAmount;
    float stripe = floor(fragCoord.x / 3.0);
    float active = step(0.995 - g*0.09, hash1(stripe + floor(uTime*0.3)*100.0));
    float colMatch = step(abs(fragCoord.x - stripe*3.0 - 1.0), 1.5);
    return active * colMatch;
}

// 2. CCD column bleed: bright star bleeds vertically
float columnBleed(vec2 fragCoord, vec2 resolution) {
    float g = uGlitchAmount;
    // A few bright star x-positions that bleed
    float bleed = 0.0;
    for (int i = 0; i < 4; i++) {
        float sx = hash1(float(i) * 17.3) * resolution.x;
        float dist = abs(fragCoord.x - sx);
        bleed += exp(-dist * 0.3) * step(0.9 - g*0.4, hash1(float(i)*31.7));
    }
    return clamp(bleed, 0.0, 1.0);
}

// 3. JPEG block artifacts: quantization error pattern over 8x8 blocks
vec3 jpegBlock(vec2 fragCoord, vec3 baseColor) {
    float g = uGlitchAmount;
    vec2 block = floor(fragCoord / 8.0);
    float blockHash = hash1(block.x + block.y * 137.0 + floor(uTime*0.1)*512.0);
    float active = step(0.93 - g*0.35, blockHash);
    // quantize color to 3 levels per channel
    vec3 quantized = floor(baseColor * 3.0) / 3.0;
    return mix(baseColor, quantized, active * g);
}

// 4. Horizontal banding (readout noise)
float scanBand(vec2 fragCoord) {
    float g = uGlitchAmount;
    float row = floor(fragCoord.y / 2.0);
    float noise = (hash1(row + floor(uTime*5.0)*200.0) - 0.5) * g * 0.15;
    return noise;
}

// 5. Bit-flip patch: color inversion in a random rect
float bitFlipMask(vec2 fragCoord, vec2 resolution) {
    float g = uGlitchAmount;
    // One patch per second-ish
    float t = floor(uTime * (0.5 + g));
    vec2 origin = vec2(hash1(t*3.1), hash1(t*7.3)) * resolution;
    vec2 size   = vec2(hash1(t*13.7), hash1(t*5.9)) * vec2(80.0, 30.0) * g;
    vec2 d      = fragCoord - origin;
    return step(0.0, d.x)*step(d.x, size.x)*step(0.0, d.y)*step(d.y, size.y) * g;
}

// 6. Packet-loss dropout (black rectangle)
float dropoutMask(vec2 fragCoord, vec2 resolution) {
    float g = uGlitchAmount;
    float t = floor(uTime * (0.3 + g * 0.5));
    float active = step(0.85 - g*0.3, hash1(t*41.3));
    vec2 origin = vec2(hash1(t*23.1), hash1(t*11.7)) * resolution;
    vec2 size   = vec2(hash1(t*17.3), hash1(t*7.1)) * vec2(100.0, 50.0) * g;
    vec2 d      = fragCoord - origin;
    return active * step(0.0,d.x)*step(d.x,size.x)*step(0.0,d.y)*step(d.y,size.y);
}

void main() {
    vec2 fragCoord = gl_FragCoord.xy;
    vec2 uv   = (fragCoord - uResolution * 0.5) / uResolution.y;
    float a   = uTime * 0.08;
    vec3 eye  = vec3(cos(a)*3.5, 1.0, sin(a)*3.5);
    mat3 cam  = lookAt(eye, vec3(0.0));
    vec3 rd   = normalize(cam * vec3(uv, -1.5));

    vec3 color = raymarcher(eye, rd);

    // Apply glitch effects layered
    float g = uGlitchAmount;

    // Scan banding
    color += scanBand(fragCoord);

    // JPEG block quantization
    color = jpegBlock(fragCoord, color);

    // Cosmic ray hit
    float cr = cosmicRay(fragCoord);
    vec3  crColor = vec3(hash1(floor(gl_FragCoord.x)*7.3),
                         hash1(floor(gl_FragCoord.x)*13.1),
                         1.0);
    color = mix(color, crColor, cr * g);

    // Column bleed
    float bleed = columnBleed(fragCoord, uResolution);
    color = mix(color, vec3(1.0, 0.95, 0.8), bleed * g * 0.6);

    // Bit-flip inversion
    float flip = bitFlipMask(fragCoord, uResolution);
    color = mix(color, 1.0 - color, flip);

    // Dropout (black)
    float dropout = dropoutMask(fragCoord, uResolution);
    color = mix(color, vec3(0.0), dropout);

    color = color / (color + 1.0);
    color = pow(max(color, vec3(0.0)), vec3(1.0/2.2));
    gl_FragColor = vec4(color, 1.0);
}
