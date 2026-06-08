"""Brick's swappable faces + Tier-4 props & effects.

All objects are built hidden (hide_render/hide_viewport=True) except the
neutral face, and parented to a bone (head / armL / armR / spine) so they ride
the posed body. render_states.py shows the right face + props per state using
the maps in brick_states.py.

build_faces()  -> list of (objname, bone)
build_props()  -> list of (objname, bone)
"""
import bpy, bmesh, math
from mathutils import Vector
import bricklib as L

R = math.radians
FY, EZ, HR = L.FACE_Y, L.EYE_Z, L.HEAD_R
HEAD_TOP = L.HEAD_Z1
WL, WR = L.WRIST["L"], L.WRIST["R"]


def _mat(n, c, **kw):
    return L.material(n, L.PALETTE[c] if c in L.PALETTE else c, **kw)


# ===========================================================================
# FACES  — each face is one joined object "Face_<name>" of black decals
# ===========================================================================
def _dot(bm, x, z, r=0.058, sy=0.42):
    g = bmesh.new()
    bmesh.ops.create_uvsphere(g, u_segments=12, v_segments=8, radius=r)
    bmesh.ops.scale(g, verts=g.verts, vec=(1, sy, 1.1))
    bmesh.ops.translate(g, verts=g.verts, vec=(x, FY, z))
    _append(bm, g)

def _bar(bm, x, z, w, h, ang=0):
    g = bmesh.new()
    bmesh.ops.create_cube(g, size=1.0)
    bmesh.ops.scale(g, verts=g.verts, vec=(w, 0.05, h))
    if ang:
        bmesh.ops.rotate(g, verts=g.verts, cent=(0, 0, 0),
                         matrix=__import__("mathutils").Matrix.Rotation(R(ang), 3, "Y"))
    bmesh.ops.translate(g, verts=g.verts, vec=(x, FY, z))
    _append(bm, g)

def _arc(bm, cx, cz, major, minor, arc_deg, start_deg):
    n = max(3, int(20 * arc_deg / 360) + 1)
    sm = 8
    rings = []
    for i in range(n):
        a = R(start_deg + arc_deg * i / (n - 1))
        cpt = Vector((cx + major * math.cos(a), FY, cz + major * math.sin(a)))
        tangent = Vector((-math.sin(a), 0, math.cos(a)))
        nrm = tangent.cross(Vector((0, 1, 0))).normalized()
        binorm = tangent.cross(nrm).normalized()
        ring = []
        for j in range(sm):
            b = R(360 * j / sm)
            off = nrm * (minor * math.cos(b)) + binorm * (minor * math.sin(b))
            ring.append(bm.verts.new(cpt + off))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for j in range(sm):
            bm.faces.new((rings[i][j], rings[i][(j+1) % sm],
                          rings[i+1][(j+1) % sm], rings[i+1][j]))

def _ring(bm, cx, cz, major, minor):
    _arc(bm, cx, cz, major, minor, 350, 0)

def _append(bm, g):
    me = bpy.data.meshes.new("_tmp")
    g.to_mesh(me); g.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)


