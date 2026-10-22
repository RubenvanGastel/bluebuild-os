#!/usr/bin/env python3
"""Port of androidx graphics-shapes (RoundedPolygon/RoundedCorner) and compose material3
MaterialShapes, emitting the M3 Expressive shapes as SVG paths in the unit square (as
RoundedPolygon.normalized()) plus polar samples for morphing.

    python3 tools/gen-material-shapes.py check    bounds of each shape
    python3 tools/gen-material-shapes.py          the JSON that services/Shapes.qml holds
"""
import math, sys, json

EPS = 1e-4  # DistanceEpsilon


def sub(a, b): return (a[0] - b[0], a[1] - b[1])
def add(a, b): return (a[0] + b[0], a[1] + b[1])
def mul(a, k): return (a[0] * k, a[1] * k)
def dot(a, b): return a[0] * b[0] + a[1] * b[1]
def length(a): return math.hypot(a[0], a[1])
def direction(a):
    d = length(a)
    return (a[0] / d, a[1] / d)
def rot90(a): return (-a[1], a[0])
def lerp(a, b, t): return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


class Rounding:
    def __init__(self, radius=0.0, smoothing=0.0):
        self.radius, self.smoothing = radius, smoothing

UNROUNDED = Rounding()


def straight(p0, p1):
    return (p0, lerp(p0, p1, 1 / 3), lerp(p0, p1, 2 / 3), p1)


def circular_arc(c, p0, p1):
    p0d = direction(sub(p0, c))
    p1d = direction(sub(p1, c))
    r0, r1 = rot90(p0d), rot90(p1d)
    clockwise = dot(r0, sub(p1, c)) >= 0
    cosa = dot(p0d, p1d)
    if cosa > 0.999:
        return straight(p0, p1)
    k = length(sub(p0, c)) * 4 / 3 * (math.sqrt(2 * (1 - cosa)) - math.sqrt(1 - cosa * cosa)) / (1 - cosa) * (1 if clockwise else -1)
    return (p0, add(p0, mul(r0, k)), sub(p1, mul(r1, k)), p1)


def line_intersection(p0, d0, p1, d1):
    rd1 = rot90(d1)
    den = dot(d0, rd1)
    if abs(den) < EPS:
        return None
    num = dot(sub(p1, p0), rd1)
    if abs(den) < EPS * abs(num):
        return None
    return add(p0, mul(d0, num / den))


class Corner:
    def __init__(self, p0, p1, p2, rounding):
        self.p0, self.p1, self.p2 = p0, p1, p2
        v01, v21 = sub(p0, p1), sub(p2, p1)
        d01, d21 = length(v01), length(v21)
        if d01 > 0 and d21 > 0:
            self.d1, self.d2 = mul(v01, 1 / d01), mul(v21, 1 / d21)
            self.r = rounding.radius if rounding else 0
            self.s = rounding.smoothing if rounding else 0
            cos_a = dot(self.d1, self.d2)
            sin_a = math.sqrt(max(0.0, 1 - cos_a * cos_a))
            self.round_cut = self.r * (cos_a + 1) / sin_a if sin_a > 1e-3 else 0
        else:
            self.d1 = self.d2 = (0, 0)
            self.r = self.s = 0
            self.round_cut = 0

    @property
    def cut(self):
        return (1 + self.s) * self.round_cut

    def smoothing_for(self, allowed):
        if allowed > self.cut:
            return self.s
        if allowed > self.round_cut:
            return self.s * (allowed - self.round_cut) / (self.cut - self.round_cut)
        return 0

    def flanking(self, round_cut, smooth, corner, side_start, ci, other_ci, center, r):
        side_dir = direction(sub(side_start, corner))
        curve_start = add(corner, mul(side_dir, round_cut * (1 + smooth)))
        p = lerp(ci, mul(add(ci, other_ci), 0.5), smooth)
        curve_end = add(center, mul(direction(sub(p, center)), r))
        tangent = rot90(sub(curve_end, center))
        anchor_end = line_intersection(side_start, side_dir, curve_end, tangent) or ci
        anchor_start = mul(add(curve_start, mul(anchor_end, 2)), 1 / 3)
        return (curve_start, anchor_start, anchor_end, curve_end)

    def cubics(self, allowed0, allowed1):
        allowed = min(allowed0, allowed1)
        if self.round_cut < EPS or allowed < EPS or self.r < EPS:
            return [straight(self.p1, self.p1)]
        actual_round_cut = min(allowed, self.round_cut)
        s0 = self.smoothing_for(allowed0)
        s1 = self.smoothing_for(allowed1)
        actual_r = self.r * actual_round_cut / self.round_cut
        center_dist = math.sqrt(actual_r ** 2 + actual_round_cut ** 2)
        center = add(self.p1, mul(direction(mul(add(self.d1, self.d2), 0.5)), center_dist))
        ci0 = add(self.p1, mul(self.d1, actual_round_cut))
        ci2 = add(self.p1, mul(self.d2, actual_round_cut))
        f0 = self.flanking(actual_round_cut, s0, self.p1, self.p0, ci0, ci2, center, actual_r)
        f2 = self.flanking(actual_round_cut, s1, self.p1, self.p2, ci2, ci0, center, actual_r)
        f2 = tuple(reversed(f2))
        return [f0, circular_arc(center, f0[3], f2[0]), f2]


