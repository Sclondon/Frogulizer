"""Signed distance field modelling for the figure builders: shapes blended and carved like clay,
then meshed in one piece, smooth where it should be smooth and creased where it is told to be.

A Field is a grid of distances over a box (Godot space: metres, Y up, facing +Z). Shapes are added
to it one after another, each only over the part of the grid it can reach, so a hand's fingers do
not cost the whole body:

    field = sdf.Field(low=Vector((-0.6, 0, -0.3)), high=Vector((0.6, 1.4, 0.35)), step=0.003)
    field.add(sdf.ellipsoid(centre, radii), blend=0.05)        # smooth union, blend in metres
    field.add(sdf.cone(a, b, ra, rb), blend=0.02)              # a tapered capsule (a limb, a finger)
    field.cut(sdf.sphere(centre, r), blend=0.01)               # smooth subtraction
    mesh = field.mesh("skin")                                  # surface nets, then smoothed

Every shape is a (bounds, function) pair: the function takes arrays of x, y, z and returns the
distance (negative inside). Distances need only be right near the surface; ellipsoids use the
usual first-order bound.

Needs only numpy (which Blender has) and bpy for the last step.
"""

import math

import numpy as np
from mathutils import Vector


# --- Shapes ---

def sphere(c, r):
    c = np.array(c)
    return (c - r, c + r), lambda x, y, z: np.sqrt((x - c[0]) ** 2 + (y - c[1]) ** 2 + (z - c[2]) ** 2) - r


def ellipsoid(c, radii, basis=None):
    """An ellipsoid, optionally turned (`basis`: a 3x3 whose columns are its axes, in the world)."""
    c = np.array(c)
    r = np.array(radii)
    reach = float(max(r))
    m = np.array(basis) if basis is not None else None

    def f(x, y, z):
        px, py, pz = x - c[0], y - c[1], z - c[2]
        if m is not None:
            px, py, pz = (m[0, 0] * px + m[1, 0] * py + m[2, 0] * pz, m[0, 1] * px + m[1, 1] * py + m[2, 1] * pz,
                          m[0, 2] * px + m[1, 2] * py + m[2, 2] * pz)
        k0 = np.sqrt((px / r[0]) ** 2 + (py / r[1]) ** 2 + (pz / r[2]) ** 2)
        k1 = np.sqrt((px / r[0] ** 2) ** 2 + (py / r[1] ** 2) ** 2 + (pz / r[2] ** 2) ** 2)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
    return (c - reach, c + reach), f


def cone(a, b, ra, rb):
    """A capsule from `a` to `b` tapering from radius `ra` to `rb` (a round cone): limbs, fingers, toes."""
    a = np.array(a)
    b = np.array(b)
    ba = b - a
    l2 = float(ba @ ba)
    rr = ra - rb
    a2 = l2 - rr * rr
    il2 = 1.0 / max(l2, 1e-12)

    def f(x, y, z):
        pa = np.stack([x - a[0], y - a[1], z - a[2]], -1)
        y_ = pa @ ba
        z_ = y_ - l2
        x2 = np.sum((pa * l2 - y_[..., None] * ba) ** 2, -1)
        y2 = y_ * y_ * l2
        z2 = z_ * z_ * l2
        k = math.copysign(1.0, rr) * rr * rr * x2
        out = (np.sqrt(x2 * a2 * il2) + y_ * rr) * il2 - ra
        out = np.where(np.sign(z_) * a2 * z2 > k, np.sqrt(x2 + z2) * il2 - rb, out)
        out = np.where(np.sign(y_) * a2 * y2 < k, np.sqrt(x2 + y2) * il2 - ra, out)
        return out
    reach = max(ra, rb)
    return (np.minimum(a, b) - reach, np.maximum(a, b) + reach), f


def chain(points, radii):
    """Round cones end to end through `points` (a tongue, a curled tail, a groove to cut)."""
    parts = [cone(points[i], points[i + 1], radii[i], radii[i + 1]) for i in range(len(points) - 1)]
    low = np.min([p[0][0] for p in parts], 0)
    high = np.max([p[0][1] for p in parts], 0)

    def f(x, y, z):
        out = parts[0][1](x, y, z)
        for p in parts[1:]:
            out = np.minimum(out, p[1](x, y, z))
        return out
    return (low, high), f


