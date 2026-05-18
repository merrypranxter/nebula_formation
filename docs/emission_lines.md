# Emission Lines Reference
## Spectral Data for Nebula Rendering

The color of a nebula is physics, not taste. Every hue is a specific atomic transition at a specific temperature and density. This document gives the spectral data you need to render nebulae accurately — or to know exactly which rules you're breaking when you don't.

---

## Primary Optical Emission Lines

| Ion | Wavelength (nm) | Color | Physical origin | Critical density (cm⁻³) |
|-----|----------------|-------|-----------------|------------------------|
| H-alpha | 656.28 | Deep red | H recombination n=3→2 | ∞ (not forbidden) |
| H-beta | 486.13 | Blue-green | H recombination n=4→2 | ∞ |
| H-gamma | 434.05 | Violet | H recombination n=5→2 | ∞ |
| [O III] | 500.68 | Teal-green | Forbidden O²⁺ ¹D₂→³P₁ | 6.8 × 10⁵ |
| [O III] | 495.89 | Teal-green | Forbidden O²⁺ ¹D₂→³P₀ | 6.8 × 10⁵ |
| [O I] | 630.03 | Red-orange | Forbidden O⁰ ¹D₂→³P₂ | 1.8 × 10⁶ |
| [N II] | 658.34 | Red | Forbidden N⁺ ¹D₂→³P₂ | 8.6 × 10⁴ |
| [N II] | 654.80 | Red | Forbidden N⁺ ¹D₂→³P₁ | 8.6 × 10⁴ |
| [S II] | 671.64 | Dark red | Forbidden S⁺ ²D₃/₂→⁴S₃/₂ | 1.5 × 10³ |
| [S II] | 673.08 | Dark red | Forbidden S⁺ ²D₅/₂→⁴S₃/₂ | 3.9 × 10³ |
| [S III] | 906.86 | Near-IR | Forbidden S²⁺ | 1.5 × 10⁴ |
| [Ar III] | 713.58 | Deep red | Forbidden Ar²⁺ | 1.3 × 10⁵ |
| He I | 587.56 | Yellow (D3) | Helium singlet | not forbidden |
| He II | 468.57 | Blue | He⁺ recombination n=4→3 | not forbidden |

**Note on forbidden lines**: brackets [X] indicate forbidden transitions. They occur only at ISM densities because collisional de-excitation is too rare to compete with radiative decay. In the lab you'd never see them.

---

## RGB Approximate Colors

For rendering purposes, here are the approximate sRGB values for each major line (assuming monochromatic source through human photopic response):

| Line | Wavelength | Approx sRGB | GLSL vec3 |
|------|-----------|-------------|-----------|
| H-alpha | 656 nm | (220, 20, 30) | vec3(0.86, 0.08, 0.12) |
| [N II] | 658 nm | (210, 15, 25) | vec3(0.82, 0.06, 0.10) |
| [S II] | 672 nm | (180, 10, 15) | vec3(0.71, 0.04, 0.06) |
| [O I] | 630 nm | (240, 70, 10) | vec3(0.94, 0.27, 0.04) |
| He I | 588 nm | (255, 180, 0) | vec3(1.00, 0.71, 0.00) |
| [O III] 501 | 501 nm | (10, 210, 180) | vec3(0.04, 0.82, 0.71) |
| H-beta | 486 nm | (30, 150, 255) | vec3(0.12, 0.59, 1.00) |
| He II | 469 nm | (30, 80, 230) | vec3(0.12, 0.31, 0.90) |
| H-gamma | 434 nm | (100, 40, 200) | vec3(0.39, 0.16, 0.78) |

---

## Hubble Palette Mapping (SHO → RGB)

The Space Telescope Science Institute's "Hubble palette" maps three narrowband filters:

```
RED   = [S II] 672 nm
GREEN = H-alpha 656 nm
BLUE  = [O III] 501 nm
```

**Why this creates teal/gold**: 
- Regions where O-III is strong relative to H-alpha → strong blue+green → **teal/cyan**
- Regions where S-II and H-alpha dominate → red+green → **yellow/gold**
- Dense pillar tips (S-II dominant, no O-III) → **red/rust**
- Hot thin ionized gas skins → high O-III → **bright teal**

GLSL implementation:
```glsl
vec3 hubblePalette(float sii, float halpha, float oiii) {
    return vec3(sii, halpha, oiii);  // that's literally it
}
```

The magic is in the *physics* of where each ion lives, not the mapping.

---

## Emission Temperature Diagnostics

### [O III] Temperature Diagnostic
The ratio of the auroral line (436.3 nm) to the nebular doublet (495.9+500.7 nm) gives electron temperature:

```
T_e ≈ 1.432 × 10⁴ K / [ ln(0.00333 × R⁻¹) ]
where R = I(436.3) / I(495.9+500.7)
```

