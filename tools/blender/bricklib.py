"""Shared Blender geometry + material helpers for building Brick.

Imported by build_brick.py and props.py. Every part is its own object with an
identity transform and geometry baked in WORLD coords, so rigid bone-parenting
only needs the bone's rest matrix inverse.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler

# --------------------------------------------------------------------------
def _lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def rgb(hexstr):
    h = hexstr.lstrip("#")
    return (_lin(int(h[0:2], 16)), _lin(int(h[2:4], 16)), _lin(int(h[4:6], 16)), 1.0)

PALETTE = {
    "yellow": "#F6C512", "teal": "#37B3A2", "brown": "#6E4A2B",
    "blue": "#2C6FB5", "red": "#C0392B", "black": "#16161A",
    "tan": "#E0B074", "white": "#F2F2F2", "grey": "#8A8F98",
    "dgrey": "#4A4F58", "steel": "#B8C0CC", "gold": "#E8B53A",
    "orange": "#F07A1A", "pink": "#E86A9A", "skyblue": "#7FB4E8",
    "darkblue": "#243B66", "green": "#3FA34D",
}

# --- shared body dimensions (world units, feet on z=0) ---
LEG_Z0, LEG_Z1 = 0.0, 1.05
FOOT_Z1 = 0.22
TORSO_Z0, TORSO_Z1 = 1.05, 2.0
NECK_Z1 = 2.12
HEAD_Z0, HEAD_Z1 = 2.12, 2.86
HEAD_R = 0.46
SH_Z = 1.9
HIP_Z = 1.05
LEG_HX = 0.30
WRIST = {"L": Vector((0.60, -0.20, 1.16)), "R": Vector((-0.60, -0.20, 1.16))}
SHOULDER = {"L": Vector((0.52, 0, SH_Z)), "R": Vector((-0.52, 0, SH_Z))}
FACE_Y = -HEAD_R - 0.006        # face-decal plane (front, -Y)
EYE_Z = HEAD_Z0 + 0.46

MATS = {}
def material(name, hexcol, rough=0.32, metallic=0.0, emit=None, emit_str=0.0,
            alpha=1.0):
    key = (name, hexcol, rough, metallic, emit, emit_str, alpha)
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = rgb(hexcol)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metallic
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.6
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else m.blend_method
    if emit is not None:
        b.inputs["Emission Color"].default_value = rgb(emit)
        b.inputs["Emission Strength"].default_value = emit_str
    MATS[key] = m
    return m

# --------------------------------------------------------------------------
PARTS = {}

def _finish(name, bm, mat, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    if smooth:
        for p in ob.data.polygons:
            p.use_smooth = True
    PARTS[name] = ob
    return ob

def prism(name, x0, x1, y0, y1, z0, z1, mat, taper_top=1.0, taper_depth=1.0):
    bm = bmesh.new()
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    def top(x, y):
        return (cx + (x - cx) * taper_top, cy + (y - cy) * taper_depth)
    tx0, ty0 = top(x0, y0); tx1, ty1 = top(x1, y1)
    v = [bm.verts.new(p) for p in [
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (tx0, ty0, z1), (tx1, ty0, z1), (tx1, ty1, z1), (tx0, ty1, z1)]]
    for a, b, c, d in [(0,1,2,3), (7,6,5,4), (0,4,5,1),
                       (1,5,6,2), (2,6,7,3), (3,7,4,0)]:
        bm.faces.new((v[a], v[b], v[c], v[d]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(name, bm, mat)

def cyl(name, r, z0, z1, mat, seg=28, axis="Z", center=(0, 0), cap=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, segments=seg,
                          radius1=r, radius2=r, depth=(z1 - z0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, (z0 + z1) / 2))
    if axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, (z0 + z1) / 2),
                         matrix=Matrix.Rotation(math.radians(90), 3, "X"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(center[0], center[1], 0))
    return _finish(name, bm, mat, smooth=True)

def cone(name, r0, r1, z0, z1, mat, seg=24):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg,
                          radius1=r0, radius2=r1, depth=(z1 - z0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, (z0 + z1) / 2))
    return _finish(name, bm, mat, smooth=True)

def sphere(name, r, center, mat, scale=(1, 1, 1), seg=16):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(8, seg // 2),
                              radius=r)
    bmesh.ops.scale(bm, verts=bm.verts, vec=scale)
    bmesh.ops.translate(bm, verts=bm.verts, vec=center)
    return _finish(name, bm, mat, smooth=True)

def box(name, cx, cy, cz, sx, sy, sz, mat):
    return prism(name, cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2,
                 cz - sz / 2, cz + sz / 2, mat)

def box_rot(name, cx, cy, cz, sx, sy, sz, mat, rx=0, ry=0, rz=0):
    """Box rotated (degrees) about its own centre, then placed at (cx,cy,cz)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=(sx, sy, sz))
    if rx or ry or rz:
        M = Euler((math.radians(rx), math.radians(ry), math.radians(rz)),
                  "XYZ").to_matrix()
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=M)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(cx, cy, cz))
    return _finish(name, bm, mat)

