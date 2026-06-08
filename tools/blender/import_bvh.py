"""Import a BVH mocap clip and retarget it onto Brick's minifig rig as a named Action.

A local, offline alternative to Mixamo's animation library: grab a free .bvh
(CMU, Truebones, or a Mixamo "Without Skin" export) and bake it onto the existing
`Brick` armature so render_states.py picks it up like any hand-authored Action.

    blender -b blender/work/brick.blend -P blender/import_bvh.py -- \
        --bvh path/to/clip.bvh --name walk --save

Brick has only 7 bones (root/spine/head/armL/armR/legL/legR) so this is an
*approximate* retarget: for each mapped bone we copy the source pose-bone's
LOCAL rotation delta (matrix_basis) per frame, run it through a per-bone axis
remap into Brick's documented convention, and keyframe it. The defaults below
are a sane starting point - calibrate AXIS_REMAP / SRC_BONES for your BVH source
(naming and rest pose vary), then re-run.

Brick bone-local rotation convention (from animate.py):
  spine/head : rx = lean/nod, ry = turn, rz = side tilt
  legL/legR  : rx = swing (- forward / + back)
  armL/armR  : rx = swing (- forward/up / + back), rz = raise sideways out
"""
import bpy, sys, os, math, json
from mathutils import Euler, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Source-bone -> Brick-bone. Lists give fallbacks so one map covers Mixamo
# ("mixamorig:Hips"), CMU ("Hips"/"LeftArm"), and Truebones naming. First match wins.
SRC_BONES = {
    "root":  ["Hips", "mixamorig:Hips", "hip"],
    "spine": ["Spine1", "Spine", "mixamorig:Spine1", "mixamorig:Spine", "chest"],
    "head":  ["Head", "mixamorig:Head", "head"],
    "armL":  ["LeftArm", "mixamorig:LeftArm", "lShldr", "LeftShoulder"],
    "armR":  ["RightArm", "mixamorig:RightArm", "rShldr", "RightShoulder"],
    "legL":  ["LeftUpLeg", "mixamorig:LeftUpLeg", "lThigh", "LeftHip"],
    "legR":  ["RightUpLeg", "mixamorig:RightUpLeg", "rThigh", "RightHip"],
}

# Per Brick bone: which source euler component (and sign) drives Brick's (rx,ry,rz).
# Each entry is (src_axis_index, sign) where src_axis 0=X 1=Y 2=Z, or None to zero it.
# Calibrated against CMU subject-07 walk (data-measured dominant axes): limb
# fore/aft swing lives on source X for legs and source Z for arms. Re-measure for
# a different BVH source with `blender ... -P import_bvh.py` after editing, or pass --map.
AXIS_REMAP = {
    "root":  [None, None, None],          # keep Brick facing the camera (no hip yaw)
    "spine": [(0, 1), None, None],        # subtle fore/aft lean
    "head":  [(0, 1), None, None],        # subtle nod
    "armL":  [(2, 1), None, None],        # arm fore/aft swing  (src Z -> Brick rx)
    "armR":  [(2, 1), None, None],
    "legL":  [(0, 1), None, None],        # leg fore/aft swing  (src X -> Brick rx)
    "legR":  [(0, 1), None, None],
}

# Bones whose rest pose differs between source and Brick (CMU holds arms out
# sideways; Brick's hang down). Transfer only the oscillation about the clip mean
# so the static rest-pose offset is dropped instead of bending the limb through
# the body. GAIN scales the transferred swing per bone.
DYNAMIC = {"armL", "armR", "head"}
GAIN = {"armL": 0.6, "armR": 0.6, "spine": 0.5, "head": 0.5}


