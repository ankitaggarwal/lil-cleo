"""Render every Action front-on at small res and tile into one montage PNG so
poses can be eyeballed in a single image. Headless:

    blender -b work/brick.blend -P contact_sheet.py -- --out /tmp/brick_contact.png [--side]
"""
import bpy, sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import brick_states as BS
except Exception:
    BS = None

def _apply_style(state):
    if not BS:
        return
    want = BS.face_for(state)
    for fn in BS.ALL_FACES:
        o = bpy.data.objects.get(fn)
        if o:
            o.hide_render = o.hide_viewport = (fn != want)
    shown = set(BS.props_for(state))
    for pn in BS.ALL_PROPS:
        o = bpy.data.objects.get(pn)
        if o:
            o.hide_render = o.hide_viewport = (pn not in shown)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(f, d=None):
    return argv[argv.index(f) + 1] if f in argv else d
OUT = arg("--out", "/tmp/brick_contact.png")
SIDE = "--side" in argv
ONLY = arg("--only")            # comma list to restrict
CELL_W, CELL_H = int(arg("--cellw", "150")), int(arg("--cellh", "188"))
COLS = int(arg("--cols", "8"))

sc = bpy.context.scene
sc.render.resolution_x = CELL_W
sc.render.resolution_y = CELL_H
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"

arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
if not arm.animation_data:
    arm.animation_data_create()
if SIDE:
    arm.rotation_euler[2] = math.radians(90)

names = sorted(a.name for a in bpy.data.actions)
if ONLY:
    keep = ONLY.split(",")
    names = [n for n in names if n in keep]

rows = (len(names) + COLS - 1) // COLS
sheet = np.zeros((rows * CELL_H, COLS * CELL_W, 4), dtype=np.float32)

tmp = "/tmp/_cs_cell.png"
for idx, nm in enumerate(names):
    act = bpy.data.actions[nm]
    arm.animation_data.action = act
    _apply_style(nm)
    f0 = int(act.frame_range[0])
    sc.frame_set(f0 + 1)
    sc.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(tmp)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(CELL_H, CELL_W, 4)
    px = px[::-1]  # flip vertical (blender origin bottom-left)
    r, c = divmod(idx, COLS)
    sheet[r * CELL_H:(r + 1) * CELL_H, c * CELL_W:(c + 1) * CELL_W] = px
    bpy.data.images.remove(img)
    print(f"  {nm}")

# composite over dark grey so transparent cells are visible, draw labels skipped
bg = np.array([0.12, 0.12, 0.14, 1.0], dtype=np.float32)
a = sheet[..., 3:4]
sheet = sheet[..., :4] * a + bg * (1 - a)
sheet[..., 3] = 1.0

out_img = bpy.data.images.new("contact", COLS * CELL_W, rows * CELL_H, alpha=True)
out_img.pixels = sheet[::-1].reshape(-1).tolist()
out_img.filepath_raw = OUT
out_img.file_format = "PNG"
out_img.save()
print(f"MONTAGE -> {OUT}  ({len(names)} cells, {COLS}x{rows})")
