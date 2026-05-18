# NEBULA FORMATION
## Volumetric Dust, Gas, and Starlight. Cosmic Womb. Interstellar Cathedral.

> *"A nebula doesn't have a shape. It has a history. Every wisp of hydrogen is a record of a shockwave from ten thousand years ago. Every color is a temperature. Every shadow is a star being born in secret."*

---

## WHAT THIS IS

This repo is a visual knowledge pack for **nebula rendering** — volumetric simulation of interstellar gas clouds, star formation regions, supernova remnants, and planetary nebulae.

You have NOTHING like this in your collection. No cosmic repos. No astronomy. No space. You've got `ufo` and `LV426` but those are about *anomalous* encounters with the cosmos. This is about the cosmos itself — the birthplaces of suns, the cathedrals of dust, the architecture of nothing becoming everything.

When RepoScripter ingests this alongside `bioluminescent_systems`, `plasma_cosmology_vis`, `caustic_networks`, or `sacred_geometry`, expect the AI to create cosmic-scale sacred art. The Pillars of Creation reinterpreted through your maximalist color palette. A supernova rendered as stained glass.

---

## CORE CONCEPTS

### 1. Volumetric Density Field
Nebulae are not surfaces. They are **volumes of gas and dust** with varying density:
- **H II regions**: Ionized hydrogen glows red/pink (H-alpha emission at 656.3nm)
- **Dust lanes**: Dark, opaque regions that absorb and scatter starlight
- **Shock fronts**: Collision interfaces where gas hits gas, creating compressed, glowing sheets
- **Bok globules**: Dense, dark pockets where stars are born in isolation

### 2. Emission / Absorption / Scattering
The three interactions of light with nebula material:
- **Emission**: Hot gas glows (power * emissivity * color)
- **Absorption**: Dust blocks light (Beer-Lambert law: I = I₀ * exp(-density * opacity))
- **Scattering**: Starlight bounces off dust particles (Mie scattering for small particles, Rayleigh for very small)

### 3. Star Formation Feedback
Young stars interact with the nebula:
- **Radiation pressure**: Starlight pushes gas away, carving bubbles
- **Stellar winds**: High-velocity particles blow away surroundings
- **Photoionization**: UV light from hot stars ionizes nearby hydrogen
- **Proplyds**: Protoplanetary disks being photoevaporated

### 4. Turbulence and Structure
Nebulae are shaped by turbulence:
- **Kolmogorov spectrum**: Energy cascades from large scales to small
- **Filamentary structure**: Gas forms sheets, then filaments, then knots
- **Fractal dimension**: Nebula edges have D ≈ 2.6 — more complex than a surface, less than a volume

---

## MATHEMATICAL FOUNDATION

### Volume Rendering Equation
```
Color = ∫[0 to D] emission(t) * exp(-∫[0 to t] absorption(s) ds) dt
```
Where D is the total ray length through the volume.

### Density Field Generation
```
density(p) = fbm(p, octaves=6) * envelope(p)
```
Where `fbm` is fractal Brownian motion (layered noise), and `envelope` is a large-scale shaping function (sphere, torus, pillar, shell).

### Emission Spectrum
```
// H-alpha dominates: deep red
// O-III dominates: teal/green  
// S-II: dark red
// N-II: red-orange
// Dust scattering: blue (Rayleigh)

emissionColor(density, temperature) = 
  if temp > 10000K: mix(teal, blue, (temp-10000)/20000)
  if temp > 7500K: mix(green, teal, (temp-7500)/2500)
  if temp > 5000K: mix(red, orange, (temp-5000)/2500)
  else: dark_red
```

### Turbulent Velocity Field
```
velocity(p) = curlNoise(p) * turbulenceScale + largeScaleFlow
```
Curl noise ensures incompressibility (div(v) = 0), physically realistic for gas.

---

## INSIDE THE BOX (Fundamentals)

### Basic Nebula Raymarcher
See `code/basic_nebula.glsl` — volumetric raymarching through a simple FBM density field. Emission + absorption. Clean, physically plausible.

