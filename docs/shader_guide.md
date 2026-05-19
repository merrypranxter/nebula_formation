# Shader Guide
## Using Every Shader in This Repository

This guide tells you exactly what each shader does, what its parameters control, and how to combine them. Every shader is a standalone WebGL fragment shader usable in the included viewer or in your own engine.

---

## Quick Reference

| Shader | Type | Highlights |
|--------|------|-----------|
| `basic_nebula.glsl` | H II region | Fractal FBM density, H-alpha + O-III emission |
| `hubble_palette.glsl` | H II region | SHO false-color, three ion channels |
| `dust_and_stars.glsl` | Reflection + stars | Mie scattering, point stars with halos |
| `supernova_shell.glsl` | SNR | Sedov-Taylor expanding shell, R-T instability |
| `living_nebula.glsl` | H II (animated) | Time-evolving ionization front |
| `emotional_nebula.glsl` | Abstract | Internal state → physical parameters |
| `sacred_nebula.glsl` | Artistic | Pillars of Creation + sacred geometry overlay |
| `glitch_nebula.glsl` | Glitch art | Data corruption aesthetics applied to gas |
| `biological_nebula.glsl` | Biological | Lungs / brain / womb / corpse modes |
| `reflection_nebula.glsl` | Reflection | Pure Rayleigh/Mie dust scatter, no emission lines |
| `planetary_nebula.glsl` | PN | Concentric shells, bipolar, cometary knots |
| `dark_nebula.glsl` | Dark | Horsehead silhouette, Bok globules |
| `proplyd.glsl` | Proplyd | Photoevaporating protoplanetary disks |
| `quantum_nebula.glsl` | Abstract | Superposition, entanglement, tunneling |
| `bipolar_nebula.glsl` | YSO | Herbig-Haro jets, bow shocks |
| `molecular_cloud.glsl` | Molecular | Filamentary cloud, dense cores |
| `filament_nebula.glsl` | Molecular | Multi-scale ISM filament web |

---

## Uniform Reference

All shaders support a shared uniform interface. Not every uniform is used by every shader — the `setUniform` call in the viewer is silently ignored if the uniform doesn't exist.

| Uniform | Type | Range | Meaning |
|---------|------|-------|---------|
| `uResolution` | vec2 | — | Canvas size in pixels |
| `uTime` | float | 0 → ∞ | Seconds since start |
| `uDensityScale` | float | 0.1 – 5.0 | Overall cloud density multiplier |
| `uTurbulence` | float | 0 – 3.0 | FBM turbulence frequency scale |
| `uEmission` | float | 0.1 – 5.0 | Emission/scatter brightness multiplier |
| `uDustOpacity` | float | 0 – 2.0 | Dust extinction multiplier |
| `uStarCount` | int | 0 – 50 | Number of rendered stars |
| `uEvolutionSpeed` | float | 0 – 1.0 | Time evolution rate (nebula age) |
| `uSacredOverlay` | float | 0 – 1.0 | Sacred geometry overlay strength |
| `uGlitchAmount` | float | 0 – 1.0 | Glitch distortion intensity |
| `uTemperatureRange` | float | 3000 – 200000 | Central source temperature in K |

---

## Shader Deep Dives

### basic_nebula.glsl

The foundation. Everything else builds on this.

**Density model**: FBM (fractal Brownian motion) with 6 octaves. Envelope is a smooth global falloff (power of distance). Domain-warped for extra complexity — a second FBM displaces the sample point before the primary FBM evaluation.

**Emission**: Two-channel. H-alpha (red) at the inner dense regions, [O III] (teal) at lower densities where the gas is hotter and more ionized. Mix controlled by density:
```glsl
float oiii_frac = 1.0 - smoothstep(0.3, 0.8, density);
color = mix(HALPHA, OIII, oiii_frac);
```

**Raymarcher**: 80 steps × 0.05 step size. Front-to-back compositing:
```glsl
color     += transmittance * emission * stepSize;
transmittance *= exp(-extinction * stepSize);
```

**Parameters to tune**:
- `uDensityScale 0.5`: wispy, thin — reflection nebula aesthetic
- `uDensityScale 2.0`: dense opaque cloud — dark nebula core aesthetic
- `uTurbulence 0.3`: smooth large-scale structure
- `uTurbulence 2.5`: highly fragmented, chaotic

---

### hubble_palette.glsl

Implements the SHO (Sulfur-Hydrogen-Oxygen) narrowband color mapping used by HST scientists.

