"""Build Brick — the LEGO-minifigure mascot — from scratch in Blender, headless.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P blender/build_brick.py

Models the character on-model per BRICK.md (palette from the actual
reference/sprites/hero.png: yellow head+hands, teal jacket+arms, brown swept
hair, BLUE legs, RED feet, black face print), rigs him with a minifig armature
(rigid bone-parented parts — the correct, LEGO-accurate deformation style),
builds swappable faces + Tier-4 props/effects (props.py), bakes a front camera
+ 3-point light rig, authors every animation/pose Action (animate.py), and
saves blender/work/brick.blend.

Re-runnable: wipes the scene and rebuilds from nothing every time.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bricklib as L
from bricklib import (PARTS, material, prism, cyl, tube_between, arc_tube,
                      sphere, box, PALETTE, rgb)
from bricklib import (HEAD_R, HEAD_Z0, HEAD_Z1, TORSO_Z0, TORSO_Z1, NECK_Z1,
                      SH_Z, HIP_Z, LEG_HX, FOOT_Z1, WRIST, SHOULDER,
                      FACE_Y, EYE_Z)
import props as P
import animate

# save the rig next to the scripts (committed) so `make brick` can rebuild it
BLEND = os.path.join(os.path.dirname(os.path.abspath(__file__)), "brick.blend")


def wipe():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for blk in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures,
                bpy.data.actions, bpy.data.cameras, bpy.data.lights):
        for d in list(blk):
            blk.remove(d)
    PARTS.clear()
    L.MATS.clear()


# ----------------------------------------------------------------------------
def build_model():
    m_yellow = material("Yellow", PALETTE["yellow"])
    m_teal   = material("Teal",   PALETTE["teal"])
    m_brown  = material("Brown",  PALETTE["brown"], rough=0.5)
    m_blue   = material("Blue",   PALETTE["blue"])
    m_red    = material("Red",    PALETTE["red"])
    m_black  = material("Black",  PALETTE["black"], rough=0.25)
    m_tan    = material("Tan",    PALETTE["tan"])

    # head + neck
    cyl("Head", HEAD_R, HEAD_Z0, HEAD_Z1, m_yellow, seg=32)
    cyl("Neck", 0.22, TORSO_Z1, NECK_Z1, m_yellow, seg=20)

    # hair: brown dome with a swept-side fringe
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=18, radius=HEAD_R + 0.07)
    bmesh.ops.scale(bm, verts=bm.verts, vec=(1.05, 0.98, 0.82))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0.03, HEAD_Z1 - 0.10))
    brow = HEAD_Z1 - 0.30
    for v in list(bm.verts):
        front = v.co.y < -0.12
        floor = (HEAD_Z1 - 0.02) if front else (HEAD_Z1 - 0.22)
        if v.co.z < (brow if front else floor):
            bm.verts.remove(v)
    for v in bm.verts:
        if v.co.y < -0.05 and v.co.z > HEAD_Z1 - 0.02:
            v.co.x += 0.10
            v.co.y -= 0.04
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    L._finish("Hair", bm, m_brown, smooth=True)

    # torso: teal trapezoid jacket
    prism("Torso", -0.54, 0.54, -0.30, 0.28, TORSO_Z0, TORSO_Z1, m_teal,
          taper_top=0.80, taper_depth=0.9)
    bm = bmesh.new()
    v = [bm.verts.new(p) for p in [
        (-0.14, -0.30, TORSO_Z1), (0.14, -0.30, TORSO_Z1),
        (0.0, -0.27, TORSO_Z1 - 0.22)]]
    bm.faces.new(v)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    L._finish("Collar", bm, m_tan)
    prism("Zip", -0.013, 0.013, -0.322, -0.30, TORSO_Z0 + 0.05, TORSO_Z1 - 0.16, m_black)
    for sx, nm in ((0.24, "PocketL"), (-0.24, "PocketR")):
        prism(nm, sx - 0.085, sx + 0.085, -0.318, -0.30,
              TORSO_Z0 + 0.32, TORSO_Z0 + 0.42, m_black)

    # arms (teal) + hands (yellow C-claws)
    for s in ("L", "R"):
        sh, wr = SHOULDER[s], WRIST[s]
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=10, radius=0.17)
        bmesh.ops.scale(bm, verts=bm.verts, vec=(1, 1, 0.85))
        bmesh.ops.translate(bm, verts=bm.verts, vec=(sh.x, 0, SH_Z - 0.02))
        L._finish(f"Shoulder{s}", bm, m_teal, smooth=True)
        tube_between(f"Arm{s}", sh + Vector((0, 0, -0.05)), wr, 0.16, m_teal)
        arc_tube(f"Hand{s}", 0.16, 0.064, 250, m_yellow,
                 seg_major=20, seg_minor=12, plane="XZ",
                 center=(wr.x, wr.y, wr.z - 0.14), start_deg=20)

    # hips (blue)
    prism("Hips", -0.58, 0.58, -0.30, 0.28, HIP_Z - 0.06, TORSO_Z0 + 0.04, m_blue)

    # legs (blue) + feet (red)
    for s, sgn in (("L", 1), ("R", -1)):
        x0, x1 = sorted((sgn * 0.04, sgn * 0.56))
        prism(f"Leg{s}", x0, x1, -0.26, 0.26, FOOT_Z1, HIP_Z, m_blue)
        prism(f"Foot{s}", x0, x1, -0.42, 0.26, 0.0, FOOT_Z1, m_red)


# ----------------------------------------------------------------------------
BONES = {
    "root":  ((0, 0, 0),            (0, 0, 0.25)),
    "spine": ((0, 0, HIP_Z),        (0, 0, TORSO_Z1)),
    "head":  ((0, 0, TORSO_Z1),     (0, 0, HEAD_Z1)),
    "armL":  (tuple(SHOULDER["L"]), tuple(WRIST["L"])),
    "armR":  (tuple(SHOULDER["R"]), tuple(WRIST["R"])),
    "legL":  ((LEG_HX, 0, HIP_Z),   (LEG_HX, 0, 0)),
    "legR":  ((-LEG_HX, 0, HIP_Z),  (-LEG_HX, 0, 0)),
}
BONE_PARENT = {"spine": "root", "head": "spine", "armL": "spine",
               "armR": "spine", "legL": "root", "legR": "root"}
PART_BONE = {
    "head": ["Head", "Neck", "Hair"],
    "spine": ["Torso", "Collar", "Zip", "PocketL", "PocketR", "ShoulderL",
              "ShoulderR", "Hips"],
    "armL": ["ArmL", "HandL"], "armR": ["ArmR", "HandR"],
    "legL": ["LegL", "FootL"], "legR": ["LegR", "FootR"],
}


def build_armature(extra_parenting):
    # merge prop/face parenting (objname -> bone) into PART_BONE
    for objname, bone in extra_parenting:
        PART_BONE.setdefault(bone, []).append(objname)

    arm_data = bpy.data.armatures.new("BrickRig")
    arm = bpy.data.objects.new("Brick", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    for name, (h, t) in BONES.items():
        b = eb.new(name)
        b.head, b.tail = Vector(h), Vector(t)
        b.use_deform = True
    for child, parent in BONE_PARENT.items():
        eb[child].parent = eb[parent]
    bpy.ops.object.mode_set(mode="OBJECT")

    for bone_name, parts in PART_BONE.items():
        bone = arm_data.bones[bone_name]
        P_ = bone.matrix_local.copy()
        P_.translation = bone.matrix_local @ Vector((0, bone.length, 0))
        Pinv = P_.inverted()
        for pname in parts:
            ob = PARTS.get(pname)
            if not ob:
                print(f"  WARN missing part {pname}"); continue
            ob.parent = arm
            ob.parent_type = "BONE"
            ob.parent_bone = bone_name
            ob.matrix_parent_inverse = Pinv
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    return arm


# ----------------------------------------------------------------------------
def build_stage():
    target = Vector((0, 0, 1.55))
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 4.0
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = (0, -9, 1.55)
    cam.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.scene.camera = cam

    def lamp(name, loc, energy, size, color="#FFFFFF"):
        ld = bpy.data.lights.new(name, type="AREA")
        ld.energy = energy; ld.size = size
        ld.color = rgb(color)[:3]
        lo = bpy.data.objects.new(name, ld)
        bpy.context.scene.collection.objects.link(lo)
        lo.location = loc
        lo.rotation_euler = (target - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        return lo
    lamp("Key", (-3.5, -5, 5.5), 900, 5)
    lamp("Fill", (4, -3.5, 2.5), 280, 4, color="#EAF0FF")
    lamp("Rim", (1.5, 4.5, 5), 700, 4, color="#FFF4E0")

    world = bpy.data.worlds.new("W"); bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.05, 0.05, 0.06, 1)
    bg.inputs[1].default_value = 0.4

    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.resolution_x = 512
    sc.render.resolution_y = 640


# ----------------------------------------------------------------------------
def main():
    wipe()
    build_model()
    faces = P.build_faces()      # [(objname, bone)]
    props_ = P.build_props()     # [(objname, bone)]
    arm = build_armature(faces + props_)

    # hide all faces except neutral, hide all props (render + viewport)
    for objname, _ in faces:
        hide = (objname != "Face_neutral")
        PARTS[objname].hide_render = hide
        PARTS[objname].hide_viewport = hide
    for objname, _ in props_:
        PARTS[objname].hide_render = True
        PARTS[objname].hide_viewport = True

    build_stage()
    animate.author_all(arm)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print(f"SAVED {BLEND}  ({len(bpy.data.actions)} actions, "
          f"{len([o for o in bpy.data.objects if o.type=='MESH'])} meshes)")


if __name__ == "__main__":
    main()
