"""Author every Brick animation/pose as a named Action on the rig.

LEGO minifig motion = rigid bone rotations (no smooth skinning), so each state
is a set of pose-bone Euler rotations (degrees, bone-local XYZ) keyed over
1..N frames. Imported by build_brick.py. Action names match CHARACTER-SPEC.md
exactly so render_states.py picks them up.

Bone-local rotation conventions (verified from matrix_local):
  spine/head : rx = lean/nod (+ forward/down), ry = turn, rz = side tilt
  legL/legR  : rx = swing (- forward / + back)
  armL/armR  : rx = swing (- forward/up / + back), rz = raise sideways out
               (armL out = rz negative, armR out = rz positive)
  root       : keyframed location too (z drop for sit / lie)
"""
import bpy, math
from mathutils import Euler, Vector

R = math.radians

# ---------------------------------------------------------------------------
def _new_action(arm, name):
    if name in bpy.data.actions:
        bpy.data.actions.remove(bpy.data.actions[name])
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = act
    return act


def _apply(arm, pose):
    """pose: {bone:(rx,ry,rz)} degrees, and optional 'root_loc':(x,y,z)."""
    loc = pose.get("root_loc")
    for pb in arm.pose.bones:
        rot = pose.get(pb.name, (0, 0, 0))
        pb.rotation_euler = Euler((R(rot[0]), R(rot[1]), R(rot[2])), "XYZ")
        if pb.name == "root":
            pb.location = Vector(loc) if loc else Vector((0, 0, 0))


def _key(arm, frame, pose):
    _apply(arm, pose)
    for pb in arm.pose.bones:
        pb.keyframe_insert("rotation_euler", frame=frame)
        if pb.name == "root":
            pb.keyframe_insert("location", frame=frame)


def still(arm, name, pose):
    _new_action(arm, name)
    _key(arm, 1, pose)
    _key(arm, 2, pose)


def cyc(arm, name, keys, loop=True):
    """keys: [(frame, pose), ...]."""
    _new_action(arm, name)
    for f, pose in keys:
        _key(arm, f, pose)


# ---------------------------------------------------------------------------
# pose vocabulary (reused across states)
# ---------------------------------------------------------------------------
ARMS_DOWN   = {"armL": (0, 0, -7),  "armR": (0, 0, 7)}      # relaxed, slight out
ARMS_STRAIT = {"armL": (0, 0, -2),  "armR": (0, 0, 2)}
HANDS_HIP   = {"armL": (10, 0, -34), "armR": (10, 0, 34)}   # hands on hips
ARMS_UP_V   = {"armL": (0, 0, -148), "armR": (0, 0, 148)}   # celebratory V
ARMS_UP_FWD = {"armL": (-150, 0, -10), "armR": (-150, 0, 10)}
ARMS_OUT    = {"armL": (0, 0, -78), "armR": (0, 0, 78)}     # T / shrug-ish


def _merge(*ds):
    out = {}
    for d in ds:
        out.update(d)
    return out


