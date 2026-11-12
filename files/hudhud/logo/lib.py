"""Shared helpers for the Hudhud round-two logo work: colour maths, SVG shapes, variable-width strokes."""
import math

# ---------- colour ----------

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def rgb_to_oklch(rgb):
    r, g, b = (srgb_to_linear(c) for c in rgb)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l_, m_, s_ = l ** (1 / 3), m ** (1 / 3), s ** (1 / 3)
    L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    C = math.hypot(a, bb)
    h = math.degrees(math.atan2(bb, a)) % 360
    return L, C, h


def luminance(h):
    r, g, b = (srgb_to_linear(c) for c in hex_to_rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(h1, h2):
    a, b = luminance(h1), luminance(h2)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def oklch_str(h):
    L, C, hue = rgb_to_oklch(hex_to_rgb(h))
    return 'oklch(%.3f %.3f %.1f)' % (L, C, hue)


# ---------- palette ----------
PAL = {
    'flame': '#F2520B',     # primary: the hoopoe's cinnamon pushed to a saturated flame orange
    'ember': '#C23A05',     # deep primary: text-safe on bone, pressed states, shadow planes
    'ink': '#15182B',       # deep / dark ground (indigo-black, complementary to flame)
    'bone': '#FBF7F0',      # light ground, sits next to Banan's paper #F6F3EE
}

# ---------- SVG geometry ----------

def P(x, y):
    return '%.2f %.2f' % (x, y)


def polar(cx, cy, r, deg):
    a = math.radians(deg)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def arc_path(cx, cy, r, a0, a1, sweep=1):
    x0, y0 = polar(cx, cy, r, a0)
    x1, y1 = polar(cx, cy, r, a1)
    large = 1 if abs(a1 - a0) > 180 else 0
    return 'M %s A %.2f %.2f 0 %d %d %s' % (P(x0, y0), r, r, large, sweep, P(x1, y1))


def ring(cx, cy, r_out, r_in):
    """Filled annulus as a path (fill-rule evenodd)."""
    return ('M %.2f %.2f a %.2f %.2f 0 1 0 %.2f 0 a %.2f %.2f 0 1 0 %.2f 0 Z '
            'M %.2f %.2f a %.2f %.2f 0 1 0 %.2f 0 a %.2f %.2f 0 1 0 %.2f 0 Z') % (
        cx - r_out, cy, r_out, r_out, 2 * r_out, r_out, r_out, -2 * r_out,
        cx - r_in, cy, r_in, r_in, 2 * r_in, r_in, r_in, -2 * r_in)


def squircle(cx, cy, size, n=5.0, steps=720):
    """Apple-style continuous-corner square, approximated by the superellipse |x|^n + |y|^n = 1."""
    a = size / 2
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        x = cx + a * math.copysign(abs(c) ** (2 / n), c)
        y = cy + a * math.copysign(abs(s) ** (2 / n), s)
        pts.append(P(x, y))
    return 'M ' + ' L '.join(pts) + ' Z'


def svg(body, size=1024, bg=None, defs=''):
    rect = '' if bg is None else '<rect width="%d" height="%d" fill="%s"/>' % (size, size, bg)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">'
            '%s%s%s</svg>') % (size, size, size, size, ('<defs>%s</defs>' % defs) if defs else '', rect, body)


def write(path, text):
    with open(path, 'w') as f:
        f.write(text)


# ---------- variable-width strokes ----------

def bezier(p0, p1, p2, p3, n=120):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        x = u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0]
        y = u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]
        pts.append((x, y))
    return pts


def ribbon(pts, width_fn):
    """Outline polygon of a centreline with width width_fn(t), t in 0..1, as a path 'd'."""
    n = len(pts)
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        x0, y0 = pts[max(i - 1, 0)]
        x1, y1 = pts[min(i + 1, n - 1)]
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L, dx / L
        w = width_fn(i / (n - 1)) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    outline = left + right[::-1]
    return 'M ' + ' L '.join(P(x, y) for x, y in outline) + ' Z'


def smoothstep(a, b, t):
    t = max(0.0, min(1.0, (t - a) / (b - a)))
    return t * t * (3 - 2 * t)