def polygon(vertices, rounding=UNROUNDED, per_vertex=None):
    """RoundedPolygon(vertices, rounding, perVertexRounding): list of cubics."""
    n = len(vertices)
    corners = []
    for i in range(n):
        r = per_vertex[i] if per_vertex else rounding
        corners.append(Corner(vertices[(i - 1) % n], vertices[i], vertices[(i + 1) % n], r))
    adjusts = []
    for i in range(n):
        erc = corners[i].round_cut + corners[(i + 1) % n].round_cut
        ec = corners[i].cut + corners[(i + 1) % n].cut
        side = length(sub(vertices[i], vertices[(i + 1) % n]))
        if erc > side:
            adjusts.append((side / erc, 0))
        elif ec > side:
            adjusts.append((1, (side - erc) / (ec - erc)))
        else:
            adjusts.append((1, 1))
    pieces = []
    for i in range(n):
        cuts = []
        for delta in (0, 1):
            rr, cr = adjusts[(i + n - 1 + delta) % n]
            cuts.append(corners[i].round_cut * rr + (corners[i].cut - corners[i].round_cut) * cr)
        pieces.append(corners[i].cubics(cuts[0], cuts[1]))
    out = []
    for i in range(n):
        out += pieces[i]
        out.append(straight(pieces[i][-1][3], pieces[(i + 1) % n][0][0]))
    return out


def radial(r, a):
    return (r * math.cos(a), r * math.sin(a))


def regular(num, radius=1.0, rounding=UNROUNDED, per_vertex=None):
    return polygon([radial(radius, math.pi / num * 2 * i) for i in range(num)], rounding, per_vertex)


def circle(num=8, radius=1.0):
    return regular(num, radius / math.cos(math.pi / num), Rounding(radius))


def rectangle(w, h, rounding=UNROUNDED, per_vertex=None):
    l, t, r, b = -w / 2, -h / 2, w / 2, h / 2
    return polygon([(r, b), (l, b), (l, t), (r, t)], rounding, per_vertex)


def star(num, inner, rounding=UNROUNDED):
    v = []
    for i in range(num):
        v.append(radial(1, math.pi / num * 2 * i))
        v.append(radial(inner, math.pi / num * (2 * i + 1)))
    return polygon(v, rounding)


def transform(cubics, f):
    return [tuple(f(p) for p in c) for c in cubics]


def rotate(deg):
    a = math.radians(deg)
    return lambda p: (p[0] * math.cos(a) - p[1] * math.sin(a), p[0] * math.sin(a) + p[1] * math.cos(a))


def scale(sx, sy):
    return lambda p: (p[0] * sx, p[1] * sy)


def bezier(c, t):
    u = 1 - t
    return (u ** 3 * c[0][0] + 3 * u * u * t * c[1][0] + 3 * u * t * t * c[2][0] + t ** 3 * c[3][0],
            u ** 3 * c[0][1] + 3 * u * u * t * c[1][1] + 3 * u * t * t * c[2][1] + t ** 3 * c[3][1])


def bounds(cubics):
    pts = [bezier(c, i / 64) for c in cubics for i in range(65)]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def normalized(cubics):
    l, t, r, b = bounds(cubics)
    w, h = r - l, b - t
    side = max(w, h)
    ox, oy = (side - w) / 2 - l, (side - h) / 2 - t
    return transform(cubics, lambda p: ((p[0] + ox) / side, (p[1] + oy) / side))