def torus(c, axis, major, minor):
    """A ring round `axis` through `c` (a rim round an eye)."""
    c = np.array(c)
    n = np.array(axis) / np.linalg.norm(axis)

    def f(x, y, z):
        p = np.stack([x - c[0], y - c[1], z - c[2]], -1)
        h = p @ n
        q = np.sqrt(np.maximum(np.sum(p * p, -1) - h * h, 0.0)) - major
        return np.sqrt(q * q + h * h) - minor
    reach = major + minor
    return (c - reach, c + reach), f


def half(shape, normal, offset):
    """A shape cut flat: only the side of the plane (through the point `offset`, facing `normal`) it is on."""
    (low, high), f = shape
    n = np.array(normal) / np.linalg.norm(normal)
    o = np.array(offset)

    def g(x, y, z):
        return np.maximum(f(x, y, z), (x - o[0]) * n[0] + (y - o[1]) * n[1] + (z - o[2]) * n[2])
    return (low, high), g


# --- Blends ---

def smin(a, b, k):
    if k <= 0.0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


# --- The field ---

class Field:
    def __init__(self, low, high, step):
        self.step = step
        self.low = np.array(low, dtype=np.float32)
        self.count = np.ceil((np.array(high) - self.low) / step).astype(int) + 1
        self.values = np.full(tuple(self.count), 1.0, dtype=np.float32)

    def _slice(self, bounds, margin):
        low, high = bounds
        a = np.clip(np.floor((np.array(low) - margin - self.low) / self.step).astype(int), 0, self.count - 1)
        b = np.clip(np.ceil((np.array(high) + margin - self.low) / self.step).astype(int) + 1, 1, self.count)
        return tuple(slice(int(a[i]), int(b[i])) for i in range(3))

    def _coords(self, sl):
        axes = [self.low[i] + np.arange(sl[i].start, sl[i].stop) * self.step for i in range(3)]
        return np.meshgrid(*axes, indexing="ij")

    def add(self, shape, blend=0.0):
        bounds, f = shape
        sl = self._slice(bounds, blend * 2.0 + self.step * 2.0)
        x, y, z = self._coords(sl)
        self.values[sl] = smin(self.values[sl], f(x, y, z).astype(np.float32), blend)

    def cut(self, shape, blend=0.0):
        bounds, f = shape
        sl = self._slice(bounds, blend * 2.0 + self.step * 2.0)
        x, y, z = self._coords(sl)
        self.values[sl] = smax(self.values[sl], -f(x, y, z).astype(np.float32), blend)

    def mesh(self, smoothing=2):
        """The surface (where the distance is 0) as quads, by surface nets: a point in each cell the
        surface passes through, at the average of where it crosses the cell's edges; a quad across
        each grid edge it crosses. Returns (points in Godot space, quads)."""
        v = self.values
        inside = v < 0.0
        nx, ny, nz = v.shape
        cells = np.zeros((nx - 1, ny - 1, nz - 1), dtype=bool)
        corners = [(i, j, k) for i in (0, 1) for j in (0, 1) for k in (0, 1)]
        any_in = np.zeros_like(cells)
        all_in = np.ones_like(cells)
        for i, j, k in corners:
            c = inside[i:nx - 1 + i, j:ny - 1 + j, k:nz - 1 + k]
            any_in |= c
            all_in &= c
        cells = any_in & ~all_in
        index = -np.ones(cells.shape, dtype=np.int64)
        where = np.argwhere(cells)
        index[cells] = np.arange(len(where))
        # Each active cell's point: the mean of the edge crossings
        total = np.zeros((len(where), 3))
        hits = np.zeros(len(where))
        edges = [((0, 0, 0), (1, 0, 0)), ((0, 1, 0), (1, 1, 0)), ((0, 0, 1), (1, 0, 1)), ((0, 1, 1), (1, 1, 1)),
                 ((0, 0, 0), (0, 1, 0)), ((1, 0, 0), (1, 1, 0)), ((0, 0, 1), (0, 1, 1)), ((1, 0, 1), (1, 1, 1)),
                 ((0, 0, 0), (0, 0, 1)), ((1, 0, 0), (1, 0, 1)), ((0, 1, 0), (0, 1, 1)), ((1, 1, 0), (1, 1, 1))]
        wi, wj, wk = where[:, 0], where[:, 1], where[:, 2]
        for a, b in edges:
            va = v[wi + a[0], wj + a[1], wk + a[2]]
            vb = v[wi + b[0], wj + b[1], wk + b[2]]
            crossing = (va < 0.0) != (vb < 0.0)
            t = np.where(crossing, va / np.where(crossing, va - vb, 1.0), 0.0)
            p = np.stack([wi + a[0] + (b[0] - a[0]) * t, wj + a[1] + (b[1] - a[1]) * t, wk + a[2] + (b[2] - a[2]) * t], -1)
            total += p * crossing[:, None]
            hits += crossing
        points = total / np.maximum(hits, 1)[:, None] * self.step + self.low
        # A quad across each grid edge the surface crosses (wound so it faces out)
        quads = []
        for axis in range(3):
            a1, a2 = [d for d in range(3) if d != axis]
            sl_lo = [slice(None)] * 3
            sl_hi = [slice(None)] * 3
            sl_lo[axis] = slice(0, -1)
            sl_hi[axis] = slice(1, None)
            crossing = inside[tuple(sl_lo)] != inside[tuple(sl_hi)]
            # (only edges with all four cells round them in the grid)
            spots = np.argwhere(crossing)
            spots = spots[(spots[:, a1] > 0) & (spots[:, a2] > 0) & (spots[:, a1] < v.shape[a1] - 1) & (spots[:, a2] < v.shape[a2] - 1)]
            if len(spots) == 0:
                continue
            flip = inside[tuple(spots.T)]
            ring = []
            for d1, d2 in ((-1, -1), (0, -1), (0, 0), (-1, 0)):
                c = spots.copy()
                c[:, a1] += d1
                c[:, a2] += d2
                ring.append(index[c[:, 0], c[:, 1], c[:, 2]])
            ring = np.stack(ring, -1)
            ring = np.where(flip[:, None] == (axis == 1), ring, ring[:, ::-1])
            quads.append(ring)
        quads = np.concatenate(quads) if quads else np.zeros((0, 4), dtype=np.int64)
        quads = quads[np.all(quads >= 0, 1)]
        # A few passes of smoothing, each point towards the mean of its neighbours, then back onto
        # the surface by the field's gradient (so smoothing rounds the facets, not the shape)
        for _ in range(smoothing):
            acc = np.zeros_like(points)
            n = np.zeros(len(points))
            for s in range(4):
                a = quads[:, s]
                b = quads[:, (s + 1) % 4]
                np.add.at(acc, a, points[b])
                np.add.at(acc, b, points[a])
                np.add.at(n, a, 1)
                np.add.at(n, b, 1)
            points = 0.5 * points + 0.5 * acc / np.maximum(n, 1)[:, None]
            points = self.project(points)
        return points, quads

    def sample(self, points):
        """The field's distance at points (trilinear)."""
        g = (points - self.low) / self.step
        i0 = np.clip(np.floor(g).astype(int), 0, self.count - 2)
        t = g - i0
        v = self.values
        out = np.zeros(len(points))
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    w = (t[:, 0] if dx else 1 - t[:, 0]) * (t[:, 1] if dy else 1 - t[:, 1]) * (t[:, 2] if dz else 1 - t[:, 2])
                    out += w * v[i0[:, 0] + dx, i0[:, 1] + dy, i0[:, 2] + dz]
        return out

    def project(self, points, passes=2):
        """Points moved onto the surface along the field's gradient."""
        e = self.step * 0.5
        for _ in range(passes):
            d = self.sample(points)
            grad = np.stack([self.sample(points + np.array(o)) - self.sample(points - np.array(o)) for o in ((e, 0, 0), (0, e, 0), (0, 0, e))], -1) / (2 * e)
            norm = np.maximum(np.linalg.norm(grad, axis=1), 1e-6)
            points = points - (d / norm ** 2)[:, None] * grad
        return points


def to_bmesh(bm, points, quads, convert):
    """Adds the meshed surface to a bmesh: `convert` takes a Godot-space Vector to Blender's."""
    verts = [bm.verts.new(convert(Vector(p))) for p in points]
    faces = []
    for q in quads:
        if len(set(q)) < 4:
            continue
        try:
            faces.append(bm.faces.new([verts[i] for i in q]))
        except ValueError:
            pass
    return faces
