from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np

# Real, used city materials. Generated during CI so the APK contains a substantial
# texture library without committing hundreds of MB of binary blobs to git.
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

def texture(seed: int, mode: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    base, hi = PALETTES[mode % len(PALETTES)]

    # Keep memory bounded: one RGB image plus compact noise buffers.
    small = rng.integers(0, 256, (256, 256), dtype=np.uint8)
    noise = np.asarray(
        Image.fromarray(small, "L").resize((SIZE, SIZE), Image.Resampling.BICUBIC),
        dtype=np.uint8,
    )
    fine = rng.integers(0, 256, (SIZE, SIZE), dtype=np.uint8)
    v = ((noise.astype(np.uint16) * 55 + fine.astype(np.uint16) * 45) // 100).astype(np.uint8)

    c0 = np.array(base, dtype=np.uint16)
    c1 = np.array(hi, dtype=np.uint16)
    rgb = (c0[None, None, :] + ((c1 - c0)[None, None, :] * v[:, :, None] // 255)).astype(np.uint8)
    image = Image.fromarray(rgb, "RGB")
    draw = ImageDraw.Draw(image)

    if mode % 4 == 0:  # worn asphalt
        for x in range(0, SIZE, 503):
            draw.line((x, 0, x + 170, SIZE), fill=(105, 107, 108), width=3)
        for y in range(90, SIZE, 311):
            draw.line((0, y, SIZE, y + 18), fill=(31, 33, 35), width=5)
    elif mode % 4 == 1:  # concrete panels
        for x in range(0, SIZE, 320):
            draw.line((x, 0, x, SIZE), fill=(40, 43, 45), width=5)
        for y in range(0, SIZE, 280):
            draw.line((0, y, SIZE, y), fill=(42, 45, 47), width=5)
    elif mode % 4 == 2:  # facade with windows
        for y in range(80, SIZE, 190):
            for x in range(70, SIZE, 145):
                if ((x // 145 + y // 190 + mode) % 3) != 0:
                    draw.rectangle((x, y, x + 78, y + 105), fill=(103, 164, 183))
                    draw.rectangle((x + 7, y + 8, x + 71, y + 97), fill=(61, 105, 122))
    else:  # brushed metal
        for x in range(0, SIZE, 17):
            draw.line((x, 0, x + 400, SIZE), fill=(118, 121, 120), width=2)

    return image

for i in range(COUNT):
    p = OUT / f"city_material_{i:02d}.png"
    image = texture(0x49524F + i * 7919, i)
    image.save(p, format="PNG", compress_level=1, optimize=False)
    print(p, p.stat().st_size)

total = sum(p.stat().st_size for p in OUT.glob("*.png"))
print(f"Generated {COUNT} 4096x4096 city textures: {total / 1024 / 1024:.1f} MiB")
if total < 500 * 1024 * 1024:
    raise SystemExit("Texture payload unexpectedly small; refusing to build undersized asset set.")
