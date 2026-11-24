#!/usr/bin/env python3
"""Multi-resolution tight-bounding-box optimizer for Tunner Studio PNG icons.

Reads each canonical PNG icon, detects the solid foreground silhouette (ignoring
faint anti-alias halos), crops tightly, and generates 3 resolution-aware tiers
matching Flutter's AssetImage DPR system and the logical sizes used in Tunner:
  - 1.0x (assets/icons/png/<name>.png):       24x24 px (1px margin) for 10-24dp UI
  - 2.0x (assets/icons/png/2.0x/<name>.png):  48x48 px (1px margin) for 2x HiDPI / 24-38dp
  - 3.0x (assets/icons/png/3.0x/<name>.png):  96x96 px (2px margin) for 3x Ultra-DPI / hero

Each tier uses Lanczos resampling, gentle edge sharpening, and lossless/near-lossless
FASTOCTREE 256-color RGBA palette quantization to minimize disk & GPU footprint
without sacrificing crispness.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
from PIL import Image, ImageFilter

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CANONICAL_ICONS_DIR = (PROJECT_ROOT / "assets" / "icons" / "png").resolve()

TIERS: list[tuple[str, int, int]] = [
    ("", 24, 1),
    ("2.0x", 48, 1),
    ("3.0x", 96, 2),
]


def _extract_tight_glyph(
    im: Image.Image,
    alpha_threshold: int = 100,
    noise_floor: int = 24,
) -> tuple[Image.Image, float]:
    """Crop tightly around the solid foreground glyph and clean stray halo noise."""
    orig_w, orig_h = im.size
    alpha = im.split()[3]

    mask = alpha.point(lambda p: 255 if p >= alpha_threshold else 0)
    bbox = mask.getbbox()
    if bbox is None:
        bbox = alpha.point(lambda p: 255 if p >= 28 else 0).getbbox()
        if bbox is None:
            return (im, 0.0)

    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]
    before_ratio = max(bw / orig_w, bh / orig_h)

    crop_box = (
        max(0, bbox[0] - 1),
        max(0, bbox[1] - 1),
        min(orig_w, bbox[2] + 1),
        min(orig_h, bbox[3] + 1),
    )
    cropped = im.crop(crop_box)

    r, g, b, a = cropped.split()
    a_clean = a.point(lambda p: 0 if p < noise_floor else p)
    return (Image.merge("RGBA", (r, g, b, a_clean)), before_ratio)


def _render_tier(
    glyph: Image.Image,
    canvas_size: int,
    margin_px: int,
    sharpen: bool = True,
    quantize: bool = True,
) -> Image.Image:
    """Scale [glyph] into a square [canvas_size] canvas and optimize palette."""
    cw, ch = glyph.size
    target_max = max(1, canvas_size - 2 * margin_px)
    scale = target_max / max(cw, ch)
    new_w = max(1, int(round(cw * scale)))
    new_h = max(1, int(round(ch * scale)))

    resized = glyph.resize((new_w, new_h), Image.Resampling.LANCZOS)

    if sharpen:
        rr, gg, bb, aa = resized.split()
        rgb = Image.merge("RGB", (rr, gg, bb)).filter(
            ImageFilter.UnsharpMask(radius=0.7, percent=65, threshold=3)
        )
        rr2, gg2, bb2 = rgb.split()
        resized = Image.merge("RGBA", (rr2, gg2, bb2, aa))

    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    offset_x = (canvas_size - new_w) // 2
    offset_y = (canvas_size - new_h) // 2
    canvas.paste(resized, (offset_x, offset_y), resized)

    if quantize:
        return canvas.quantize(
            colors=256,
            method=Image.Quantize.FASTOCTREE,
            dither=Image.Dither.NONE,
        )
    return canvas


def optimize_icon(
    filename: str,
    sharpen: bool = True,
    quantize: bool = True,
) -> tuple[int, int]:
    """Optimize a single PNG icon from highest-res source into 1x/2x/3x tiers.

    Returns (before_total_bytes, after_total_bytes).
    """
    base_path = (CANONICAL_ICONS_DIR / filename).resolve()
    master_3x_path = (CANONICAL_ICONS_DIR / "3.0x" / filename).resolve()

    if not base_path.is_relative_to(CANONICAL_ICONS_DIR):
        raise ValueError(f"Invalid icon path: {base_path}")

    # Prefer existing 3.0x master if present so re-runs never lose source resolution.
    source_path = master_3x_path if master_3x_path.is_file() else base_path
    before_bytes = base_path.stat().st_size if base_path.is_file() else 0

    im = Image.open(source_path).convert("RGBA")
    glyph, _ = _extract_tight_glyph(im)

    after_bytes = 0
    for subdir, size, margin in TIERS:
        out_dir = (CANONICAL_ICONS_DIR / subdir).resolve() if subdir else CANONICAL_ICONS_DIR
        if not out_dir.is_relative_to(CANONICAL_ICONS_DIR):
            raise ValueError(f"Invalid tier directory: {out_dir}")
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = (out_dir / filename).resolve()
        if not out_path.is_relative_to(CANONICAL_ICONS_DIR):
            raise ValueError(f"Invalid output path: {out_path}")

        rendered = _render_tier(
            glyph,
            canvas_size=size,
            margin_px=margin,
            sharpen=sharpen,
            quantize=quantize,
        )
        rendered.save(out_path, format="PNG", optimize=True)
        if not subdir:
            after_bytes = out_path.stat().st_size

    return (before_bytes, after_bytes)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate optimized 1x (24px), 2x (48px), 3x (96px) PNG icon tiers."
    )
    parser.add_argument(
        "--no-quantize",
        action="store_true",
        help="Disable 256-color RGBA palette quantization.",
    )
    args = parser.parse_args()

    if not CANONICAL_ICONS_DIR.is_dir():
        print(f"Icons directory not found: {CANONICAL_ICONS_DIR}", file=sys.stderr)
        return 1

    files = sorted(
        p.name
        for p in CANONICAL_ICONS_DIR.iterdir()
        if p.is_file()
        and not p.is_symlink()
        and p.suffix.lower() == ".png"
        and p.resolve().is_relative_to(CANONICAL_ICONS_DIR)
    )
    if not files:
        print(f"No PNG icons found in {CANONICAL_ICONS_DIR}", file=sys.stderr)
        return 1

    total_before = 0
    total_after_1x = 0
    print(f"Optimizing {len(files)} icons into 1x (24px), 2x (48px), 3x (96px) tiers...")
    for name in files:
        before, after = optimize_icon(name, quantize=not args.no_quantize)
        total_before += before
        total_after_1x += after
        pct = ((before - after) / before * 100.0) if before > 0 else 0.0
        print(f"  {name:30s} 1x: {before:6d} B -> {after:5d} B (-{pct:4.1f}%)")

    total_pct = ((total_before - total_after_1x) / total_before * 100.0) if total_before > 0 else 0.0
    print(f"Total 1x size: {total_before / 1024:.1f} KB -> {total_after_1x / 1024:.1f} KB (-{total_pct:.1f}%)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
