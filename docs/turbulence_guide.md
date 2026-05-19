# Turbulence Guide
## From Kolmogorov to GLSL: The Physics of Procedural Gas

Turbulence is not decoration. It is the dominant physical process in the interstellar medium. Every density fluctuation, every filament, every pillar tip is a consequence of turbulence interacting with gravity, radiation, and magnetic fields. This guide explains the physics and how to implement it correctly in shaders.

---

## Why Nebulae Are Turbulent

Molecular clouds have Mach numbers M = σ_v / c_s ≈ 5–20. That means the gas is moving 5–20 times faster than the speed of sound in the gas. This is **supersonic turbulence** — a fundamentally different regime from the turbulence in your coffee cup (which is subsonic, M < 1).

Consequences:
- Shocks everywhere: turbulent compression → density fluctuations of 10–1000×
- Power law density PDF: log-normal in molecular clouds (Hopkins 2013)
- Filamentary structure: shocks intersect → dense ridges
- Self-similar structure: turbulent cascade → same statistical properties at all scales

The energy is injected at large scales (by supernovae, galactic shear) and cascades to small scales where it dissipates. The range in between is the **inertial range** — the statistically self-similar regime we model with FBM.

---

## Kolmogorov Turbulence (K41)

Andrei Kolmogorov (1941) derived the statistical properties of turbulence in the inertial range for incompressible flow. For our purposes:

**Velocity structure function**:
```
σ²(l) = ⟨|v(r+l) - v(r)|²⟩ ∝ l^(2/3)
σ(l) ∝ l^(1/3)
```

**3D Power spectrum**:
```
E(k) ∝ k^(-5/3)  (Kolmogorov)
P(k) ∝ k^(-11/3)  (3D power spectrum from E(k))
```

**Hurst exponent**: H = 1/3 (from σ ∝ l^H)

**In FBM terms**: persistence per octave = 2^(-H) = 2^(-1/3) ≈ 0.794

**Note**: standard FBM with persistence = 0.5 (H = 0.5) is **Brownian motion** — softer, smoother than Kolmogorov. For physically accurate turbulence, use persistence ≈ 0.79.

### Larson's Relations (empirical)

Bob Larson (1981) fitted molecular cloud data:
```
σ_v ∝ R^0.38     (velocity-size relation)
```

This gives H ≈ 0.38 for molecular clouds — slightly steeper than Kolmogorov. FBM persistence = 2^(-0.38) ≈ 0.770.

The difference (0.79 vs 0.77) is cosmetically small but physically significant: Larson's relation likely reflects the supersonic modification of Kolmogorov.

---

## Implementing Kolmogorov FBM in GLSL

### Standard FBM (Brownian, H = 0.5)
```glsl
float fbm(vec3 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;    // H=0.5: per-octave amplitude = 2^(-0.5) ≈ 0.707 → normalized to 0.5
    float frequency = 1.0;
    for (int i = 0; i < octaves; i++) {
        value     += amplitude * noise(p * frequency);
        amplitude *= 0.5;       // BROWNIAN: 2^(-H) = 2^(-0.5) = 0.707, but typically just 0.5
        frequency *= 2.0;
    }
    return value;
}
```

### Kolmogorov FBM (physically calibrated, H = 1/3)
```glsl
float fbmKolmogorov(vec3 p, int octaves) {
    float value = 0.0;
    float amplitude = 1.0;
    float norm = 0.0;
    float frequency = 1.0;
    for (int i = 0; i < octaves; i++) {
        value     += amplitude * noise(p * frequency);
        norm      += amplitude;
        amplitude *= 0.794;    // KOLMOGOROV: 2^(-1/3) ≈ 0.794
        frequency *= 2.0;
        p         += vec3(1.7, 9.2, 3.4);  // domain offset per octave
    }
    return value / norm;   // normalize to [0,1]
}
```

### Larson FBM (H = 0.38, molecular cloud observations)
```glsl
amplitude *= 0.770;   // 2^(-0.38) ≈ 0.770
```

---

## Curl Noise (Divergence-Free Turbulence)

Standard FBM velocity fields have divergence — the gas compresses and expands in an unphysical way. For truly incompressible flow (divergence-free), use **curl noise** (Bridson, Houriham & Nordenstam 2007).

See `code/curl_noise.glsl` for the full implementation. Key concept:

```
v = ∇ × N(p)
```

Where N(p) is a smooth vector potential field. The curl of any field is automatically divergence-free: `∇ · (∇ × N) = 0`.

### Physical significance
- div(v) = 0 means gas is incompressible at that scale
- Correct for subsonic turbulence
- For molecular clouds (supersonic, M >> 1): curl noise is an approximation.
  Real supersonic turbulence has significant compression.