Typical values: R ≈ 0.01–0.1 → T_e ≈ 8000–15000 K.

### [S II] Density Diagnostic
The ratio of the doublet lines gives electron density:

```
I(671.6) / I(673.1) → ne
Low ratio (~0.6) → ne > 10⁴ cm⁻³ (high density)
High ratio (~1.4) → ne < 100 cm⁻³ (low density)
```

### In shaders: temperature/density → color
```glsl
vec3 emissionByTemperature(float ne, float Te) {
    // High Te → more O-III (collisional excitation needs kT > 2.5 eV)
    float oiii_frac = smoothstep(6000.0, 12000.0, Te);
    // High ne → suppress forbidden lines (collisional de-excitation)
    float forbid_suppress = 1.0 / (1.0 + ne / 1000.0);
    
    vec3 halpha = vec3(0.86, 0.08, 0.12);
    vec3 oiii   = vec3(0.04, 0.82, 0.71);
    
    return mix(halpha, oiii, oiii_frac) * forbid_suppress;
}
```

---

## Near-Infrared and UV Lines (JWST relevance)

JWST opens up wavelengths Hubble couldn't reach well:

| Line | Wavelength | Significance |
|------|-----------|--------------|
| Paschen-alpha (Pa-α) | 1875 nm | H recombination, traces embedded HII regions |
| Paschen-beta (Pa-β) | 1282 nm | Similar, less obscured than H-alpha |
| Brackett-gamma (Br-γ) | 2166 nm | Deeply embedded star formation |
| H₂ 1-0 S(1) | 2122 nm | Warm molecular hydrogen (PDR tracer) |
| [Fe II] | 1644 nm | Shock tracer (supernova remnants, jets) |
| CO 2-0 bandhead | 2294 nm | Cold molecular gas |

---

## Spectral Energy Distributions by Nebula Type

### H II Region (e.g., Orion, Carina)
Dominant: H-alpha >> [O III] > [N II] > [S II]
Color perception (natural): pink-red glow with teal halos

### Planetary Nebula (e.g., Ring, Helix)
Dominant: [O III] >> H-alpha (if hot central star)
Color perception: bright teal/blue-green with red outer ring (H-alpha)
Central star: He II if T* > 50,000 K → blue point source

### Supernova Remnant (e.g., Crab, Veil)
- Young SNR: [O III], [Ne III], X-ray dominant
- Old SNR: [S II] prominent (slower, denser shocked gas)
- Pulsar wind nebula: synchrotron continuum (non-thermal, blue-white)

### Reflection Nebula (e.g., Pleiades nebula)
No emission lines — pure scattered starlight.
Color: blue (Rayleigh scattering of stellar photons off dust).
The blue is NOT [O III] — it's genuinely scattered starlight.
Spectrum = stellar spectrum + scattering efficiency function (∝ λ⁻⁴ for small grains).

### Dark Nebula (e.g., Horsehead, Barnard 68)
No emission, no reflection — pure absorption.
Color: black silhouette against background.
Boundary: sharpest dust feature in astronomy (sub-arcsecond edges possible).

---

## Interstellar Extinction Curves

The ratio A(λ)/A(V) tells you how much more you're extincted at wavelength λ vs V-band:

| λ (nm) | A(λ)/A(V) | R_V = 3.1 | Region |
|--------|-----------|-----------|--------|
| 912 | ~8.0 | Lyman limit | UV |
| 365 (U) | 1.57 | Standard ISM | |
| 440 (B) | 1.32 | | |
| 550 (V) | 1.00 | Reference | |
| 640 (R) | 0.75 | | |
| 800 (I) | 0.48 | | |
| 1220 (J) | 0.29 | Near-IR | |
| 2200 | 0.11 | | |

**R_V** varies with environment:
- R_V = 3.1: standard diffuse ISM
- R_V = 5–6: dense molecular clouds (larger grains, less reddening per extinction)

**In GLSL**: apply per-wavelength extinction:
```glsl
vec3 extinguish(vec3 rgb, float A_V, float R_V) {
    // Approximate relative extinctions for R, G, B channels
    vec3 A_lambda = vec3(0.75, 1.0, 1.32) * A_V / R_V;
    return rgb * exp(-A_lambda);
}
```

---

## H-alpha Luminosity and Star Formation Rate

The H-alpha luminosity of an H II region directly traces the ionizing photon rate, which traces the star formation rate (SFR):

```
SFR (M☉/yr) = 7.9 × 10⁻⁴²  ×  L(H-alpha) (erg/s)
```

For the Orion Nebula: L(H-alpha) ≈ 4 × 10³⁶ erg/s → SFR ≈ 3 × 10⁻⁶ M☉/yr.
Not much — but it's one molecular cloud. Scale to galaxy: ~1 M☉/yr for the Milky Way.

This is how astronomers measure star formation rates across the universe. The red glow of H-alpha = stars being born in real time.