def author_all(arm):
    # ============================ TIER 0 — core ============================
    still(arm, "idle", ARMS_DOWN)
    still(arm, "happy", _merge({"armL": (0, 0, -14), "armR": (0, 0, 14)},
                               {"head": (-3, 0, 0)}))
    still(arm, "excited", _merge({"armL": (-44, 0, -30), "armR": (-44, 0, 30)},
                                 {"head": (-8, 0, 0), "root_loc": (0, 0, 0.03)}))
    still(arm, "sad", _merge({"armL": (6, 0, -5), "armR": (6, 0, 5)},
                             {"spine": (12, 0, 0), "head": (18, 0, 0)}))

    # walk — side travel, arms+legs counter-swing (8 keys over 1..8, looping)
    sw = 32   # leg swing amplitude
    aw = 22   # arm swing amplitude
    walk_keys = []
    for i in range(9):
        ph = math.sin(2 * math.pi * i / 8)
        walk_keys.append((i + 1, {
            "legL": (-sw * ph, 0, 0), "legR": (sw * ph, 0, 0),
            "armL": (aw * ph, 0, -7), "armR": (-aw * ph, 0, 7),
            "spine": (4, 0, 0),
        }))
    cyc(arm, "walk", walk_keys)

    # run — EXAGGERATED sprint: deep forward lean, big stride, hard-pumping bent
    # arms, pronounced airborne bob. Reads unmistakably as "running", not walking.
    sw, aw = 62, 52
    run_keys = []
    for i in range(7):
        ph = math.sin(2 * math.pi * i / 6)
        run_keys.append((i + 1, {
            "legL": (-sw * ph, 0, 0), "legR": (sw * ph, 0, 0),
            "armL": (-68 + aw * ph, 0, -8), "armR": (-68 - aw * ph, 0, 8),
            "spine": (28, 0, 0),
            "root_loc": (0, 0, 0.10 * abs(ph)),
        }))
    cyc(arm, "run", run_keys)

    # wave — animated: the raised arm swings side to side (a real hello).
    cyc(arm, "wave", [
        (1, _merge({"armL": (-20, 0, -150), "armR": (0, 0, 7)}, {"head": (0, 9, 0)})),
        (2, _merge({"armL": (-20, 0, -108), "armR": (0, 0, 7)}, {"head": (0, 4, 0)})),
        (3, _merge({"armL": (-20, 0, -150), "armR": (0, 0, 7)}, {"head": (0, 9, 0)}))])
    still(arm, "point", {"armL": (-92, 0, -6), "armR": (0, 0, 7)})
    still(arm, "sit", _merge(
        {"legL": (-86, 0, 4), "legR": (-86, 0, -4),
         "armL": (-14, 0, -20), "armR": (-14, 0, 20)},
        {"root_loc": (0, 0, -0.62)}))
    # celebrate — animated: a big two-footed hop with arms in a victory V.
    cyc(arm, "celebrate", [
        (1, _merge(ARMS_UP_V, {"head": (-6, 0, 0), "legL": (-10, 0, 0),
                               "legR": (10, 0, 0), "root_loc": (0, 0, 0.0)})),
        (2, _merge(ARMS_UP_V, {"head": (-14, 0, 0), "legL": (-26, 0, 0),
                               "legR": (-26, 0, 0), "root_loc": (0, 0, 0.42)})),  # bigger hop
        (3, _merge(ARMS_UP_V, {"head": (-6, 0, 0), "legL": (-10, 0, 0),
                               "legR": (10, 0, 0), "root_loc": (0, 0, 0.0)}))])
    # panic — animated: arms thrown overhead, flailing left/right, head shaking.
    cyc(arm, "panic", [
        (1, _merge({"armL": (-150, 0, -34), "armR": (-150, 0, 34)},
                   {"head": (-12, 0, -9), "spine": (-6, 0, 0)})),
        (2, _merge({"armL": (-150, 0, -64), "armR": (-150, 0, 64)},
                   {"head": (-12, 0, 9), "spine": (-6, 0, 0)})),
        (3, _merge({"armL": (-150, 0, -34), "armR": (-150, 0, 34)},
                   {"head": (-12, 0, -9), "spine": (-6, 0, 0)}))])
    still(arm, "thinking", _merge(
        {"armL": (-104, 0, 44), "armR": (0, 0, 7)}, {"head": (10, -10, 4)}))
    still(arm, "sleeping", _merge(
        {"armL": (6, 0, -10), "armR": (6, 0, 10)},
        {"head": (26, 0, 16), "spine": (6, 0, 0)}))

    # ====================== TIER 1 — extended emotions =====================
    still(arm, "neutral", ARMS_STRAIT)
    still(arm, "smiling", ARMS_DOWN)
    still(arm, "laughing", _merge({"armL": (8, 0, -16), "armR": (8, 0, 16)},
                                  {"head": (-16, 0, 0), "spine": (-8, 0, 0)}))
    still(arm, "angry", _merge({"armL": (14, 0, -20), "armR": (14, 0, 20)},
                               {"head": (10, 0, 0), "spine": (8, 0, 0)}))
    still(arm, "surprised", _merge({"armL": (-30, 0, -40), "armR": (-30, 0, 40)},
                                   {"head": (-14, 0, 0)}))
    still(arm, "confused", _merge({"armL": (-20, 0, 30), "armR": (0, 0, 7)},
                                  {"head": (6, 0, 18)}))
    still(arm, "curious", _merge({"armL": (-44, 0, 30), "armR": (0, 0, 7)},
                                 {"head": (6, -12, 9), "spine": (2, 0, 0)}))
    still(arm, "proud", _merge(HANDS_HIP, {"spine": (-8, 0, 0), "head": (-6, 0, 0)}))
    still(arm, "nervous", _merge({"armL": (-40, 0, 38), "armR": (-40, 0, -38)},
                                 {"head": (8, 0, 8)}))
    still(arm, "bored", _merge({"armL": (4, 0, -10), "armR": (-30, 0, 40)},
                               {"head": (14, 0, 22), "spine": (8, 0, 0)}))
    still(arm, "love", _merge({"armL": (-70, 0, 36), "armR": (-70, 0, -36)},
                              {"head": (-6, 0, 0)}))
    still(arm, "crying", _merge({"armL": (-96, 0, 42), "armR": (-96, 0, -42)},
                                {"head": (16, 0, 0), "spine": (8, 0, 0)}))
    still(arm, "embarrassed", _merge({"armL": (-120, 0, 30), "armR": (10, 0, 22)},
                                     {"head": (8, -16, 10)}))
    still(arm, "determined", _merge({"armL": (24, 0, -24), "armR": (24, 0, 24)},
                                    {"spine": (10, 0, 0), "head": (-4, 0, 0)}))
    still(arm, "smug", _merge({"armL": (10, 0, -34), "armR": (-30, 0, 40)},
                              {"head": (-6, 14, 8)}))
    still(arm, "scared", _merge({"armL": (-60, 0, -30), "armR": (-60, 0, 30)},
                                {"spine": (-14, 0, 0), "head": (-12, 0, 0)}))
    still(arm, "relieved", _merge({"armL": (-110, 0, 36), "armR": (6, 0, 10)},
                                  {"spine": (-8, 0, 0), "head": (-8, 0, 6)}))

    # ====================== TIER 2 — gestures =====================
    cyc(arm, "clap", [
        (1, {"armL": (-70, 0, 18), "armR": (-70, 0, -18)}),
        (2, {"armL": (-70, 0, 40), "armR": (-70, 0, -40)}),
        (3, {"armL": (-70, 0, 18), "armR": (-70, 0, -18)})])
    still(arm, "thumbsup", {"armL": (-58, 0, 10), "armR": (0, 0, 7)})
    still(arm, "facepalm", _merge({"armL": (-128, 0, 26), "armR": (0, 0, 7)},
                                  {"head": (12, 0, 0)}))
    still(arm, "shrug", _merge({"armL": (24, 0, -54), "armR": (24, 0, 54)},
                               {"head": (6, 0, 0)}))
    cyc(arm, "nod", [
        (1, {"head": (-8, 0, 0)}), (2, {"head": (16, 0, 0)}),
        (3, {"head": (-8, 0, 0)})])
    cyc(arm, "headshake", [
        (1, {"head": (0, -20, 0)}), (2, {"head": (0, 20, 0)}),
        (3, {"head": (0, -20, 0)})])
    still(arm, "bow", _merge({"armL": (10, 0, -14), "armR": (10, 0, 14)},
                             {"spine": (46, 0, 0), "head": (20, 0, 0),
                              "root_loc": (0, 0, -0.05)}))
    cyc(arm, "dance", [
        (1, _merge({"armL": (-150, 0, -10), "armR": (10, 0, 30)}, {"spine": (0, 14, 0)})),
        (3, _merge({"armL": (10, 0, -30), "armR": (-150, 0, 10)}, {"spine": (0, -14, 0)})),
        (5, _merge({"armL": (-150, 0, -10), "armR": (10, 0, 30)}, {"spine": (0, 14, 0)})),
        (6, _merge({"armL": (10, 0, -30), "armR": (-150, 0, 10)}, {"spine": (0, -14, 0)}))])
    still(arm, "yawn", _merge({"armL": (-150, 0, -20), "armR": (-150, 0, 20)},
                              {"head": (-18, 0, 0)}))
    still(arm, "peace", {"armL": (-150, 0, -16), "armR": (0, 0, 7)})
    # fistpump — animated: the fist drives up and down ("yes!").
    cyc(arm, "fistpump", [
        (1, {"armL": (-150, 0, -6), "armR": (10, 0, 24)}),
        (2, {"armL": (-92, 0, -6), "armR": (10, 0, 24)}),
        (3, {"armL": (-150, 0, -6), "armR": (10, 0, 24)})])
    still(arm, "salute", _merge({"armL": (-118, 0, 14), "armR": (0, 0, 7)},
                                {"head": (-4, 0, 0)}))

    # ====================== TIER 3 — locomotion extras =====================
    cyc(arm, "jump", [
        (1, _merge({"legL": (-26, 0, 0), "legR": (-26, 0, 0),
                    "armL": (24, 0, -10), "armR": (24, 0, 10)},
                   {"root_loc": (0, 0, -0.26)})),                 # deep crouch
        (2, _merge(ARMS_UP_FWD, {"legL": (18, 0, 0), "legR": (18, 0, 0),
                                 "root_loc": (0, 0, 0.55)})),     # airborne — feet off the ground
        (3, _merge({"legL": (-20, 0, 0), "legR": (-20, 0, 0),
                    "armL": (12, 0, -10), "armR": (12, 0, 10)},
                   {"root_loc": (0, 0, -0.08)}))])

    # ====================== TIER 4 — prop / effect poses =====================
    # body poses; props + effects are toggled by render_states.py per state.
    # hairfire — animated: arms flail overhead in alarm while the head shakes.
    cyc(arm, "hairfire", [
        (1, _merge({"armL": (-62, 0, -72), "armR": (-62, 0, 72)},
                   {"head": (-8, 0, -7), "spine": (-4, 0, 0)})),
        (2, _merge({"armL": (-38, 0, -42), "armR": (-38, 0, 42)},
                   {"head": (-8, 0, 7), "spine": (-4, 0, 0)})),
        (3, _merge({"armL": (-62, 0, -72), "armR": (-62, 0, 72)},
                   {"head": (-8, 0, -7), "spine": (-4, 0, 0)}))])
    still(arm, "coffee", _merge({"armL": (-58, 0, 16), "armR": (0, 0, 7)},
                                {"head": (5, 0, 0)}))   # present the mug forward at chest
    still(arm, "idea", _merge({"armL": (0, 0, -150), "armR": (0, 0, 7)},
                              {"head": (-6, 0, 0)}))
    still(arm, "debug", _merge({"armL": (-74, 0, 42), "armR": (0, 0, 7)},
                               {"head": (6, 0, 6), "spine": (6, 0, 0)}))
    still(arm, "fixing", _merge({"armL": (-84, 0, 34), "armR": (10, 0, 18)},
                                {"head": (4, 0, 0)}))
    still(arm, "trophy", _merge(ARMS_UP_V, {"head": (-6, 0, 0)}))
    still(arm, "party", _merge(ARMS_UP_V, {"head": (-4, 0, 0)}))
    still(arm, "raincloud", _merge({"armL": (6, 0, -8), "armR": (6, 0, 8)},
                                   {"head": (14, 0, 0), "spine": (10, 0, 0)}))
    still(arm, "headphones", ARMS_DOWN)
    still(arm, "reading", _merge({"armL": (-48, 0, 22), "armR": (-48, 0, -22)},
                                 {"head": (10, 0, 0)}))
    still(arm, "coding", {"armL": (-74, 0, 24), "armR": (-74, 0, -24)})
    still(arm, "glitch", ARMS_STRAIT)
    still(arm, "loading", _merge(ARMS_DOWN, {"head": (-4, 0, 0)}))
    still(arm, "sweating", _merge({"armL": (10, 0, -16), "armR": (-20, 0, 30)},
                                  {"head": (6, 0, 8), "spine": (6, 0, 0)}))
    # meditate — calm STANDING zen pose (rigid minifig legs can't cross cleanly,
    # so we keep feet planted) with open palms out to the sides + sleepy face.
    still(arm, "meditate", _merge(
        {"armL": (-16, 0, -54), "armR": (-16, 0, 54)},
        {"head": (-2, 0, 0)}))
    # clipboard — hold the board forward at chest (so it faces the camera), other
    # hand resting on it.
    still(arm, "clipboard", {"armL": (-46, 0, 12), "armR": (-64, 0, 20)})

    # reset to idle so the saved file opens on a clean pose
    if "idle" in bpy.data.actions:
        arm.animation_data.action = bpy.data.actions["idle"]
    print(f"  authored {len(bpy.data.actions)} actions")
