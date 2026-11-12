"""Build every final deliverable into the folder this file lives in: python3 -I build.py"""
import sys, os, base64, subprocess, shutil, math
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from lib import *
from marks import *

FLAME, EMBER, INK, BONE = PAL['flame'], PAL['ember'], PAL['ink'], PAL['bone']
FONT = "font-family=\"Helvetica Neue, Helvetica, Arial, sans-serif\""


def out(name):
    return os.path.join(HERE, name)


def run(cmd):
    subprocess.run(['nice', '-n', '15'] + cmd, check=True)


def render(svg_path, png_path, w, h=None):
    run(['rsvg-convert', '-w', str(w)] + (['-h', str(h)] if h else []) + [svg_path, '-o', png_path])


def data_uri(png_path):
    with open(png_path, 'rb') as f:
        return 'data:image/png;base64,' + base64.b64encode(f.read()).decode()


def fills(paths, color):
    return ''.join('<path d="%s" fill="%s" fill-rule="evenodd"/>' % (d, color) for d in paths)


# ---------------------------------------------------------------------------
# app icon
# ---------------------------------------------------------------------------
ICON_N = 5.0
ICON_S = 0.70
ICON_TF = 'translate(%.1f %.1f) scale(%.3f)' % (512 - 512 * ICON_S, 512 - 512 * ICON_S, ICON_S)


def icon_svg(paths, mode='dark'):
    sq = squircle(512, 512, 824, n=ICON_N)
    if mode == 'mono':
        return svg('<path d="%s" fill="%s"/>' % (sq, INK) + '<g transform="%s">%s</g>' % (ICON_TF, fills(paths, BONE)))
    if mode == 'dark':
        g_top, g_bot, plane, glow = '#262B4F', '#0E1020', '#1B2040', '#3A4170'
        m_top, m_bot, shadow_op = '#FF6E2E', '#E24708', 0.55
    else:
        g_top, g_bot, plane, glow = '#FFFDF8', '#EFE8DC', '#F4EEE4', '#FFFFFF'
        m_top, m_bot, shadow_op = '#FF6A28', '#DD4407', 0.28
    y0 = 512 - (R + W / 2) * ICON_S
    y1 = 512 + (R + W / 2) * ICON_S
    # the mark's gradient and specular are defined in user space / clipped to the union of all its paths,
    # so ring, curl and fillets share one continuous tone map across the join
    defs = (
        '<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % (g_top, g_bot) +
        '<radialGradient id="glow" cx="0.3" cy="0.1" r="0.9"><stop offset="0" stop-color="%s" stop-opacity="0.55"/><stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>' % (glow, glow) +
        '<linearGradient id="mk" gradientUnits="userSpaceOnUse" x1="0" y1="%.0f" x2="0" y2="%.0f"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % (y0, y1, m_top, m_bot) +
        '<linearGradient id="spec" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.38"/><stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>' +
        '<linearGradient id="rim" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.45"/><stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0.04"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0.12"/></linearGradient>' +
        '<clipPath id="sqclip"><path d="%s"/></clipPath>' % sq +
        '<clipPath id="mkclip"><g transform="%s">%s</g></clipPath>' % (ICON_TF, ''.join('<path d="%s" clip-rule="evenodd"/>' % d for d in paths)) +
        '<filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="18"/></filter>' +
        '<filter id="softer" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="40"/></filter>'
    )
    body = (
        '<path d="%s" fill="url(#bg)"/>' % sq +
        '<path d="%s" fill="url(#glow)"/>' % sq +
        '<g clip-path="url(#sqclip)">'
        '<circle cx="512" cy="512" r="%d" fill="%s"/>' % (int(R * ICON_S * 2.0), plane) +
        '<circle cx="512" cy="512" r="%d" fill="%s" opacity="0.5" filter="url(#softer)"/>' % (int(R * ICON_S * 1.25), plane) +
        '</g>' +
        '<g transform="translate(0 16)" opacity="%.2f" filter="url(#soft)"><g transform="%s">%s</g></g>' % (shadow_op, ICON_TF, fills(paths, '#000000')) +
        '<g transform="%s">%s</g>' % (ICON_TF, fills(paths, 'url(#mk)')) +
        '<g clip-path="url(#mkclip)"><rect x="0" y="0" width="1024" height="1024" fill="url(#spec)"/></g>' +
        '<g clip-path="url(#sqclip)"><path d="%s" fill="none" stroke="url(#rim)" stroke-width="6"/></g>' % sq
    )
    return svg(body, defs=defs)


