# Astrophysics Basics
## The Real Physics Behind Nebula Rendering

This document covers the astrophysical processes modelled in this repo. Every shader has a physical basis; understanding it makes your nebulae better.

---

## 1. What Is a Nebula?

A nebula is an interstellar cloud of gas and dust. "Nebula" simply means cloud in Latin. They are the recycling centers of the galaxy:

- **Stellar nurseries**: molecular clouds where gravity overcomes thermal pressure and stars are born
- **Stellar graveyards**: planetary nebulae from dying stars; supernova remnants from violent deaths
- **Star-shaped byproducts**: H II regions lit up by the UV radiation of newly formed hot stars

### Scale
- Typical H II region diameter: 10–100 light-years (3–30 parsecs)
- Typical molecular cloud: 100–1000 light-years
- Bok globule (dense collapsing core): 0.1–1 light-year
- For rendering: scale to whatever looks good, but preserve *ratios*

---

## 2. Gas Phases of the ISM

The interstellar medium (ISM) has multiple thermal phases coexisting in pressure equilibrium:

| Phase | Temperature | Density | Tracer |
|-------|-------------|---------|--------|
| Molecular cloud | 10–30 K | 10³–10⁶ cm⁻³ | CO, H₂ |
| Cold neutral medium | 50–100 K | 10–100 cm⁻³ | H I 21cm |
| Warm neutral medium | 6000–10000 K | 0.1–1 cm⁻³ | H I |
| H II region (ionized) | 8000–10000 K | 1–100 cm⁻³ | H-alpha, O-III |
| Coronal gas | 10⁶ K | < 0.001 cm⁻³ | X-ray |

In rendering: molecular cloud = dense dark regions; H II region = glowing colored gas.

---

## 3. Emission Lines

Nebulae glow not as blackbodies but through discrete spectral lines:

### Hydrogen (most abundant element, ~74% by mass)
- **H-alpha** (Hα): 656.3 nm — deep red. Recombination line: e⁻ + H⁺ → H + photon. Strongest optical line in H II regions.
- **H-beta** (Hβ): 486.1 nm — blue-green. Weaker; used for extinction correction.
- **Lyman-alpha** (Lyα): 121.6 nm — UV. Resonance line; absorbed and re-emitted many times (scattering).

### Oxygen
- **[O III] 500.7 + 495.9 nm**: doublet, teal/green. "Forbidden" transition. Indicates hot, low-density ionized gas. The classic nebula teal.
- **[O I] 630.0 nm**: red. Neutral oxygen at ionization front boundary.
- **[O II] 372.7 nm**: UV doublet. Traces denser ionized gas.

### Sulfur
- **[S II] 671.6 + 673.1 nm**: red doublet. Traces warm neutral/partially ionized gas at the ionization front edge. Hubble palette "red channel."
- **[S III] 906.9, 953.1 nm**: near-infrared.

### Nitrogen
- **[N II] 654.8 + 658.4 nm**: red, very close to H-alpha. Traces similar regions to S II.

### The Forbidden Transition
Lines in brackets like [O III] are "forbidden" — they occur via magnetic dipole or electric quadrupole transitions disallowed by quantum selection rules in the lab. In the ISM they're allowed because the density is so low (collisional de-excitation is rare) that the long-lived excited state has time to radiate. Typical "critical densities" are 10²–10⁶ cm⁻³.

---

## 4. Volume Rendering Equation

The fundamental integral:

```
I(λ) = ∫₀ᴰ  j(s,λ) · exp( -∫₀ˢ κ(s',λ) ds' ) ds
```

Where:
- `I(λ)`: specific intensity along ray at wavelength λ
- `j(s,λ)`: volume emissivity at position s along ray
- `κ(s,λ)`: extinction coefficient (absorption + scattering)
- `exp(-∫κ ds)` = transmittance (Beer-Lambert law)

In GLSL (discretized):
```glsl
color       += transmittance * emission * stepSize;
transmittance *= exp(-extinction * stepSize);
```

**Critical**: always apply emission BEFORE updating transmittance within the same step (front-to-back compositing), or you introduce bias.

---

## 5. Dust: Absorption and Scattering

Interstellar dust grains (silicates and carbonaceous particles, 0.005–1 μm) do two things:

### Absorption
Dust absorbs photons and re-emits in infrared. Described by absorption cross-section σ_abs(λ). Causes "extinction" — stars behind dust appear fainter AND redder.

### Scattering (Mie regime)
Dust scatters photons. The scattered intensity depends on:
- **Phase function** p(θ): probability of scattering into angle θ
- **Asymmetry parameter g**: g=0 isotropic, g≈0.6 for ISM dust (forward-preferred)
- **Wavelength dependence**: blue scattered more than red → reflection nebulae look blue

The **Henyey-Greenstein** phase function is the standard approximation:
```
p(θ) = (1 - g²) / [4π (1 + g² - 2g·cosθ)^(3/2)]
```

### Dust-to-Gas Ratio
ISM standard: ≈ 1:100 by mass (δ/ρ_gas ≈ 0.01). In H II regions the dust has been partially destroyed by the UV field, so δ may be lower by 2–3×. In molecular clouds dust dominates the visual opacity.

### Reddening
E(B-V) = selective extinction. For ISM: Aᵥ ≈ 3.1 × E(B-V). Every 3 magnitudes of Vband extinction halves the optical depth through the cloud. One magnitude of visual extinction corresponds to ~1.8 × 10²¹ H atoms cm⁻².

