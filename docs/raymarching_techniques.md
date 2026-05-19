# Raymarching Techniques
## Volume Rendering in Practice for Nebula Shaders

Raymarching is the central technique of this entire repository. Every shader is a raymarcher. This document explains the theory, the tradeoffs, and the specific techniques used here — including pitfalls that will make your nebula wrong in subtle ways.

---

## The Volume Rendering Equation (Again, Properly)

The fundamental integral from radiative transfer:

```
I(λ) = ∫₀ᴰ  j(s, λ)  ·  T(0, s)  ds
```

Where:
- `I(λ)`: intensity along the ray at wavelength λ
- `j(s, λ)`: volume emissivity at position s
- `T(0, s) = exp( -∫₀ˢ κ(s', λ) ds' )`: transmittance from 0 to s
- `κ(s, λ)`: extinction coefficient (absorption + out-scatter)

In discrete form (raymarcher):

```
T₀ = 1.0
For step i at position pᵢ:
    color     += Tᵢ × j(pᵢ) × Δs
    Tᵢ₊₁     = Tᵢ × exp(-κ(pᵢ) × Δs)
```

This is **front-to-back compositing** — the correct order. Do not reverse it.

---

## The Front-to-Back Pitfall

**WRONG (back-to-front)**:
```glsl
// DON'T DO THIS
color += emission * stepSize;
transmittance *= exp(-extinction * stepSize);
```

Wait — this looks like the right order? The bug is subtle: you've applied the emission from this step *before* extincting it. Front material partially blocks itself.

**CORRECT**:
```glsl
// Apply emission THEN update transmittance
color += transmittance * emission * stepSize;
transmittance *= exp(-extinction * stepSize);
```

The `transmittance` here is the cumulative transmittance from the *camera* to the current step, not from the current step forward. Apply it to the emission before updating it.

---

## Step Size and the CFL Condition

The Shannon sampling theorem applied to raymarching:

**You must sample at least 2× the Nyquist frequency of the density field.**

If your smallest density feature has scale `L_min`, then `step_size < L_min / 2`.

For FBM with `octaves = 6` and `lacunarity = 2.0`:
- Largest feature: `1 / freq_1 = 1 / 1 = 1`
- Finest feature: `1 / freq_6 = 1 / 32 ≈ 0.03`
- Required step size: `< 0.015` for perfect accuracy
- Practical step size: `0.03–0.05` (some aliasing, acceptable for art)

**Rule of thumb**: `step_size ≈ 0.05` works for most nebula shaders. Use `0.03` for crisp thin features (ionization fronts, jet beams).

---

## Adaptive Step Size

Fixed step size wastes samples in empty space. Adaptive stepping:

```glsl
const float STEP_MIN = 0.01;
const float STEP_MAX = 0.10;

float stepSize = STEP_MIN;
for (int i = 0; i < MAX_STEPS; i++) {
    vec3  p = ro + rd * dist;
    float d = density(p);

    // Empty space: take large step
    // Dense region: take small step
    stepSize = mix(STEP_MAX, STEP_MIN, clamp(d * 10.0, 0.0, 1.0));

    if (d > 0.001) {
        color += transmittance * emitColor(p, d) * stepSize;
        transmittance *= exp(-d * extinction * stepSize);
    }
    dist += stepSize;
    if (transmittance < 0.01 || dist > MAX_DIST) break;
}
```

This typically gives 2–4× speedup for nebulae with large empty regions (planetary nebulae, proplyds).

---

## Early Ray Termination

Always implement early exit when `transmittance < threshold`:

```glsl
if (transmittance < 0.01) break;
```

A threshold of 0.01 (1% remaining light) is nearly visually lossless. For high-quality rendering use 0.001.

In shaders with multiple light sources (secondary illumination), you may want `transmittance < 0.001` to capture subtle secondary scattering.

---

## Sphere Bounding

Never raymarch through empty space. Compute the intersection of the ray with a bounding sphere around the density field, then start the march there:

```glsl
bool sphereIntersect(vec3 ro, vec3 rd, float radius, out float tNear, out float tFar) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - radius*radius;
    float disc = b*b - c;
    if (disc < 0.0) return false;
    float sq = sqrt(disc);
    tNear = -b - sq;
    tFar  = -b + sq;
    return tFar > 0.0;
}

// In main render:
float tNear, tFar;
if (!sphereIntersect(ro, rd, CLOUD_RADIUS, tNear, tFar)) {
    gl_FragColor = vec4(BACKGROUND, 1.0);
    return;
}
float dist = max(tNear, 0.0);
float distMax = tFar;
```

For most nebula shaders in this repo, the cloud fits within a sphere of radius 2.5–3.0. Adding a bounding sphere check reduces wasted fragment work by 30–50% for views from outside the cloud.

---

## Secondary Illumination (Shadow Rays)

The `dust_and_stars.glsl` and `reflection_nebula.glsl` shaders cast shadow rays toward the light source to compute self-shadowing. This is the most expensive part — it runs a full sub-march for every primary march step.

**Optimization: coarse shadow march**

Real production code uses 4–16 shadow steps instead of the full 80:

```glsl
float shadowTransmittance(vec3 p, vec3 lightDir, float lightDist) {
    float tau = 0.0;
    const int SHADOW_N = 8;
    float shadowStep = lightDist / float(SHADOW_N);
    for (int i = 1; i <= SHADOW_N; i++) {
        vec3 sp = p + lightDir * (float(i) * shadowStep);
        tau += density(sp) * shadowStep;
    }
    return exp(-tau * DUST_EXTINCTION);
}
```

8 shadow steps gives acceptable quality with ~10× less cost than the full primary march.

