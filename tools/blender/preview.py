"""Import a .glb and render quick preview shots (front + side) to verify the
image->3D mesh. Headless:

    blender -b -P tools/blender/preview.py -- --glb tools/blender/work/cleo.glb --out /tmp/cleo3d
"""
import bpy, sys, os, math

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(flag, default=None):
    return argv[argv.index(flag) + 1] if flag in argv else default

GLB = arg("--glb")
OUT = arg("--out", "/tmp/preview")

# clean default scene
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

# frame all imported geometry: compute bounds
objs = [o for o in bpy.data.objects if o.type == "MESH"]
if not objs:
    print("NO MESH IMPORTED"); sys.exit(1)

import mathutils
mn = mathutils.Vector((1e9, 1e9, 1e9)); mx = -mn
for o in objs:
    for c in o.bound_box:
        w = o.matrix_world @ mathutils.Vector(c)
        mn = mathutils.Vector((min(mn[i], w[i]) for i in range(3)))
        mx = mathutils.Vector((max(mx[i], w[i]) for i in range(3)))
center = (mn + mx) / 2
size = (mx - mn).length

sc = bpy.context.scene
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"
sc.render.resolution_x = 512; sc.render.resolution_y = 640
try:
    sc.render.engine = "BLENDER_EEVEE_NEXT"
except Exception:
    sc.render.engine = "BLENDER_EEVEE"

# light
light_data = bpy.data.lights.new("key", type="SUN"); light_data.energy = 3
light = bpy.data.objects.new("key", light_data); sc.collection.objects.link(light)
light.rotation_euler = (math.radians(55), 0, math.radians(40))

cam_data = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_data)
sc.collection.objects.link(cam); sc.camera = cam

def shoot(name, ang):
    d = size * 1.6
    cam.location = (center.x + d * math.sin(ang), center.y - d * math.cos(ang), center.z + size * 0.15)
    # point camera at center
    dirv = center - cam.location
    cam.rotation_euler = dirv.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = f"{OUT}_{name}.png"
    bpy.ops.render.render(write_still=True)
    print("rendered", sc.render.filepath)

shoot("front", 0)
shoot("side", math.radians(90))
print("DONE")