def _face(name, build):
    bm = bmesh.new()
    build(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    black = _mat("FaceBlack", "black", rough=0.25)
    ob = L._finish(name, bm, black, smooth=True)
    return ob


def build_faces():
    faces = []

    def neutral(bm):
        _dot(bm, 0.15, EZ); _dot(bm, -0.15, EZ)
        _arc(bm, 0, EZ - 0.20, 0.17, 0.028, 110, 215)
    def happy(bm):                      # arched eyes + big open smile
        _arc(bm, 0.15, EZ - 0.02, 0.07, 0.022, 150, 200)
        _arc(bm, -0.15, EZ - 0.02, 0.07, 0.022, 150, 200)
        _arc(bm, 0, EZ - 0.17, 0.20, 0.03, 150, 195)
    def sad(bm):                        # dots + frown + worried brows
        _dot(bm, 0.15, EZ); _dot(bm, -0.15, EZ)
        _arc(bm, 0, EZ - 0.34, 0.17, 0.028, 110, 35)
        _bar(bm, 0.18, EZ + 0.11, 0.10, 0.02, -22)
        _bar(bm, -0.18, EZ + 0.11, 0.10, 0.02, 22)
    def angry(bm):                      # dots + frown + down brows
        _dot(bm, 0.15, EZ); _dot(bm, -0.15, EZ)
        _arc(bm, 0, EZ - 0.34, 0.15, 0.028, 100, 40)
        _bar(bm, 0.17, EZ + 0.10, 0.13, 0.022, 24)
        _bar(bm, -0.17, EZ + 0.10, 0.13, 0.022, -24)
    def surprised(bm):                  # wide eyes + O mouth
        _dot(bm, 0.17, EZ + 0.01, r=0.07, sy=0.5)
        _dot(bm, -0.17, EZ + 0.01, r=0.07, sy=0.5)
        _ring(bm, 0, EZ - 0.20, 0.07, 0.025)
    def sleepy(bm):                     # closed eyes + small mouth
        _arc(bm, 0.15, EZ + 0.02, 0.07, 0.022, 140, 200)
        _arc(bm, -0.15, EZ + 0.02, 0.07, 0.022, 140, 200)
        _arc(bm, 0, EZ - 0.19, 0.09, 0.024, 90, 225)
    def thinking(bm):                   # eyes glance up, cocked brow + furrow, FLAT mouth
        _dot(bm, 0.15, EZ + 0.04); _dot(bm, -0.15, EZ + 0.04)
        _bar(bm, -0.17, EZ + 0.16, 0.13, 0.022, 16)   # one raised brow
        _bar(bm, 0.02, EZ + 0.10, 0.022, 0.085, 0)    # furrow crease between brows
        _bar(bm, 0.0, EZ - 0.20, 0.13, 0.024, 0)      # straight, unsmiling mouth
    def curious(bm):                    # wide eyes, one raised brow, tiny "o"
        _dot(bm, 0.15, EZ, r=0.07, sy=0.5); _dot(bm, -0.15, EZ, r=0.07, sy=0.5)
        _bar(bm, -0.17, EZ + 0.15, 0.12, 0.022, 20)   # one brow up
        _ring(bm, 0, EZ - 0.20, 0.05, 0.022)          # small curious "o"
    def worried(bm):                    # dots + inner-up brows + small frown
        _dot(bm, 0.15, EZ); _dot(bm, -0.15, EZ)
        _bar(bm, 0.16, EZ + 0.12, 0.11, 0.02, -28)    # inner-up worried brows
        _bar(bm, -0.16, EZ + 0.12, 0.11, 0.02, 28)
        _arc(bm, 0, EZ - 0.32, 0.13, 0.026, 80, 50)   # slight frown
    def dead(bm):                       # big X_X eyes + flat mouth (error / wiped out)
        for ex in (0.16, -0.16):
            _bar(bm, ex, EZ, 0.16, 0.032, 45)
            _bar(bm, ex, EZ, 0.16, 0.032, -45)
        _bar(bm, 0, EZ - 0.21, 0.15, 0.026, 0)
    def wink(bm):                       # one open eye + one winking ^ + smirk
        _dot(bm, 0.15, EZ)
        _arc(bm, -0.15, EZ + 0.02, 0.07, 0.022, 150, 200)
        _arc(bm, 0.02, EZ - 0.17, 0.18, 0.03, 130, 200)   # asymmetric smirk
    def laughing(bm):                   # arched eyes + BIG open mouth
        _arc(bm, 0.15, EZ - 0.02, 0.07, 0.022, 150, 200)
        _arc(bm, -0.15, EZ - 0.02, 0.07, 0.022, 150, 200)
        _dot(bm, 0, EZ - 0.24, r=0.15, sy=0.9)            # wide-open laugh

    for nm, fn in [("neutral", neutral), ("happy", happy), ("sad", sad),
                   ("angry", angry), ("surprised", surprised), ("sleepy", sleepy),
                   ("thinking", thinking), ("curious", curious), ("worried", worried),
                   ("dead", dead), ("wink", wink), ("laughing", laughing)]:
        _face(f"Face_{nm}", fn)
        faces.append((f"Face_{nm}", "head"))
    # love: heart eyes (pink) + open smile
    bm = bmesh.new(); happy(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = L._finish("Face_love", bm, _mat("FaceBlack", "black", rough=0.25), smooth=True)
    for x in (0.15, -0.15):
        L.sphere(f"_heart{x}", 0.095, (x, FY - 0.005, EZ + 0.01),
                 _mat("HeartPink", "pink", emit="#E86A9A", emit_str=1.6),
                 scale=(1, 0.4, 1))
    L.join_into("Face_love", ["Face_love", "_heart0.15", "_heart-0.15"])
    faces.append(("Face_love", "head"))
    return faces


# ===========================================================================
# PROPS & EFFECTS
# ===========================================================================
def build_props():
    props = []   # (objname, bone)

    yellow = _mat("Yellow", "yellow")
    # --- coffee mug (armL hand) — a big-but-clean cup held in front (the pose
    # "coffee" in animate.py presents it forward at chest height so it never
    # overlaps the face). ---
    mugC = (WL.x, WL.y - 0.05)
    L.cyl("Mug", 0.20, WL.z + 0.02, WL.z + 0.44, _mat("MugWhite", "white"),
          seg=26, center=mugC)
    L.arc_tube("MugHandle", 0.15, 0.038, 250, _mat("MugWhite", "white"),
               plane="XZ", center=(WL.x + 0.21, WL.y - 0.05, WL.z + 0.22), start_deg=270)
    L.cyl("MugCoffee", 0.165, WL.z + 0.39, WL.z + 0.42, _mat("Coffee", "#3A2417"),
          seg=24, center=mugC)
    L.join_into("Mug", ["Mug", "MugHandle", "MugCoffee"])
    _steam("MugSteam", Vector((WL.x, WL.y - 0.05, WL.z + 0.54)))
    props += [("Mug", "armL"), ("MugSteam", "armL")]

    # --- lightbulb idea (above head, centred) — bigger, brighter ---
    L.sphere("Bulb", 0.27, (0, FY - 0.10, HEAD_TOP + 0.46),
             _mat("BulbGlow", "white", emit="#FFF1B0", emit_str=4.5))
    L.cyl("BulbBase", 0.13, 0, 0.12, _mat("Steel", "steel", metallic=0.8),
          seg=16, center=(0, FY - 0.10))
    L.PARTS["BulbBase"].location = (0, 0, HEAD_TOP + 0.22)
    L.join_into("Bulb", ["Bulb", "BulbBase"])
    props += [("Bulb", "head")]

    # --- magnifying glass (armL) debug ---
    L.torus("MagRing", 0.17, 0.034, (WL.x, WL.y - 0.10, WL.z + 0.22),
            _mat("Steel", "steel", metallic=0.8), plane="XZ")
    L.sphere("MagLens", 0.15, (WL.x, WL.y - 0.10, WL.z + 0.22),
             _mat("Glass", "skyblue", rough=0.05, alpha=0.45), scale=(1, 0.25, 1))
    L.tube_between("MagGrip", (WL.x - 0.06, WL.y - 0.10, WL.z + 0.07),
                   (WL.x - 0.17, WL.y - 0.10, WL.z - 0.10), 0.035,
                   _mat("MagGrip", "dgrey"))
    L.join_into("MagRing", ["MagRing", "MagLens", "MagGrip"])
    props += [("MagRing", "armL")]

    # --- wrench (armL) fixing ---
    L.box("WrenchBar", WL.x, WL.y - 0.06, WL.z + 0.14, 0.06, 0.06, 0.44,
          _mat("Steel", "steel", metallic=0.85))
    L.torus("WrenchHead", 0.10, 0.030, (WL.x, WL.y - 0.06, WL.z + 0.40),
            _mat("Steel", "steel", metallic=0.85), plane="XZ")
    L.join_into("WrenchBar", ["WrenchBar", "WrenchHead"])
    props += [("WrenchBar", "armL")]

    # --- trophy (held overhead, parent head) ---
    cupc = (0, FY - 0.22, HEAD_TOP + 0.18)
    L.cone("TrophyCup", 0.18, 0.22, cupc[2], cupc[2] + 0.24,
           _mat("Gold", "gold", metallic=0.9, rough=0.2))
    L.PARTS["TrophyCup"].location = (cupc[0], cupc[1], 0)
    L.cyl("TrophyStem", 0.04, cupc[2] - 0.14, cupc[2],
          _mat("Gold", "gold", metallic=0.9, rough=0.2), seg=12,
          center=(cupc[0], cupc[1]))
    L.box("TrophyBase", cupc[0], cupc[1], cupc[2] - 0.17, 0.22, 0.22, 0.07,
          _mat("Gold", "gold", metallic=0.9, rough=0.2))
    for hx in (0.20, -0.20):   # little handles
        L.arc_tube(f"_th{hx}", 0.07, 0.02, 200, _mat("Gold", "gold", metallic=0.9),
                   plane="XZ", center=(hx, cupc[1], cupc[2] + 0.10), start_deg=290)
    L.join_into("TrophyCup", ["TrophyCup", "TrophyStem", "TrophyBase", "_th0.2", "_th-0.2"])
    props += [("TrophyCup", "head")]

    # --- party hat (head) + confetti ---
    L.cone("PartyHat", 0.22, 0.0, HEAD_TOP + 0.0, HEAD_TOP + 0.46,
           _mat("HatPink", "pink"))
    L.PARTS["PartyHat"].location = (0.05, 0.05, 0)
    L.sphere("PartyPom", 0.06, (0.05, 0.05, HEAD_TOP + 0.48),
             _mat("PomYellow", "yellow"))
    L.join_into("PartyHat", ["PartyHat", "PartyPom"])
    props += [("PartyHat", "head")]
    _confetti("Confetti", "spine")
    props += [("Confetti", "spine")]

    # --- raincloud (above head) ---
    cloudz = HEAD_TOP + 0.52
    for i, (dx, dy, r) in enumerate([(0, 0, 0.20), (0.22, 0, 0.15),
                                     (-0.22, 0, 0.15), (0.08, -0.12, 0.14)]):
        L.sphere(f"_cl{i}", r, (dx, FY - 0.10 + dy, cloudz), _mat("Cloud", "grey"))
    L.join_into("_cl0", ["_cl0", "_cl1", "_cl2", "_cl3"], rename="Raincloud")
    for i in range(5):
        x = -0.20 + i * 0.10
        L.box(f"_rain{i}", x, FY - 0.10, cloudz - 0.30, 0.018, 0.018, 0.12,
              _mat("Rain", "skyblue", emit="#7FB4E8", emit_str=0.6))
    L.join_into("Raincloud", ["Raincloud"] + [f"_rain{i}" for i in range(5)])
    props += [("Raincloud", "head")]

    # --- headphones (head): band over the top + ear cups at the sides ---
    headc = (L.HEAD_Z0 + L.HEAD_Z1) / 2
    L.arc_tube("HpBand", HR + 0.07, 0.04, 180, _mat("Hp", "dgrey"),
               plane="XZ", center=(0, 0.02, headc - 0.02), start_deg=0)
    for s, x in (("L", HR + 0.05), ("R", -(HR + 0.05))):
        L.sphere(f"HpCup{s}", 0.12, (x, 0, headc - 0.05), _mat("Hp", "dgrey"),
                 scale=(0.4, 1, 1.1))
    L.join_into("HpBand", ["HpBand", "HpCupL", "HpCupR"], rename="Headphones")
    props += [("Headphones", "head")]

    # --- book (between hands) reading — a BIG open book ---
    bz = L.TORSO_Z0 + 0.46      # chest height, matches the reading hand pose
    by = FY - 0.30
    L.box_rot("BookL", 0.19, by, bz, 0.38, 0.06, 0.50, _mat("BookCover", "red"), rz=-14)
    L.box_rot("BookR", -0.19, by, bz, 0.38, 0.06, 0.50, _mat("BookCover", "red"), rz=14)
    L.box_rot("BookPgL", 0.19, by - 0.03, bz + 0.006, 0.34, 0.04, 0.46, _mat("Paper", "white"), rz=-14)
    L.box_rot("BookPgR", -0.19, by - 0.03, bz + 0.006, 0.34, 0.04, 0.46, _mat("Paper", "white"), rz=14)
    L.join_into("BookL", ["BookL", "BookR", "BookPgL", "BookPgR"], rename="Book")
    props += [("Book", "spine")]

    # --- laptop (in front, coding) parent spine ---
    lz = L.TORSO_Z0 + 0.18
    L.box("LapBase", 0, FY - 0.34, lz, 0.54, 0.34, 0.04, _mat("Lap", "dgrey"))
    L.box_rot("LapScreen", 0, FY - 0.50, lz + 0.18, 0.54, 0.04, 0.34,
              _mat("LapScr", "skyblue", emit="#9FD0FF", emit_str=1.2), rx=-22)
    L.join_into("LapBase", ["LapBase", "LapScreen"], rename="Laptop")
    props += [("Laptop", "spine")]

    # --- clipboard (armL) — bigger board facing forward ---
    L.box("Clip", WL.x + 0.02, WL.y - 0.16, WL.z + 0.18, 0.36, 0.03, 0.48,
          _mat("ClipBrown", "#7A5A33"))
    L.box("ClipPaper", WL.x + 0.02, WL.y - 0.18, WL.z + 0.20, 0.30, 0.02, 0.40,
          _mat("Paper", "white"))
    L.box("ClipClip", WL.x + 0.02, WL.y - 0.19, WL.z + 0.41, 0.12, 0.02, 0.06,
          _mat("Steel", "steel", metallic=0.8))
    L.join_into("Clip", ["Clip", "ClipPaper", "ClipClip"])
    props += [("Clip", "armL")]

    # --- hourglass (above head, centred) loading ---
    hz = HEAD_TOP + 0.16
    L.cone("HgTop", 0.16, 0.01, hz + 0.16, hz + 0.32, _mat("Glass", "skyblue",
           rough=0.05, alpha=0.4))
    L.cone("HgBot", 0.01, 0.16, hz, hz + 0.16, _mat("Glass", "skyblue",
           rough=0.05, alpha=0.4))
    for nm in ("HgTop", "HgBot"):
        L.PARTS[nm].location = (0, FY - 0.10, 0)
    L.box("HgFrameT", 0, FY - 0.10, hz + 0.32, 0.36, 0.05, 0.05, _mat("Gold", "gold", metallic=0.9))
    L.box("HgFrameB", 0, FY - 0.10, hz, 0.36, 0.05, 0.05, _mat("Gold", "gold", metallic=0.9))
    L.join_into("HgTop", ["HgTop", "HgBot", "HgFrameT", "HgFrameB"], rename="Hourglass")
    props += [("Hourglass", "head")]

    # --- hairfire (BIG cartoon flames roaring up off the hair) ---
    # Exaggerated on purpose: tall, chunky, bright tongues that clearly read as
    # "this minifig is ON FIRE" even at thumbnail size (the old ones were too small
    # and got lost in the hair).
    # Saturated orange/red/yellow with MODERATE emission so the colour reads as fire
    # (very high emission blooms out to pink/white in EEVEE).
    flameR = _mat("FlameR", "#E01505", emit="#E01505", emit_str=2.6)
    flame = _mat("Flame", "#FF6A0A", emit="#FF6A0A", emit_str=3.0)
    flameY = _mat("FlameY", "#FFC21E", emit="#FFC21E", emit_str=4.0)
    fnames = []
    # (dx, dy, height, radius) — a wide fan of tall tongues, center tallest. Heights
    # tuned to stay just inside the 512x640 frame (no clipped tips).
    for i, (dx, dy, h, r) in enumerate([
            (0.0, 0.02, 0.86, 0.22), (0.27, 0.0, 0.66, 0.17),
            (-0.27, 0.03, 0.70, 0.17), (0.15, -0.12, 0.58, 0.14),
            (-0.15, -0.10, 0.54, 0.13), (0.40, 0.02, 0.44, 0.11),
            (-0.40, 0.02, 0.46, 0.11)]):
        # outer red base, mid orange, inner yellow core — layered for depth.
        L.cone(f"_flo{i}", r, 0.0, HEAD_TOP - 0.10, HEAD_TOP + h, flameR)
        L.PARTS[f"_flo{i}"].location = (dx, dy, 0)
        L.cone(f"_fl{i}", r * 0.72, 0.0, HEAD_TOP - 0.06, HEAD_TOP + h * 0.92, flame)
        L.PARTS[f"_fl{i}"].location = (dx, dy, 0)
        L.cone(f"_flc{i}", r * 0.42, 0.0, HEAD_TOP + 0.02, HEAD_TOP + h * 0.72, flameY)
        L.PARTS[f"_flc{i}"].location = (dx, dy, 0)
        fnames += [f"_flo{i}", f"_fl{i}", f"_flc{i}"]
    L.join_into(fnames[0], fnames, rename="Hairfire")
    props += [("Hairfire", "head")]

    # --- tears (crying): blue drops welling from under each eye ---
    tear = _mat("Tear", "skyblue", emit="#BFE4FF", emit_str=0.7, alpha=0.92)
    L.sphere("_tr0", 0.055, (0.16, FY + 0.01, EZ - 0.12), tear, scale=(1, 1, 1.6))
    L.sphere("_tr1", 0.05, (0.18, FY + 0.03, EZ - 0.34), tear, scale=(1, 1, 1.5))
    L.sphere("_tr2", 0.055, (-0.16, FY + 0.01, EZ - 0.12), tear, scale=(1, 1, 1.6))
    L.sphere("_tr3", 0.05, (-0.18, FY + 0.03, EZ - 0.34), tear, scale=(1, 1, 1.5))
    L.join_into("_tr0", ["_tr0", "_tr1", "_tr2", "_tr3"], rename="Tears")
    props += [("Tears", "head")]

    # --- exclaim "!" (attention / alert) floating above head ---
    exc = _mat("Excl", "red", emit="#FF3B30", emit_str=2.5)
    L.box("_ex0", 0, FY - 0.10, HEAD_TOP + 0.66, 0.12, 0.05, 0.36, exc)
    L.sphere("_ex1", 0.08, (0, FY - 0.10, HEAD_TOP + 0.36), exc)
    L.join_into("_ex0", ["_ex0", "_ex1"], rename="Exclaim")
    props += [("Exclaim", "head")]

    # --- question "?" (confused) floating above head ---
    qm = _mat("Quest", "yellow", emit="#FFD24A", emit_str=2.5)
    L.arc_tube("_q0", 0.14, 0.04, 250, qm, plane="XZ",
               center=(0, FY - 0.10, HEAD_TOP + 0.66), start_deg=300)
    L.box("_q1", 0.0, FY - 0.10, HEAD_TOP + 0.48, 0.06, 0.05, 0.14, qm)
    L.sphere("_q2", 0.07, (0.0, FY - 0.10, HEAD_TOP + 0.30), qm)
    L.join_into("_q0", ["_q0", "_q1", "_q2"], rename="Question")
    props += [("Question", "head")]

    # --- big heart (love) popping out above the head ---
    hmat = _mat("BigHeart", "#FF3B6B", emit="#FF3B6B", emit_str=2.2)
    hz = HEAD_TOP + 0.36   # kept low enough that the heart's top stays in-frame
    L.sphere("_bh0", 0.16, (-0.13, FY - 0.12, hz + 0.07), hmat)
    L.sphere("_bh1", 0.16, (0.13, FY - 0.12, hz + 0.07), hmat)
    L.cone("_bh2", 0.0, 0.28, hz - 0.34, hz + 0.11, hmat)   # point-down bottom
    L.PARTS["_bh2"].location = (0, FY - 0.12, 0)
    L.join_into("_bh0", ["_bh0", "_bh1", "_bh2"], rename="BigHeart")
    props += [("BigHeart", "head")]

    # --- lightning bolt (glitch) zig-zagging beside the head ---
    bolt = _mat("Bolt", "yellow", emit="#FFE34A", emit_str=3.5)
    L.box_rot("_b0", 0.34, FY - 0.06, HEAD_TOP + 0.34, 0.09, 0.05, 0.30, bolt, ry=30)
    L.box_rot("_b1", 0.40, FY - 0.06, HEAD_TOP + 0.10, 0.09, 0.05, 0.26, bolt, ry=-30)
    L.join_into("_b0", ["_b0", "_b1"], rename="Bolt")
    props += [("Bolt", "head")]

    # --- sweat drops (temple) ---
    drop = _mat("Sweat", "skyblue", emit="#BFE4FF", emit_str=0.5, alpha=0.85)
    L.sphere("_sw0", 0.05, (HR - 0.02, FY + 0.02, EZ + 0.18), drop, scale=(1, 1, 1.4))
    L.sphere("_sw1", 0.035, (HR + 0.04, FY + 0.05, EZ + 0.02), drop, scale=(1, 1, 1.4))
    L.join_into("_sw0", ["_sw0", "_sw1"], rename="Sweat")
    props += [("Sweat", "head")]

    # --- zzz (sleeping) ---
    zmat = _mat("Zzz", "skyblue", emit="#9FD0FF", emit_str=1.0)
    for i, (s, dz) in enumerate([(0.07, 0), (0.10, 0.16), (0.13, 0.34)]):
        _zletter(f"_z{i}", (0.34 + i * 0.06, FY + 0.04, HEAD_TOP + 0.10 + dz), s, zmat)
    L.join_into("_z0", ["_z0", "_z1", "_z2"], rename="Zzz")
    props += [("Zzz", "head")]

    # --- sparkles (excited) ---
    spk = _mat("Spark", "gold", emit="#FFE680", emit_str=3.0)
    snames = []
    import random
    pts = [(0.4, 0.1, HEAD_TOP), (-0.4, 0.0, HEAD_TOP - 0.1), (0.5, 0.0, EZ),
           (-0.48, 0.0, EZ + 0.2), (0.0, 0.0, HEAD_TOP + 0.25)]
    for i, p in enumerate(pts):
        _spark(f"_sp{i}", (p[0], FY + 0.02, p[2]), 0.05, spk)
        snames.append(f"_sp{i}")
    L.join_into("_sp0", snames, rename="Sparkles")
    props += [("Sparkles", "head")]

    return props


# ---- small effect builders -------------------------------------------------
def _steam(name, base):
    m = _mat("Steam", "white", emit="#FFFFFF", emit_str=0.4, alpha=0.5)
    parts = []
    for i in range(3):
        L.sphere(f"{name}_{i}", 0.04 + 0.01 * i, (base.x, base.y, base.z + i * 0.10),
                 m, scale=(1, 1, 1.3))
        parts.append(f"{name}_{i}")
    L.join_into(parts[0], parts, rename=name)

def _confetti(name, bone):
    cols = ["red", "yellow", "teal", "pink", "skyblue", "green", "gold"]
    import math as _m
    parts = []
    for i in range(22):
        ang = i * 2.39998
        rad = 0.35 + 0.5 * (i / 22)
        x = rad * _m.cos(ang)
        z = L.TORSO_Z1 + 0.2 + rad * _m.sin(ang) * 0.8
        c = cols[i % len(cols)]
        L.box_rot(f"{name}_{i}", x, FY - 0.10, z, 0.055, 0.02, 0.055,
                  _mat(f"Conf{c}", c, emit=L.PALETTE[c], emit_str=0.8),
                  rx=i * 33, ry=i * 21, rz=i * 12)
        parts.append(f"{name}_{i}")
    L.join_into(parts[0], parts, rename=name)

def _zletter(name, c, s, mat):
    # a little "Z" from 3 bars
    L.box(name + "a", c[0], c[1], c[2] + s, s * 1.2, 0.03, s * 0.28, mat)
    L.box(name + "b", c[0], c[1], c[2] - s, s * 1.2, 0.03, s * 0.28, mat)
    L.box_rot(name + "c", c[0], c[1], c[2], s * 0.28, 0.03, s * 2.2, mat, ry=38)
    L.join_into(name + "a", [name + "a", name + "b", name + "c"], rename=name)

def _spark(name, c, s, mat):
    L.box(name + "h", c[0], c[1], c[2], s * 2, 0.03, s * 0.4, mat)
    L.box(name + "v", c[0], c[1], c[2], s * 0.4, 0.03, s * 2, mat)
    L.join_into(name + "h", [name + "h", name + "v"], rename=name)