# ---------------------------------------------------------------------------
# construction grid
# ---------------------------------------------------------------------------
GL = 'fill="none" stroke="%s" stroke-width="2"' % INK
GD = 'fill="none" stroke="%s" stroke-width="2" stroke-dasharray="10 10"' % INK


def grid():
    cx, cy = O
    ccx, ccy = curl_centre()
    g = ''.join('<circle cx="%d" cy="%d" r="%.1f" %s/>' % (cx, cy, r, GL) for r in (RI, R, R + W / 2))
    g += ''.join('<circle cx="%.1f" cy="%.1f" r="%.1f" %s/>' % (ccx, ccy, r, GL) for r in (HOOK['rc'] - WC / 2, HOOK['rc'], HOOK['rc'] + WC / 2))
    g += '<line x1="%d" y1="40" x2="%d" y2="984" %s/>' % (cx, cx, GD) + '<line x1="40" y1="%d" x2="984" y2="%d" %s/>' % (cy, cy, GD)
    ex, ey = polar(cx, cy, R + 170, ATTACH_DEG)
    g += '<line x1="%d" y1="%d" x2="%.1f" y2="%.1f" %s/>' % (cx, cy, ex, ey, GL)
    g += '<path d="%s" %s/>' % (arc_path(cx, cy, 120, 0, ATTACH_DEG), GL)
    g += '<circle cx="%.1f" cy="%.1f" r="6" fill="%s"/>' % (ccx, ccy, INK)
    g += '<text x="%d" y="%d" font-size="30" fill="%s" %s>−45°</text>' % (cx + 140, cy + 60, INK, FONT)
    g += '<text x="%.0f" y="%.0f" font-size="26" fill="%s" %s>r %d · %.2f W · %d° ccw · root %.0f in · fillet %d</text>' % (
        ex - 300, ey + 36, INK, FONT, HOOK['rc'], HOOK['ratio'], HOOK['sweep'], SINK, FILLET)
    return g


# ---------------------------------------------------------------------------
# board
# ---------------------------------------------------------------------------
def generic_icon(ground, glyph):
    return '<path d="%s" fill="%s"/>%s' % (squircle(512, 512, 824, n=ICON_N), ground, glyph)


NEIGHBOURS = [
    generic_icon('#3B6FE0', '<circle cx="512" cy="512" r="230" fill="none" stroke="#FFFFFF" stroke-width="70"/>'),
    generic_icon('#8A8F9A', '<rect x="312" y="312" width="400" height="400" rx="60" fill="#FFFFFF"/>'),
    generic_icon('#3FBF6B', '<path d="M 512 300 L 740 700 L 284 700 Z" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="80" stroke-linejoin="round"/>'),
    generic_icon('#F2F2F2', '<rect x="300" y="300" width="424" height="424" rx="40" fill="none" stroke="#333" stroke-width="56"/><line x1="300" y1="440" x2="724" y2="440" stroke="#333" stroke-width="56"/>'),
    generic_icon('#8A47D6', '<circle cx="512" cy="512" r="190" fill="#FFFFFF"/>'),
]