def argv():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"bvh": None, "name": None, "scale": 1.0, "step": 1, "cycle": 0,
         "rootmotion": False, "save": False, "map": None}
    i = 0
    while i < len(a):
        k = a[i]
        if k == "--bvh": o["bvh"] = a[i + 1]; i += 2
        elif k == "--name": o["name"] = a[i + 1]; i += 2
        elif k == "--scale": o["scale"] = float(a[i + 1]); i += 2
        elif k == "--step": o["step"] = max(1, int(a[i + 1])); i += 2
        elif k == "--loop": o["cycle"] = max(0, int(a[i + 1])); i += 2
        elif k == "--map": o["map"] = a[i + 1]; i += 2
        elif k == "--root-motion": o["rootmotion"] = True; i += 1
        elif k == "--save": o["save"] = True; i += 1
        else: i += 1
    return o


def detect_period(sig):
    """Frames-per-gait-cycle via autocorrelation of a swing signal."""
    n = len(sig)
    m = sum(sig) / n
    s = [v - m for v in sig]
    lo, hi = max(2, int(n * 0.05)), int(n * 0.6)
    best_lag, best = lo, -1e18
    for lag in range(lo, hi):
        c = sum(s[i] * s[i + lag] for i in range(n - lag)) / (n - lag)
        if c > best:
            best, best_lag = c, lag
    return best_lag


def lerp_sample(series, idx):
    """Linear-interpolate a list of (x,y,z) tuples at fractional index idx (wraps)."""
    n = len(series)
    i0 = int(idx) % n
    i1 = (i0 + 1) % n
    fr = idx - int(idx)
    a, b = series[i0], series[i1]
    return tuple(a[k] + (b[k] - a[k]) * fr for k in range(3))


def find_src_armature(before):
    """The armature object that appeared after the BVH import (not 'Brick')."""
    for o in bpy.data.objects:
        if o.type == "ARMATURE" and o.name != "Brick" and o.name not in before:
            return o
    return None


def resolve(src_arm):
    """Build {brick_bone: src_bone_name} from SRC_BONES against the imported rig."""
    have = {b.name: b.name for b in src_arm.pose.bones}
    lower = {b.name.lower(): b.name for b in src_arm.pose.bones}
    out = {}
    for brick, cands in SRC_BONES.items():
        for c in cands:
            if c in have:
                out[brick] = have[c]; break
            if c.lower() in lower:
                out[brick] = lower[c.lower()]; break
    return out