---

## 6. Ionization Structure

### Strömgren Sphere
A hot star (T > ~25,000 K) emits copious UV photons above 13.6 eV (the hydrogen ionization energy). These photons ionize surrounding H gas out to the **Strömgren radius**:

```
R_S = [ 3·Q_H / (4π·α_B·nH²) ]^(1/3)
```

Where:
- Q_H: ionizing photon luminosity (s⁻¹). For an O3 star: ~10⁵⁰ s⁻¹.
- α_B: Case B recombination coefficient ≈ 2.6×10⁻¹³ cm³/s (at 10⁴ K)
- nH: hydrogen number density

Example: O5 star, nH = 100 cm⁻³ → R_S ≈ 10 pc (30 light-years).

### Ionization Front Types
- **R-type** (rarefied): front moves supersonically through gas. Gas doesn't know it's coming. Thin, sharp boundary. Common at early nebula stages.
- **D-type** (dense): front slowed to sonic/subsonic speed. Gas piles up ahead in a dense shell. Drives shock into surrounding neutral cloud. The **Pillars of Creation** are D-type fronts — the pillars are gas columns being photoevaporated from the outside in.

---

## 7. Turbulence in Molecular Clouds

Molecular cloud turbulence is supersonic (Mach numbers M ~ 5–20) and is the dominant pressure support against gravitational collapse.

### Kolmogorov Scaling
In the inertial range: velocity structure function `σ_v(l) ∝ l^(1/3)`.
Energy spectrum: `E(k) ∝ k^(-5/3)`.
In FBM terms: persistence = 0.5 gives Hurst exponent H = 0.5 ≈ close but Kolmogorov is H = 1/3. Use `amplitude *= 0.63` per octave for a more accurate Kolmogorov cascade.

### Larson's Relations (1981)
Observational fits:
- σ_v ∝ R^0.38  (velocity-size relation)
- M ∝ R^1.97    (mass-size relation)
- σ_v ∝ M^0.2  (velocity-mass relation)

These give filament widths of ~0.1 pc and imply star formation efficiency ~1–2% per free-fall time.

### Jeans Instability
Collapse occurs when gravity overcomes thermal pressure:
```
M > M_Jeans = (5kT / GmH)^(3/2) · (3/4π·ρ)^(1/2)
```
For T=10K, nH=10⁴ cm⁻³: M_Jeans ≈ 1 M☉ — just right to form a sun.

---

## 8. Star Formation Feedback

Newly formed stars are not passive inhabitants of the cloud; they reshape it violently:

| Feedback type | Effect | Timescale |
|---------------|--------|-----------|
| Photoionization | Creates H II region, expands Strömgren sphere | 10⁴–10⁶ yr |
| Stellar winds | Blows bubbles, creates wind-blown shells | 10⁶ yr |
| Radiation pressure | Drives dusty gas outward | Throughout |
| Supernovae | Blast wave, shreds cloud, triggers new SF | 3–30 Myr |
| Protostellar jets | Bipolar outflows punch through dense gas | 10⁴–10⁵ yr |

The **self-regulation** of star formation: feedback eventually destroys the molecular cloud that formed the stars, limiting star formation efficiency to ~2–5% of the original cloud mass.

---

## 9. Protoplanetary Disks and Proplyds

Inside dense Bok globules, protostellar disks form from angular momentum conservation during collapse:
- Disk radius: 10–1000 AU (astronomical units; 1 AU = Earth-Sun distance)
- Disk mass: ~1–10% of stellar mass
- Lifetime: ~3–5 Myr before photoevaporation

**Proplyds** (protoplanetary disks being photoevaporated by nearby O stars) are seen in the Orion Nebula as teardrop-shaped comet-like structures. The ionization front wraps around the disk like a bow shock.

---

## 10. Color Palettes in Real Astronomy

### True Color
What your eye would see: very dark, mostly reddish (H-alpha), with some teal (O-III) around hot regions.

### Hubble Palette (SHO → RGB)
- S-II (672 nm) → Red channel
- H-alpha (656 nm) → Green channel
- O-III (501 nm) → Blue channel
This produces the iconic teal-gold-pink nebulae because: where O-III > H-alpha, the result is teal-cyan; where H-alpha > O-III, it's yellow-green.

### "Natural" False Color
H-alpha → red, O-III → blue, H-beta → blue (mixed). More intuitive than Hubble palette.

### JWST Palette
James Webb uses near-infrared: F090W (0.9μm) → blue, F187N (Pa-alpha, 1.87μm) → green, F470N (H₂ + CO, 4.7μm) → red. Shows embedded protostars invisible to Hubble.

---

## Key Numbers to Know

| Quantity | Value |
|---------|-------|
| H-alpha wavelength | 656.3 nm |
| [O III] wavelength | 500.7 nm |
| [S II] wavelength | 671.6 / 673.1 nm |
| Electron temperature in H II region | 8000–10000 K |
| Molecular cloud temperature | 10–30 K |
| Speed of ionization front (R-type) | > 20 km/s |
| Sound speed in H II region | ~11 km/s |
| Dust-to-gas ratio (ISM) | ~1:100 by mass |
| H-G asymmetry parameter g (ISM dust) | ~0.6 |
| Strömgren radius (typical) | 1–30 pc |
| Hubble constant | 70 km/s/Mpc (not relevant here but always know this) |
