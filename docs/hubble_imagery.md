# Hubble Imagery
## How Space Telescopes Actually See Nebulae

Before you render a nebula, understand how the reference images you're looking at were made. Almost everything you've ever seen labeled "Hubble image" is a constructed false-color composite. Understanding the construction helps you reverse-engineer the art.

---

## The Hubble Space Telescope (HST)

Launched 1990. Primary mirror: 2.4 m. Orbits at 340 miles altitude, above atmospheric distortion.

### Key Instruments (relevant to nebula imaging)

**WFC3** (Wide Field Camera 3, installed 2009):
- UVIS channel: 200–1000 nm (UV + optical), 4096×2051 pixels, 0.04"/pixel
- IR channel: 800–1700 nm, 1024×1024, 0.13"/pixel
- Field of view: ~162"×162" (UVIS), ~136"×123" (IR)

**ACS** (Advanced Camera for Surveys):
- WFC: 4096×4096, 0.05"/pixel, optical
- Workhorse for many iconic nebula images (Pillars of Creation 2015)

**WFPC2** (original, now retired): used for the 1995 Pillars of Creation

---

## The Filter System

HST doesn't take "photos." It takes exposures through specific narrowband and broadband filters, one at a time. A color image requires at minimum 3 exposures (one per color channel).

### Common Narrowband Filters

| Filter | Central λ | Width (FWHM) | What it traces |
|--------|-----------|--------------|----------------|
| F656N | 656.3 nm | ~2 nm | H-alpha only |
| F658N | 658.5 nm | ~2 nm | [N II] 658.4 nm |
| F502N | 502.0 nm | ~2 nm | [O III] 500.7 nm |
| F673N | 673.0 nm | ~2 nm | [S II] 671.6+673.1 nm |
| F631N | 631.0 nm | ~2 nm | [O I] 630.0 nm |

### Common Broadband Filters
- F435W: B-band (440 nm)
- F555W: V-band (555 nm)  
- F606W: Wide V (606 nm, popular — very broad)
- F814W: I-band (814 nm)

---

## How a Hubble Image Is Made

### Step 1: Data Reduction
Raw CCD frames have defects: cosmic rays, hot pixels, read noise, dark current, flat-field variations. The Space Telescope Science Institute (STScI) pipeline removes these automatically. Output: calibrated FITS files in electrons/second.

### Step 2: Drizzling
Multiple dithered exposures (offset by sub-pixel amounts) are combined using the "drizzle" algorithm to improve spatial resolution and remove artifacts. The Pillars of Creation is a 2×2 mosaic of ACS pointings, drizzled.

### Step 3: Color Assignment
This is where art meets science. The scientist/artist assigns each narrowband filter to a color channel. Common choices:

**Hubble Palette (SHO)**:
```
[S II] → Red
H-alpha → Green
[O III] → Blue
```

**"Natural" Color (HHO or AHO)**:
```
H-alpha → Red
H-alpha + [N II] → Green (slight mix)
[O III] → Blue
```

**Broadband "True Color"**:
```
F435W (B) → Blue
F555W (V) → Green
F814W (I) → Red
```

### Step 4: Level Adjustment
Each channel is histogram-stretched independently (usually logarithmic or arcsinh stretch to compress dynamic range). This is why nebulae look so detailed — the faint outer emission is boosted to visibility.

### Step 5: Color Balancing
The three channels are manually balanced for aesthetic appeal. The scientists often spend significant time adjusting the color balance to make the structure most legible. The final colors are interpretive, not documentary.

---

## Why Is Everything Teal and Gold?

The Hubble Palette creates the characteristic teal-gold palette because:

1. H-alpha (mapped to GREEN) is present everywhere ionized hydrogen is
2. [O III] (mapped to BLUE) is strong in the hotter, outer ionization layers
3. [S II] (mapped to RED) is strongest in the warm partially-ionized PDR layer

Regions with **high O-III relative to S-II**:
- Green (H-alpha) + Blue (O-III) → **teal**

Regions with **high S-II and H-alpha, low O-III** (dense inner pillars):
- Red (S-II) + Green (H-alpha) → **yellow/gold**

Pillar tips and bright knots: often appear **golden** because S-II and H-alpha peak there.
Diffuse outer halos: appear **teal** because O-III is dominant in the hot thin ionized gas.

---

## The Pillars of Creation: A Case Study

**Object**: Eagle Nebula (M16), ~7000 light-years away, Serpens constellation.

**1995 image** (WFPC2): Became one of the most famous astronomical images in history. Used HHO color scheme. Exposure: ~4.8 hours total.