def dock(x, y, w, icons):
    size, pad = 128, 24
    bar_w = len(icons) * (size + pad) + pad
    bx = x + (w - bar_w) / 2
    g = '<rect x="%d" y="%d" width="%d" height="%d" rx="36" fill="#FFFFFF" fill-opacity="0.55" stroke="#FFFFFF" stroke-opacity="0.7" stroke-width="2"/>' % (bx, y, bar_w, size + 2 * pad)
    for i, ic in enumerate(icons):
        g += '<g transform="translate(%d %d) scale(%.5f)">%s</g>' % (bx + pad + i * (size + pad), y + pad, size / 1024, ic)
    return g


def tabstrip(x, y, w, fav16_uri, title):
    g = '<rect x="%d" y="%d" width="%d" height="128" rx="14" fill="#DCD8D0"/>' % (x, y, w)
    g += '<rect x="%d" y="%d" width="260" height="44" rx="10" fill="#CFCAC1"/>' % (x + 18, y + 14)
    g += '<circle cx="%d" cy="%d" r="7" fill="#8A8F9A"/>' % (x + 40, y + 36)
    g += '<text x="%d" y="%d" font-size="18" fill="#555" %s>bunasys.com</text>' % (x + 56, y + 42, FONT)
    g += '<path d="M %d %d h 300 a 10 10 0 0 1 10 10 v 48 h -320 v -48 a 10 10 0 0 1 10 -10 Z" fill="%s"/>' % (x + 298, y + 14, BONE)
    g += '<image x="%d" y="%d" width="16" height="16" href="%s"/>' % (x + 318, y + 28, fav16_uri)
    g += '<text x="%d" y="%d" font-size="18" fill="%s" %s>%s</text>' % (x + 344, y + 42, INK, FONT, title)
    g += '<rect x="%d" y="%d" width="%d" height="44" rx="12" fill="%s"/>' % (x, y + 72, w, BONE)
    g += '<text x="%d" y="%d" font-size="18" fill="#777" %s>hudhud://private   ·   Shields on</text>' % (x + 24, y + 100, FONT)
    return g


