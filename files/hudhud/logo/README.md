# Hudhud — final mark

The isolated Arabic letter **ه** as a bold loop with a lighter curl growing out of its lower-right wall:
the stroke-end of a written heh, reduced to one curve. Faces left (Arabic reading direction = ahead).
Chosen by the client from round four (`hook-ccw`); this round fixes the join.

## Geometry (viewBox 0 0 1024 1024)
- Outer loop: centre (512, 512), centreline radius 200, stroke W = 96 (inner wall radius 152, outer 248).
- Curl: circle of radius 84 whose centre lies on the −45° ray (0° = right, south = down; +45° in SVG's
  y-down space); stroke 0.46 W = 44; turns 230° **counter-clockwise** from its root, tapering to 0.55 of
  its weight over the last 30%.
- Root: the curl's centre is pushed out along the ray until the root sits **34 units inside the ring body**
  (half the curl stroke + 12). The round-four value was 15 (0.35 of the stroke).
- Join: the two concave corners where the curl's inner and outer edges leave the inner wall are filleted
  with circles of radius 11 tangent to both the wall and the edge; the fillet polygons overdraw 2.5 units
  into both bodies so the union has no coincident edges.

### What changed at the join, and why
In round four the root sank only 15 units, so the flat start cap's inner corner sat 6.5 units *inside the
counter*: that corner was the spike. The curl circle only grazes the ring band, so extending the curl
backwards along its own circle would poke out again on the far side. The fix is therefore (1) bury the
whole start cap in the ring body (sink ≥ half the stroke, +12 margin) and (2) fillet the two wall corners.
`join-check.png` shows the root region at 4096 px equivalent before and after, on bone and ink, and in the
app icon, where the mark's gradient is user-space and the specular is clipped to the union of all its
paths, so both are continuous across the join. Optical side effect of the deeper root: the curl moved
19 units toward the lower right; nothing else was changed.

## Palette
| Role | Name | Hex | oklch |
|---|---|---|---|
| Primary | Flame | `#F2520B` | oklch(0.652 0.207 38.6) |
| Deep primary | Ember | `#C23A05` | oklch(0.545 0.180 36.9) |
| Dark | Ink | `#15182B` | oklch(0.216 0.038 276.0) |
| Light | Bone | `#FBF7F0` | oklch(0.977 0.010 81.8) |

Contrast: Flame on Bone 3.28:1 (graphics), Flame on Ink 5.00:1, Ember on Bone 5.04:1 (text), Ink/Bone 16.4:1.

## Files
- `hudhud.svg` — primary flat mark (flame on transparent); `hudhud-light.svg` (on bone), `hudhud-dark.svg`
  (on ink), `hudhud-mono.svg` (black); `hudhud-{1024,256,32}.png`, `hudhud-16.png` (= favicon)
- `favicon-16.svg/.png` — 16 px simplification: outer loop + solid dot where the curl roots
- `icon.svg` (indigo app icon), `icon-light.svg`, `icon-mono.svg`; `icon-{1024,512,256,128,64,48,32,24,16}.png`, `icon-light-1024.png`
- `AppIcon.iconset/` (icon_16x16 … icon_512x512@2x) and `app.icns` (`iconutil -c icns AppIcon.iconset -o app.icns`)
- `linux/{16,24,32,48,64,128,256}.png` (hicolor, transparent outside the squircle) and `linux/hudhud.svg`
- `join-check.png`, `board.png`, `overview.png`
- `lib.py`, `marks.py`, `build.py`

## Regenerate
`python3 -I build.py` in this folder (needs `rsvg-convert`, `magick`, `iconutil`; renders run under `nice -n 15`).

## In bunix

- Linux: `icon.svg` rendered at 16, 24, 32, 48, 64, 128 and 256 px into
  `files/hudhud/install/icons/<size>.png`, and copied there as `hudhud.svg`
  (the `linux/` output of `build.py`); `base/hudhud.bst` installs them into
  the hicolor theme.
- macOS: `macos/app.icns` (the `app.icns` output of `build.py`) and
  `macos/Assets.car`, compiled from `macos/Assets.xcassets` (the PNGs of
  `icon.svg` at 16-1024 px, in Chromium's own catalogue layout) with
  Xcode's actool:

      xcrun actool --compile <out> --platform macosx \
        --minimum-deployment-target 12.0 --app-icon AppIcon \
        --output-partial-info-plist <out>/partial.plist macos/Assets.xcassets

  `tools/build-macos.sh` copies both over Chromium's in
  `chrome/app/theme/chromium/mac`.
- `python3 -I build.py` writes its renders next to itself; `.gitignore`
  keeps them out of git.