**Three density channels** computed separately, each with its own ionization physics:
- **S-II density**: peaks at the PDR (partially ionized zone) just outside the Strömgren sphere. Low ionization fraction, moderate temperature.
- **H-alpha density**: peaks throughout the ionized region. Follows recombination rate ∝ n_e × n_p × α_Hα.
- **O-III density**: peaks at high-ionization inner region. Requires T > ~8000 K AND low density (forbidden line: quenched at n > 6.8×10⁵ cm⁻³).

**Color mapping**:
```glsl
vec3 hubblePalette(float sii, float halpha, float oiii) {
    return vec3(sii, halpha, oiii);  // S→R, Ha→G, O→B
}
```

The teal-gold characteristic pattern emerges from WHERE each ion lives, not from the mapping. You don't choose the colors; the ionization physics chooses them for you.

---

### dust_and_stars.glsl

The showpiece for Mie scattering physics.

**Dust scattering**: Henyey-Greenstein phase function with wavelength-dependent scattering cross-section. Blue scatters more than red (Rayleigh limit for small grains). Creates the characteristic blue tint of reflection nebulae.

**Point stars**: Stars are rendered as analytical Gaussian blooms. Each has:
- Position from hash-seeded random
- Temperature-dependent color (Wien's law approximation)
- Distance halo: exponential falloff with a secondary broader Gaussian for the diffraction spike approximation

**When to use**: When you want a nebula that shows real starlight illumination — not self-luminous gas, but scattered starlight.

---

### supernova_shell.glsl

The death that fertilizes the next generation.

**Sedov-Taylor dynamics**: Shell radius scales as `R ∝ t^0.4`. As time advances (`uEvolutionSpeed`), the shell expands. Shell velocity `V = 0.4 R/t` decreases as the shell sweeps up mass.

**Rayleigh-Taylor instabilities**: The decelerating shell is R-T unstable. Dense shell material falls inward, forming fingers. Implemented as FBM perturbation of the shell radius in the direction of the surface normal:
```glsl
float rt_perp = fbm(normalize(p) * 3.0) * 0.15;
float shell = exp(-pow(r - rShell - rt_perp, 2.0) / shellThickness);
```

**Interior vs shell emission**:
- Shell (compressed swept-up material): H-alpha + [O III]
- Interior (hot shocked ejecta): [O III] dominant, blue-white
- Pulsar wind nebula center (if present): synchrotron purple

---

### living_nebula.glsl

Time as a physics variable, not just an animation clock.

**Evolution stages** controlled by `uEvolutionSpeed`:
- Phase 0: dense neutral cloud, no emission
- Phase 1: first stars ignite, R-type ionization front races outward
- Phase 2: D-type front slows, pillars form
- Phase 3: stellar winds blow bubbles, pillar tips evaporate
- Phase 4: feedback destroys the cloud

**Interpolation**: each phase transition is smooth, using `smoothstep` on the age parameter. The visual transitions mimic real H II region evolution observed in clusters from ~0.1 Myr (buried protostar) to ~5 Myr (dispersed H II region).

---

### emotional_nebula.glsl

Physics as emotional vocabulary. See `docs/artistic_cosmology.md` for the theoretical framework.

**Eight states**, each with distinct density function, color palette, and dynamical behavior:
- AWE: vast diffuse shell, silent expansion
- GRIEF: dark absorption, faint reddened H-alpha
- RAGE: chaotic turbulence, shock fronts, saturated [O I]
- JOY: bright diffuse emission, multiple stars firing
- FEAR: dense Bok globule, contraction, no emission
- TENDERNESS: warm low-density H II glow, faint stellar halos
- DISSOLUTION: expanding remnant, fading transmittance
- BECOMING: protostellar core collapsing, ignition flash

---

### sacred_nebula.glsl

Astrophysics as sacred geometry.

**Pillars of Creation base**: D-type ionization front geometry with three distinct pillars. Physically: elongated dense gas columns being photoevaporated.

**Sacred geometry overlay** (`uSacredOverlay` [0,1]):
- At 0: pure physical pillars
- At 0.5: Fibonacci spiral and golden ratio structure visible in the emission pattern
- At 1.0: full icosahedron vertex structure, Flower of Life pattern, the nebula as mandala

The sacred geometry is not an overlay drawn on top — it modulates the density field, so the gas itself follows sacred proportions.

---

### glitch_nebula.glsl

The nebula as corrupted data.

**Glitch techniques applied to astrophysics**:
- Bit-shift density: density values quantized and bit-rotated at random intervals
- Scanline corruption: horizontal bands of density remapped or dropped
- Color channel displacement: R, G, B channels sampled from offset positions
- Repeat artifact: tile repetition with phase offset (like corrupted video)
- The underlying gas is still physical — the glitch is the transmission error, not the source

**`uGlitchAmount`**: 0 = clean nebula, 1 = fully corrupted. The transition is nonlinear — glitches appear suddenly as thresholds are crossed, just like real data corruption.

---

### biological_nebula.glsl

Four anatomical modes, cycling with time or driven by `uEvolutionSpeed`.

**Mode cycling**: `bioPhase(t)` returns [0,4), each unit = one biological mode. Mode 0–1 = lungs, 1–2 = brain, 2–3 = womb, 3–4 = corpse. Modes blend smoothly at transitions.

**Lungs**: Alveolar void subtraction from gas field. Bronchial tube cylinders. Breathing phase modulates void size. Physical analog: the foam of a reflection nebula / molecular cloud interface.

**Brain**: Neural filament ridges found via |FBM - 0.5| edge detection. Synaptic nodes: hash-seeded bright points with random firing phase. Physical analog: cosmic web filaments; galaxy cluster nodes.

**Womb**: Amniotic gas envelope + Bok globule "eggs" that collapse with time. Protostar ignition when collapse factor high. Physical analog: Bok globule star formation.

**Corpse**: Sedov-Taylor supernova shell as exploded organ. Rayleigh-Taylor fingers. Scattered ejecta clumps. Hot synchrotron interior. Physical analog: Cas A supernova remnant.

---

### reflection_nebula.glsl

The only shader with **no emission lines**. Everything is scattered starlight.

**Key physics**:
- `scatterColor(grainSize)`: returns RGB scattering efficiency, blue >> red for small grains
- `dustPhase(cosTheta, grainSize)`: Henyey-Greenstein with grain-size-dependent asymmetry
- `shadowTransmittance()`: coarse 8-step shadow ray to simulate self-shadowing

**Illuminating star**: off-center, slowly drifting. This demonstrates how the nebula appearance changes with illumination angle — bright forward-scatter lobe points toward the star; backscatter is fainter and less blue.

**Grain size effect**:
- 0.05 μm: very blue (Rayleigh), isotropic scatter
- 0.2 μm: moderately blue, forward-preferring
- 0.5 μm: nearly grey, strongly forward-peaked

---

### planetary_nebula.glsl

A star's death as concentric geometry.

**Bipolar geometry**: `shellRadius_polar()` implements an ellipsoidal shell whose polar-to-equatorial ratio is controlled by `bipolar` parameter. Most real planetary nebulae are bipolar (probably due to binary companions or magnetic fields).

**Three shells**:
1. Inner hot torus (fast post-AGB wind)
2. Main bright ellipsoidal shell (compressed slow wind)
3. Outer halo (ancient AGB mass loss)

**Cometary knots**: 12 evaporating globules embedded in the main shell. Each has a dense "head" and a fainter "tail" pointing toward the central star. These are real features of the Helix Nebula.

**Color stratification**: ionization-parameter gradient from center outward:
- Central white dwarf region: He II blue-violet (T* = `uTemperatureRange`)
- Middle: [O III] teal
- Outer ring: H-alpha red

---

### dark_nebula.glsl

Presence through absence.

**The technique**: the shader renders ONLY what the dark nebula blocks. The background (H II region glow + stars) is computed; the cloud is pure extinction.

**Horsehead pillar**: vertical cylindrical protrusion from a broad dark base. Top is rounded. FBM textures the surface for realistic edge raggedness.

**Bok globules**: three separate spherical absorption kernels placed at offset positions. Each is a Gaussian density peak with very high opacity.

**Star field**: 40 background stars rendered at z = -3.0, attenuated by the accumulated dust column between them and the camera. Blue stars get attenuated more (differential reddening).

**The aesthetic**: the darker the shadow, the denser the star-forming gas. Absolute darkness = stellar birth.

---

### proplyd.glsl

Four protoplanetary disks simultaneously, each at a different orientation.

**Disk geometry**: flat Gaussian slab (`diskRadius` × `diskThick`). Sampled in the disk's local coordinate system.

**Teardrop envelope**: asymmetric around the disk. Upstream (facing ionizing star): tight bow-shaped front. Downstream: elongated comet tail with exponential falloff.

**Self-shadowing**: the disk itself shadows its own downstream tail. The ionized sheath is brightest where it faces the ionizing star.

**Color**: H-alpha + [O III] mix controlled by distance from ionizing star (ionization parameter gradient). Disk head: neutral/molecular (dark, brown). Sheath: ionized (pink-teal). Tail: faint H-alpha.

---

### quantum_nebula.glsl

Quantum mechanics as an aesthetic framework.

**Three eigenstates** (ground, first excited, second excited) are summed with time-evolving coefficients to produce a superposition density. The coefficients rotate in "Hilbert space" (cosines of different frequencies).

**Wave function collapse bands**: `collapseFactor()` computes a sinusoidal wavefront propagating outward. Where the wave passes, the superposition collapses to the classical (ground state) solution. The bands sweep the field continuously.

**Heisenberg color uncertainty**: `emitColor()` measures the local density gradient magnitude. High gradient = precisely localized particle = uncertain color (spectral noise injected). Low gradient = delocalized = definite color.

**Tunneling stars**: stars at known positions but with position uncertainty proportional to `HBAR`. Each star has a sharp bloom (classical) plus a ghost bloom (delocalized wave function).

---

### bipolar_nebula.glsl

The birth scream of a star.

**Jet dynamics**: `jetBeam()` computes a narrow Gaussian column along the jet axis. Internal knot structure (Kelvin-Helmholtz beads) implemented as a sine wave along the axis that creates periodic bright knots. The jet propagates outward at `uEvolutionSpeed`.

**Herbig-Haro bow shocks**: paraboloidal surface at the jet terminus. The paraboloid opens upstream (facing the jet). Bright rim, fainter interior.

**Cavity wall**: conical surface around the jet axis. FBM texture. Illuminated by the central protostar's scattered light → warm orange.

**Disk shadow**: the accretion disk blocks protostellar light in the equatorial plane. Implemented as `1 - exp(-equatorial²)` weighting — dark band across the equator.

---

### molecular_cloud.glsl

The progenitor cloud. Before any of the other shaders can exist, this happened.

**Kolmogorov FBM**: persistence = 0.63 (= 2^(-1/3)) instead of the standard 0.5. This correctly reproduces the Kolmogorov energy spectrum P(k) ∝ k^(-11/3) for 3D supersonic turbulence.

**False-color palette**: following Herschel PACS+SPIRE color conventions. Cold diffuse CO → olive-green. Warm filament dust → orange. Hot dense core → red → amber (as protostellar heating increases).

**Plummer density profile** for prestellar cores: ρ ∝ (1 + (r/r₀)²)^(-5/2). This is observationally appropriate — Bonnell profiles, not Gaussians.

---

### filament_nebula.glsl

The skeleton of the ISM.

**Ridge extraction**: `ridgeDensity()` uses `1 - |FBM - 0.55|` to find where FBM = 0.55 — these are the crests of the noise field, which form connected ridge networks (filaments).

**Three scales**: main filaments (0.8× frequency), sub-filaments (1.8×), fibers (4.0×). Each scale is independently seeded. This produces the observed self-similar filament hierarchy.

**Hub-filament junctions**: `hubDensity()` = product of main and sub-filament values. High only where both are simultaneously high → intersection points → the densest nodes where massive star clusters form.

**Herschel false-color**: cold = blue-teal (250 μm), warm = orange (160 μm), hot = red (100 μm), hub = golden-orange, protostellar = warm white.

---

## Combining Shaders

The viewer loads one shader at a time. To combine effects in your own engine:

### Method 1: Include both as functions
Copy the density functions from two shaders into one file, sum their outputs:
```glsl
float density = 0.7*basicNebulaD(p) + 0.3*supernovaD(p);
```

### Method 2: Blend by parameter
Use a uniform to cross-fade:
```glsl
float d = mix(hubbleDensity(p), molecularDensity(p), uBlend);
```

### Method 3: Multi-pass rendering
Render each shader to a framebuffer texture. Composite in a final pass using additive blending. This allows each shader to have independent depth/transmittance.

### Method 4: Nested raymarcher
At each step, compute density from a combination:
```glsl
for (each step) {
    float d = densityA(p) * aWeight + densityB(p) * bWeight;
    // single transmittance and emission accumulation
}
```

---

## Adding a New Shader

All shaders follow the same pattern:

1. **Uniforms**: copy the standard uniform block from any existing shader
2. **Density function**: `float nebulaDensity(vec3 p)` — returns volume density ≥ 0
3. **Color function**: `vec3 emitColor(vec3 p, float density)` — returns emission color
4. **Raymarcher**: standard front-to-back loop (copy from basic_nebula.glsl)
5. **Camera**: lookAt setup + `main()` entry point

The density function is the creative work. Everything else is infrastructure.

---

## Performance Guide

| Setting | Steps | Step Size | Cost |
|---------|-------|-----------|------|
| Preview | 48 | 0.07 | Fast |
| Standard | 80 | 0.05 | Medium |
| Quality | 128 | 0.03 | Slow |
| Ultra | 200 | 0.02 | Very slow |

**Optimization tricks**:
- Early exit when `transmittance < 0.01` (included in all shaders)
- Empty space skipping: if density at current step is 0, advance by larger `STEP_SZ_FAST`
- Level-of-detail: reduce octave count for FBM at low density regions
- Precomputed density textures: bake to 3D texture, sample instead of evaluating FBM each step (for real-time interactive use)
