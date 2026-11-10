"""Generate Moss logo PNGs (512px) with PIL — no stock images, no network.

Mark: three overlapping rounded moss mounds (domes) in emerald tones,
with a small two-leaf sprout. Drawn at 4x and downscaled for smooth edges.
- assets/logo.png            : full icon (gradient bg + mark) — legacy + iOS
- assets/logo_foreground.png : mark only on transparency — adaptive foreground
"""
import os
from PIL import Image, ImageDraw

OUT = os.path.expanduser("~/workspace/moss/assets")
os.makedirs(OUT, exist_ok=True)

S = 4            # supersample factor
W = 512 * S      # canvas


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient_bg(size):
    top = (10, 53, 42)      # #0A352A deep moss
    bottom = (6, 95, 70)    # #065F46 emerald
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        c = lerp(top, bottom, y / (size - 1))
        for x in range(size):
            px[x, y] = c
    return img


def dome(draw, cx, cy, w, h, color):
    """Upper half of an ellipse = a rounded moss mound."""
    draw.pieslice([cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2],
                  start=180, end=360, fill=color)


def leaf(size, color, angle):
    """A small pointed leaf on its own layer, rotated."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # pointed-oval leaf: two arcs via pieslice-ish shape; use ellipse + taper
    d.ellipse([size * 0.30, size * 0.05, size * 0.70, size * 0.95],
              fill=color + (255,))
    return layer.rotate(angle, resample=Image.BICUBIC, center=(size // 2, size // 2))


def draw_mark(base):
    """Draw the moss mark onto RGBA image `base` (size W). Returns base."""
    mark = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(mark)
    cy = int(W * 0.66)  # ground line
    # back mounds
    dome(d, int(W * 0.30), cy, int(W * 0.42), int(W * 0.34), (52, 211, 153))   # #34D399
    dome(d, int(W * 0.72), cy, int(W * 0.40), int(W * 0.30), (110, 231, 183))  # #6EE7B7
    # front mound
    dome(d, int(W * 0.50), cy, int(W * 0.58), int(W * 0.46), (16, 185, 129))   # #10B981
    # sprout: two leaves above the front mound
    leaf_size = int(W * 0.30)
    left = leaf(leaf_size, (167, 243, 208), -32)
    right = leaf(leaf_size, (52, 211, 153), 32)
    mark.alpha_composite(left, (int(W * 0.27), int(W * 0.18)))
    mark.alpha_composite(right, (int(W * 0.53), int(W * 0.18)))
    base.alpha_composite(mark)
    return base


# Full icon: gradient background + mark.
full = gradient_bg(W).convert("RGBA")
full = draw_mark(full)
full.resize((512, 512), Image.LANCZOS).save(f"{OUT}/logo.png")

# Adaptive foreground: mark only, ~72% scale, centred on transparency.
fg = Image.new("RGBA", (W, W), (0, 0, 0, 0))
fg = draw_mark(fg)
fg = fg.resize((int(512 * 0.72), int(512 * 0.72)), Image.LANCZOS)
canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
canvas.alpha_composite(fg, ((512 - fg.width) // 2, (512 - fg.height) // 2))
canvas.save(f"{OUT}/logo_foreground.png")

print("wrote", f"{OUT}/logo.png", f"{OUT}/logo_foreground.png")
