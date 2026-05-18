// mie_scattering.glsl
// Mie scattering phase function and wavelength-dependent dust opacities.
//
// Mie scattering: elastic scattering of EM radiation by particles whose
// diameter is comparable to the wavelength (d ~ λ).  Interstellar dust
// grains range from ~0.005 μm to ~1 μm, so visible light (0.4–0.7 μm)
// falls firmly in the Mie regime.
//
// Key properties vs Rayleigh:
//   - Rayleigh (d << λ): σ ∝ λ⁻⁴  →  very strong blue preference
//   - Mie      (d ~ λ) : σ ∝ λ⁻¹…²  →  gentler wavelength dependence
//   - Mie is strongly FORWARD-scattering (g ≈ 0.6–0.9 for dust)
//   - Combined gives "reddening": blue scattered away, red transmitted
//
// Usage: #include this file (or copy into your shader), then call
//   henyeyGreenstein(cosTheta, g)    — normalized phase function
//   mieExtinction(lambda, grainSize) — relative extinction coefficient
//   mieColor(incidentColor, density, pathLength, g) — scattered + reddened color
//
// References:
//   Henyey & Greenstein 1941, ApJ 93, 70
//   Draine 2003, ARA&A 41, 241  (interstellar dust review)

// ── Henyey-Greenstein phase function ─────────────────────────────────────────
// cosTheta: cos of angle between incident and scattered directions
// g:        asymmetry parameter.  0=isotropic, 0.6=typical dust, 0.9=large grain
// Returns:  normalized probability density [sr⁻¹], integrates to 1 over sphere
float henyeyGreenstein(float cosTheta, float g) {
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * cosTheta;
    return (1.0 - g2) / (4.0 * 3.14159265 * pow(max(denom, 1e-6), 1.5));
}

// Double Henyey-Greenstein (better fit to real dust: forward + weak backscatter)
// f: weight of forward lobe [0,1], usually ~0.9 for interstellar dust
float doubleHG(float cosTheta, float gFwd, float gBack, float f) {
    return f * henyeyGreenstein(cosTheta, gFwd)
         + (1.0 - f) * henyeyGreenstein(cosTheta, -abs(gBack));
}

// ── Wavelength-dependent extinction ──────────────────────────────────────────
// Simplified power-law: κ ∝ (a/λ)^alpha
//   lambda:    wavelength in microns (0.4=blue, 0.55=green, 0.7=red)
//   grainSize: effective grain radius in microns (ISM: 0.1–0.3 μm typical)
//   alpha:     size parameter determines regime (2=Mie, 4=Rayleigh limit)
float mieExtinction(float lambda, float grainSize) {
    float x = 2.0 * 3.14159 * grainSize / lambda;   // Mie size parameter

    float alpha;
    if (x < 1.0) {
        alpha = 4.0;                 // Rayleigh regime: d << λ → σ ∝ λ⁻⁴
    } else if (x < 10.0) {
        alpha = mix(4.0, 1.0, (x - 1.0) / 9.0);  // Mie transition
    } else {
        alpha = 1.0;                 // geometric optics: σ ≈ constant
    }

    return pow(grainSize / lambda, alpha);
}

// ── RGB extinction vector ─────────────────────────────────────────────────────
// Returns relative extinction for (R=0.65μm, G=0.55μm, B=0.44μm)
// normalized so G = 1.0
vec3 dustExtinctionRGB(float grainSize) {
    float extR = mieExtinction(0.65, grainSize);
    float extG = mieExtinction(0.55, grainSize);
    float extB = mieExtinction(0.44, grainSize);
    // Normalize to green
    return vec3(extR, extG, extB) / max(extG, 1e-6);
}

// ── Beer-Lambert transmittance with wavelength-dependent extinction ────────────
// incidentColor: RGB color of light before dust column
// density:       local dust number density (arbitrary units)
// pathLength:    distance traveled through dust [same units as density]
// grainSize:     grain radius in microns
vec3 dustTransmittance(vec3 incidentColor, float density, float pathLength, float grainSize) {
    vec3 extinctionRGB = dustExtinctionRGB(grainSize);
    vec3 tau = extinctionRGB * density * pathLength;   // optical depth per channel
    return incidentColor * exp(-tau);
}

// ── In-scattering contribution ────────────────────────────────────────────────
// Computes the scattered-in color contribution from a point light (starlight)
// lightDir: unit vector FROM sample point TOWARD light
// viewDir:  unit vector FROM sample point TOWARD viewer
// lightColor: incident light color
// density:  local dust density
// g:        HG asymmetry (0.6 typical dust)
vec3 dustInScatter(vec3 lightDir, vec3 viewDir, vec3 lightColor,
                   float density, float g, float grainSize) {
    float cosTheta = dot(-viewDir, lightDir);   // angle between view and light
    float phase    = doubleHG(cosTheta, g, 0.2, 0.9);

    // Wavelength-dependent scattering albedo (small grains scatter blue more)
    vec3 scatterAlbedo = dustExtinctionRGB(grainSize);
    scatterAlbedo /= max(scatterAlbedo.x + scatterAlbedo.y + scatterAlbedo.z, 1e-6);
    scatterAlbedo = normalize(scatterAlbedo) * 0.6;   // total albedo ~0.5-0.6 for ISM dust

    return lightColor * scatterAlbedo * phase * density;
}

// ── Polarization degree (bonus: Mie gives partial polarization) ───────────────
// Returns degree of linear polarization P = (I_perp - I_par)/(I_perp + I_par)
// Simplified Rayleigh-Mie interpolation
float scatteringPolarization(float cosTheta, float g) {
    // Exact for Rayleigh: P = sin²θ / (1 + cos²θ)
    float sinSq   = 1.0 - cosTheta * cosTheta;
    float rayleighP = sinSq / (1.0 + cosTheta * cosTheta + 1e-6);

    // Mie reduces polarization toward forward peak (g → 1 → P → 0)
    float mieFactor = 1.0 - g * g;
    return rayleighP * mieFactor;
}

// ── Example usage in a raymarcher step ────────────────────────────────────────
// Call this inside your integration loop:
//
// vec3 stepContribution(vec3 p, vec3 rd, vec3 lightPos, vec3 lightColor,
//                       float density, float stepSize) {
//     vec3  toLight = normalize(lightPos - p);
//     float g        = 0.6;                     // ISM dust asymmetry
//     float grain    = 0.1;                     // 0.1 μm grain radius
//
//     // Emission (gas glows independently)
//     vec3 emission  = gasEmission(p, density) * stepSize;
//
//     // Scattering of starlight
//     vec3 scattered = dustInScatter(toLight, rd, lightColor, density, g, grain) * stepSize;
//
//     // Extinction along this step
//     vec3 extinction = dustExtinctionRGB(grain) * density * stepSize;
//     float transmittance = exp(-dot(extinction, vec3(0.299, 0.587, 0.114)));  // luminance-weighted
//
//     return (emission + scattered) * transmittance;
// }
