"""Draws the app icon: a day ring with a check mark on an indigo→cyan gradient.

    .venv\\Scripts\\python tools\\make_icon.py

Writes App/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024×1024, no transparency;
iOS rounds the corners itself).
"""
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 4  # draw large, then downsample for smooth edges
OUT = Path(__file__).resolve().parents[1] / "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

TOP_LEFT = (79, 70, 229)      # indigo
BOTTOM_RIGHT = (6, 182, 212)  # cyan
WHITE = (255, 255, 255)


def gradient(size: int) -> Image.Image:
    small = Image.new("RGB", (64, 64))
    pixels = small.load()
    for y in range(64):
        for x in range(64):
            t = (x + y) / 126
            pixels[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(TOP_LEFT, BOTTOM_RIGHT))
    return small.resize((size, size), Image.BICUBIC)


def round_line(draw: ImageDraw.ImageDraw, points, width: int, fill) -> None:
    draw.line(points, fill=fill, width=width, joint="curve")
    r = width / 2
    for x, y in (points[0], points[-1]):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=fill)


def main() -> None:
    s = SIZE * SCALE
    image = gradient(s)
    draw = ImageDraw.Draw(image)

    # Ring with a gap at the top right, like a day that's almost complete.
    center, radius, ring = s / 2, s * 0.30, int(s * 0.075)
    box = (center - radius, center - radius, center + radius, center + radius)
    start, end = -50, 250  # degrees, clockwise from 3 o'clock
    draw.arc(box, start=start, end=end, fill=WHITE, width=ring)
    import math
    for angle in (start, end):
        a = math.radians(angle)
        x = center + (radius - ring / 2) * math.cos(a)
        y = center + (radius - ring / 2) * math.sin(a)
        draw.ellipse((x - ring / 2, y - ring / 2, x + ring / 2, y + ring / 2), fill=WHITE)

    # Check mark inside the ring.
    check = [(s * 0.385, s * 0.515), (s * 0.465, s * 0.595), (s * 0.630, s * 0.425)]
    round_line(draw, check, int(s * 0.065), WHITE)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.resize((SIZE, SIZE), Image.LANCZOS).save(OUT, optimize=True)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