def custom(pnr, reps, center=(0.5, 0.5), mirroring=False):
    pts = []
    if mirroring:
        angles = [math.degrees(math.atan2(p[0][1] - center[1], p[0][0] - center[0])) for p in pnr]
        dists = [length(sub(p[0], center)) for p in pnr]
        actual = reps * 2
        section = 360 / actual
        for it in range(actual):
            for index in range(len(pnr)):
                i = index if it % 2 == 0 else len(pnr) - 1 - index
                if i > 0 or it % 2 == 0:
                    a = math.radians(section * it + (angles[i] if it % 2 == 0 else section - angles[i] + 2 * angles[0]))
                    pts.append(((math.cos(a) * dists[i] + center[0], math.sin(a) * dists[i] + center[1]), pnr[i][1]))
    else:
        np_ = len(pnr)
        for it in range(np_ * reps):
            o, r = pnr[it % np_]
            a = math.radians((it // np_) * 360 / reps)
            off = sub(o, center)
            pts.append(((off[0] * math.cos(a) - off[1] * math.sin(a) + center[0], off[0] * math.sin(a) + off[1] * math.cos(a) + center[1]), r))
    return polygon([p[0] for p in pts], per_vertex=[p[1] for p in pts])


R = Rounding
P = lambda x, y, r=UNROUNDED: ((x, y), r)
r15, r20, r30, r50, r100 = R(.15), R(.2), R(.3), R(.5), R(1)

SHAPES = {
    "circle": circle(10),
    "square": rectangle(1, 1, r30),
    "slanted": custom([P(0.926, 0.970, R(0.189, 0.811)), P(-0.021, 0.967, R(0.187, 0.057))], 2),
    "arch": transform(regular(4, per_vertex=[r100, r100, r20, r20]), rotate(-135)),
    "fan": custom([P(1.004, 1.000, R(0.148, 0.417)), P(0.000, 1.000, R(0.151)), P(0.000, -0.003, R(0.148)), P(0.978, 0.020, R(0.803))], 1),
    "arrow": custom([P(0.500, 0.892, R(0.313)), P(-0.216, 1.050, R(0.207)), P(0.499, -0.160, R(0.215, 1.000)), P(1.225, 1.060, R(0.211))], 1),
    "semiCircle": rectangle(1.6, 1, per_vertex=[r20, r20, r100, r100]),
    "oval": transform(transform(circle(), scale(1, 0.64)), rotate(-45)),
    "pill": custom([P(0.961, 0.039, R(0.426)), P(1.001, 0.428), P(1.000, 0.609, R(1.000))], 2, mirroring=True),
    "triangle": transform(regular(3, rounding=r20), rotate(-90)),
    "diamond": custom([P(0.500, 1.096, R(0.151, 0.524)), P(0.040, 0.500, R(0.159))], 2),
    "clamShell": custom([P(0.171, 0.841, R(0.159)), P(-0.020, 0.500, R(0.140)), P(0.170, 0.159, R(0.159))], 2),
    "pentagon": custom([P(0.500, -0.009, R(0.172)), P(1.030, 0.365, R(0.164)), P(0.828, 0.970, R(0.169))], 1, mirroring=True),
    "gem": custom([P(0.499, 1.023, R(0.241, 0.778)), P(-0.005, 0.792, R(0.208)), P(0.073, 0.258, R(0.228)), P(0.433, -0.000, R(0.491))], 1, mirroring=True),
    "sunny": star(8, .8, r15),
    "verySunny": custom([P(0.500, 1.080, R(0.085)), P(0.358, 0.843, R(0.085))], 8),
    "cookie4Sided": custom([P(1.237, 1.236, R(0.258)), P(0.500, 0.918, R(0.233))], 4),
    "cookie6Sided": custom([P(0.723, 0.884, R(0.394)), P(0.500, 1.099, R(0.398))], 6),
    "cookie7Sided": transform(star(7, .75, r50), rotate(-90)),
    "cookie9Sided": transform(star(9, .8, r50), rotate(-90)),
    "cookie12Sided": transform(star(12, .8, r50), rotate(-90)),
    "ghostish": custom([P(0.500, 0, R(1.000)), P(1, 0, R(1.000)), P(1, 1.140, R(0.254, 0.106)), P(0.575, 0.906, R(0.253))], 1, mirroring=True),
    "clover4Leaf": custom([P(0.500, 0.074), P(0.725, -0.099, R(0.476))], 4, mirroring=True),
    "clover8Leaf": custom([P(0.500, 0.036), P(0.758, -0.101, R(0.209))], 8),
    "burst": custom([P(0.500, -0.006, R(0.006)), P(0.592, 0.158, R(0.006))], 12),
    "softBurst": custom([P(0.193, 0.277, R(0.053)), P(0.176, 0.055, R(0.053))], 10),
    "boom": custom([P(0.457, 0.296, R(0.007)), P(0.500, -0.051, R(0.007))], 15),
    "softBoom": custom([P(0.733, 0.454), P(0.839, 0.437, R(0.532)), P(0.949, 0.449, R(0.439, 1.000)), P(0.998, 0.478, R(0.174))], 16, mirroring=True),
    "flower": custom([P(0.370, 0.187), P(0.416, 0.049, R(0.381)), P(0.479, 0.001, R(0.095))], 8, mirroring=True),
    "puffy": transform(custom([P(0.500, 0.053), P(0.545, -0.040, R(0.405)), P(0.670, -0.035, R(0.426)), P(0.717, 0.066, R(0.574)), P(0.722, 0.128), P(0.777, 0.002, R(0.360)), P(0.914, 0.149, R(0.660)), P(0.926, 0.289, R(0.660)), P(0.881, 0.346), P(0.940, 0.344, R(0.126)), P(1.003, 0.437, R(0.255))], 2, mirroring=True), scale(1, 0.742)),
    "puffyDiamond": custom([P(0.870, 0.130, R(0.146)), P(0.818, 0.357), P(1.000, 0.332, R(0.853))], 4, mirroring=True),
    "pixelCircle": custom([P(0.500, 0.000), P(0.704, 0.000), P(0.704, 0.065), P(0.843, 0.065), P(0.843, 0.148), P(0.926, 0.148), P(0.926, 0.296), P(1.000, 0.296)], 2, mirroring=True),
    "pixelTriangle": custom([P(0.110, 0.500), P(0.113, 0.000), P(0.287, 0.000), P(0.287, 0.087), P(0.421, 0.087), P(0.421, 0.170), P(0.560, 0.170), P(0.560, 0.265), P(0.674, 0.265), P(0.675, 0.344), P(0.789, 0.344), P(0.789, 0.439), P(0.888, 0.439)], 1, mirroring=True),
    "bun": custom([P(0.796, 0.500), P(0.853, 0.518, R(1)), P(0.992, 0.631, R(1)), P(0.968, 1.000, R(1))], 2, mirroring=True),
    "heart": custom([P(0.500, 0.268, R(0.016)), P(0.792, -0.066, R(0.958)), P(1.064, 0.276, R(1.000)), P(0.501, 0.946, R(0.129))], 1, mirroring=True),
}

# LoadingIndicatorDefaults.IndeterminateIndicatorPolygons, in order.
LOADER = ["softBurst", "cookie9Sided", "pentagon", "pill", "sunny", "cookie4Sided", "oval"]


def fmt(v):
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def svg(cubics):
    cubics = [c for c in cubics if length(sub(c[0], c[3])) > 1e-6 or length(sub(c[1], c[0])) > 1e-6]
    out = [f"M{fmt(cubics[0][0][0])} {fmt(cubics[0][0][1])}"]
    for c in cubics:
        out.append("C" + " ".join(f"{fmt(p[0])} {fmt(p[1])}" for p in c[1:]))
    return "".join(out) + "Z"


def polar(cubics, n):
    """Radius from the centre (0.5, 0.5) at n even angles, starting at 0 (+x), clockwise on
    screen (y down). The outline must be star-shaped around the centre."""
    pts = [bezier(c, i / 40) for c in cubics for i in range(40)]
    samples = sorted((math.atan2(p[1] - .5, p[0] - .5) % (2 * math.pi), length(sub(p, (.5, .5)))) for p in pts)
    out = []
    for k in range(n):
        a = 2 * math.pi * k / n
        # Nearest samples on either side, wrapping around.
        j = next((i for i, s in enumerate(samples) if s[0] >= a), len(samples))
        lo = samples[j - 1] if j > 0 else (samples[-1][0] - 2 * math.pi, samples[-1][1])
        hi = samples[j] if j < len(samples) else (samples[0][0] + 2 * math.pi, samples[0][1])
        t = 0 if hi[0] == lo[0] else (a - lo[0]) / (hi[0] - lo[0])
        out.append(round(lo[1] + (hi[1] - lo[1]) * t, 4))
    return out


def star_shaped(cubics):
    pts = [bezier(c, i / 40) for c in cubics for i in range(40)]
    angles = [math.atan2(p[1] - .5, p[0] - .5) for p in pts]
    total = 0
    for a, b in zip(angles, angles[1:] + angles[:1]):
        d = (b - a + math.pi) % (2 * math.pi) - math.pi
        if d < -1e-6:
            return False
        total += d
    return abs(total - 2 * math.pi) < 1e-3


if __name__ == "__main__":
    norm = {k: normalized(v) for k, v in SHAPES.items()}
    for k in LOADER:
        # The loader's shapes go round in one direction, so they must be star-shaped (and
        # wound the same way) to be sampled by angle.
        ok = star_shaped(norm[k]) or star_shaped(list(reversed([tuple(reversed(c)) for c in norm[k]])))
        assert ok, k
    if sys.argv[1:] == ["check"]:
        for k, v in norm.items():
            print(k, bounds(v), star_shaped(v))
        sys.exit()
    json.dump({
        "paths": {k: svg(v) for k, v in norm.items()},
        "loader": [polar(norm[k], 96) for k in LOADER],
    }, sys.stdout)
