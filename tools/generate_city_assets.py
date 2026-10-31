from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
import hashlib

SIZE = 4096
COUNT = 16
OUT = Path("assets/generated")
OUT.mkdir(parents=True, exist_ok=True)

PALETTES = [
    ((38,42,46),(92,98,101)), ((55,60,64),(126,130,128)),
    ((48,55,62),(116,126,135)), ((68,57,50),(142,118,96)),
    ((34,48,54),(94,137,151)), ((44,50,44),(86,120,83)),
    ((72,73,70),(158,153,137)), ((42,44,49),(104,108,119)),
]

def texture(seed, mode):
    rng = np.random.default_rng(seed)
    h = w = SIZE
    base, hi = PALETTES[mode % len(PALETTES)]
    y, x = np.mgrid[0:h, 0:w]
    # Multi-scale noise creates a detailed, non-repeating material surface.
    small = rng.random((256,256), dtype=np.float32)
    noise = np.array(Image.fromarray((small*255).astype(np.uint8)).resize((w,h), Image.Resampling.BICUBIC), dtype=np.float32)/255.0
    fine = rng.random((h,w), dtype=np.float32)
    grain = rng.random((h,w), dtype=np.float32)
    v = np.clip(noise*0.55 + fine*0.30 + grain*0.15, 0, 1)
    c0 = np.array(base, dtype=np.float32)
    c1 = np.array(hi, dtype=np.float32)
    rgb = c0[None,None,:]*(1-v[:,:,None]) + c1[None,None,:]*v[:,:,None]

    if mode % 4 == 0:  # asphalt/road
        stripe = ((x + (y//24)*13 + mode*97) % 503)
        rgb += (stripe < 3)[...,None] * 35
    elif mode % 4 == 1:  # concrete
        seams = ((x//160 + y//190 + mode) % 2 == 0) & ((x%160)<4)
        rgb -= seams[...,None] * 22
    elif mode % 4 == 2:  # facade
        windows = ((x//110 + mode) % 4 == 0) & ((y//150 + mode) % 5 == 0)
        rgb[windows] = np.array([125, 185, 205])
        glow = windows & (((x//17 + y//23) % 5) < 2)
        rgb[glow] += 30
    else:  # metal/trim
        brushed = (np.sin(x/7.0 + y/41.0) * 0.5 + 0.5)
        rgb = rgb*0.75 + brushed[...,None]*70

    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    return Image.fromarray(rgb, "RGB")

for i in range(COUNT):
    p = OUT / f"city_material_{i:02d}.png"
    if not p.exists():
        image = texture(0x49524f + i*7919, i)
        image.save(p, format="PNG", compress_level=1, optimize=False)
    print(p, p.stat().st_size)

total = sum(p.stat().st_size for p in OUT.glob("*.png"))
print(f"Generated {COUNT} 4096x4096 city textures: {total/1024/1024:.1f} MiB")
if total < 650*1024*1024:
    raise SystemExit("Texture payload unexpectedly small; refusing to build undersized asset set.")
