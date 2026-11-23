#!/usr/bin/env python3
"""Smart tight-bounding-box auto-fitter for Tunner Studio PNG icons.

Detects the real foreground icon silhouette using an alpha threshold (ignoring
faint anti-alias halos or stray dust pixels), crops tightly around the icon,
scales it with Lanczos resampling to maximize canvas utilization (96% fill on
a 96x96 canvas with a 2px anti-aliasing safety border), applies gentle edge
sharpening, and centers the glyph optically.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
from PIL import Image, ImageFilter

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CANONICAL_ICONS_DIR = (PROJECT_ROOT / "assets" / "icons" / "png").resolve()


def optimize_icon(
    path: Path,
    canvas_size: int = 96,
    margin_px: int = 2,
    alpha_threshold: int = 100,
    noise_floor: int = 24,
    sharpen: bool = True,
) -> tuple[float, float]:
    """Optimize a single RGBA PNG icon in-place.

    Detects the real solid glyph body using [alpha_threshold] (ignoring soft
    outer glows or background halos that shrink perceived icon size), crops
    tightly with a 1px anti-alias guard, scales to maximize canvas fill, and
    centers the icon optically.

    Returns (before_fill_ratio, after_fill_ratio) measured at [alpha_threshold].
    """
    im = Image.open(path).convert("RGBA")
    orig_w, orig_h = im.size
    alpha = im.split()[3]

    # Compute tight solid-body bounding box above alpha_threshold.
    mask = alpha.point(lambda p: 255 if p >= alpha_threshold else 0)
    bbox = mask.getbbox()
    if bbox is None:
        # Fallback for very faint translucent icons.
        bbox = alpha.point(lambda p: 255 if p >= 28 else 0).getbbox()
        if bbox is None:
            return (0.0, 0.0)

    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]
    before_ratio = max(bw / orig_w, bh / orig_h)

    # Expand crop by 1px (clamped) to preserve smooth anti-aliased edge pixels.
    crop_box = (
        max(0, bbox[0] - 1),
        max(0, bbox[1] - 1),
        min(orig_w, bbox[2] + 1),
        min(orig_h, bbox[3] + 1),
    )
    cropped = im.crop(crop_box)

    # Clean faint outer halo/noise pixels below noise_floor.
    r, g, b, a = cropped.split()
    a_clean = a.point(lambda p: 0 if p < noise_floor else p)
    cropped = Image.merge("RGBA", (r, g, b, a_clean))

    cw, ch = cropped.size
    target_max = max(1, canvas_size - 2 * margin_px)
    scale = target_max / max(cw, ch)
    new_w = max(1, int(round(cw * scale)))
    new_h = max(1, int(round(ch * scale)))

    resized = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)

    if sharpen:
        # Sharpen RGB channels gently while keeping alpha smooth.
        rr, gg, bb, aa = resized.split()
        rgb = Image.merge("RGB", (rr, gg, bb)).filter(
            ImageFilter.UnsharpMask(radius=0.8, percent=70, threshold=3)
        )
        rr2, gg2, bb2 = rgb.split()
        resized = Image.merge("RGBA", (rr2, gg2, bb2, aa))

    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    offset_x = (canvas_size - new_w) // 2
    offset_y = (canvas_size - new_h) // 2
    canvas.paste(resized, (offset_x, offset_y), resized)

    canvas.save(path, format="PNG", optimize=True)

    after_alpha = canvas.split()[3]
    after_mask = after_alpha.point(lambda p: 255 if p >= alpha_threshold else 0)
    after_bbox = after_mask.getbbox()
    if after_bbox is None:
        after_ratio = 0.0
    else:
        aw = after_bbox[2] - after_bbox[0]
        ah = after_bbox[3] - after_bbox[1]
        after_ratio = max(aw / canvas_size, ah / canvas_size)

    return (before_ratio, after_ratio)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Auto-detect tight icon bounds and maximize canvas fill."
    )
    parser.add_argument(
        "--size",
        type=int,
        default=96,
        help="Target square canvas size in pixels (default: 96).",
    )
    parser.add_argument(
        "--margin",
        type=int,
        default=2,
        help="Safety anti-alias border in pixels per side (default: 2).",
    )
    args = parser.parse_args()

    if not CANONICAL_ICONS_DIR.is_dir():
        print(f"Icons directory not found: {CANONICAL_ICONS_DIR}", file=sys.stderr)
        return 1

    files = sorted(
        p
        for p in CANONICAL_ICONS_DIR.iterdir()
        if p.is_file()
        and not p.is_symlink()
        and p.suffix.lower() == ".png"
        and p.resolve().is_relative_to(CANONICAL_ICONS_DIR)
    )
    if not files:
        print(f"No PNG icons found in {CANONICAL_ICONS_DIR}", file=sys.stderr)
        return 1

    print(
        f"Optimizing {len(files)} icons in {CANONICAL_ICONS_DIR} "
        f"({args.size}x{args.size}, margin={args.margin}px)..."
    )
    for path in files:
        before, after = optimize_icon(
            path,
            canvas_size=args.size,
            margin_px=args.margin,
        )
        print(f"  {path.name:32s} fill: {before:5.1%} -> {after:5.1%}")

    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