def main():
    o = argv()
    if not o["bvh"] or not o["name"]:
        print("ERROR: need --bvh <file> and --name <action>"); return
    bvh = o["bvh"] if os.path.isabs(o["bvh"]) else os.path.join(ROOT, o["bvh"])
    if not os.path.exists(bvh):
        print(f"ERROR: no such BVH: {bvh}"); return

    brick = bpy.data.objects.get("Brick")
    if not brick or brick.type != "ARMATURE":
        print("ERROR: no 'Brick' armature in this .blend - open brick.blend"); return

    if o["map"]:
        cfg = json.loads(o["map"]) if o["map"].strip().startswith("{") \
            else json.load(open(o["map"]))
        SRC_BONES.update(cfg.get("bones", {}))
        AXIS_REMAP.update(cfg.get("remap", {}))

    before = {x.name for x in bpy.data.objects}
    bpy.ops.import_anim.bvh(filepath=bvh, global_scale=1.0,
                            rotate_mode="NATIVE", axis_forward="-Z", axis_up="Y")
    src = find_src_armature(before)
    if not src:
        print("ERROR: BVH import produced no armature"); return

    bmap = resolve(src)
    missing = [b for b in SRC_BONES if b not in bmap]
    print(f"mapped {len(bmap)}/{len(SRC_BONES)} bones: {bmap}")
    if missing:
        print(f"  WARN unmapped (left at rest): {missing} - "
              f"source bones are {[b.name for b in src.pose.bones][:12]}...")

    sc = bpy.context.scene
    f0, f1 = (int(x) for x in src.animation_data.action.frame_range)
    print(f"source frames {f0}..{f1}")

    # fresh Action on Brick (mirror animate.py: fake user so it survives save)
    if o["name"] in bpy.data.actions:
        bpy.data.actions.remove(bpy.data.actions[o["name"]])
    act = bpy.data.actions.new(o["name"]); act.use_fake_user = True
    if not brick.animation_data:
        brick.animation_data_create()
    brick.animation_data.action = act
    bpy.context.view_layer.objects.active = brick

    spb = {pb.name: pb for pb in src.pose.bones}
    frames = list(range(f0, f1 + 1, o["step"]))

    # pass 1: sample every mapped source bone's local euler + hip translation
    samp = {b: [] for b in bmap}          # samp[brick_bone] = [(x,y,z) per frame]
    hip = []
    for f in frames:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        for brick_bone, src_name in bmap.items():
            e = spb[src_name].matrix_basis.to_euler("XYZ")
            samp[brick_bone].append((e.x, e.y, e.z))
        hip.append(spb[bmap["root"]].matrix_basis.translation.copy()
                   if "root" in bmap else Vector())

    # per-bone mean (only used for DYNAMIC bones, to drop the rest-pose offset)
    mean = {b: tuple(sum(c) / len(s) for c in zip(*s)) for b, s in samp.items()}

    def remapped(brick_bone, sv):
        """source euler -> Brick (rx,ry,rz) via DYNAMIC/AXIS_REMAP/GAIN."""
        if brick_bone in DYNAMIC:
            m = mean[brick_bone]
            sv = (sv[0] - m[0], sv[1] - m[1], sv[2] - m[2])
        rm = AXIS_REMAP.get(brick_bone, [(0, 1), (1, 1), (2, 1)])
        g = GAIN.get(brick_bone, 1.0) * o["scale"]
        rot = [0.0, 0.0, 0.0]
        for i, mp in enumerate(rm):
            if mp is not None:
                rot[i] = sv[mp[0]] * mp[1] * g
        return rot

    # build the output frame schedule: either the raw clip, or one detected gait
    # cycle resampled to N+1 phases (phase N == phase 0) so it loops seamlessly.
    if o["cycle"] and "legL" in bmap:
        drive = [remapped("legL", samp["legL"][i])[0] for i in range(len(frames))]
        period = detect_period(drive)
        start = max(range(period), key=lambda i: drive[i])   # begin at max swing
        N = o["cycle"]
        schedule = [start + (period * k / N) for k in range(N + 1)]
        print(f"gait period {period} frames; resampled to {N}-frame loop "
              f"(start idx {start})")
    else:
        schedule = list(range(len(frames)))

    # pass 2: sample (interpolated for cycle mode) -> remap -> keyframe
    for n, idx in enumerate(schedule):
        out_f = n + 1
        for brick_bone, src_name in bmap.items():
            sv = lerp_sample(samp[brick_bone], idx) if o["cycle"] \
                else samp[brick_bone][int(idx)]
            rot = remapped(brick_bone, sv)
            pb = brick.pose.bones[brick_bone]
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = Euler(rot, "XYZ")
            pb.keyframe_insert("rotation_euler", frame=out_f)
            if brick_bone == "root" and o["rootmotion"]:
                d = (lerp_sample([(v.x, v.y, v.z) for v in hip], idx) if o["cycle"]
                     else (hip[int(idx)].x, hip[int(idx)].y, hip[int(idx)].z))
                pb.location = Vector(d) * o["scale"]
                pb.keyframe_insert("location", frame=out_f)
    out_f = len(schedule) + 1

    # clean up the imported source rig; keep only the baked Brick Action
    bpy.data.objects.remove(src, do_unlink=True)
    print(f"BAKED Action '{o['name']}'  ({out_f - 1} frames) onto Brick")

    if o["save"]:
        bpy.ops.wm.save_mainfile()
        print(f"SAVED {bpy.data.filepath}")


main()
