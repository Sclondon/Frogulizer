"""Builds the frog folk (the band and the crowd on the riverboat) and exports them for Godot.

Run from the project root:
    blender --background --python tools/build_frogs.py
    blender --background --python tools/build_frogs.py -- <folder>   # also renders previews there

Writes models/frog.glb and models/frog_lo.glb (and editable copies in tools/).

Anthropomorphic frogs in Victorian Sunday best, after the riverboat frogs in
Over the Garden Wall (see inpsirationArt/): a broad flat head as wide as the
shoulders, sitting straight on the body with no neck to speak of; a wide mouth
right round the front; big round eyes up on top, under heavy lids that droop
half shut; a pear of a body, narrow in the shoulder and round in the belly
(pale cream in front); thin arms and long thin fingers ending in round pads;
thin legs; and long flat webbed feet, always bare.

It is built on the boy's skeleton (tools/build_figure_template.py has the
contract), so CharacterRig (and FrogRig, scripts/frog_rig.gd, on it) moves it
as it moves the boy. Its own extra bones, which FrogRig poses:
    jaw          (under head) hinges the lower jaw from behind the corners of the mouth
    lid_l/lid_r  (under head) the upper lids, turned about the eye's centre on X to blink
    eye_l/eye_r  (under head) the eyes, which CharacterRig already turns to look about
Hands are three long fingers and a thumb (finger0..2 a/b/c, thumba/b), each with
a round pad at its tip.

Clothes are options on slots (CharacterRig.restyle: a mesh named
`frog_<slot>__<option>` shows when the look's "parts" names it):
    hat:   top, bowler, shako, boater, bonnet, helmet, cap, fez, none
    coat:  tails, band, frock, jacket, dress, waistcoat, none
    neck:  bow, cravat, scarf, none
    legs:  trousers, breeches, none
Colours are by material (Toon recolours by name: see FrogLook).
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
PREVIEWS = kit.PREVIEW_DIR
kit.PREVIEW_DIR = None  # (the kit's own previews are the boy's; these are below)

NAME = "frog"

# --- Joints (Godot space: metres, Y up, facing +Z, +X his left) ---

ANKLE_Y = 0.05
THIGH = 0.24
SHIN = 0.25
HIP_X = 0.078
HIP_Y = ANKLE_Y + SHIN + THIGH
KNEE_Y = HIP_Y - THIGH
HIPS = Vector((0.0, HIP_Y + 0.03, 0.0))
SPINE = Vector((0.0, 0.66, 0.0))
CHEST = Vector((0.0, 0.80, 0.0))
NECK = Vector((0.0, 0.90, 0.0))
HEAD = Vector((0.0, 0.945, 0.0))
SHOULDER = Vector((0.145, 0.865, 0.0))
UPPER_ARM = 0.19
FOREARM = 0.18
ELBOW_X = SHOULDER.x + UPPER_ARM
WRIST_X = ELBOW_X + FOREARM
TOE = Vector((0.0, -0.035, 0.075))  # where the foot bends, from the ankle

# The head: everything above the line of the mouth is the head bone's; below it, the jaw's.
MOUTH_Y = 0.995
HEAD_Z = 0.02
JAW = Vector((0.0, MOUTH_Y - 0.005, -0.075))  # the hinge, behind the corners of the mouth
EYE_RADIUS = 0.041
EYE_CENTRE = Vector((0.078, 1.098, 0.088))
EYE_WAY = Vector((0.36, 0.12, 0.92)).normalized()
LID_RADIUS = EYE_RADIUS + 0.0055
# The lid at rest covers from behind the eye round over the top to this angle
# (from straight up, towards the front): just above the pupil, the sleepy look.
LID_EDGE = math.radians(48.0)
HAT_Y = 1.13  # where a hat sits, on the crown between and behind the eyes
HAT_Z = -0.02

# Fingers: (offset across the hand, length, radius, how far it fans out from the middle)
FINGERS = [(0.017, 0.068, 0.0095, 0.22), (0.0, 0.074, 0.0098, 0.0), (-0.017, 0.066, 0.0092, -0.22)]
KNUCKLES = (0.0, 0.45, 0.76)
PALM = 0.048
THUMB_LENGTH = 0.05

# --- Colours (sRGB). Toon gives `eyewhite` and `pupil` a wet glint. FrogLook
# (scripts/frog_look.gd) recolours any of these by name. ---

MATERIALS = [
    ("skin", (0.45, 0.55, 0.27)),
    ("belly", (0.82, 0.80, 0.55)),
    ("eyewhite", (0.95, 0.93, 0.80)),
    ("pupil", (0.04, 0.04, 0.05)),
    ("mouth", (0.32, 0.09, 0.10)),
    ("tongue", (0.86, 0.45, 0.45)),
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
SKIN, BELLY, EYEWHITE, PUPIL, MOUTH, TONGUE, COAT, TRIM, VEST, TROUSERS, HAT, BAND, COLLAR, TIE, DRESS, FEATHER = range(len(MATERIALS))


# --- Small shape helpers ---

def loft(b, loops, start=True, end=True):
    """Skins rings of points (each the same count, going the same way round) into
    a closed surface, capping either end with a point in its middle."""
    count = len(loops[0])
    made = [[b._vert(p, None) for p in loop] for loop in loops]
    faces = []
    for a, c in zip(made, made[1:]):
        for i in range(count):
            j = (i + 1) % count
            faces.append(b.bm.faces.new((a[i], a[j], c[j], c[i])))
    for use, ring, points in ((start, made[0], loops[0]), (end, made[-1], loops[-1])):
        if use:
            middle = sum(points, Vector()) / count
            pole = b._vert(middle, None)
            for i in range(count):
                faces.append(b.bm.faces.new((ring[i], ring[(i + 1) % count], pole)))
    import bmesh
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)


def outline(y, rx, front, back, centre_z, power=2.3, count=28):
    """A level ring, wider one way than the other and fuller in front than behind (a head seen from above)."""
    if kit.LOW:
        count = 12
    points = []
    for k in range(count):
        a = math.tau * k / count
        c, s = math.cos(a), math.sin(a)
        x = rx * math.copysign(abs(c) ** (2.0 / power), c)
        z = (front if s > 0.0 else back) * math.copysign(abs(s) ** (2.0 / power), s)
        points.append(Vector((x, y, centre_z + z)))
    return points


def frame_of(way, up=Y):
    """A basis whose Z points along `way`."""
    w = way.normalized()
    r = up.cross(w).normalized()
    u = w.cross(r)
    return Matrix((r, u, w)).transposed()


def sides():
    return (1.0, -1.0)


# --- The head ---

# The head above the mouth, as level slices: (height above the mouth, half width, reach forward, reach back)
# (Low at the back, so the crown runs straight down into the shoulders: a wedge from the side, no neck.)
CRANIUM = [(0.0, 0.150, 0.168, 0.098), (0.012, 0.155, 0.168, 0.100), (0.035, 0.151, 0.158, 0.092), (0.06, 0.137, 0.142, 0.074),
           (0.08, 0.117, 0.120, 0.054), (0.097, 0.090, 0.092, 0.034), (0.108, 0.060, 0.062, 0.018), (0.115, 0.026, 0.028, 0.004)]
# The jaw and throat below it, down to where they go into the body: (depth below the mouth, half width, forward, back, centre shift)
JAWLINE = [(0.0, 0.149, 0.166, 0.098, 0.0), (0.016, 0.151, 0.160, 0.100, 0.0), (0.04, 0.145, 0.140, 0.100, -0.004),
           (0.065, 0.130, 0.110, 0.098, -0.010), (0.09, 0.112, 0.075, 0.094, -0.016), (0.11, 0.098, 0.045, 0.090, -0.020),
           (0.125, 0.090, 0.020, 0.086, -0.022)]

# The head is drawn at the sizes above and then made this much bigger about the
# middle of the mouth: frog folk are mostly head.
HEAD_SIZE = 1.22
HEAD_PIVOT = Vector((0.0, MOUTH_Y, 0.0))


def big(p):
    return HEAD_PIVOT + (p - HEAD_PIVOT) * HEAD_SIZE


def unbig(p):
    return HEAD_PIVOT + (p - HEAD_PIVOT) / HEAD_SIZE


def smile(p):
    """The mouth's line rises a little towards its corners: a frog's smirk."""
    lift = 0.012 * blend(0.06, -0.07, p.z) * blend(0.03, 0.14, abs(p.x))
    return Vector((p.x, p.y + lift * blend(MOUTH_Y + 0.07, MOUTH_Y, p.y) * blend(MOUTH_Y - 0.08, MOUTH_Y, p.y), p.z))


def eye_centre(side, drawn=True):
    """Where an eye is: as drawn (made bigger with the head), or as laid out above."""
    e = Vector((side * EYE_CENTRE.x, EYE_CENTRE.y, EYE_CENTRE.z))
    return big(e) if drawn else e


def eye_way(side):
    return Vector((side * EYE_WAY.x, EYE_WAY.y, EYE_WAY.z))


def head(b):
    b.place = lambda p: big(smile(p))
    loft(b, [outline(MOUTH_Y + h, rx, front, back, HEAD_Z) for h, rx, front, back in CRANIUM])
    b.place = big
    # The mounds the eyes sit up in, and a brow ridge running back from each
    for side in sides():
        e = eye_centre(side, False)
        b.ellipsoid(e - eye_way(side) * 0.022 + Vector((0.0, -0.010, 0.0)), Vector((0.047, 0.044, 0.047)), None, 16, 9)
        b.ellipsoid(e + Vector((-side * 0.01, -0.03, -0.05)), Vector((0.04, 0.03, 0.05)), None, 12, 6)
    # Nostrils: two small bumps on the snout
    for side in sides():
        b.ellipsoid(Vector((side * 0.026, MOUTH_Y + 0.062, HEAD_Z + 0.150)), Vector((0.011, 0.008, 0.008)), None, 8, 4)
    b.place = None


def jaw(b):
    b.place = lambda p: big(smile(p))
    loft(b, [outline(MOUTH_Y - d, rx, front, back, HEAD_Z + shift) for d, rx, front, back, shift in JAWLINE])
    b.place = None


def jaw_mesh():
    """The jaw and throat, fused."""
    b = kit.Builder()
    jaw(b)
    return painted(b, (0.003, 4, 9000), lambda p, n: SKIN)


def mouth(b):
    b.place = big
    # The roof of the mouth, dark, inside the head where the jaw meets it
    b.ellipsoid(Vector((0.0, MOUTH_Y - 0.004, HEAD_Z + 0.03)), Vector((0.135, 0.022, 0.125)), None, 20, 6)
    b.place = None


def tongue(b):
    b.place = big
    b.ellipsoid(Vector((0.0, MOUTH_Y - 0.008, HEAD_Z + 0.04)), Vector((0.085, 0.016, 0.095)), None, 16, 5)
    b.place = None


def eyes(b):
    b.place = big
    for side in sides():
        b.ellipsoid(eye_centre(side, False), Vector((EYE_RADIUS,) * 3), None, 18, 10)
    b.place = None


def pupils(b):
    b.place = big
    for side in sides():
        e = eye_centre(side, False)
        way = eye_way(side)
        tilt = frame_of(way)
        b.ellipsoid(e + way * (EYE_RADIUS - 0.003), Vector((0.0175, 0.0135, 0.006)), tilt, 14, 5)
    b.place = None


def lids(b):
    """Each upper lid: a shell over the top of the eyeball, from well behind it
    round over the top to LID_EDGE. In slices across the eye (along X, which is
    the axis FrogRig turns it about to blink), each a crescent."""
    b.place = big
    slices = 9 if not kit.LOW else 5
    arc = 12 if not kit.LOW else 6
    for side in sides():
        e = eye_centre(side, False)
        loops = []
        for k in range(slices):
            x = (-0.94 + 1.88 * k / (slices - 1)) * LID_RADIUS
            outer = math.sqrt(max(LID_RADIUS ** 2 - x * x, 1e-6))
            inner = math.sqrt(max((LID_RADIUS - 0.005) ** 2 - x * x, 1e-6))
            loop = []
            for i in range(arc + 1):
                a = -1.9 + (LID_EDGE + 1.9) * i / arc
                loop.append(e + Vector((x, outer * math.cos(a), outer * math.sin(a))))
            for i in range(arc, -1, -1):
                a = -1.9 + (LID_EDGE + 1.9) * i / arc
                loop.append(e + Vector((x, inner * math.cos(a), inner * math.sin(a))))
            loops.append(loop)
        loft(b, loops)
    b.place = None


# --- The body ---

# Bare skin: (height, half width, half depth, forward), crotch to throat. A pear.
TORSO = [(0.50, 0.05, 0.05, 0.0), (0.53, 0.12, 0.10, 0.0), (0.58, 0.158, 0.130, 0.008), (0.65, 0.170, 0.143, 0.022),
         (0.72, 0.166, 0.142, 0.026), (0.79, 0.152, 0.128, 0.018), (0.85, 0.137, 0.110, 0.004), (0.89, 0.134, 0.106, -0.004),
         (0.93, 0.132, 0.106, -0.012), (0.97, 0.122, 0.10, -0.02), (1.0, 0.10, 0.09, -0.025)]


def ring_at(profile, y, grow=0.0):
    """The body's ring at a height, from a profile, with something added all round (for clothes over it)."""
    for (y0, rx0, rz0, z0), (y1, rx1, rz1, z1) in zip(profile, profile[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            return kit.upright(0.0, y, z0 + (z1 - z0) * t, rx0 + (rx1 - rx0) * t + grow, rz0 + (rz1 - rz0) * t + grow)
    y0, rx, rz, z0 = profile[0] if y < profile[0][0] else profile[-1]
    return kit.upright(0.0, y, z0, rx + grow, rz + grow)


def torso(b):
    b.tube([kit.upright(0.0, y, z, rx, rz) for y, rx, rz, z in TORSO], 24)
    # (and the nape, carrying the back of the head down into the shoulders)
    b.ellipsoid(Vector((0.0, 0.94, -0.045)), Vector((0.125, 0.09, 0.075)), None, 16, 8)


def torso_mesh():
    b = kit.Builder()
    torso(b)

    def paint(p, n):
        # The pale front: the belly and the chest, up to the throat
        centre = ring_at(TORSO, p.y)[0]
        around = abs(math.atan2(p.x, p.z - centre.z + 0.04))
        return BELLY if around < 0.95 and 0.53 < p.y < 0.97 else SKIN
    return painted(b, (0.0045, 4, 7000), paint)


# Arms, straight out: (distance from the shoulder, radius)
ARM = [(-0.05, 0.040), (0.0, 0.036), (0.08, 0.031), (UPPER_ARM, 0.027), (0.28, 0.025), (UPPER_ARM + FOREARM - 0.01, 0.020), (UPPER_ARM + FOREARM + 0.01, 0.018)]


def arms(b):
    for side in sides():
        b.tube([(Vector((side * (SHOULDER.x + d), SHOULDER.y, 0.0)), Y * r, Z * r * 1.05) for d, r in ARM], 12)


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
        # (distance past the wrist, half thickness, half width): up inside the arm, flattening into the palm
        palm = [(-0.02, 0.018, 0.019), (0.0, 0.015, 0.019), (0.02, 0.013, 0.025), (0.04, 0.012, 0.030), (PALM + 0.004, 0.011, 0.028)]
        rings = [(wrist + X * side * d, Y * ry, Z * rz) for d, ry, rz in palm]
        b.tube(rings + kit.dome(rings[-1], X * side, 0.008, 2), 12)


def fingers(b):
    for side in sides():
        for index, (_z, length, radius, _fan) in enumerate(FINGERS):
            knuckle, along = finger_line(side, index)
            spans = (-0.1, 0.0, 0.2, 0.38, 0.45, 0.52, 0.68, 0.76, 0.84, 0.92)
            b.strand([knuckle + along * length * t for t in spans], [radius * (1.0 - 0.25 * max(t, 0.0)) for t in spans], 8)
            # The round pad at its tip
            b.ellipsoid(knuckle + along * length * 0.97, Vector((radius * 1.35, radius * 1.05, radius * 1.35)), None, 10, 5)
        root, along = thumb_line(side)
        b.strand([root + along * THUMB_LENGTH * t for t in (-0.2, 0.0, 0.3, 0.5, 0.7, 0.9)], [0.0105, 0.0105, 0.0098, 0.009, 0.0085, 0.008], 8)
        b.ellipsoid(root + along * THUMB_LENGTH * 0.95, Vector((0.012, 0.01, 0.012)), None, 10, 5)


# Legs: (height, radius). Thin, a little thicker in the thigh.
LEG = [(HIP_Y + 0.05, 0.055), (HIP_Y - 0.02, 0.054), (0.42, 0.045), (KNEE_Y, 0.036), (0.24, 0.032), (0.14, 0.026), (0.08, 0.023), (0.05, 0.022)]


def legs(b):
    for side in sides():
        b.tube([kit.upright(side * HIP_X, y, 0.0, r, r) for y, r in LEG], 12)


# Each foot's toes, from the ankle: (angle out from straight ahead, length, radius). Long, splayed, with pads.
TOES = [(-0.42, 0.13, 0.010), (-0.12, 0.165, 0.011), (0.2, 0.15, 0.011), (0.5, 0.11, 0.0095)]


def toe_lines(side):
    root = Vector((side * HIP_X, 0.012, 0.045))
    out = []
    for angle, length, radius in TOES:
        way = Vector((side * math.sin(angle) * (1.0 if angle > 0 else 1.0), 0.0, math.cos(angle)))
        # (the outer toes on each side are on the outside of that foot)
        way = Vector((side * math.sin(angle), 0.0, math.cos(angle)))
        out.append((root, way.normalized(), length, radius))
    return out


def feet(b):
    for side in sides():
        ankle = Vector((side * HIP_X, ANKLE_Y, 0.0))
        # The heel and the top of the foot, flat on the ground, broadening forward
        foot = [(-0.04, 0.0, 0.026, 0.022), (-0.02, 0.004, 0.032, 0.03), (0.01, -0.006, 0.036, 0.028),
                (0.04, -0.024, 0.044, 0.018), (0.07, -0.034, 0.05, 0.011)]
        rings = [(ankle + Vector((0.0, y, z)), X * rx, Y * ry) for z, y, rx, ry in foot]
        b.tube(kit.dome(rings[0], -Z, 0.014, 3)[::-1] + rings + kit.dome(rings[-1], Z, 0.01, 2), 16, 0.0)
        for root, way, length, radius in toe_lines(side):
            points = [root + way * length * t + Vector((0.0, -0.002 * t, 0.0)) for t in (0.0, 0.3, 0.6, 0.85, 1.0)]
            b.strand(points, [radius * (1.0 - 0.15 * t) for t in (0.0, 0.3, 0.6, 0.85, 1.0)], 8)
            b.ellipsoid(points[-1], Vector((radius * 1.5, radius * 0.9, radius * 1.5)), None, 10, 4)


def webs(b):
    """The webbing between the toes: a thin sheet from the middle of the foot out to
    two-thirds of the way along each toe, its edge scalloped in between."""
    for side in sides():
        lines = toe_lines(side)
        loop_top, loop_bottom = [], []
        root = lines[0][0] + Vector((0.0, 0.0, -0.01))
        for k, (r, way, length, _radius) in enumerate(lines):
            tip = r + way * length * 0.72
            loop_top.append(tip)
            if k + 1 < len(lines):
                r2, way2, length2, _ = lines[k + 1]
                mid = (r + way * length * 0.45 + r2 + way2 * length2 * 0.45) * 0.5
                loop_top.append(mid)
        points = [root] + loop_top
        middle = sum(points, Vector()) / len(points)
        made_top = [b._vert(p + Vector((0.0, 0.004, 0.0)), 0.0) for p in points]
        made_bottom = [b._vert(Vector((p.x, 0.001, p.z)), None) for p in points]
        top_pole = b._vert(middle + Vector((0.0, 0.004, 0.0)), 0.0)
        bottom_pole = b._vert(Vector((middle.x, 0.001, middle.z)), None)
        n = len(points)
        faces = []
        for i in range(n):
            j = (i + 1) % n
            faces.append(b.bm.faces.new((made_top[i], made_top[j], top_pole)))
            faces.append(b.bm.faces.new((made_bottom[j], made_bottom[i], bottom_pole)))
            faces.append(b.bm.faces.new((made_top[j], made_top[i], made_bottom[i], made_bottom[j])))
        import bmesh
        bmesh.ops.recalc_face_normals(b.bm, faces=faces)


def painted(b, fuse, paint):
    """A builder's shapes as one mesh (fused if asked), each face given a material by `paint(centre, normal)`."""
    mesh = kit.fused(b, None if kit.LOW else fuse)
    for polygon in mesh.polygons:
        centre = kit.from_blender(Vector(polygon.center))
        normal = kit.from_blender(Vector(polygon.normal))
        polygon.material_index = paint(centre, normal)
    return mesh


def head_mesh():
    b = kit.Builder()
    head(b)
    return painted(b, (0.0035, 3, 9000), lambda p, n: SKIN)


# --- Clothes. Each is drawn over the bare body, and each is an object of its own. ---

def sleeves(b, grow, cuff, puffed=0.0):
    for side in sides():
        sleeve = [(-0.06, 0.052), (0.0, 0.050 + puffed * 0.03), (0.07, 0.044 + puffed * 0.04), (UPPER_ARM, 0.036), (0.27, 0.033), (cuff, 0.031), (cuff + 0.005, 0.026)]
        b.tube([(Vector((side * (SHOULDER.x + d), SHOULDER.y, 0.0)), Y * (r + grow), Z * (r + grow) * 1.05) for d, r in sleeve], 12)


def coat_body(b, bottom, grow, top=0.955, flare=0.0, back_only=False):
    """A garment round the trunk from `bottom` up to the throat, `grow` clear of the skin."""
    rings = []
    y = bottom
    steps = 9
    for k in range(steps + 1):
        y = bottom + (top - bottom) * k / steps
        centre, u, v = ring_at(TORSO, max(y, 0.53), grow)
        if y < 0.56:
            # Below the seat a skirt hangs straight down and flares a little
            spread = flare * (0.56 - y) / 0.3
            u = u + X * spread
            v = v + Z * spread
        rings.append((centre, u, v))
    b.tube(rings, 22)


def tails(b, length):
    """Two tails hanging behind, from the waist."""
    for side in sides():
        rows = []
        for t in (0.0, 0.25, 0.5, 0.75, 1.0):
            y = 0.62 - length * t
            centre = Vector((side * (0.07 - 0.015 * t), y, -0.13 - 0.02 * t))
            rows.append((centre, X * (0.075 - 0.02 * t), Z * 0.012))
        b.tube(rows, 10)


def lapels(b, depth=0.86, low=0.70):
    for side in sides():
        rows = []
        for t in (0.0, 0.33, 0.66, 1.0):
            y = low + (depth + 0.07 - low) * t
            centre, u, v = ring_at(TORSO, y, 0.022)
            front = centre + v * 0.98
            rows.append((front + X * side * (0.012 + 0.035 * t), X * 0.028 * (0.4 + 0.6 * t), Z * 0.006))
        b.tube(rows, 8)


def buttons(b, ys, x=0.0, grow=0.022, size=0.009):
    for y in ys:
        centre, _u, v = ring_at(TORSO, y, grow)
        for sx in ((x, -x) if x else (0.0,)):
            b.ellipsoid(centre + v * 1.0 + X * sx, Vector((size, size, size * 0.6)), None, 8, 3)


def collar_band(b, height=0.03, grow=0.03):
    b.tube([kit.upright(0.0, y, 0.0, 0.106 + grow, 0.090 + grow) for y in (0.94, 0.94 + height)], 20)


def coat_tails(b):
    coat_body(b, 0.60, 0.022)
    sleeves(b, 0.0, UPPER_ARM + FOREARM - 0.02)
    tails(b, 0.3)


def coat_band(b):
    coat_body(b, 0.56, 0.024)
    sleeves(b, 0.002, UPPER_ARM + FOREARM - 0.02)
    collar_band(b, 0.035, 0.028)


def band_trim(b):
    # Gold braid across the chest, cuffs, a belt and epaulettes on a bandsman's jacket
    buttons(b, (0.64, 0.70, 0.76, 0.82, 0.88), 0.045, 0.026, 0.009)
    for y in (0.70, 0.76, 0.82):
        centre, u, v = ring_at(TORSO, y, 0.026)
        b.tube([(centre + v * 0.99 + X * x, Y * 0.005, Z * 0.004) for x in (-0.045, 0.0, 0.045)], 6)
    for side in sides():
        b.ellipsoid(Vector((side * (SHOULDER.x + 0.01), SHOULDER.y + 0.04, 0.0)), Vector((0.05, 0.014, 0.045)), None, 12, 4)
        b.tube([(Vector((side * (WRIST_X - d), SHOULDER.y, 0.0)), Y * 0.034, Z * 0.036) for d in (0.035, 0.05, 0.065)], 12)
    b.tube([kit.upright(0.0, y, ring_at(TORSO, 0.6, 0.0)[0].z, ring_at(TORSO, 0.6, 0.028)[1].x, ring_at(TORSO, 0.6, 0.028)[2].z) for y in (0.585, 0.615)], 22)


def coat_frock(b):
    coat_body(b, 0.33, 0.022, flare=0.05)
    sleeves(b, 0.0, UPPER_ARM + FOREARM - 0.02)


def coat_jacket(b):
    coat_body(b, 0.53, 0.022, flare=0.02)
    sleeves(b, 0.0, UPPER_ARM + FOREARM - 0.03)


def coat_dress(b):
    # A gown: fitted bodice, a full bell of a skirt to the ground, puffed sleeves
    rings = []
    for y, grow in ((0.955, 0.012), (0.90, 0.014), (0.82, 0.014), (0.72, 0.012), (0.66, 0.014)):
        rings.append(ring_at(TORSO, y, grow))
    for y, r, d in ((0.61, 0.20, 0.17), (0.50, 0.24, 0.22), (0.35, 0.28, 0.26), (0.18, 0.31, 0.29), (0.06, 0.33, 0.31), (0.035, 0.33, 0.31)):
        rings.append(kit.upright(0.0, y, 0.01, r, d))
    b.tube(rings[::-1], 26, 0.03)
    sleeves(b, 0.004, 0.24, puffed=1.0)


def dress_frills(b):
    # A frill round the hem and lace at the throat
    for k in range(18):
        a = math.tau * k / 18
        b.ellipsoid(Vector((math.sin(a) * 0.33, 0.055, 0.01 + math.cos(a) * 0.31)), Vector((0.05, 0.03, 0.05)), None, 8, 4)
    b.tube([kit.upright(0.0, y, 0.004, 0.13, 0.115) for y in (0.93, 0.96, 0.975)], 20)


def coat_waistcoat(b):
    coat_body(b, 0.58, 0.016, top=0.93)
    for side in sides():
        # (the armholes are bare: short stubs at the shoulders)
        b.tube([(Vector((side * (SHOULDER.x + d), SHOULDER.y, 0.0)), Y * 0.048, Z * 0.05) for d in (-0.05, 0.0, 0.02)], 12)


def vest_front(b):
    # A waistcoat's front showing between the lapels of a tailcoat
    rows = [ring_at(TORSO, y, 0.024) for y in (0.62, 0.66, 0.74, 0.82, 0.88)]
    b.tube([(c + v * 0.97, X * 0.05 * (1.2 - 0.4 * k / 4), Z * 0.006) for k, (c, u, v) in enumerate(rows)], 8)
    buttons(b, (0.66, 0.72, 0.78), 0.0, 0.032, 0.007)


def trousers(b, bottom=0.10):
    # (the seat, and up over the belly to under the coat, clear of the skin)
    b.tube([kit.upright(0.0, 0.48, 0.0, 0.07, 0.07)] + [ring_at(TORSO, y, 0.014) for y in (0.52, 0.56, 0.60, 0.64, 0.67)], 20)
    for side in sides():
        leg = [(HIP_Y + 0.05, 0.072), (HIP_Y - 0.02, 0.07), (0.42, 0.062), (KNEE_Y, 0.054), (0.22, 0.05), (bottom + 0.02, 0.046), (bottom, 0.046)]
        if bottom > 0.2:
            leg = [(y, r) for y, r in leg if y > bottom + 0.02] + [(bottom + 0.02, 0.05), (bottom, 0.045)]
        b.tube([kit.upright(side * HIP_X, y, 0.0, r, r * 1.04) for y, r in leg], 14)


def breeches(b):
    trousers(b, KNEE_Y - 0.03)


def collar_ring(b):
    # A stiff white collar under the chin
    b.tube([kit.upright(0.0, y, 0.004, 0.112, 0.098) for y in (0.905, 0.925, 0.945)], 20)


def bow_tie(b):
    at = Vector((0.0, 0.925, 0.118))
    for side in sides():
        b.ellipsoid(at + Vector((side * 0.03, 0.0, 0.0)), Vector((0.03, 0.02, 0.012)), Matrix.Rotation(side * 0.25, 3, "Z"), 10, 4)
    b.ellipsoid(at + Vector((0.0, 0.0, 0.006)), Vector((0.012, 0.014, 0.012)), None, 8, 4)


def cravat(b):
    b.tube([kit.upright(0.0, y, 0.006, 0.118, 0.104) for y in (0.89, 0.92, 0.95)], 20)
    b.ellipsoid(Vector((0.0, 0.86, 0.12)), Vector((0.04, 0.06, 0.03)), None, 12, 6)


def scarf(b):
    b.tube([kit.upright(0.0, y, 0.006, 0.125, 0.11) for y in (0.88, 0.905, 0.93, 0.955)], 20)
    b.strand([Vector((0.06, 0.9, 0.12)), Vector((0.08, 0.82, 0.14)), Vector((0.09, 0.72, 0.16)), Vector((0.095, 0.64, 0.17))], [0.03, 0.028, 0.026, 0.024], 8)


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
    peak = [(Vector((0.0, HAT_Y + 0.005, HAT_Z + z)), X * half, Y * 0.004) for z, half in ((0.04, 0.06), (0.07, 0.062), (0.095, 0.05), (0.105, 0.03))]
    b.tube(peak, 10)


def band_shako(b):
    b.tube([hat_ring(y, 0.069, 0.065) for y in (0.012, 0.03)], 22)
    b.tube([hat_ring(y, 0.073, 0.069) for y in (0.096, 0.108)], 22)
    # (a plume)
    b.ellipsoid(Vector((0.0, HAT_Y + 0.15, HAT_Z + 0.05)), Vector((0.015, 0.045, 0.015)), None, 8, 6)


def hat_boater(b):
    brim(b, 0.11, 0.10, 0.005)
    b.tube([hat_ring(y, 0.066, 0.06) for y in (0.0, 0.05, 0.052)], 22)


def band_boater(b):
    b.tube([hat_ring(y, 0.068, 0.062) for y in (0.006, 0.024)], 22)


def hat_bonnet(b):
    # A lady's wide hat, tilted, with a feather
    tilt = Matrix.Rotation(-0.18, 3, "X")
    b.place = lambda p: Vector((0.0, HAT_Y, HAT_Z)) + tilt @ (p - Vector((0.0, HAT_Y, HAT_Z)))
    brim(b, 0.15, 0.14, 0.006, 0.02)
    b.tube([hat_ring(y, rx, rz) for y, rx, rz in ((0.0, 0.07, 0.065), (0.05, 0.072, 0.067), (0.07, 0.05, 0.045))], 22)
    b.place = None


def band_bonnet(b):
    tilt = Matrix.Rotation(-0.18, 3, "X")
    b.place = lambda p: Vector((0.0, HAT_Y, HAT_Z)) + tilt @ (p - Vector((0.0, HAT_Y, HAT_Z)))
    b.tube([hat_ring(y, 0.074, 0.069) for y in (0.006, 0.026)], 22)
    for k in range(5):
        a = -0.6 + 0.3 * k
        b.ellipsoid(Vector((0.07 * math.sin(a) + 0.04, HAT_Y + 0.03, HAT_Z + 0.07 * math.cos(a))), Vector((0.018, 0.016, 0.018)), None, 8, 4)
    b.place = None


def bonnet_feather(b):
    tilt = Matrix.Rotation(-0.18, 3, "X")
    b.place = lambda p: Vector((0.0, HAT_Y, HAT_Z)) + tilt @ (p - Vector((0.0, HAT_Y, HAT_Z)))
    for k, lean in enumerate((-0.35, 0.0, 0.3)):
        base = Vector((-0.05 + 0.02 * k, HAT_Y + 0.05, HAT_Z - 0.02))
        tip = base + Vector((-0.06 + lean * 0.1, 0.17 - abs(lean) * 0.05, -0.06))
        mid = base.lerp(tip, 0.5) + Vector((-0.02, 0.01, 0.0))
        b.strand([base, base.lerp(mid, 0.5), mid, mid.lerp(tip, 0.5), tip], [0.012, 0.024, 0.03, 0.024, 0.008], 8)
    b.place = None


def hat_helmet(b):
    # A tall policeman's helmet, with a star on the front
    rings = []
    for y, r in ((0.0, 0.074), (0.04, 0.078), (0.09, 0.07), (0.13, 0.05), (0.15, 0.024), (0.155, 0.01)):
        rings.append(hat_ring(y, r, r * 0.95))
    b.tube(rings, 22)
    brim(b, 0.085, 0.085, 0.004)


def band_helmet(b):
    b.ellipsoid(Vector((0.0, HAT_Y + 0.07, HAT_Z + 0.075)), Vector((0.022, 0.022, 0.006)), None, 10, 4)
    b.ellipsoid(Vector((0.0, HAT_Y + 0.165, HAT_Z)), Vector((0.012, 0.012, 0.012)), None, 8, 4)


def hat_cap(b):
    # A peaked cap, a conductor's or a steamboat man's
    b.tube([hat_ring(y, rx, rz) for y, rx, rz in ((0.0, 0.068, 0.064), (0.035, 0.07, 0.066), (0.05, 0.085, 0.082), (0.065, 0.082, 0.08), (0.07, 0.05, 0.048))], 22)
    peak = [(Vector((0.0, HAT_Y + 0.008 - 0.25 * (z - 0.05), HAT_Z + z)), X * half, Y * 0.004) for z, half in ((0.05, 0.062), (0.08, 0.064), (0.105, 0.05), (0.12, 0.028))]
    b.tube(peak, 10)


def band_cap(b):
    b.tube([hat_ring(y, 0.071, 0.067) for y in (0.012, 0.03)], 22)


def hat_fez(b):
    b.tube([hat_ring(y, rx, rz) for y, rx, rz in ((0.0, 0.065, 0.062), (0.08, 0.052, 0.05), (0.082, 0.03, 0.028))], 20)


def band_fez(b):
    b.strand([Vector((0.0, HAT_Y + 0.083, HAT_Z)), Vector((0.03, HAT_Y + 0.07, HAT_Z - 0.02)), Vector((0.05, HAT_Y + 0.03, HAT_Z - 0.03))], [0.004, 0.004, 0.004], 6)
    b.ellipsoid(Vector((0.052, HAT_Y + 0.02, HAT_Z - 0.03)), Vector((0.012, 0.02, 0.012)), None, 8, 4)


# --- Skin weights ---

def body_weights(p, skirt=0.0):
    """The trunk, arms and legs, by where a point sits (the template's scheme).
    `skirt` 1 keeps what hangs below the seat with the hips instead of the legs."""
    suffix = "_l" if p.x >= 0.0 else "_r"
    reach = abs(p.x)
    arm = blend(SHOULDER.x - 0.03, SHOULDER.x + 0.03, reach) if p.y > CHEST.y - 0.03 else 0.0
    fore = blend(ELBOW_X - 0.03, ELBOW_X + 0.03, reach)
    hand = blend(WRIST_X - 0.015, WRIST_X + 0.012, reach)
    leg = blend(HIP_Y + 0.035, HIP_Y - 0.05, p.y) * (1.0 - skirt)
    left = blend(-0.012, 0.012, p.x)
    shin = blend(KNEE_Y + 0.04, KNEE_Y - 0.04, p.y)
    low = blend(SPINE.y + 0.05, SPINE.y - 0.05, p.y)
    high = blend(CHEST.y - 0.06, CHEST.y + 0.05, p.y)
    neck = blend(NECK.y - 0.03, NECK.y + 0.02, p.y) if reach < 0.12 else 0.0
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
        # (a gown or a frock coat's skirts go some way with the legs, more the lower they hang)
        swing = blend(HIP_Y, 0.2, p.y) * 0.45 * skirt
        for name, share in (("_l", left), ("_r", 1.0 - left)):
            result["thigh" + name] = result.get("thigh" + name, 0.0) + swing * share
        result["hips"] = result["hips"] * (1.0 - swing) + (1.0 - (1.0 - arm)) * 0.0
        for key in ("spine", "chest", "neck"):
            result[key] *= (1.0 - swing)
    for name, share in (("_l", left), ("_r", 1.0 - left)):
        result["thigh" + name] = result.get("thigh" + name, 0.0) + leg * share * (1.0 - shin)
        result["shin" + name] = leg * share * shin
    return result


def line_weights(suffix, lines, p):
    """Fingers or toes: find the line this point is on and how far along it, and share it out over its joints."""
    best = None
    for name, root, along, length, joints in lines:
        t = (p - root).dot(along)
        away = (p - root - along * min(max(t, 0.0), length)).length
        if best is None or away < best[0]:
            best = (away, name, t / length, joints, length)
    _away, name, t, joints, length = best
    soft = 0.006 / length
    shares = [blend(joint - soft, joint + soft, t) for joint in joints]
    result = {"hand" + suffix: 1.0 - shares[0]}
    for k, letter in enumerate("abc"[:len(joints)]):
        result[name + letter + suffix] = shares[k] - (shares[k + 1] if k + 1 < len(joints) else 0.0)
    return result


def weights(part, p):
    suffix = "_l" if p.x >= 0.0 else "_r"
    side = 1.0 if p.x >= 0.0 else -1.0
    slot = part.split("__")[0]
    if slot in ("head", "mouth", "nostrils") or slot.startswith("hat") or slot.startswith("band"):
        return {"head": 1.0}
    if slot == "jaw" or slot == "tongue":
        # The throat, low and behind, stays with the neck
        q = unbig(p)
        throat = max(blend(JAW.z + 0.03, JAW.z - 0.03, q.z), blend(MOUTH_Y - 0.08, MOUTH_Y - 0.12, q.y))
        return {"jaw": 1.0 - throat, "neck": throat}
    if slot in ("eyes", "pupils"):
        return {"eye" + suffix: 1.0}
    if slot == "lids":
        return {"lid" + suffix: 1.0}
    if slot == "fingers":
        lines = [("finger%d" % i,) + finger_line(side, i) + (FINGERS[i][1], KNUCKLES) for i in range(len(FINGERS))]
        lines.append(("thumb",) + thumb_line(side) + (THUMB_LENGTH, (0.0, 0.5)))
        return line_weights(suffix, lines, p)
    if slot in ("feet", "webs"):
        shin = blend(0.075, 0.11, p.y)
        toe = blend(TOE.z - 0.02, TOE.z + 0.02, p.z) * (1.0 - shin)
        return {"shin" + suffix: shin, "foot" + suffix: 1.0 - shin - toe, "toe" + suffix: toe}
    if part in ("coat__dress", "coat__frock", "coattrim__dress"):
        return body_weights(p, 1.0)
    if part == "coat__tails":
        return body_weights(p, 1.0 if p.z < -0.08 and p.y < 0.62 else 0.0)
    return body_weights(p)


# --- The skeleton ---

def bones():
    listed = [("hips", HIPS, None), ("spine", SPINE, "hips"), ("chest", CHEST, "spine"), ("neck", NECK, "chest"), ("head", HEAD, "neck"),
              ("jaw", big(JAW), "head")]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        listed.append(("eye" + suffix, eye_centre(side), "head"))
        listed.append(("lid" + suffix, eye_centre(side), "head"))
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


def mesh_part(make):
    """A part whose mesh is made whole (and painted) rather than filled into the kit's builder."""
    return lambda _b: make()


# (part, material, shapes, fuse). Parts with `__` in their names are clothes: each its own object.
BODY = [
    ("head", None, mesh_part(head_mesh), None),
    ("jaw", None, mesh_part(jaw_mesh), None),
    ("mouth", MOUTH, mouth, None),
    ("tongue", TONGUE, tongue, None),
    ("eyes", EYEWHITE, eyes, None),
    ("pupils", PUPIL, pupils, None),
    ("lids", SKIN, lids, None),
    ("torso", None, mesh_part(torso_mesh), None),
    ("arms", SKIN, arms, (0.004, 2, 1400)),
    ("hands", SKIN, hands, (0.003, 2, 1000)),
    ("fingers", SKIN, fingers, None),
    ("legs", SKIN, legs, (0.004, 2, 1400)),
    ("feet", SKIN, feet, (0.003, 2, 2400)),
    ("webs", SKIN, webs, None),
]
CLOTHES = [
    ("coat__tails", COAT, coat_tails, (0.005, 3, 5000)),
    ("coattrim__tails", VEST, vest_front, None),
    ("coat__band", COAT, coat_band, (0.005, 3, 4500)),
    ("coattrim__band", TRIM, band_trim, None),
    ("coat__frock", COAT, coat_frock, (0.005, 3, 5000)),
    ("coattrim__frock", TRIM, lambda b: buttons(b, (0.62, 0.70, 0.78), 0.05), None),
    ("coat__jacket", COAT, coat_jacket, (0.005, 3, 4500)),
    ("coattrim__jacket", TRIM, lambda b: buttons(b, (0.64, 0.72), 0.0), None),
    ("coat__dress", DRESS, coat_dress, (0.006, 3, 5000)),
    ("coattrim__dress", COLLAR, dress_frills, (0.006, 2, 2500)),
    ("coat__waistcoat", VEST, coat_waistcoat, (0.005, 3, 3500)),
    ("coattrim__waistcoat", TRIM, lambda b: buttons(b, (0.64, 0.70, 0.76, 0.82), 0.0, 0.018, 0.007), None),
    ("neck__bow", COLLAR, collar_ring, None),
    ("necktie__bow", TIE, bow_tie, None),
    ("neck__cravat", TIE, cravat, None),
    ("neck__scarf", TIE, scarf, (0.005, 2, 1800)),
    ("legs__trousers", TROUSERS, trousers, (0.005, 3, 3500)),
    ("legs__breeches", TROUSERS, breeches, (0.005, 3, 3000)),
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
# (A slot's trimmings are slots of their own: `coattrim`, `necktie`, `hatband`,
# `hatfeather`. FrogLook names the same option for them as for the slot they trim.)
PARTS = BODY + CLOTHES
APART = [part for part, _m, _s, _f in CLOTHES]


def previews(folder, name):
    """Renders the frog in a few turn-outs, from the front and three-quarters."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 700, 900
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    looks = {
        "bare": {},
        "gent": {"coat": "tails", "neck": "bow", "legs": "trousers", "hat": "top"},
        "band": {"coat": "band", "legs": "trousers", "hat": "shako"},
        "lady": {"coat": "dress", "hat": "bonnet"},
        "frock": {"coat": "frock", "neck": "cravat", "legs": "trousers", "hat": "bowler"},
        "police": {"coat": "jacket", "legs": "trousers", "hat": "helmet"},
        "boater": {"coat": "waistcoat", "neck": "scarf", "legs": "breeches", "hat": "boater"},
    }
    trims = {"coattrim": "coat", "necktie": "neck", "hatband": "hat", "hatfeather": "hat"}
    views = [("front", (0, -1, 0.08), (0.0, 0.0, 0.62), 1.45), ("quarter", (0.7, -0.7, 0.25), (0.0, 0.0, 0.62), 1.45)]
    for look, parts in looks.items():
        for obj in bpy.data.objects:
            if "__" in obj.name:
                slot, option = obj.name.split("__")
                slot = slot.split("_")[-1]
                wanted = parts.get(trims.get(slot, slot), "none")
                obj.hide_render = wanted != option
        for view, direction, target, frame in views if look in ("bare", "gent", "lady") else views[1:]:
            offset = Vector(direction).normalized() * 4.0
            camera.data.ortho_scale = frame
            camera.location = Vector(target) + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(folder, "%s_%s_%s.png" % (name, look, view))
            bpy.ops.render.render(write_still=True)
    # and the head close up
    for obj in bpy.data.objects:
        if "__" in obj.name:
            obj.hide_render = True
    for view, direction in (("head", (0.45, -0.85, 0.2)), ("headside", (1, 0, 0.05))):
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = 0.45
        camera.location = Vector((0.0, -0.03, 1.04)) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


kit.export(NAME, bones(), PARTS, weights, MATERIALS, apart=APART)
if PREVIEWS:
    previews(PREVIEWS, NAME)
if os.environ.get("FROG_ONLY_FULL") != "1":
    kit.LOW = True
    kit.export(NAME + "_lo", bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in PARTS], weights, MATERIALS, apart=APART)