### Hubble Palette Rendering
See `code/hubble_palette.glsl` — the classic "Hubble palette": S-II mapped to red, H-alpha to green, O-III to blue. Creates those iconic teal-orange-pink nebulae.

### Dust and Stars
See `code/dust_and_stars.glsl` — nebula with embedded point stars, dust lanes, and scattered light. More complex, more beautiful.

### Supernova Remnant Shell
See `code/supernova_shell.glsl` — expanding spherical shell with Rayleigh-Taylor instabilities at the contact front. The Crab Nebula in miniature.

---

## OUTSIDE THE BOX (Creative Destinations)

### Living Nebula
The nebula is not static — it's a 4D volume that evolves:
- **Breathing**: Gas density pulses with a heartbeat-like rhythm
- **Giving birth**: Stars ignite suddenly, blasting holes in the cloud
- **Dying**: Older stars shed their envelopes, creating new shells inside the nebula
- **Memory**: The nebula retains "scars" from past stars — ghost shells, faded bubbles

### Emotional Nebula
Colors don't follow physics — they follow feeling:
- **Grief**: Deep purples, slow-moving, heavy dust that doesn't disperse
- **Joy**: Brilliant golds and magentas, rapid star formation, explosive energy
- **Longing**: Blue-shifted everything — the nebula is moving away from you at high velocity
- **Rage**: Red, compressed, violent stellar winds carving violent shapes

### Sacred Nebula
The nebula as religious architecture:
- Pillars of Creation = Cathedral columns
- Proplyds = Rose windows
- H II glow = Stained glass light
- Dust lanes = Flying buttresses
- The entire nebula is a church built by gravity and light

### Biological Nebula
Nebula as body:
- **Lungs**: The alveolar structure of gas/dust interface
- **Brain**: Neural-like filaments of molecular gas
- **Womb**: The Bok globules as eggs, stars as embryos
- **Corpse**: Supernova remnant as exploded organ

### Quantum Nebula
Nebula physics replaced with quantum phenomena:
- Gas exists in superposition of densities until observed
- Stars tunnel through dust barriers
- Entanglement: two distant stars are correlated — when one flickers, the other responds
- Uncertainty: the more precisely you know a gas cloud's position, the less you know its momentum

### Glitch Nebula
The Hubble image as corrupted data:
- Cosmic ray hits as vertical streaks of pure color
- CCD bleeding as saturated stars with bloom artifacts
- Transmission errors as blocky JPEG artifacts in the nebula
- The "truth" of the nebula and the "artifact" of its recording become indistinguishable

### Miniature Nebula
A nebula that fits in a jar:
- Tiny, contained, held by artificial gravity
- You can walk around it, look at it from all angles
- The size of a bonsai tree but containing a star's worth of material
- Domesticated cosmos

---

## BLENDING WITH OTHER REPOS

**+ `bioluminescent_systems`** → Deep-sea nebulae. Bioluminescent creatures as stars. The ocean floor as a dark nebula. Bioluminescence as stellar formation feedback.

**+ `plasma_cosmology_vis`** → Birkeland currents shaping the nebula. Z-pinch filaments as star formation channels. Electric universe aesthetic meets real astrophysics.

**+ `sacred_geometry`** → Nebula filaments forming Sri Yantra, Flower of Life, Metatron's Cube. Star positions at golden ratio intervals. The nebula as a temple.

**+ `dream_physics`** → Nebula that responds to dream-logic. Flying through a nebula changes its properties based on your emotional state. Lucid dreaming in space.

**+ `caustic_networks`** → Caustics within the nebula — light focused by density gradients creates bright filigree patterns inside the gas. Light sculpture inside cloud sculpture.

**+ `alien_language`** → The nebula IS a message. The filaments form glyphs. The stars are punctuation. We are reading an interstellar poem written in hydrogen.

---

## ARTISTIC REFERENCES

