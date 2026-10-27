"""Builds the frog folk (the band and the crowd on the riverboat) and exports them for Godot.

Run from the project root:
    blender --background --python tools/build_frogs.py
    blender --background --python tools/build_frogs.py -- <folder>   # also renders previews there

Writes models/frog_<body>.glb and models/frog_<body>_lo.glb for each body in BODIES (and editable
copies in tools/).

Anthropomorphic frogs in Victorian Sunday best, after the riverboat frogs in Over the Garden Wall
(inpsirationArt/, frogBody.jpg above all). The head is a long, flat-topped wedge: a rounded snout,
a brow over each eye, the crown running straight back and down into the back with no neck, so the
head and the body are one skin. The mouth is a long line from the snout back to its corners under
the eyes, and stops there. Under it the lower jaw and the throat are one piece of their own, a
shade lighter, as is the belly. The eyes sit in sockets on top under heavy lids that droop. Thin
arms, three long fingers and a thumb with round pads; thin legs; long flat webbed feet, always bare.
Some are warty (subtly: an option, `warts`).

There are three bodies, so a crowd is not all one shape: `round` (a pear), `slim` (tall, long in the
leg, narrow) and `squat` (a toad: short legs, broad, a bigger head). Each is its own model, and the
rig measures each.

It is built on the boy's skeleton (tools/build_figure_template.py has the contract), so
CharacterRig, and FrogRig (scripts/frog_rig.gd) on it, moves it as it moves the boy. Its own extra
bones, which FrogRig poses:
    jaw              (under head) the lower jaw and throat, hinged behind the corners of the mouth
    lid_l/lid_r      (under head) the upper lids, turned about the eye's centre on X to blink
    eye_l/eye_r      (under head) the eyes, which CharacterRig already turns to look about
    tongue0..3       (under jaw) the long tongue, a chain: folded away (tongue0 scaled down) or flailing
Hands are three long fingers and a thumb (finger0..2 a/b/c, thumba/b) with round pads.

Clothes and the warts are options on slots (CharacterRig.restyle shows a mesh named
`frog_<slot>__<option>` when the look's "parts" names it); FrogLook lists them.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
PREVIEWS = kit.PREVIEW_DIR
kit.PREVIEW_DIR = None  # (the kit's own previews are the boy's; these are below)

# --- The bodies: legs, how tall and broad the trunk is against the round one, arms, head ---

BODIES = {
# (Short stout bodies on long thin limbs: `limb` thins the arms and legs.)
    "round": {"thigh": 0.26, "shin": 0.27, "tall": 0.82, "broad": 1.12, "upper_arm": 0.21, "forearm": 0.2, "head": 1.0, "limb": 0.8},
    "slim": {"thigh": 0.29, "shin": 0.3, "tall": 0.95, "broad": 0.92, "upper_arm": 0.22, "forearm": 0.21, "head": 0.95, "limb": 0.75},
    "squat": {"thigh": 0.22, "shin": 0.23, "tall": 0.72, "broad": 1.32, "upper_arm": 0.19, "forearm": 0.18, "head": 1.08, "limb": 0.85},
}

ANKLE_Y = 0.05
TOE = Vector((0.0, -0.035, 0.075))  # where the foot bends, from the ankle

# The trunk of the round body, from the crotch up: (height above the crotch, half width, half depth, forward).
# (It does not narrow to a neck: it tapers up into the head, which is the top of it, as in the concept art.)
TORSO_ROUND = [(0.0, 0.05, 0.05, 0.0), (0.03, 0.12, 0.10, 0.0), (0.08, 0.158, 0.13, 0.008), (0.15, 0.17, 0.143, 0.022),
               (0.22, 0.167, 0.142, 0.026), (0.29, 0.16, 0.132, 0.02), (0.35, 0.155, 0.122, 0.012), (0.40, 0.152, 0.116, 0.008),
               (0.44, 0.15, 0.112, 0.004), (0.49, 0.145, 0.11, 0.0)]

# Set for each body by `shape_body` (and read by everything below).
THIGH = SHIN = HIP_X = HIP_Y = KNEE_Y = CROTCH = TALL = BROAD = HEAD_SIZE = LIMB = 0.0
HIPS = SPINE = CHEST = NECK = HEAD = SHOULDER = HEAD_ORIGIN = Vector()
UPPER_ARM = FOREARM = ELBOW_X = WRIST_X = HAT_Y = HAT_Z = 0.0
TORSO = []


def shape_body(name):
    global THIGH, SHIN, HIP_X, HIP_Y, KNEE_Y, CROTCH, TALL, BROAD, HEAD_SIZE, HIPS, SPINE, CHEST, NECK, HEAD, SHOULDER
    global HEAD_ORIGIN, UPPER_ARM, FOREARM, ELBOW_X, WRIST_X, HAT_Y, HAT_Z, TORSO, LIMB
    body = BODIES[name]
    THIGH, SHIN = body["thigh"], body["shin"]
    TALL, BROAD, HEAD_SIZE, LIMB = body["tall"], body["broad"], body["head"], body["limb"]
    UPPER_ARM, FOREARM = body["upper_arm"], body["forearm"]
    HIP_X = 0.078 * (0.6 + 0.4 * BROAD)
    HIP_Y = ANKLE_Y + SHIN + THIGH
    KNEE_Y = HIP_Y - THIGH
    CROTCH = HIP_Y - 0.04
    HIPS = Vector((0.0, HIP_Y + 0.03, 0.0))
    SPINE = Vector((0.0, T(0.16), 0.0))
    CHEST = Vector((0.0, T(0.30), 0.0))
    NECK = Vector((0.0, T(0.40), 0.0))
    HEAD = Vector((0.0, T(0.445), 0.0))
    SHOULDER = Vector((0.145 * BROAD ** 0.7, T(0.365), 0.0))
    ELBOW_X = SHOULDER.x + UPPER_ARM
    WRIST_X = ELBOW_X + FOREARM
    TORSO = [(T(h), rx * BROAD, rz * (0.6 + 0.4 * BROAD), z) for h, rx, rz, z in TORSO_ROUND]
    # The head: drawn about the middle of its mouth (head space, below), which sits here
    HEAD_ORIGIN = Vector((0.0, T(0.495), 0.0))
    hat = head_point(Vector((0.0, 0.104, -0.03)))
    HAT_Y, HAT_Z = hat.y, hat.z


def T(height):
    """A height on the round body's trunk (above its crotch) on this body's trunk."""
    return CROTCH + height * TALL


def head_point(p):
    """From head space (the middle of the mouth at the origin, at the round body's size) to the model."""
    return HEAD_ORIGIN + p * HEAD_SIZE


def head_space(p):
    return (p - HEAD_ORIGIN) / HEAD_SIZE


# --- Colours (sRGB). Toon gives `eyewhite` and `pupil` a wet glint. FrogLook recolours any by name. ---

MATERIALS = [
    ("skin", (0.42, 0.52, 0.25)),
    ("belly", (0.62, 0.68, 0.40)),
    ("eye_l", (0.95, 0.93, 0.82)),
    ("eye_r", (0.95, 0.93, 0.82)),
    ("pupil", (0.04, 0.04, 0.05)),
    ("ink", (0.05, 0.04, 0.04)),
    ("mouth", (0.36, 0.10, 0.12)),
    ("tongue", (0.86, 0.46, 0.48)),
    ("coat", (0.42, 0.13, 0.12)),
    ("trim", (0.84, 0.66, 0.24)),
    ("vest", (0.66, 0.52, 0.25)),
    ("trousers", (0.62, 0.56, 0.46)),
    ("hat", (0.16, 0.14, 0.16)),
    ("band", (0.42, 0.20, 0.30)),
    ("collar", (0.94, 0.92, 0.86)),
    ("tie", (0.75, 0.62, 0.20)),
    ("dress", (0.62, 0.50, 0.70)),
    ("feather", (0.86, 0.80, 0.92)),
]
SKIN, BELLY, EYE_L, EYE_R, PUPIL, INK, MOUTH, TONGUE, COAT, TRIM, VEST, TROUSERS, HAT, BAND, COLLAR, TIE, DRESS, FEATHER = range(len(MATERIALS))


# --- Small shape helpers ---

def loft(b, loops, start=True, end=True):
    """Skins rings of points (each the same count, going the same way round) into a closed
    surface, capping either end with a point in its middle."""
    count = len(loops[0])
    made = [[b._vert(p, None) for p in loop] for loop in loops]
    faces = []
    for a, c in zip(made, made[1:]):
        for i in range(count):
            j = (i + 1) % count
            faces.append(b.bm.faces.new((a[i], a[j], c[j], c[i])))
    for use, ring, points in ((start, made[0], loops[0]), (end, made[-1], loops[-1])):
        if use:
            pole = b._vert(sum(points, Vector()) / count, None)
            for i in range(count):
                faces.append(b.bm.faces.new((ring[i], ring[(i + 1) % count], pole)))
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)