- For H II regions (warm ionized gas, subsonic): curl noise is appropriate

### Multi-octave curl noise
```glsl
vec3 turbulentVelocity(vec3 p, int octaves) {
    vec3  v   = vec3(0.0);
    float amp = 1.0;
    float frq = 1.0;
    for (int i = 0; i < octaves; i++) {
        v   += amp * curlNoise(p * frq);
        amp *= 0.794;   // Kolmogorov
        frq *= 2.0;
    }
    return v;
}
```

---

## Domain Warping

Domain warping ("warp noise" or "self-similar warp") displaces the sample point before evaluating the primary FBM. This breaks the axis-aligned symmetry of standard FBM and creates more organic, filamentary structure.

```glsl
// First FBM: compute displacement field
vec3 warp = vec3(
    fbm(p * 0.8 + vec3(0.0, 0.0, 0.0)),
    fbm(p * 0.8 + vec3(5.2, 1.3, 0.0)),
    fbm(p * 0.8 + vec3(0.0, 5.2, 1.3))
);
warp = warp * 2.0 - 1.0;    // remap [0,1] → [-1,1]

// Primary FBM: sampled at warped position
float density = fbm(p + warpStrength * warp);
```

### Double domain warping
Apply the warp twice for more complex filamentary structure:
```glsl
vec3 warp1 = warpField(p);
vec3 warp2 = warpField(p + warp1);
float density = fbm(p + warp1 + warp2 * 0.5);
```

### Physical analog
Domain warping mimics the effect of large-scale velocity fluctuations displacing small-scale density structures. It's a simplified model of turbulent advection.

---

## Filament Generation from Noise Ridges

The Herschel Space Observatory (2009–2013) showed that molecular cloud structure is dominated by networks of filaments. Here is how to generate them procedurally:

### Method 1: FBM ridges
```glsl
float filamentDensity(vec3 p) {
    float f = fbm(p * freq);
    // Filaments appear where FBM ≈ 0.5 (the crests of noise)
    float ridge = 1.0 - abs(f - 0.5) * 2.0;
    return pow(max(0.0, ridge), sharpness);
}
```

`sharpness = 4.0` gives thin sharp filaments. `sharpness = 2.0` gives broader ridges.

### Method 2: Gradient magnitude → ridge width
```glsl
float filamentWidth(vec3 p) {
    float h = 0.01;
    float gx = fbm(p+vec3(h,0,0)) - fbm(p-vec3(h,0,0));
    float gy = fbm(p+vec3(0,h,0)) - fbm(p-vec3(0,h,0));
    float gz = fbm(p+vec3(0,0,h)) - fbm(p-vec3(0,0,h));
    float gradMag = length(vec3(gx,gy,gz)) / (2.0*h);
    // High gradient = filament boundary; low gradient = filament center OR empty
    // Combine with fbm value to isolate filament spines
    float f = fbm(p * freq);
    return exp(-pow(f - 0.5, 2.0) * 20.0) * exp(-gradMag * 0.5);
}
```

### Physical filament width (~0.1 pc)
Filament widths are surprisingly constant across many clouds. In a shader:
```glsl
float FILAMENT_WIDTH = 0.04;   // scene units (where cloud diameter ≈ 2.5)
// If cloud = 5 pc across, filament width = 0.04 * 5 / 2.5 = 0.08 pc ✓
```

---

## Vorticity and Density Enhancement

In turbulent flow, vorticity concentrates in thin filaments. The **Kelvin-Helmholtz instability** at shear interfaces amplifies vorticity and compresses gas.

From `code/curl_noise.glsl`:
```glsl
vec3 vorticityField(vec3 p) {
    // ω = ∇ × v
    // For curl noise v = ∇ × N:
    // ω = ∇ × (∇ × N) = ∇(∇·N) - ∇²N
    // Approximate numerically...
}
float vorticity(vec3 p) { return length(vorticityField(p)); }
```

**Using vorticity to enhance density**:
```glsl
float density = baseDensity(p) * (1.0 + vorticity(p) * VORTICITY_STRENGTH);
```

High vorticity → compressed gas → higher density. This mimics the real process where turbulent energy cascades into dense filaments.

---

## Supersonic vs. Subsonic Turbulence

|  | Subsonic (H II region) | Supersonic (molecular cloud) |
|--|------------------------|------------------------------|
| Mach number | M < 1 | M = 5–20 |
| Density PDF | Gaussian | Log-normal |
| Velocity | Curl noise (div-free) | Has compression |
| Shock structure | No shocks | Shocks everywhere |
| FBM approach | Standard H-G FBM | Kolmogorov FBM |
| Filaments | Smooth, rounded | Sharp, shock-bounded |