- **Pillars of Creation** (Hubble, 1995/2015) — Eagle Nebula, M16. The iconic.
- **Crab Nebula** — supernova remnant, pulsar heart, violent filaments.
- **Orion Nebula** (M42) — closest massive star formation region, complex, alive.
- **Carina Nebula** — the most detailed Hubble image, incredibly complex.
- **Helix Nebula** — "Eye of God," planetary nebula, concentric rings.
- **Veil Nebula** — supernova remnant, delicate filaments, false-color brilliance.
- **James Turrell** — light as material, perception as medium.
- **Olafur Eliasson** — artificial weather, constructed atmospheres.
- **Vija Celmins** — obsessive night sky drawings, hand-made cosmos.
- **Kazimir Malevich's "Black Square"** — the void before the nebula, the nebula before the void.

---

## PARAMETER SPACE

| Parameter | Range | Effect |
|-----------|-------|--------|
| `densityScale` | 0.1-5.0 | Overall thickness of nebula |
| `turbulence` | 0.0-3.0 | How chaotic the gas structure is |
| `emissionStrength` | 0.1-5.0 | How brightly the gas glows |
| `dustOpacity` | 0.0-2.0 | How much dust blocks light |
| `starCount` | 0-50 | Embedded point light sources |
| `temperatureRange` | 3000-50000 | Kelvin. Controls color palette |
| `colorPalette` | hubble/natural/emotional/surreal | Which color mapping to use |
| `evolutionSpeed` | 0.0-1.0 | 0 = static, 1 = rapid star formation cycles |
| `scale` | 0.1-10.0 | Spatial scale — miniature jar to cosmic |
| `glitchAmount` | 0.0-1.0 | Data corruption as aesthetic |
| `sacredOverlay` | 0.0-1.0 | Sacred geometry filigree intensity |

---

## REPOSCRIPTER INTEGRATION

When this repo is loaded into RepoScripter as context:
- **Volume rendering** is the primary technique — raymarching, density fields, emission/absorption
- **Astronomical palettes** are strong suggestions — Hubble palette, emission line colors
- **Turbulence and FBM** are the structural generators
- **Star formation physics** adds life and dynamism
- The AI should feel free to make nebulae represent ANYTHING: wombs, brains, cathedrals, wounds, dreams, data structures
- Suggest **volumetric compositing** when blending with other repos — a nebula that contains a crystalline structure, or a bioluminescent ocean inside a gas cloud

---

## FILES

```
README.md                    <— You are here
context.manifest.json        <— RepoScripter ingestion manifest
code/
  basic_nebula.glsl         <— Fundamental volumetric raymarching
  hubble_palette.glsl       <— Classic false-color astronomy
  dust_and_stars.glsl       <— Embedded point lights + scattering
  supernova_shell.glsl      <— Expanding shock front
  living_nebula.glsl        <— Time-evolving gas dynamics
  emotional_nebula.glsl     <— Feeling drives physics
  sacred_nebula.glsl        <— Cosmic cathedral architecture
  glitch_nebula.glsl        <— Data corruption as aesthetic
docs/
  astrophysics_basics.md    <— Real nebula science
  emission_lines.md         <— H-alpha, O-III, S-II spectral data
  hubble_imagery.md         <— How space telescopes actually see
  artistic_cosmology.md     <— Cosmos in art history
images/
  [placeholders for reference imagery]
```

---

## MANIFESTO

> *"A nebula is a lie that tells the truth. It looks solid — a cloud you could touch — but it's thinner than Earth's atmosphere, spread across light-years. It looks colorful — pink, teal, gold — but those are lies told by filters, human decisions about which wavelengths to trust. The truth is: a nebula is almost nothing. Almost empty. Almost cold. And yet it is where everything begins. Every star that ever warmed a face. Every planet that ever held an ocean. Every atom in your body that isn't hydrogen was forged in the heart of a star that was born in a nebula. You are the nebula's memory. You are what the gas was dreaming about while it collapsed."*

---

*NEBULA FORMATION v1.0*
*For RepoScripter v7.7.7+*
*Created by Merry Pranxter's chaos consortium*
*"You looked at the stars but never built them. Now you will."*