def section(z, half, top, bottom, flat, count=28, flat_top=False):
    """A slice across the head at `z` (head space): round over the top, and underneath as flat as
    `flat` says (0 round, 1 flat as a plate, which is what the mouth line cuts). `flat_top` the
    other way up (the jaw: flat along the mouth, round underneath)."""
    if kit.LOW:
        count = 12
    points = []
    middle = (top + bottom) * 0.5
    for k in range(count):
        a = math.tau * k / count
        c, s = math.cos(a), math.sin(a)
        # (an oval, eased towards a soft flat only along the mouth's line: never a box)
        power = (2.0 if s > 0.0 else 2.0 + 1.8 * flat) if not flat_top else (2.0 + 1.8 * flat if s > 0.0 else 2.0)
        x = half * math.copysign(abs(c) ** (2.0 / power), c)
        y = middle + (top - middle if s > 0.0 else middle - bottom) * math.copysign(abs(s) ** (2.0 / power), s)
        points.append(Vector((x, y, z)))
    return points


def frame_of(way, up=Y):
    """A basis whose Z points along `way`."""
    w = way.normalized()
    r = up.cross(w).normalized()
    u = w.cross(r)
    return Matrix((r, u, w)).transposed()


def sides():
    return (1.0, -1.0)


def painted(b, fuse, paint):
    """A builder's shapes as one mesh (fused if asked), each face given a material by `paint(centre, normal)`."""
    mesh = kit.fused(b, None if kit.LOW else fuse)
    for polygon in mesh.polygons:
        polygon.material_index = paint(kit.from_blender(Vector(polygon.center)), kit.from_blender(Vector(polygon.normal)))
    return mesh


def mesh_part(make):
    """A part whose mesh is made whole (and painted) rather than filled into the kit's builder."""
    return lambda _b: make()


# --- The head (in head space: the middle of the mouth at the origin, facing +Z) ---

# Slices from the snout back: (z, half width, top, bottom, how flat underneath). In front of the
# corners of the mouth the underside is the flat line of the mouth; behind them the slices go down
# into the back and the throat, so the head runs on into the body.
CRANIUM = [(0.192, 0.042, 0.036, 0.004, 1.0), (0.18, 0.084, 0.07, 0.0, 1.0), (0.152, 0.116, 0.096, 0.0, 1.0),
           (0.11, 0.14, 0.114, 0.0, 1.0), (0.07, 0.154, 0.126, 0.0, 1.0), (0.03, 0.162, 0.13, 0.0, 1.0),
           (-0.01, 0.163, 0.124, -0.004, 1.0), (-0.045, 0.158, 0.11, -0.03, 0.6), (-0.075, 0.148, 0.088, -0.07, 0.2),
           (-0.10, 0.132, 0.058, -0.09, 0.0), (-0.115, 0.10, 0.02, -0.08, 0.0)]
# (and a nape, fused with the crown and the trunk: the back of the head going down smoothly into the back)
NAPE = (Vector((0.0, -0.075, -0.055)), Vector((0.142, 0.12, 0.085)))
# The jaw and throat under the mouth: (z, half width, top, bottom). The back of it is tucked inside the
# cheeks and the neck, so the head shows no seam behind the corners of the mouth.
# (Its top rises a hair above the mouth's line, into the head, so a shut mouth shows no gap.)
JAWLINE = [(0.178, 0.05, 0.006, -0.018), (0.158, 0.094, 0.006, -0.036), (0.125, 0.122, 0.006, -0.058), (0.085, 0.14, 0.006, -0.078),
           (0.045, 0.149, 0.006, -0.095), (0.005, 0.153, 0.005, -0.108), (-0.03, 0.15, -0.006, -0.12), (-0.07, 0.136, -0.04, -0.13),
           (-0.10, 0.115, -0.07, -0.135)]
JAW_HINGE = Vector((0.0, -0.01, -0.06))
EYE_CENTRE = Vector((0.082, 0.1, 0.05))
EYE_WAY = Vector((0.5, 0.18, 0.85)).normalized()
EYE_RADIUS = 0.036
# How far round the eyeball its visible cap reaches from the middle (the rest is under the skin)
EYE_CAP = math.radians(72.0)
LID_RADIUS = EYE_RADIUS + 0.005
# The lid at rest covers from behind the eye round over the top to this angle (from straight up,
# towards the front): over the top of the pupil, the sleepy look. FrogRig droops it further.
LID_EDGE = math.radians(40.0)
PUPIL_SIZE = Vector((0.021, 0.019, 0.006))
# (it lies in the slit, so it slides out between the lips)
TONGUE_ROOT = Vector((0.0, -0.002, -0.02))
TONGUE_LENGTH = 0.40
TONGUE_JOINTS = (0.0, 0.11, 0.22, 0.31)


def smile(p):
    """The mouth's line rises a little towards its corners: a frog's smirk."""
    lift = 0.01 * blend(0.06, -0.04, p.z) * blend(0.05, 0.14, abs(p.x)) * (1.0 - blend(0.0, 0.04, abs(p.y)))
    return Vector((p.x, p.y + lift, p.z))


def in_head(b, shapes):
    b.place = lambda p: head_point(smile(p))
    shapes()
    b.place = None


def eye_centre(side):
    return Vector((side * EYE_CENTRE.x, EYE_CENTRE.y, EYE_CENTRE.z))


def eye_way(side):
    return Vector((side * EYE_WAY.x, EYE_WAY.y, EYE_WAY.z))


def skin_mesh():
    """All the bare skin as one surface, fused: the head with its jaw and throat, the back of the
    head running down into the back, the trunk, the arms, hands and fingers, the legs, feet, toes
    and webs, as the frogs in the concept art are one smooth shape. The mouth is not cut: the skin
    shader draws its line, and FrogRig drops the jaw (all that is below the line and in front of
    its corners) to open it, stretching a thin band under the line which the shader paints as the
    inside of the mouth (see `mouth_coords`). How pale the skin is goes in its vertex colour."""
    b = kit.Builder()

    def head():
        loft(b, [section(z, half, top, bottom, flat) for z, half, top, bottom, flat in CRANIUM])
        loft(b, [section(z, half, top, bottom, 0.85, flat_top=True) for z, half, top, bottom in JAWLINE])
        for side in sides():
            e = eye_centre(side)
            # the socket the eye sits in
            b.ellipsoid(e - eye_way(side) * 0.012 + Vector((0.0, -0.01, 0.0)), Vector((0.046, 0.04, 0.046)), None, 16, 9)
            # the nostrils, small bumps on the snout
            b.ellipsoid(Vector((side * 0.024, 0.058, 0.168)), Vector((0.01, 0.007, 0.008)), None, 8, 4)
        b.ellipsoid(NAPE[0], NAPE[1], None, 20, 10)
    in_head(b, head)
    b.tube([kit.upright(0.0, y, z, rx, rz) for y, rx, rz, z in TORSO], 24)
    arms(b)
    hands(b)
    fingers(b)
    legs(b)
    feet(b)
    webs(b)
    mesh = kit.fused(b, (0.006, 3, 5000) if kit.LOW else (0.0028, 6, 16000))
    for polygon in mesh.polygons:
        polygon.material_index = SKIN
    return mesh


def mouth_at(q):
    """Where a point (head space) is against the mouth, for the skin shader to draw it by: how far
    round it (-1 at one corner, 1 at the other; well beyond for anywhere else), and how far below
    its line. Written in the vertex colour (see `add_paleness`), taken where each point rests."""
    flat = Vector((q.x, 0.0, q.z - SLIT_MIDDLE.z))
    a = math.atan2(flat.x, flat.z) / SLIT_SWEEP
    # (behind the head, or far from the mouth's height, nothing: well away)
    if flat.length < 0.05 or flat.length > 0.21 or abs(q.y) > 0.08:
        return (4.0, 1.0)
    return (a, lip_y(q) - q.y)


