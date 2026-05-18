# Images

Reference images for nebula rendering. This directory intentionally contains no copyrighted imagery.

## What to put here

Place your own reference images or openly licensed astronomical images here.
Suggested naming:
```
pillars_of_creation_hubble.jpg
crab_nebula.jpg
orion_nebula_m42.jpg
helix_nebula_eye_of_god.jpg
carina_nebula.jpg
veil_nebula.jpg
eta_carinae.jpg
horsehead_nebula.jpg
```

## Free sources (CC-licensed or public domain)

- **NASA/ESA Hubble Heritage**: https://hubblesite.org/images/gallery — many released as public domain
- **ESA Hubble**: https://esahubble.org/images/ — CC BY 4.0
- **JWST images**: https://webbtelescope.org/news/webb-missions-gallery
- **NASA Image Gallery**: https://images.nasa.gov/
- **APOD (Astronomy Picture of the Day)**: https://apod.nasa.gov/ — check individual license per image

## Palettes extracted from reference images

When you find reference images, extract the dominant color palette with:
```python
from PIL import Image
import numpy as np

img = np.array(Image.open("your_nebula.jpg").resize((200,200)))
# Sample a grid of colors
samples = img[::10, ::10].reshape(-1, 3)
print("Dominant colors (RGB):", samples.tolist()[:10])
```

Or use the `colorthief` library:
```python
from colorthief import ColorThief
ct = ColorThief("your_nebula.jpg")
palette = ct.get_palette(color_count=8)
print(palette)
```