def board(paths, fav_svg, icon_inner):
    tmp = out('_tmp_mark.svg')
    write(tmp, svg(fills(paths, FLAME)))
    uris = {}
    for px in (16, 32, 64):
        p = out('_tmp_%d.png' % px); render(fav_svg if px == 16 else tmp, p, px); uris[px] = data_uri(p)
        big = out('_tmp_%d_x4.png' % px)
        run(['magick', p, '-filter', 'point', '-resize', '400%', big])
        uris[(px, 4)] = data_uri(big)
    W_, H_ = 2000, 1400
    g = '<rect width="%d" height="%d" fill="#ECE8E1"/>' % (W_, H_)
    g += '<text x="60" y="78" font-size="34" fill="%s" %s font-weight="bold">Hudhud · ه · final</text>' % (INK, FONT)
    g += '<rect x="60" y="110" width="760" height="760" rx="24" fill="%s"/>' % BONE
    g += '<g transform="translate(80 130) scale(0.7031)">%s%s</g>' % (fills(paths, FLAME), grid())
    g += '<text x="60" y="905" font-size="22" fill="#666" %s>construction: loop R 200 / W 96; curl r 84 / 0.46 W, 230° counter-clockwise, rooted on the −45° ray, filleted into the wall</text>' % FONT
    for i, (ground, col) in enumerate(((BONE, FLAME), (INK, FLAME), ('#FFFFFF', INK), (INK, BONE))):
        tx = 860 + (i % 2) * 300; ty = 110 + (i // 2) * 300
        g += '<rect x="%d" y="%d" width="280" height="280" rx="20" fill="%s"/>' % (tx, ty, ground)
        g += '<g transform="translate(%d %d) scale(0.2344)">%s</g>' % (tx + 20, ty + 20, fills(paths, col))
    g += '<text x="860" y="730" font-size="22" fill="#666" %s>primary on light / dark · ink and bone mono</text>' % FONT
    sx, sy = 1480, 110
    for row, ground in enumerate((BONE, INK)):
        g += '<rect x="%d" y="%d" width="460" height="130" rx="16" fill="%s"/>' % (sx, sy + row * 150, ground)
        xx = sx + 24
        for px in (64, 32, 16):
            g += '<image x="%d" y="%d" width="%d" height="%d" href="%s"/>' % (xx, sy + row * 150 + 65 - px / 2, px, px, uris[px])
            xx += px + 28
        g += '<image x="%d" y="%d" width="64" height="64" href="%s"/>' % (xx + 10, sy + row * 150 + 33, uris[(16, 4)])
        g += '<image x="%d" y="%d" width="128" height="128" href="%s"/>' % (xx + 100, sy + row * 150 + 1, uris[(32, 4)])
    g += '<text x="1480" y="430" font-size="22" fill="#666" %s>64 · 32 · 16 px at 1:1 (16 = favicon), then 16 and 32 at 4x</text>' % FONT
    g += '<defs><linearGradient id="wall" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2E3A6B"/><stop offset="1" stop-color="#6B3A5C"/></linearGradient></defs>'
    g += '<rect x="60" y="950" width="1880" height="250" rx="24" fill="url(#wall)"/>'
    g += dock(60, 985, 1880, NEIGHBOURS[:2] + [icon_inner] + NEIGHBOURS[2:])
    g += tabstrip(60, 1230, 1880, uris[16], 'Hudhud — Private window')
    doc = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">%s</svg>' % (W_, H_, W_, H_, g)
    p = out('_tmp_board.svg')
    write(p, doc)
    render(p, out('board.png'), W_, H_)


# ---------------------------------------------------------------------------
# join check: the root region at 4096 px equivalent, before and after, on bone and ink, plus the icon
# ---------------------------------------------------------------------------
def join_check(paths_before, paths_after, icon_svg_path):
    tiles = []
    root = polar(O[0], O[1], RI + 20, ATTACH_DEG)           # look at the wall around the root
    cx, cy = int(root[0] * 4), int(root[1] * 4)
    crop = '900x900+%d+%d' % (cx - 450, cy - 450)
    for label, paths in (('before (round four)', paths_before), ('after (final)', paths_after)):
        for ground in (BONE, INK):
            s = out('_tmp_join.svg'); write(s, svg(fills(paths, FLAME), bg=ground))
            p = out('_tmp_join_%d.png' % len(tiles)); render(s, p, 4096)
            run(['magick', p, '-crop', crop, '+repage', p])
            tiles.append((p, label))
    # the icon's join with gradient and specular: the icon at 4096, the root region scaled by ICON_S
    ri = 512 + ((RI + 20) * ICON_S) * 0.7071 * 1 - 0           # placeholder, replaced below
    rx = (512 - 512 * ICON_S + root[0] * ICON_S) * 4
    ry = (512 - 512 * ICON_S + root[1] * ICON_S) * 4
    p = out('_tmp_join_icon.png'); render(icon_svg_path, p, 4096)
    run(['magick', p, '-crop', '900x900+%d+%d' % (int(rx) - 450, int(ry) - 450), '+repage', p])
    tiles.append((p, 'after, in the app icon'))
    labelled = []
    for i, (p, label) in enumerate(tiles):
        q = out('_tmp_join_l%d.png' % i)
        run(['magick', p, '-gravity', 'south', '-background', '#ECE8E1', '-splice', '0x60',
             '-font', '/System/Library/Fonts/Supplemental/Arial.ttf', '-pointsize', '34', '-fill', INK,
             '-annotate', '+0+14', label, q])
        labelled.append(q)
    run(['magick'] + labelled[:2] + ['+append', out('_tmp_row1.png')])
    run(['magick'] + labelled[2:4] + ['+append', out('_tmp_row2.png')])
    run(['magick', out('_tmp_row1.png'), out('_tmp_row2.png'), labelled[4], '-background', '#ECE8E1', '-gravity', 'west', '-append', out('join-check.png')])


# ---------------------------------------------------------------------------
def main():
    paths = mark()
    write(out('hudhud.svg'), svg(fills(paths, FLAME)))
    write(out('hudhud-light.svg'), svg(fills(paths, FLAME), bg=BONE))
    write(out('hudhud-dark.svg'), svg(fills(paths, FLAME), bg=INK))
    write(out('hudhud-mono.svg'), svg(fills(paths, '#000000')))
    fav = out('favicon-16.svg')
    write(fav, svg(fills(favicon(), FLAME)))
    render(fav, out('favicon-16.png'), 16)
    for px in (1024, 256, 32):
        render(out('hudhud.svg'), out('hudhud-%d.png' % px), px)
    render(fav, out('hudhud-16.png'), 16)

    write(out('icon.svg'), icon_svg(paths, 'dark'))
    write(out('icon-light.svg'), icon_svg(paths, 'light'))
    write(out('icon-mono.svg'), icon_svg(paths, 'mono'))
    for px in (1024, 512, 256, 128, 64, 48, 32, 24, 16):
        render(out('icon.svg'), out('icon-%d.png' % px), px)
    render(out('icon-light.svg'), out('icon-light-1024.png'), 1024)

    # macOS iconset + icns
    iconset = out('AppIcon.iconset')
    os.makedirs(iconset, exist_ok=True)
    for base in (16, 32, 128, 256, 512):
        render(out('icon.svg'), os.path.join(iconset, 'icon_%dx%d.png' % (base, base)), base)
        render(out('icon.svg'), os.path.join(iconset, 'icon_%dx%d@2x.png' % (base, base)), base * 2)
    run(['iconutil', '-c', 'icns', iconset, '-o', out('app.icns')])

    # Linux hicolor set
    linux = out('linux')
    os.makedirs(linux, exist_ok=True)
    for px in (16, 24, 32, 48, 64, 128, 256):
        render(out('icon.svg'), os.path.join(linux, '%d.png' % px), px)
    shutil.copy(out('icon.svg'), os.path.join(linux, 'hudhud.svg'))

    with open(out('icon.svg')) as f:
        d = f.read()
    icon_inner = d[d.index('>', d.index('<svg')) + 1:d.rindex('</svg>')]
    board(paths, fav, icon_inner)
    join_check(mark_before(), paths, out('icon.svg'))

    # overview: mark and icon at 512 / 64 / 32 / 16 on light and dark
    W_, H_ = 1800, 1700
    g = ''
    for row, ground in enumerate((BONE, INK)):
        g += '<rect x="0" y="%d" width="%d" height="850" fill="%s"/>' % (row * 850, W_, ground)
        for i, base in enumerate(('hudhud', 'hudhud-mono', 'icon')):
            x = 60 + i * 580
            uris = {}
            src_svg = out('hudhud-mono.svg') if base == 'hudhud-mono' else out(base + '.svg')
            if base == 'hudhud-mono':
                src_svg = out('_tmp_mono_%d.svg' % row); write(src_svg, svg(fills(paths, BONE if row else INK)))
            for px in (512, 64, 32, 16):
                src = fav if (px == 16 and base == 'hudhud') else src_svg
                p = out('_tmp_ov_%s_%d.png' % (base, px)); render(src, p, px); uris[px] = data_uri(p)
            g += '<image x="%d" y="%d" width="512" height="512" href="%s"/>' % (x, row * 850 + 60, uris[512])
            xx = x
            for px in (64, 32, 16):
                g += '<image x="%d" y="%d" width="%d" height="%d" href="%s"/>' % (xx, row * 850 + 640 - px / 2, px, px, uris[px])
                xx += px + 40
            g += '<text x="%d" y="%d" font-size="26" fill="#888" %s>%s</text>' % (x, row * 850 + 760, FONT, base)
    doc = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">%s</svg>' % (W_, H_, W_, H_, g)
    write(out('_tmp_overview.svg'), doc)
    render(out('_tmp_overview.svg'), out('overview.png'), W_, H_)

    for f in os.listdir(HERE):
        if f.startswith('_tmp_'):
            os.remove(out(f))
    print('built')


if __name__ == '__main__':
    main()