# The mouth: round the head from one corner to the other about this middle (head space), this far
# each way from straight ahead.
SLIT_MIDDLE = Vector((0.0, 0.0, 0.025))
SLIT_SWEEP = math.radians(112.0)
# The band under the mouth's line that stretches when the jaw drops (head space, metres).
MOUTH_BAND = 0.02


def lip_y(q):
    """The height of the mouth's line at a point (head space): level, rising a little at the corners."""
    return smile(Vector((q.x, 0.0, q.z))).y


def skin_paint(p, n):
    return SKIN


def paleness(p):
    """How pale the skin is at a point, 0..1, smoothly: the jaw and the throat (below the mouth,
    forward of the cheeks, from right at the lip), and the front of the belly down to the crotch.
    Written as a vertex colour; shaders/toon.gdshader cuts it at a half into a clean edge."""
    q = head_space(p)
    # (the jaw and throat: from the lip down to where the throat meets the chest, not round the back)
    jaw = blend(0.0, 0.003, lip_y(q) - q.y) * blend(-0.11, -0.05, q.z + 0.35 * min(q.y + 0.02, 0.0)) * blend(-0.22, -0.14, q.y)
    # (and no wider than the jaw: the arms are at the throat's height)
    jaw *= 1.0 - blend(0.13, 0.165, abs(q.x))
    centre, u, _v = ring_at(TORSO, min(max(p.y, TORSO[0][0]), TORSO[-1][0]))
    around = abs(math.atan2(p.x, p.z - centre.z + 0.04))
    trunk = (1.0 - blend(0.8, 1.05, around)) * blend(CROTCH + 0.01, CROTCH + 0.05, p.y) * (1.0 - blend(u.x + 0.01, u.x + 0.04, abs(p.x)))
    trunk *= 1.0 - blend(lip_y(q) - 0.002, lip_y(q) + 0.002, q.y)
    return max(jaw, trunk)


def crease_x(z, y):
    """How far out the head's surface is at height `y` on its slice at `z` (head space): where the
    jaw meets it, which is the line of the mouth."""
    slices = sorted(CRANIUM, key=lambda c: c[0])
    for (z0, h0, t0, b0, f0), (z1, h1, t1, b1, f1) in zip(slices, slices[1:]):
        if z0 <= z <= z1:
            k = (z - z0) / (z1 - z0)
            half, top, bottom, flat = h0 + (h1 - h0) * k, t0 + (t1 - t0) * k, b0 + (b1 - b0) * k, f0 + (f1 - f0) * k
            break
    else:
        return 0.0
    middle = (top + bottom) * 0.5
    power = 2.0 + 1.8 * flat
    if y >= middle:
        return half
    s = min(max((middle - y) / max(middle - bottom, 1e-6), 0.0), 1.0) ** (power / 2.0)
    return half * math.sqrt(max(1.0 - s * s, 0.0)) ** (2.0 / power)


def tongue(b):
    """The long tongue, lying straight forward from the back of the mouth; FrogRig folds it away
    (its root scaled down, inside the mouth) or throws it out flailing."""
    def shapes():
        rows = []
        steps = 12
        for k in range(steps + 1):
            t = k / steps
            half = 0.03 * (1.0 - 0.45 * t)
            rows.append((TONGUE_ROOT + Z * TONGUE_LENGTH * t, X * half, Y * half * 0.42))
        b.tube(kit.dome(rows[0], -Z, 0.01, 2)[::-1] + rows + kit.dome(rows[-1], Z, 0.016, 3), 12)
    in_head(b, shapes)


def eye_cap(b, side):
    """One eye: the cap of a ball set in its socket, with texture coordinates across it (-1..1,
    looking out along it: X across, Y up) for shaders/eye.gdshader, which draws on it the white,
    the pupil and the lid, so the white is always a clean oval."""
    def shapes():
        e = eye_centre(side)
        way = eye_way(side)
        frame = frame_of(way)
        across, up = frame.col[0], frame.col[1]
        rings, steps = (8, 24) if not kit.LOW else (4, 12)
        reach = math.sin(EYE_CAP)
        made = []
        for r in range(rings + 1):
            t = EYE_CAP * r / rings
            ring = []
            for k in range(steps if r > 0 else 1):
                a = math.tau * k / steps
                d = across * math.cos(a) + up * math.sin(a)
                point = e + (way * math.cos(t) + d * math.sin(t)) * EYE_RADIUS
                uv = (math.sin(t) * math.cos(a) / reach * 0.5 + 0.5, math.sin(t) * math.sin(a) / reach * 0.5 + 0.5)
                ring.append((b._vert(point, None), uv))
            made.append(ring)
        faces = []
        for r in range(rings):
            for k in range(steps):
                corners = [made[r][0 if r == 0 else k], made[r + 1][k], made[r + 1][(k + 1) % steps]]
                if r > 0:
                    corners.append(made[r][(k + 1) % steps])
                face = b.bm.faces.new([c[0] for c in corners][::-1])
                for loop, corner in zip(face.loops, corners[::-1]):
                    loop[b.uv].uv = corner[1]
                faces.append(face)
    in_head(b, shapes)


# --- The body ---# --- The body ---