### Log-normal density for molecular clouds
```glsl
// Log-normal density: ln(ρ/ρ₀) ~ N(μ, σ²)
// For M = σ_v/c_s: σ² = ln(1 + b²M²) where b ≈ 0.33 (forcing parameter)
float logNormalDensity(vec3 p, float mach) {
    float sigma2 = log(1.0 + 0.11 * mach * mach);
    float sigma  = sqrt(sigma2);
    float xi     = fbm(p) * 2.0 - 1.0;    // Gaussian noise, mean 0
    float lnRho  = xi * sigma - sigma2 / 2.0;  // shifted so mean density = ρ₀
    return exp(lnRho);   // range: 0 → ∞ (most values near 1, rare high values)
}
```

This gives realistic density contrast ratios: most gas has near-average density; rare dense clumps can be 10–1000× denser.

---

## Turbulent Power Spectra and FBM Parameters

| Model | Hurst H | Persistence | FBM slope | Power spectrum |
|-------|---------|-------------|-----------|---------------|
| White noise | 0 | 0.5 | -3 | P ∝ k⁰ |
| Brownian | 0.5 | 0.707 | -4 | P ∝ k⁻² |
| Kolmogorov | 0.33 | 0.794 | -11/3 | P ∝ k^(-11/3) |
| Larson | 0.38 | 0.770 | -3.76 | P ∝ k^(-3.76) |
| Intermittent | — | varies | — | lognormal corrections |

From `code/curl_noise.glsl` and `python/reference_calculations.py`:
```python
persistence = fbm_persistence_from_hurst(H)   # = 2^(-H)
beta = power_spectrum_slope(H)                  # = 2H + 3
```

---

## Kolmogorov Velocity Scale

The velocity dispersion at scale l relative to driving scale L₀:
```
σ(l) = σ₀ × (l/L₀)^(1/3)
```

At the dissipation scale η (below which energy is thermalized):
```
σ(η) ≈ viscous velocity ~ 0.001 km/s for typical ISM
η ≈ (ν³/ε)^(1/4) ~ 10⁻⁸ pc (100 km) for ISM
```

For rendering, the FBM driving scale L₀ = largest feature in the scene. For a cloud of radius 2.5 scene units: `L₀ = 2.5`. The smallest feature = finest FBM octave.

---

## Intermittency and Coherent Structures

Real turbulence is **intermittent**: energy is not uniformly distributed but concentrated in rare violent structures (shocks, vortex tubes). This is why molecular clouds have:
- A few very dense cores (10⁵–10⁶ cm⁻³) embedded in
- Moderate density filaments (10³–10⁴ cm⁻³) embedded in
- Diffuse gas (10–100 cm⁻³)

FBM is NOT intermittent — it has a Gaussian distribution. To add intermittency:

```glsl
// Method 1: FBM squared (log-normal approach)
float density = fbm(p) * fbm(p * 2.0 + vec3(5.1));   // multiplicative cascade

// Method 2: Threshold + power law
float raw = fbm(p);
float density = raw > 0.5 ? pow(raw - 0.5, 0.5) * 5.0 : 0.0;  // rare dense peaks

// Method 3: Log of FBM
float density = exp(fbm(p) * 3.0 - 1.5);  // log-normal via exponentiation
```

Method 3 most closely matches the observed log-normal density PDF of molecular clouds.

---

## Practical Shader Recipe: Turbulent H II Region

```glsl
float nebulaDensity(vec3 p) {
    // 1. Envelope: falls off from center
    float env = pow(max(0.0, 1.0 - dot(p,p)*0.22), 1.3);

    // 2. Domain warp: breaks axis symmetry, creates filamentary structure
    vec3 warp = vec3(fbm(p*0.7 + vec3(5.2, 1.3, 0.0), 3),
                     fbm(p*0.7 + vec3(0.0, 5.2, 1.3), 3),
                     fbm(p*0.7 + vec3(1.3, 0.0, 5.2), 3)) * 0.6;

    // 3. Primary density: Kolmogorov FBM at warped position
    float base = fbmKolmogorov(p + warp, 6);

    // 4. Threshold: creates cloud boundary
    float cloud = max(0.0, base - 0.35) * env;

    // 5. High-frequency detail: surface texture
    float detail = fbm(p * 4.0, 3) * 0.15;

    return cloud * (1.0 + detail) * uDensityScale;
}
```

This produces a physically motivated turbulent H II region density field with Kolmogorov statistics, domain warping for non-axis-symmetric structure, and surface detail.