**Further optimization**: precompute the shadow transmittance into a 3D texture (shadow map in volume space). Sample this texture during the primary march instead of re-casting shadow rays.

---

## Multi-Wavelength Rendering

Physically accurate nebula rendering requires per-wavelength integration. We approximate with RGB:
- R channel: long wavelengths (H-alpha 656nm, [S II] 672nm)
- G channel: mid wavelengths (H-alpha partial, [O III] 501nm → green leakage)
- B channel: short wavelengths ([O III] 501nm, [O II] 373nm)

**Wavelength-dependent extinction** (Beer-Lambert per channel):
```glsl
vec3 extinctionRGB = vec3(extR, extG, extB);    // from dustExtinctionRGB()
transmittance *= exp(-extinctionRGB * density * stepSize);
// This is a vec3 — transmittance has different values per channel
```

**Common error**: using a scalar transmittance when the extinction is wavelength-dependent. This loses the reddening effect. Always maintain `vec3 transmittance`.

---

## Tone Mapping

Raw raymarched values span 0 to ∞ with very high dynamic range. Always tonemap before display.

### Reinhard (used throughout this repo)
```glsl
color = color / (color + 1.0);
```
Maps [0,∞) → [0,1). Preserves color ratios at low values. Compresses highlights smoothly. Simple and fast.

### ACES Filmic (better for high-dynamic-range scenes)
```glsl
vec3 ACESFilm(vec3 x) {
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((x*(a*x+b)) / (x*(c*x+d)+e), 0.0, 1.0);
}
```
More contrast, better highlight rolloff. Mimics photographic film response.

### Exposure control
Add an exposure multiplier before tonemapping:
```glsl
color *= uExposure;  // 0.5=underexposed/dark, 2.0=overexposed/bright
color = color / (color + 1.0);
```

### Gamma correction
Always apply gamma at the very end:
```glsl
color = pow(color, vec3(1.0/2.2));
```

---

## Anti-Aliasing in Raymarching

### Temporal anti-aliasing (TAA)
On each frame, jitter the ray direction by a sub-pixel offset. Accumulate into a history buffer with exponential moving average:
```
accumulate = mix(accumulate, newFrame, 0.1)
```
This gives MSAA-quality results for volumetric rendering.

### Stochastic sampling
Jitter the starting position along the ray:
```glsl
float jitter = hash(vec2(gl_FragCoord.xy + uTime)) * stepSize;
float dist = jitter;
```
Converts banding artifacts into noise, which the eye tolerates better.

---

## Maximum Step Count

There is always a tradeoff: more steps = more accuracy = slower.

### Choosing step count
For a cloud of diameter D in scene units, with minimum feature scale L_min:
```
steps = D / (step_size)
     = D / (L_min / 2)
```

For our shaders: D ≈ 6 (diameter of traversal), L_min ≈ 0.05–0.1 → steps = 60–120.

80 steps × 0.05 step size = 4.0 units of traversal depth. This barely covers the cloud at maximum camera distance. If you move the camera farther away, increase step count or step size accordingly.

---

## Physically-Based vs. Artistic Step Sizes

| Mode | Step size | Steps | Use case |
|------|-----------|-------|---------|
| Artistic sketch | 0.10 | 40 | Fast preview, real-time interaction |
| Standard | 0.05 | 80 | Default in this repo |
| High quality | 0.025 | 160 | Screenshot renders |
| Reference | 0.01 | 400 | Offline/photorealistic |
| Production VFX | 0.005 | 800+ | With 3D texture acceleration |

---

## The Density Function Is Everything

The step count, tone mapping, and all the rendering infrastructure are just plumbing. The entire visual character of a nebula comes from the density function `float density(vec3 p)`.

### Canonical density function anatomy

```glsl
float density(vec3 p) {
    // 1. ENVELOPE: global falloff that prevents infinite clouds
    float env = pow(max(0.0, 1.0 - dot(p,p)*0.22), 1.3);

    // 2. BASE STRUCTURE: FBM or procedural geometry
    float base = fbm(p * frequency + offset, turbulence);

    // 3. THRESHOLD: creates hard-edged features from smooth noise
    float field = max(0.0, base - threshold);

    // 4. DETAIL: high-frequency perturbation of surface
    float detail = fbm(p * frequency * 4.0) * 0.1;

    // 5. COMBINE
    return (field + detail) * env * densityScale;
}
```

Every additional physical effect (bipolar geometry, ionization front, shell, jet) is an additional term or modulation of this base structure.

---

## Common Rendering Artifacts and Fixes

### Banding
**Cause**: step size too large → discrete layers visible.
**Fix**: jitter starting position (stochastic sampling). Reduce step size.

### Fireflies (bright single-pixel spikes)
**Cause**: density spike in a single step, multiplied by high emission.
**Fix**: clamp density per step: `d = min(d, MAX_DENSITY)`. Apply moving average filter.

### Dark halos around bright gas
**Cause**: extinction applied to both emission AND to the background, creating an over-dark region around bright gas.
**Fix**: ensure background color is added after the transmittance from the foreground volume, not before.

### Color shifting in deep gas
**Cause**: wavelength-dependent extinction is removing blue faster than red (correct! but can look wrong if too extreme).
**Fix**: reduce `uDustOpacity`. Or apply only luminance-averaged extinction: `trans *= exp(-mean(extinctionRGB) * d * step)`.

### Pillar edges too smooth
**Cause**: FBM persistence too high, or threshold too low (gradual density falloff).
**Fix**: increase FBM contrast: `density = pow(max(0, raw - threshold), 2.0)` creates sharper edges.