def ring_at(profile, y, grow=0.0):
    """The trunk's ring at a height, with something added all round (for clothes over it)."""
    for (y0, rx0, rz0, z0), (y1, rx1, rz1, z1) in zip(profile, profile[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            return kit.upright(0.0, y, z0 + (z1 - z0) * t, rx0 + (rx1 - rx0) * t + grow, rz0 + (rz1 - rz0) * t + grow)
    y0, rx, rz, z0 = profile[0] if y < profile[0][0] else profile[-1]
    return kit.upright(0.0, y, z0, rx + grow, rz + grow)


def arm_profile():
    return [(-0.05, 0.040), (0.0, 0.036), (0.08, 0.031), (UPPER_ARM, 0.027), (UPPER_ARM + 0.09, 0.025),
            (UPPER_ARM + FOREARM - 0.01, 0.020), (UPPER_ARM + FOREARM + 0.01, 0.018)]


def arms(b):
    for side in sides():
        b.tube([(Vector((side * (SHOULDER.x + d), SHOULDER.y, 0.0)), Y * r * LIMB, Z * r * 1.05 * LIMB) for d, r in arm_profile()], 12)


FINGERS = [(0.017, 0.068, 0.0095, 0.22), (0.0, 0.074, 0.0098, 0.0), (-0.017, 0.066, 0.0092, -0.22)]
KNUCKLES = (0.0, 0.45, 0.76)
PALM = 0.048
THUMB_LENGTH = 0.05


def hand_wrist(side):
    return Vector((side * WRIST_X, SHOULDER.y, 0.0))


def finger_line(side, index):
    """A finger's knuckle and the way it points (held out straight, palm down)."""
    z, _length, _radius, fan = FINGERS[index]
    return hand_wrist(side) + Vector((side * PALM, -0.002, z)), Vector((side * math.cos(fan), -0.05, math.sin(fan))).normalized()


def thumb_line(side):
    return hand_wrist(side) + Vector((side * 0.016, -0.004, 0.017)), Vector((side * 0.55, -0.15, 0.82)).normalized()


def hands(b):
    for side in sides():
        wrist = hand_wrist(side)
        palm = [(-0.02, 0.018, 0.019), (0.0, 0.015, 0.019), (0.02, 0.013, 0.025), (0.04, 0.012, 0.030), (PALM + 0.004, 0.011, 0.028)]
        rings = [(wrist + X * side * d, Y * ry, Z * rz) for d, ry, rz in palm]
        b.tube(rings + kit.dome(rings[-1], X * side, 0.008, 2), 12)


def fingers(b):
    for side in sides():
        for index, (_z, length, radius, _fan) in enumerate(FINGERS):
            knuckle, along = finger_line(side, index)
            spans = (-0.1, 0.0, 0.2, 0.38, 0.45, 0.52, 0.68, 0.76, 0.84, 0.92)
            b.strand([knuckle + along * length * t for t in spans], [radius * (1.0 - 0.25 * max(t, 0.0)) for t in spans], 8)
            b.ellipsoid(knuckle + along * length * 0.97, Vector((radius * 1.35, radius * 1.05, radius * 1.35)), None, 10, 5)
        root, along = thumb_line(side)
        b.strand([root + along * THUMB_LENGTH * t for t in (-0.2, 0.0, 0.3, 0.5, 0.7, 0.9)], [0.0105, 0.0105, 0.0098, 0.009, 0.0085, 0.008], 8)
        b.ellipsoid(root + along * THUMB_LENGTH * 0.95, Vector((0.012, 0.01, 0.012)), None, 10, 5)


def leg_profile():
    thick = 0.8 + 0.2 * BROAD
    return [(HIP_Y + 0.05, 0.055 * thick), (HIP_Y - 0.02, 0.054 * thick), (KNEE_Y + THIGH * 0.5, 0.045 * thick), (KNEE_Y, 0.036),
            (KNEE_Y - SHIN * 0.4, 0.032), (ANKLE_Y + 0.09, 0.026), (ANKLE_Y + 0.03, 0.023), (ANKLE_Y, 0.022)]


def legs(b):
    for side in sides():
        b.tube([kit.upright(side * HIP_X, y, 0.0, r * LIMB, r * LIMB) for y, r in leg_profile()], 12)


TOES = [(-0.42, 0.13, 0.010), (-0.12, 0.165, 0.011), (0.2, 0.15, 0.011), (0.5, 0.11, 0.0095)]


def toe_lines(side):
    root = Vector((side * HIP_X, 0.012, 0.045))
    return [(root, Vector((side * math.sin(angle), 0.0, math.cos(angle))).normalized(), length, radius) for angle, length, radius in TOES]


def feet(b):
    for side in sides():
        ankle = Vector((side * HIP_X, ANKLE_Y, 0.0))
        foot = [(-0.04, 0.0, 0.026, 0.022), (-0.02, 0.004, 0.032, 0.03), (0.01, -0.006, 0.036, 0.028),
                (0.04, -0.024, 0.044, 0.018), (0.07, -0.034, 0.05, 0.011)]
        rings = [(ankle + Vector((0.0, y, z)), X * rx, Y * ry) for z, y, rx, ry in foot]
        b.tube(kit.dome(rings[0], -Z, 0.014, 3)[::-1] + rings + kit.dome(rings[-1], Z, 0.01, 2), 16, 0.0)
        for root, way, length, radius in toe_lines(side):
            points = [root + way * length * t + Vector((0.0, -0.002 * t, 0.0)) for t in (0.0, 0.3, 0.6, 0.85, 1.0)]
            b.strand(points, [radius * (1.0 - 0.15 * t) for t in (0.0, 0.3, 0.6, 0.85, 1.0)], 8)
            b.ellipsoid(points[-1], Vector((radius * 1.5, radius * 0.9, radius * 1.5)), None, 10, 4)


def webs(b):
    """The webbing between the toes: a thin sheet out to two-thirds of the way along each toe, scalloped between."""
    for side in sides():
        lines = toe_lines(side)
        points = [lines[0][0] + Vector((0.0, 0.0, -0.01))]
        for k, (r, way, length, _radius) in enumerate(lines):
            points.append(r + way * length * 0.72)
            if k + 1 < len(lines):
                r2, way2, length2, _ = lines[k + 1]
                points.append((r + way * length * 0.45 + r2 + way2 * length2 * 0.45) * 0.5)
        middle = sum(points, Vector()) / len(points)
        top = [b._vert(p + Vector((0.0, 0.004, 0.0)), 0.0) for p in points]
        bottom = [b._vert(Vector((p.x, 0.001, p.z)), None) for p in points]
        top_pole = b._vert(middle + Vector((0.0, 0.004, 0.0)), 0.0)
        bottom_pole = b._vert(Vector((middle.x, 0.001, middle.z)), None)
        faces = []
        n = len(points)
        for i in range(n):
            j = (i + 1) % n
            faces.append(b.bm.faces.new((top[i], top[j], top_pole)))
            faces.append(b.bm.faces.new((bottom[j], bottom[i], bottom_pole)))
            faces.append(b.bm.faces.new((top[j], top[i], bottom[i], bottom[j])))
        bmesh.ops.recalc_face_normals(b.bm, faces=faces)


def warts(b):
    """A toad's warts, low and few: on the crown and the back of the head, down the back, on the
    upper arms and the thighs. Most frogs are smooth; this is an option (`warts`)."""
    rng = random.Random(11)
    found = []
    for _ in range(46):
        z = rng.uniform(-0.13, 0.06)
        slices = [s for s in CRANIUM if abs(s[0] - z) < 0.03] or [CRANIUM[-3]]
        _z, half, top, bottom, _flat = slices[0]
        a = rng.uniform(0.25, math.pi - 0.25)
        p = Vector((math.cos(a) * half * 0.92, (top + bottom) * 0.5 + math.sin(a) * (top - (top + bottom) * 0.5) * 0.95, z))
        if abs(p.x) < 0.11 and abs(p.z - EYE_CENTRE.z) < 0.06 and p.y > 0.06:
            continue
        found.append((head_point(p), rng.uniform(0.007, 0.012)))
    for _ in range(40):
        y = T(rng.uniform(0.18, 0.44))
        centre, u, v = ring_at(TORSO, y, -0.002)
        a = rng.uniform(math.pi * 0.55, math.pi * 1.45)
        found.append((centre + u * math.sin(a) + v * math.cos(a), rng.uniform(0.008, 0.013)))
    for side in sides():
        for _ in range(8):
            d = rng.uniform(0.02, UPPER_ARM)
            a = rng.uniform(0.0, math.pi)
            found.append((Vector((side * (SHOULDER.x + d), SHOULDER.y + 0.03 * math.sin(a), -0.03 * math.cos(a))), rng.uniform(0.006, 0.009)))
        for _ in range(10):
            y = rng.uniform(KNEE_Y + 0.03, HIP_Y - 0.02)
            a = rng.uniform(math.pi * 0.3, math.pi * 1.7)
            found.append((Vector((side * HIP_X + 0.046 * math.sin(a), y, 0.046 * math.cos(a))), rng.uniform(0.007, 0.011)))
    for at, r in found:
        b.ellipsoid(at, Vector((r, r * 0.8, r)), None, 8, 4)


# --- Clothes: each drawn over the bare body, and each an object of its own ---

def sleeves(b, grow, cuff, puffed=0.0):
    for side in sides():
        sleeve = [(-0.06, 0.052), (0.0, 0.050 + puffed * 0.03), (0.07, 0.044 + puffed * 0.04), (UPPER_ARM, 0.036),
                  (UPPER_ARM + 0.08, 0.033), (cuff, 0.031), (cuff + 0.005, 0.026)]
        b.tube([(Vector((side * (SHOULDER.x + d), SHOULDER.y, 0.0)), Y * (r + grow), Z * (r + grow) * 1.05) for d, r in sleeve], 12)


def coat_body(b, bottom, grow, top=0.455, flare=0.0):
    """A garment round the trunk from `bottom` up to `top` (heights on the round trunk), `grow` clear of the skin."""
    rings = []
    steps = 9
    for k in range(steps + 1):
        h = bottom + (top - bottom) * k / steps
        centre, u, v = ring_at(TORSO, max(T(h), T(0.03)), grow)
        if h < 0.06:
            # below the seat a skirt hangs straight down and flares a little
            spread = flare * (0.06 - h) / 0.3
            u = u + X * spread
            v = v + Z * spread
        centre = Vector((centre.x, T(h), centre.z))
        rings.append((centre, u, v))
    b.tube(rings, 22)


def tails(b, length):
    for side in sides():
        rows = []
        back = ring_at(TORSO, T(0.12), 0.02)
        for t in (0.0, 0.25, 0.5, 0.75, 1.0):
            centre = Vector((side * (0.07 - 0.015 * t) * BROAD, T(0.12) - length * t, back[0].z - back[2].z - 0.02 * t + 0.01))
            rows.append((centre, X * (0.075 - 0.02 * t) * BROAD, Z * 0.012))
        b.tube(rows, 10)


def buttons(b, heights, x=0.0, grow=0.022, size=0.009):
    for h in heights:
        centre, _u, v = ring_at(TORSO, T(h), grow)
        for sx in ((x, -x) if x else (0.0,)):
            b.ellipsoid(centre + v + X * sx * BROAD, Vector((size, size, size * 0.6)), None, 8, 3)


def collar_ring(b, low=0.37, high=0.43, grow=0.012):
    b.tube([ring_at(TORSO, T(h), grow) for h in (low, (low + high) * 0.5, high)], 20)


def coat_tails(b):
    coat_body(b, 0.10, 0.022)
    sleeves(b, 0.0, UPPER_ARM + FOREARM - 0.02)
    tails(b, 0.3 * TALL)


def coat_band(b):
    coat_body(b, 0.06, 0.024)
    sleeves(b, 0.002, UPPER_ARM + FOREARM - 0.02)
    collar_ring(b, 0.40, 0.45, 0.03)


def band_trim(b):
    # Gold braid across the chest, cuffs, a belt and epaulettes on a bandsman's jacket
    buttons(b, (0.14, 0.20, 0.26, 0.32, 0.37), 0.045, 0.026, 0.009)
    for h in (0.20, 0.26, 0.32):
        centre, u, v = ring_at(TORSO, T(h), 0.026)
        b.tube([(centre + v * 0.99 + X * x * BROAD, Y * 0.005, Z * 0.004) for x in (-0.045, 0.0, 0.045)], 6)
    for side in sides():
        b.ellipsoid(Vector((side * (SHOULDER.x + 0.01), SHOULDER.y + 0.04, 0.0)), Vector((0.05, 0.014, 0.045)), None, 12, 4)
        b.tube([(Vector((side * (WRIST_X - d), SHOULDER.y, 0.0)), Y * 0.034, Z * 0.036) for d in (0.035, 0.05, 0.065)], 12)
    b.tube([ring_at(TORSO, T(h), 0.028) for h in (0.085, 0.115)], 22)


def coat_frock(b):
    coat_body(b, -0.17, 0.022, flare=0.05)
    sleeves(b, 0.0, UPPER_ARM + FOREARM - 0.02)


def coat_jacket(b):
    coat_body(b, 0.03, 0.022, flare=0.02)
    sleeves(b, 0.0, UPPER_ARM + FOREARM - 0.03)


def coat_dress(b):
    # A gown: a fitted bodice, a full bell of a skirt to the ground, puffed sleeves
    rings = [ring_at(TORSO, T(h), grow) for h, grow in ((0.44, 0.012), (0.40, 0.014), (0.32, 0.014), (0.22, 0.012), (0.16, 0.014))]
    flare = [(0.11, 0.20, 0.17), (0.0, 0.24, 0.22)]
    for h, r, d in flare:
        rings.append(kit.upright(0.0, T(h), 0.01, r * BROAD, d * BROAD))
    for y, r, d in ((CROTCH * 0.62, 0.28, 0.26), (CROTCH * 0.33, 0.31, 0.29), (0.06, 0.33, 0.31), (0.035, 0.33, 0.31)):
        rings.append(kit.upright(0.0, y, 0.01, r * (0.5 + 0.5 * BROAD), d * (0.5 + 0.5 * BROAD)))
    b.tube(rings[::-1], 26, 0.03)
    sleeves(b, 0.004, 0.24, puffed=1.0)


def dress_frills(b):
    # A frill round the hem and lace at the throat
    reach = 0.33 * (0.5 + 0.5 * BROAD)
    for k in range(18):
        a = math.tau * k / 18
        b.ellipsoid(Vector((math.sin(a) * reach, 0.055, 0.01 + math.cos(a) * reach * 0.94)), Vector((0.05, 0.03, 0.05)), None, 8, 4)
    collar_ring(b, 0.40, 0.46, 0.02)


def coat_waistcoat(b):
    coat_body(b, 0.08, 0.016, top=0.43)
    for side in sides():
        b.tube([(Vector((side * (SHOULDER.x + d), SHOULDER.y, 0.0)), Y * 0.048, Z * 0.05) for d in (-0.05, 0.0, 0.02)], 12)


def vest_front(b):
    # A waistcoat's front showing at the opening of a tailcoat
    rows = [ring_at(TORSO, T(h), 0.024) for h in (0.12, 0.16, 0.24, 0.32, 0.38)]
    b.tube([(c + v * 0.97, X * 0.05 * BROAD * (1.2 - 0.4 * k / 4), Z * 0.006) for k, (c, u, v) in enumerate(rows)], 8)
    buttons(b, (0.16, 0.22, 0.28), 0.0, 0.032, 0.007)


def trousers(b, bottom=0.10):
    # (the seat, and up over the belly to under the coat, clear of the skin)
    b.tube([kit.upright(0.0, CROTCH - 0.02, 0.0, 0.07 * BROAD, 0.07)] + [ring_at(TORSO, T(h), 0.014) for h in (0.02, 0.06, 0.10, 0.14, 0.17)], 20)
    for side in sides():
        thick = 0.8 + 0.2 * BROAD
        leg = [(HIP_Y + 0.05, 0.072 * thick), (HIP_Y - 0.02, 0.07 * thick), (KNEE_Y + THIGH * 0.5, 0.062 * thick), (KNEE_Y, 0.054),
               (KNEE_Y - SHIN * 0.45, 0.05), (bottom + 0.02, 0.046), (bottom, 0.046)]
        if bottom > KNEE_Y - 0.1:
            leg = [(y, r) for y, r in leg if y > bottom + 0.02] + [(bottom + 0.02, 0.05), (bottom, 0.045)]
        b.tube([kit.upright(side * HIP_X, y, 0.0, r, r * 1.04) for y, r in leg], 14)


def breeches(b):
    trousers(b, KNEE_Y - 0.03)


def bow_tie(b):
    centre, _u, v = ring_at(TORSO, T(0.385), 0.012)
    at = centre + v
    for side in sides():
        b.ellipsoid(at + Vector((side * 0.03, 0.0, 0.0)), Vector((0.03, 0.02, 0.012)), Matrix.Rotation(side * 0.25, 3, "Z"), 10, 4)
    b.ellipsoid(at + Vector((0.0, 0.0, 0.006)), Vector((0.012, 0.014, 0.012)), None, 8, 4)


def cravat(b):
    collar_ring(b, 0.36, 0.43, 0.014)
    centre, _u, v = ring_at(TORSO, T(0.33), 0.012)
    b.ellipsoid(centre + v, Vector((0.04, 0.06, 0.03)), None, 12, 6)


def scarf(b):
    collar_ring(b, 0.35, 0.44, 0.02)
    centre, _u, v = ring_at(TORSO, T(0.37), 0.025)
    start = centre + v + X * 0.05
    b.strand([start, start + Vector((0.02, -0.08, 0.02)), start + Vector((0.03, -0.18, 0.04)), start + Vector((0.035, -0.26, 0.05))],
             [0.03, 0.028, 0.026, 0.024], 8)


def hat_ring(y, rx, rz):
    return kit.upright(0.0, HAT_Y + y, HAT_Z, rx, rz)


def brim(b, rx, rz, thickness=0.006, curl=0.0):
    b.tube([hat_ring(-thickness, rx * 0.6, rz * 0.6), hat_ring(-thickness, rx, rz), hat_ring(curl, rx * 1.02, rz * 1.02), hat_ring(thickness * 0.5, rx * 0.6, rz * 0.6)], 24)


def hat_top(b):
    brim(b, 0.105, 0.095, 0.006, 0.01)
    b.tube([hat_ring(y, rx, rz) for y, rx, rz in ((0.0, 0.065, 0.06), (0.1, 0.06, 0.055), (0.17, 0.066, 0.061), (0.172, 0.04, 0.036))], 22)


def band_top(b):
    b.tube([hat_ring(y, 0.067, 0.062) for y in (0.004, 0.03)], 22)


def hat_bowler(b):
    brim(b, 0.09, 0.08, 0.005, 0.012)
    rings = []
    for k in range(8):
        a = math.pi / 2 * k / 8
        rings.append(hat_ring(0.075 * math.sin(a), 0.066 * math.cos(a) + 0.001, 0.06 * math.cos(a) + 0.001))
    b.tube(rings, 22)


def band_bowler(b):
    b.tube([hat_ring(y, 0.068, 0.062) for y in (0.002, 0.018)], 22)


def hat_shako(b):
    # A bandsman's cap: a tall drum widening a little to a flat top, a stiff peak
    b.tube([hat_ring(y, rx, rz) for y, rx, rz in ((0.0, 0.066, 0.062), (0.11, 0.072, 0.068), (0.112, 0.05, 0.046))], 22)
    b.tube([(Vector((0.0, HAT_Y + 0.005, HAT_Z + z)), X * half, Y * 0.004) for z, half in ((0.04, 0.06), (0.07, 0.062), (0.095, 0.05), (0.105, 0.03))], 10)


def band_shako(b):
    b.tube([hat_ring(y, 0.069, 0.065) for y in (0.012, 0.03)], 22)
    b.tube([hat_ring(y, 0.073, 0.069) for y in (0.096, 0.108)], 22)
    b.ellipsoid(Vector((0.0, HAT_Y + 0.15, HAT_Z + 0.05)), Vector((0.015, 0.045, 0.015)), None, 8, 6)


def hat_boater(b):
    brim(b, 0.11, 0.10, 0.005)
    b.tube([hat_ring(y, 0.066, 0.06) for y in (0.0, 0.05, 0.052)], 22)


def band_boater(b):
    b.tube([hat_ring(y, 0.068, 0.062) for y in (0.006, 0.024)], 22)


def tilted(b, shapes):
    tilt = Matrix.Rotation(-0.18, 3, "X")
    b.place = lambda p: Vector((0.0, HAT_Y, HAT_Z)) + tilt @ (p - Vector((0.0, HAT_Y, HAT_Z)))
    shapes()
    b.place = None


def hat_bonnet(b):
    # A lady's wide hat, tilted, with feathers
    def shapes():
        brim(b, 0.15, 0.14, 0.006, 0.02)
        b.tube([hat_ring(y, rx, rz) for y, rx, rz in ((0.0, 0.07, 0.065), (0.05, 0.072, 0.067), (0.07, 0.05, 0.045))], 22)
    tilted(b, shapes)


def band_bonnet(b):
    def shapes():
        b.tube([hat_ring(y, 0.074, 0.069) for y in (0.006, 0.026)], 22)
        for k in range(5):
            a = -0.6 + 0.3 * k
            b.ellipsoid(Vector((0.07 * math.sin(a) + 0.04, HAT_Y + 0.03, HAT_Z + 0.07 * math.cos(a))), Vector((0.018, 0.016, 0.018)), None, 8, 4)
    tilted(b, shapes)


def bonnet_feather(b):
    def shapes():
        for k, lean in enumerate((-0.35, 0.0, 0.3)):
            base = Vector((-0.05 + 0.02 * k, HAT_Y + 0.05, HAT_Z - 0.02))
            tip = base + Vector((-0.06 + lean * 0.1, 0.17 - abs(lean) * 0.05, -0.06))
            mid = base.lerp(tip, 0.5) + Vector((-0.02, 0.01, 0.0))
            b.strand([base, base.lerp(mid, 0.5), mid, mid.lerp(tip, 0.5), tip], [0.012, 0.024, 0.03, 0.024, 0.008], 8)
    tilted(b, shapes)


def hat_helmet(b):
    # A tall policeman's helmet, with a star on the front
    b.tube([hat_ring(y, r, r * 0.95) for y, r in ((0.0, 0.074), (0.04, 0.078), (0.09, 0.07), (0.13, 0.05), (0.15, 0.024), (0.155, 0.01))], 22)
    brim(b, 0.085, 0.085, 0.004)


def band_helmet(b):
    b.ellipsoid(Vector((0.0, HAT_Y + 0.07, HAT_Z + 0.075)), Vector((0.022, 0.022, 0.006)), None, 10, 4)
    b.ellipsoid(Vector((0.0, HAT_Y + 0.165, HAT_Z)), Vector((0.012, 0.012, 0.012)), None, 8, 4)


def hat_cap(b):
    # A peaked cap, a conductor's or a steamboat man's
    b.tube([hat_ring(y, rx, rz) for y, rx, rz in ((0.0, 0.068, 0.064), (0.035, 0.07, 0.066), (0.05, 0.085, 0.082), (0.065, 0.082, 0.08), (0.07, 0.05, 0.048))], 22)
    b.tube([(Vector((0.0, HAT_Y + 0.008 - 0.25 * (z - 0.05), HAT_Z + z)), X * half, Y * 0.004) for z, half in ((0.05, 0.062), (0.08, 0.064), (0.105, 0.05), (0.12, 0.028))], 10)


def band_cap(b):
    b.tube([hat_ring(y, 0.071, 0.067) for y in (0.012, 0.03)], 22)


def hat_fez(b):
    b.tube([hat_ring(y, rx, rz) for y, rx, rz in ((0.0, 0.065, 0.062), (0.08, 0.052, 0.05), (0.082, 0.03, 0.028))], 20)


def band_fez(b):
    b.strand([Vector((0.0, HAT_Y + 0.083, HAT_Z)), Vector((0.03, HAT_Y + 0.07, HAT_Z - 0.02)), Vector((0.05, HAT_Y + 0.03, HAT_Z - 0.03))], [0.004, 0.004, 0.004], 6)
    b.ellipsoid(Vector((0.052, HAT_Y + 0.02, HAT_Z - 0.03)), Vector((0.012, 0.02, 0.012)), None, 8, 4)


# --- Skin weights ---

def body_weights(p, skirt=0.0):
    """The trunk, arms and legs, by where a point sits (the template's scheme). `skirt` 1 keeps
    what hangs below the seat with the hips, going some way with the legs."""
    suffix = "_l" if p.x >= 0.0 else "_r"
    reach = abs(p.x)
    arm = blend(SHOULDER.x - 0.03, SHOULDER.x + 0.03, reach) if p.y > CHEST.y - 0.03 else 0.0
    # (only what is near the arm's own line: a broad trunk reaches out past the shoulders)
    arm *= 1.0 - blend(0.045, 0.075, Vector((0.0, p.y - SHOULDER.y, p.z)).length) * (1.0 - blend(ELBOW_X - 0.05, ELBOW_X, reach))
    # (and not the trunk's own flank under the arm: inside its outline, it is trunk)
    if p.y < SHOULDER.y + 0.01 and TORSO:
        flank = ring_at(TORSO, p.y)[1].x
        arm *= blend(flank - 0.005, flank + 0.025, reach)
    fore = blend(ELBOW_X - 0.03, ELBOW_X + 0.03, reach)
    hand = blend(WRIST_X - 0.015, WRIST_X + 0.012, reach)
    leg = blend(HIP_Y + 0.035, HIP_Y - 0.05, p.y) * (1.0 - skirt)
    left = blend(-0.012, 0.012, p.x)
    shin = blend(KNEE_Y + 0.04, KNEE_Y - 0.04, p.y)
    low = blend(SPINE.y + 0.05, SPINE.y - 0.05, p.y)
    high = blend(CHEST.y - 0.06, CHEST.y + 0.05, p.y)
    neck = blend(NECK.y - 0.03, NECK.y + 0.03, p.y) if reach < SHOULDER.x - 0.01 else 0.0
    trunk = (1.0 - arm) * (1.0 - leg)
    result = {
        "hips": trunk * low,
        "spine": trunk * (1.0 - low) * (1.0 - high),
        "chest": trunk * (1.0 - low) * high * (1.0 - neck),
        "neck": trunk * (1.0 - low) * high * neck,
        "upper_arm" + suffix: arm * (1.0 - fore),
        "forearm" + suffix: arm * fore * (1.0 - hand),
        "hand" + suffix: arm * fore * hand,
    }
    if skirt > 0.0:
        swing = blend(HIP_Y, 0.2, p.y) * 0.45 * skirt
        for name, share in (("_l", left), ("_r", 1.0 - left)):
            result["thigh" + name] = result.get("thigh" + name, 0.0) + swing * share
        for key in ("hips", "spine", "chest", "neck"):
            result[key] *= (1.0 - swing)
    for name, share in (("_l", left), ("_r", 1.0 - left)):
        result["thigh" + name] = result.get("thigh" + name, 0.0) + leg * share * (1.0 - shin)
        result["shin" + name] = leg * share * shin
    return result


def line_weights(suffix, lines, p, parent):
    """Fingers or the tongue: the line this point is on and how far along it, shared over its joints."""
    best = None
    for name, root, along, length, joints in lines:
        t = (p - root).dot(along)
        away = (p - root - along * min(max(t, 0.0), length)).length
        if best is None or away < best[0]:
            best = (away, name, t / length, joints, length)
    _away, name, t, joints, length = best
    soft = 0.006 / length
    shares = [blend(joint - soft, joint + soft, t) for joint in joints]
    result = {parent: 1.0 - shares[0]}
    for k, letter in enumerate("abc"[:len(joints)]):
        result[name + letter + suffix] = shares[k] - (shares[k + 1] if k + 1 < len(joints) else 0.0)
    return result


def head_share(p):
    """How much of a point of the skin goes with the head: all of it above the mouth's level, none below the neck."""
    q = head_space(p)
    return blend(-0.09, -0.02, q.y) * blend(-0.17, -0.12, q.z)


def mixed(a, b, share):
    out = {}
    for name, w in a.items():
        out[name] = out.get(name, 0.0) + w * (1.0 - share)
    for name, w in b.items():
        out[name] = out.get(name, 0.0) + w * share
    return out


def weights(part, p):
    suffix = "_l" if p.x >= 0.0 else "_r"
    side = 1.0 if p.x >= 0.0 else -1.0
    slot = part.split("__")[0]
    if slot in ("mouth", "lip") or slot.startswith("hat"):
        return {"head": 1.0}
    if slot == "skin":
        # The hands and fingers, out at the end of the arms
        if abs(p.x) > WRIST_X - 0.015 and abs(p.y - SHOULDER.y) < 0.08:
            if abs(p.x) < WRIST_X + PALM * 0.5:
                return body_weights(p)
            lines = [("finger%d" % i,) + finger_line(side, i) + (FINGERS[i][1], KNUCKLES) for i in range(len(FINGERS))]
            lines.append(("thumb",) + thumb_line(side) + (THUMB_LENGTH, (0.0, 0.5)))
            return line_weights(suffix, lines, p, "hand" + suffix)
        # The feet, toes and webs
        if p.y < 0.115 and abs(abs(p.x) - HIP_X) < 0.13:
            shin = blend(0.075, 0.11, p.y)
            toe = blend(TOE.z - 0.02, TOE.z + 0.02, p.z) * (1.0 - shin)
            return {"shin" + suffix: shin, "foot" + suffix: 1.0 - shin - toe, "toe" + suffix: toe}
        # The head: above the mouth's line, the head; just under it (MOUTH_BAND) and on down, in
        # front of its corners, the jaw; the throat going down to the neck; the rest the body's
        q = head_space(p)
        a, d = mouth_at(q)
        jaw = blend(0.0, MOUTH_BAND, d) * (1.0 - blend(0.92, 1.12, abs(a))) * blend(-0.17, -0.11, q.y)
        # (the throat only: no wider than the jaw, or it takes the shoulders and arms with it)
        throat = blend(-0.25, -0.12, q.y) * blend(-0.2, -0.05, q.z) * (1.0 - blend(0.1, 0.14, abs(q.x))) * (1.0 - head_share(p))
        under = mixed(mixed(body_weights(p), {"head": 1.0}, head_share(p)), {"neck": 1.0}, throat)
        return mixed(under, {"jaw": 1.0}, jaw)
    if slot == "warts":
        return mixed(body_weights(p), {"head": 1.0}, head_share(p))
    if slot in ("jaw", "floor"):
        # The throat, low and behind, stays with the neck
        q = head_space(p)
        throat = max(blend(JAW_HINGE.z + 0.02, JAW_HINGE.z - 0.04, q.z), blend(-0.11, -0.15, q.y))
        return {"jaw": 1.0 - throat, "neck": throat}
    if slot == "tongue":
        q = head_space(p)
        t = (q.z - TONGUE_ROOT.z) / TONGUE_LENGTH
        names = ["tongue%d" % k for k in range(len(TONGUE_JOINTS))]
        shares = [blend(j - 0.03, j + 0.03, t) for j in TONGUE_JOINTS[1:]]
        out = {}
        last = 1.0
        for k, name in enumerate(names):
            nxt = shares[k] if k < len(shares) else 0.0
            out[name] = last - nxt
            last = nxt
        return out
    if slot in ("eye_l", "eye_r"):
        return {"head": 1.0}
    if slot == "fingers":
        lines = [("finger%d" % i,) + finger_line(side, i) + (FINGERS[i][1], KNUCKLES) for i in range(len(FINGERS))]
        lines.append(("thumb",) + thumb_line(side) + (THUMB_LENGTH, (0.0, 0.5)))
        return line_weights(suffix, lines, p, "hand" + suffix)
    if slot in ("feet", "webs"):
        shin = blend(0.075, 0.11, p.y)
        toe = blend(TOE.z - 0.02, TOE.z + 0.02, p.z) * (1.0 - shin)
        return {"shin" + suffix: shin, "foot" + suffix: 1.0 - shin - toe, "toe" + suffix: toe}
    if part in ("coat__dress", "coat__frock", "coattrim__dress"):
        return body_weights(p, 1.0)
    if part == "coat__tails":
        return body_weights(p, 1.0 if p.z < -0.08 and p.y < T(0.12) else 0.0)
    return body_weights(p)


# --- The skeleton ---

def bones():
    listed = [("hips", HIPS, None), ("spine", SPINE, "hips"), ("chest", CHEST, "spine"), ("neck", NECK, "chest"), ("head", HEAD, "neck"),
              ("jaw", head_point(JAW_HINGE), "head")]
    parent = "jaw"
    for k, along in enumerate(TONGUE_JOINTS):
        listed.append(("tongue%d" % k, head_point(TONGUE_ROOT + Z * TONGUE_LENGTH * along), parent))
        parent = "tongue%d" % k
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        listed.append(("eye" + suffix, head_point(eye_centre(side)), "head"))
        listed.append(("lid" + suffix, head_point(eye_centre(side)), "head"))
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        shoulder = Vector((side * SHOULDER.x, SHOULDER.y, 0.0))
        listed.append(("upper_arm" + suffix, shoulder, "chest"))
        listed.append(("forearm" + suffix, shoulder + X * side * UPPER_ARM, "upper_arm" + suffix))
        listed.append(("hand" + suffix, hand_wrist(side), "forearm" + suffix))
        for index in range(len(FINGERS)):
            knuckle, along = finger_line(side, index)
            parent = "hand" + suffix
            for letter, share in zip("abc", KNUCKLES):
                listed.append(("finger%d%s%s" % (index, letter, suffix), knuckle + along * FINGERS[index][1] * share, parent))
                parent = listed[-1][0]
        root, along = thumb_line(side)
        listed.append(("thumba" + suffix, root, "hand" + suffix))
        listed.append(("thumbb" + suffix, root + along * THUMB_LENGTH * 0.5, "thumba" + suffix))
        hip = Vector((side * HIP_X, HIP_Y, 0.0))
        listed.append(("thigh" + suffix, hip, "hips"))
        listed.append(("shin" + suffix, hip - Y * THIGH, "hips"))
        listed.append(("foot" + suffix, hip - Y * (THIGH + SHIN), "hips"))
        listed.append(("toe" + suffix, hip - Y * (THIGH + SHIN) + TOE, "foot" + suffix))
    return listed


# (part, material, shapes, fuse). Parts with `__` in their names are options: each an object of its own.
BODY = [
    ("skin", None, mesh_part(skin_mesh), None),
    ("tongue", TONGUE, tongue, None),
    ("eye_l", EYE_L, lambda b: eye_cap(b, 1.0), None),
    ("eye_r", EYE_R, lambda b: eye_cap(b, -1.0), None),
]
OPTIONS = [
    ("warts__on", SKIN, warts, None),
    ("coat__tails", COAT, coat_tails, (0.007, 3, 2200)),
    ("coattrim__tails", VEST, vest_front, None),
    ("coat__band", COAT, coat_band, (0.007, 3, 2000)),
    ("coattrim__band", TRIM, band_trim, None),
    ("coat__frock", COAT, coat_frock, (0.007, 3, 2200)),
    ("coattrim__frock", TRIM, lambda b: buttons(b, (0.12, 0.20, 0.28), 0.05), None),
    ("coat__jacket", COAT, coat_jacket, (0.007, 3, 2000)),
    ("coattrim__jacket", TRIM, lambda b: buttons(b, (0.14, 0.22), 0.0), None),
    ("coat__dress", DRESS, coat_dress, (0.008, 3, 2200)),
    ("coattrim__dress", COLLAR, dress_frills, (0.008, 2, 1200)),
    ("coat__waistcoat", VEST, coat_waistcoat, (0.007, 3, 1600)),
    ("coattrim__waistcoat", TRIM, lambda b: buttons(b, (0.14, 0.20, 0.26, 0.32), 0.0, 0.018, 0.007), None),
    ("neck__bow", COLLAR, collar_ring, None),
    ("necktie__bow", TIE, bow_tie, None),
    ("neck__cravat", TIE, cravat, None),
    ("neck__scarf", TIE, scarf, (0.007, 2, 900)),
    ("legs__trousers", TROUSERS, trousers, (0.007, 3, 1600)),
    ("legs__breeches", TROUSERS, breeches, (0.007, 3, 1400)),
    ("hat__top", HAT, hat_top, None),
    ("hatband__top", BAND, band_top, None),
    ("hat__bowler", HAT, hat_bowler, None),
    ("hatband__bowler", BAND, band_bowler, None),
    ("hat__shako", HAT, hat_shako, None),
    ("hatband__shako", TRIM, band_shako, None),
    ("hat__boater", HAT, hat_boater, None),
    ("hatband__boater", BAND, band_boater, None),
    ("hat__bonnet", HAT, hat_bonnet, None),
    ("hatband__bonnet", BAND, band_bonnet, None),
    ("hatfeather__bonnet", FEATHER, bonnet_feather, None),
    ("hat__helmet", HAT, hat_helmet, None),
    ("hatband__helmet", TRIM, band_helmet, None),
    ("hat__cap", HAT, hat_cap, None),
    ("hatband__cap", BAND, band_cap, None),
    ("hat__fez", HAT, hat_fez, None),
    ("hatband__fez", BAND, band_fez, None),
]
PARTS = BODY + OPTIONS
APART = [part for part, _m, _s, _f in OPTIONS]


def previews(folder, name):
    """Renders the frog in a few turn-outs: front, side and three-quarters, and the head close up."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 600, 800
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    looks = {"bare": {}, "gent": {"coat": "tails", "neck": "bow", "legs": "trousers", "hat": "top"},
             "lady": {"coat": "dress", "hat": "bonnet"}, "warty": {"warts": "on", "coat": "waistcoat", "legs": "breeches", "hat": "cap"}}
    trims = {"coattrim": "coat", "necktie": "neck", "hatband": "hat", "hatfeather": "hat"}
    middle = HEAD_ORIGIN.y * 0.55
    views = [("front", (0, -1, 0.08), (0.0, 0.0, middle), 1.5), ("side", (1, 0, 0.05), (0.0, 0.0, middle), 1.5),
             ("quarter", (0.7, -0.7, 0.25), (0.0, 0.0, middle), 1.5)]
    for look, parts in looks.items():
        for obj in bpy.data.objects:
            if "__" in obj.name:
                slot, option = obj.name.split("__")
                slot = slot.split("_")[-1]
                obj.hide_render = parts.get(trims.get(slot, slot), "none") != option
        for view, direction, target, frame in (views if look == "bare" else views[2:]):
            offset = Vector(direction).normalized() * 4.0
            camera.data.ortho_scale = frame
            camera.location = Vector(target) + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(folder, "%s_%s_%s.png" % (name, look, view))
            bpy.ops.render.render(write_still=True)
    for obj in bpy.data.objects:
        if "__" in obj.name:
            obj.hide_render = True
    head = kit.to_blender(head_point(Vector((0.0, 0.0, 0.0))))
    for view, direction in (("head", (0.45, -0.85, 0.2)), ("headside", (1, 0, 0.05)), ("headback", (-0.5, 0.8, 0.3))):
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = 0.55
        camera.location = head + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


# --- Mouth shapes (shape keys on the body), for singing: with the jaw, they make the vowels ---

def mouth_region(q):
    """How much a point (head space) is of the lips: near the mouth's line, in front of its corners."""
    return (1.0 - blend(0.0, 0.05, abs(q.y))) * blend(-0.09, -0.04, q.z)


def add_paleness():
    """The body's vertex colour: red how pale (see `paleness`); green and blue where the point is
    against the mouth (`mouth_at`: round it, a / 2.6 + 0.5; below its line, (d + 0.03) / 0.08), for
    shaders/toon.gdshader to draw the mouth by. Floats, so nothing is rounded or made sRGB."""
    body = bpy.data.objects.get(NAME_NOW)
    if body is None or body.type != "MESH":
        return
    colours = body.data.color_attributes.new(name="pale", type="FLOAT_COLOR", domain="POINT")
    for i, vert in enumerate(body.data.vertices):
        p = kit.from_blender(vert.co)
        a, d = mouth_at(head_space(p))
        colours.data[i].color = (paleness(p), min(max(a / 2.6 + 0.5, 0.0), 1.0), min(max((d + 0.03) / 0.08, 0.0), 1.0), 1.0)
    body.data.color_attributes.active_color_name = "pale"
    body.data.color_attributes.render_color_index = body.data.color_attributes.find("pale")


def add_mouth_shapes():
    """`wide`: the corners drawn back, out and up (E, I, a grin). `round`: the lips gathered in and
    pushed forward (O, U, a whistle). `frown`: the corners pulled down (doubt, dismay). On the body
    object only (the clothes do not reach the mouth)."""
    body = bpy.data.objects.get(NAME_NOW)
    if body is None or body.type != "MESH":
        return
    body.shape_key_add(name="Basis", from_mix=False)
    keys = {}
    for key in ("wide", "round", "frown"):
        keys[key] = body.shape_key_add(name=key, from_mix=False)
    for i, vert in enumerate(body.data.vertices):
        q = head_space(kit.from_blender(vert.co))
        m = mouth_region(q)
        if m <= 0.0:
            continue
        side = 1.0 if q.x >= 0.0 else -1.0
        corner = blend(0.07, 0.15, abs(q.x))
        wide = Vector((side * 0.014 * corner, 0.007 * corner, -0.018 * corner)) * m
        front = blend(-0.04, 0.06, q.z)
        gather = Vector((-side * 0.4 * max(abs(q.x) - 0.035, 0.0), 0.0, 0.02 * front)) * m * (0.4 + 0.6 * front)
        keys["wide"].data[i].co = vert.co + kit.to_blender(wide * HEAD_SIZE) - kit.to_blender(Vector())
        keys["round"].data[i].co = vert.co + kit.to_blender(gather * HEAD_SIZE) - kit.to_blender(Vector())
        frown = Vector((0.0, -0.016 * corner * blend(-0.02, 0.02, -q.y + 0.02), 0.004 * corner)) * m
        keys["frown"].data[i].co = vert.co + kit.to_blender(frown * HEAD_SIZE) - kit.to_blender(Vector())


class _Scene:
    def gltf(self, **options):
        add_paleness()
        add_mouth_shapes()
        options["export_vertex_color"] = "ACTIVE"
        bpy.ops.export_scene.gltf(**options)


class _Ops:
    export_scene = _Scene()

    def __getattr__(self, name):
        return getattr(bpy.ops, name)


class _Bpy:
    """bpy as the kit sees it: the same, but its glTF export first adds the mouth shapes."""
    ops = _Ops()

    def __getattr__(self, name):
        return getattr(bpy, name)


kit.bpy = _Bpy()
NAME_NOW = ""

ONLY_BODIES = [b for b in os.environ.get("FROG_BODIES", "").split(",") if b] or list(BODIES)
for body in ONLY_BODIES:
    kit.LOW = False
    shape_body(body)
    name = "frog_" + body
    NAME_NOW = name
    kit.export(name, bones(), PARTS, weights, MATERIALS, apart=APART)
    if PREVIEWS:
        previews(PREVIEWS, name)
    if os.environ.get("FROG_ONLY_FULL") != "1":
        kit.LOW = True
        NAME_NOW = name + "_lo"
        kit.export(name + "_lo", bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in PARTS], weights, MATERIALS, apart=APART)