**2015 image** (WFC3 ACS): 20th anniversary re-imaging, higher resolution, both optical and near-infrared.
- Optical: ACS/WFC with F502N ([O III]), F657N (H-alpha + [N II] blend), F673N ([S II])
- Near-IR: WFC3/IR with F110W, F160W (sees into dust, reveals embedded stars)

**What the pillars are physically**:
- Cold (10–50 K) molecular gas columns, ~4–5 light-years tall
- Being photoevaporated by hot O stars (θ¹ Ori region analog) ~2 light-years away
- D-type ionization front eating the pillar tips
- Globules at tips: protostars forming inside, shielded by column of gas
- "Evaporating gaseous globules" (EGGs) visible at fingertip-like protrusions

---

## James Webb Space Telescope (JWST)

Launched December 2021. 6.5 m primary mirror (gold-coated beryllium). L2 orbit. Primarily IR.

### Why IR?
- See through dust: at 2–5 μm, dust is 10–100× less opaque than optical
- Detect embedded protostars: T~300–2000 K → peak emission in IR
- Redshifted galaxies: high-z universe emission shifted to IR
- Molecular emission: CO, H₂, PAHs all glow in IR

### JWST Pillars of Creation (2022)
Released October 2022. Two versions:
- **NIRCam (near-IR)**: shows previously hidden stars behind/within dust. Uses F090W, F187N, F200W, F335M, F444W, F470N
  - Blue = F090W (0.9μm) — older stars, scattered light
  - Cyan = F187N (1.87μm) — H I Paschen-alpha, embedded HII regions
  - Green = F200W (2.0μm) — continuum, mixed
  - Yellow-orange = F335M (3.35μm) — hot dust, PAHs
  - Red = F470N (4.7μm) — H₂ emission, CO emission
- **MIRI (mid-IR)**: Pillars look almost opaque — dust glows but stars hidden again

---

## Processing Your Own Hubble Data (MAST Archive)

HST and JWST data are publicly available after 12 months proprietary period.

**Access**: [Mikulski Archive for Space Telescopes](https://mast.stsci.edu/)

**File format**: FITS (.fits) — standard astronomical data format. Use:
- Python: `astropy.io.fits`, `astropy.visualization`
- DS9: free desktop FITS viewer
- Aladin: online FITS viewer

**Pipeline output files**:
- `*_drz.fits` or `*_drc.fits`: fully processed, drizzle-combined image
- `*_flt.fits`: individual exposure (flat-fielded, bias-subtracted)
- Extension [SCI]: the science data (electrons/second)
- Extension [WHT]: weight map (effective exposure time per pixel)
- Extension [CTX]: context map (which input image contributed)

**Python quickstart**:
```python
from astropy.io import fits
from astropy.visualization import ZScaleInterval, ImageNormalize
import matplotlib.pyplot as plt

hdu = fits.open('hst_image_drz.fits')
sci = hdu['SCI'].data

norm = ImageNormalize(sci, interval=ZScaleInterval())
plt.imshow(sci, norm=norm, cmap='gray', origin='lower')
plt.colorbar()
plt.show()
```

---

## Color Representation and Perceptual Issues

### Non-linearity is Essential
Nebula surface brightness spans 4–6 orders of magnitude. Linear display is useless — the core saturates while the faint outer shell disappears. Standard stretch options:

- **Log stretch**: `display = log(image + c)` — most common
- **Arcsinh stretch**: `display = arcsinh(image/σ)` — handles negative values, popular for Hubble
- **Power law**: `display = image^γ` — adjustable
- **Histogram equalization**: makes all brightness levels equally represented

### The Meaning of "Real Color"
There is no "true color" of a nebula in any meaningful sense:
1. Most of the light is in emission lines your eye can't separate spectrally
2. The dominant line (H-alpha) is barely visible to the human eye compared to green
3. The gas column extends 10–100 light-years — "color" varies with position

What astronomers call "natural color" is usually H-alpha → red, O-III → blue-green, which roughly matches what you'd see if you had extremely good eyes and a very dark sky. But even this is a construction.

---

## Useful Resources

- **HubbleSite**: hubblesite.org — press images with captions explaining color choices
- **MAST**: mast.stsci.edu — raw HST/JWST data
- **ESA Hubble**: esahubble.org — European partner, different image selection
- **Legado de Hubble**: astronomy.swin.edu.au — Hubble Heritage images
- **astropy docs**: docs.astropy.org — for FITS processing
- **APLpy**: aplpy.github.io — astronomical imaging library for Python
