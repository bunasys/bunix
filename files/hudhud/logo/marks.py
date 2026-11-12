"""Hudhud — final mark: the isolated letter heh (ه) as a bold loop with a lighter counter-clockwise curl
rooted in its lower-right wall (the client's -45 degrees: 0 = right, south = down; +45 in SVG y-down).

The join. In round four the curl's root sank only 0.35 of its stroke into the ring, so the flat start cap's
inner corner sat 6.5 units inside the counter: that corner was the spike. The curl circle only grazes the
ring band, so extending the curl backwards along its own circle would poke out again on the other side.
The construction here: (1) sink the root deep enough that the whole start cap is buried in the ring body,
(2) fillet the two concave corners where the curl's inner and outer edges leave the inner wall, with
circles tangent to both the wall and the edge. The result is one clean union; the curl grows out of the wall.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

O = (512, 512)                     # outer loop centre (the isolated loop is centred in the box)
R, W = 200, 96                     # outer loop centreline radius and stroke
RI = R - W / 2                     # inner wall radius (152)
ATTACH_DEG = 45                    # the ray, SVG y-down (client: -45 degrees)
HOOK = dict(rc=84, ratio=0.46, sweep=230, tip_ratio=0.55, direction=-1)   # round four's hook-ccw, unchanged
WC = W * HOOK['ratio']             # curl stroke (44.16)
SINK = WC * 0.5 + 12               # root depth into the ring: half the stroke buries the cap, +12 margin (34.1)
FILLET = 11                        # fillet radius at the two wall corners (about W/9)

# round four's value, kept only for the before/after join check
SINK_BEFORE = WC * 0.35


def outer_ring(c=O):
    return ring(c[0], c[1], R + W / 2, R - W / 2)


def curl_centre(c=O, sink=SINK):
    d = RI - HOOK['rc'] + sink
    return polar(c[0], c[1], d, ATTACH_DEG)


def curl(c=O, sink=SINK):
    cc = curl_centre(c, sink)
    n = 240
    s = HOOK['direction'] * HOOK['sweep']
    pts = [polar(cc[0], cc[1], HOOK['rc'], ATTACH_DEG + s * i / n) for i in range(n + 1)]
    return ribbon(pts, lambda t: WC * (1 - (1 - HOOK['tip_ratio']) * smoothstep(0.7, 1.0, t)))


# ---------- the join: fillets where the curl's edges leave the inner wall ----------

def _circle_intersections(c1, r1, c2, r2):
    dx, dy = c2[0] - c1[0], c2[1] - c1[1]
    d = math.hypot(dx, dy)
    a = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
    h = math.sqrt(max(r1 * r1 - a * a, 0.0))
    mx, my = c1[0] + a * dx / d, c1[1] + a * dy / d
    return [(mx + h * dy / d, my - h * dx / d), (mx - h * dy / d, my + h * dx / d)]


def _ang(c, p):
    return math.degrees(math.atan2(p[1] - c[1], p[0] - c[0]))


def _arc_pts(c, r, a0, a1, n=40):
    """Points along the short arc from angle a0 to a1 (degrees) around c."""
    da = (a1 - a0 + 180) % 360 - 180
    return [polar(c[0], c[1], r, a0 + da * i / n) for i in range(n + 1)]


def _fillet(c, edge_r, edge_inside, f=FILLET):
    """Fillet between the inner wall (circle O, RI) and one edge of the curl (circle c, edge_r).
    edge_inside: the empty space is inside the edge circle (the curl's own hole) or outside it."""
    # the corner X: where the edge leaves the wall, on the side the curl travels (ccw = decreasing angle)
    cands = _circle_intersections(O, RI, c, edge_r)
    root_a = ATTACH_DEG
    def travel(p):
        return (_ang(c, p) - root_a + 180) % 360 - 180
    X = min(cands, key=lambda p: travel(p) if HOOK['direction'] < 0 else -travel(p))
    # fillet centre: tangent to the wall from inside, and to the edge from the empty side
    fr = edge_r - f if edge_inside else edge_r + f
    fc = min(_circle_intersections(O, RI - f, c, fr), key=lambda p: math.dist(p, X))
    T1 = polar(O[0], O[1], RI, _ang(O, fc))                  # tangent point on the wall
    T2 = polar(c[0], c[1], edge_r, _ang(c, fc))              # tangent point on the curl edge
    # the fillet's wall and edge boundaries are overdrawn 2.5 units INTO the ring and curl bodies, so the
    # union has no coincident edges (which leave hairline seams); only the fillet arc is a visible boundary
    over = 2.5
    wall_r = RI + over
    edge_body_r = edge_r + over if edge_inside else edge_r - over
    a_x = _ang(O, X)
    arc_fillet = _arc_pts(fc, f, _ang(fc, T2), _ang(fc, T1))
    # choose the fillet arc that faces the corner: its midpoint lies nearer X than the other arc's does
    mid = arc_fillet[20]
    opp = (2 * fc[0] - mid[0], 2 * fc[1] - mid[1])
    if math.dist(opp, X) < math.dist(mid, X):
        a2, a1 = _ang(fc, T2), _ang(fc, T1)
        da = (a1 - a2 + 180) % 360 - 180
        da = da - 360 if da > 0 else da + 360         # the long way round
        arc_fillet = [polar(fc[0], fc[1], f, a2 + da * i / 40) for i in range(41)]
    pts = (_arc_pts(O, wall_r, _ang(O, T1), a_x) + [polar(O[0], O[1], wall_r, a_x)] +
           _arc_pts(c, edge_body_r, _ang(c, X), _ang(c, T2)) +
           arc_fillet)
    return 'M ' + ' L '.join(P(x, y) for x, y in pts) + ' Z'


def fillets(c=O, sink=SINK):
    cc = curl_centre(c, sink)
    return [_fillet(cc, HOOK['rc'] - WC / 2, True), _fillet(cc, HOOK['rc'] + WC / 2, False)]


def mark(sink=SINK, with_fillets=True):
    paths = [outer_ring(), curl(O, sink)]
    if with_fillets:
        paths += fillets(O, sink)
    return paths


def mark_before():
    """Round four's hook-ccw, for the join check."""
    return [outer_ring(), curl(O, SINK_BEFORE)]


def dot(centre, r):
    x, y = centre
    return 'M %.2f %.2f a %.2f %.2f 0 1 0 %.2f 0 a %.2f %.2f 0 1 0 %.2f 0 Z' % (x - r, y, r, r, 2 * r, r, r, -2 * r)


def favicon():
    """16 px: the outer loop plus a solid dot where the curl roots (a tapered 1 px curl cannot be drawn)."""
    return [outer_ring(), dot(curl_centre(), 58)]