def tube_between(name, p0, p1, r, mat, seg=18):
    p0, p1 = Vector(p0), Vector(p1)
    L = (p1 - p0).length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg,
                          radius1=r, radius2=r, depth=L)
    quat = (p1 - p0).normalized().to_track_quat("Z", "Y")
    M = Matrix.Translation((p0 + p1) / 2) @ quat.to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return _finish(name, bm, mat, smooth=True)

def arc_tube(name, major_r, minor_r, arc_deg, mat, seg_major=16, seg_minor=10,
             plane="XZ", center=(0, 0, 0), start_deg=0):
    bm = bmesh.new()
    rings = []
    n = max(2, int(seg_major * arc_deg / 360) + 1)
    up = Vector((0, 1, 0)) if plane == "XZ" else Vector((0, 0, 1))
    for i in range(n):
        a = math.radians(start_deg + arc_deg * i / (n - 1))
        if plane == "XZ":
            cpt = Vector((major_r * math.cos(a), 0, major_r * math.sin(a)))
            tangent = Vector((-math.sin(a), 0, math.cos(a)))
        else:
            cpt = Vector((major_r * math.cos(a), major_r * math.sin(a), 0))
            tangent = Vector((-math.sin(a), math.cos(a), 0))
        nrm = tangent.cross(up).normalized()
        binorm = tangent.cross(nrm).normalized()
        ring = []
        for j in range(seg_minor):
            b = math.radians(360 * j / seg_minor)
            off = nrm * (minor_r * math.cos(b)) + binorm * (minor_r * math.sin(b))
            ring.append(bm.verts.new(cpt + off))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for j in range(seg_minor):
            bm.faces.new((rings[i][j], rings[i][(j+1) % seg_minor],
                          rings[i+1][(j+1) % seg_minor], rings[i+1][j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.translate(bm, verts=bm.verts, vec=center)
    return _finish(name, bm, mat, smooth=True)

def torus(name, major_r, minor_r, center, mat, plane="XZ", seg_major=20,
          seg_minor=12):
    return arc_tube(name, major_r, minor_r, 360 * (seg_major - 1) / seg_major,
                    mat, seg_major=seg_major, seg_minor=seg_minor, plane=plane,
                    center=center)

def join_into(target_name, names, rename=None):
    """Join meshes `names` into `target_name`; optionally rename the result."""
    tgt = PARTS[target_name]
    objs = [PARTS[n] for n in names if n in PARTS]
    if len(objs) >= 2:
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = tgt
        bpy.ops.object.join()
        for n in names:
            if n != target_name and n in PARTS:
                PARTS.pop(n, None)
    if rename and rename != target_name:
        PARTS.pop(target_name, None)
        tgt.name = rename
        PARTS[rename] = tgt
    return tgt
