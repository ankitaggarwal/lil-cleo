"""Render a rigged Blender character into LilCleo's app-ready sprite states.

Run headless:
    blender -b character.blend -P tools/blender/render_states.py -- --id cleo3d

The .blend must contain ONE armature-driven character with named animation
Actions (the rig contract):
    idle, walk, happy, excited, sad, thinking, sleeping, wave, sit, point,
    panic, celebrate
Emotion/gesture states render FRONT; `walk` renders a SIDE-profile cycle of
8 frames (walk1..walk8). Output: transparent PNGs in
    Sources/LilCleo/Resources/characters/<id>/

This is the high-quality path: a real rig gives clean, articulated motion (legs
AND arms) that 2D keyframes can't match. A designer (or an auto-rig such as
Mixamo) only needs to match the Action names above.
"""
import bpy, sys, os, math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import brick_states as BS
except Exception:
    BS = None

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
CHAR_ID = argv[argv.index("--id") + 1] if "--id" in argv else "cleo3d"

# <repo>/tools/blender/render_states.py -> writes app sprites to
# <repo>/Sources/LilCleo/Resources/characters/<id>/
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "Sources", "LilCleo", "Resources", "characters", CHAR_ID)
os.makedirs(OUT, exist_ok=True)

# Full state list from CHARACTER-SPEC.md. Any state whose Action is absent in the
# .blend is skipped automatically, so you can render incrementally as you author.
# Front EMOTION/POSE stills (single frame each).
FRONT = [
    # Tier 0 — core (mandatory)
    "hero", "happy", "excited", "sad", "thinking", "curious", "sleeping",
    "sit", "point",
    # Tier 1 — extended emotions
    "neutral", "smiling", "laughing", "angry", "surprised", "confused",
    "proud", "nervous", "bored", "love", "crying", "embarrassed",
    "determined", "smug", "scared", "relieved",
    # Tier 2 — gesture stills
    "thumbsup", "facepalm", "shrug", "bow", "yawn", "peace", "salute",
    # Tier 4 — prop & effect "story" states
    "coffee", "idea", "debug", "fixing", "trophy", "party",
    "raincloud", "headphones", "reading", "coding", "glitch", "loading",
    "sweating", "meditate", "clipboard",
]

# Front ANIMATED states → frame count. Each is a `cyc` action in animate.py; we
# render `<state>1..<state>N` front frames sampled across its cycle, which
# `ImageCharacterView` plays back as a loop (just like the side walk cycle).
FRONT_CYCLE = {
    "wave": 6, "panic": 6, "celebrate": 6, "fistpump": 6,
    "clap": 6, "nod": 6, "headshake": 6, "dance": 6, "hairfire": 6, "jump": 6,
}

# action name in the .blend for each state ("hero" uses the idle action)
ACTION = {s: ("idle" if s == "hero" else s) for s in FRONT}

WALK_FRAMES = 8


def setup_render():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in \
        [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.resolution_x = 512
    sc.render.resolution_y = 640
    sc.render.resolution_percentage = 100


def armature():
    for o in bpy.data.objects:
        if o.type == "ARMATURE":
            return o
    return None


def root_object():
    # the top-level character object/empty to rotate for side views
    arm = armature()
    return arm if arm else bpy.context.scene.objects[0]


def set_action(name):
    arm = armature()
    if not arm or name not in bpy.data.actions:
        return False
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = bpy.data.actions[name]
    return True


def face(side):
    # side profile must face screen-RIGHT to match the sprite contract
    # (ImageCharacterView flips via scaleEffect for leftward travel). Brick's front
    # is -Y and camera-right is +X, so a +90° turn about Z points the face right.
    obj = root_object()
    obj.rotation_euler[2] = math.radians(90 if side else 0)


def _show(name, visible):
    o = bpy.data.objects.get(name)
    if o:
        o.hide_render = not visible
        o.hide_viewport = not visible


def style(state):
    """Toggle the swappable face + props/effects for a state (no-op if the
    blend predates them)."""
    if not BS:
        return
    want_face = BS.face_for(state)
    for fn in BS.ALL_FACES:
        _show(fn, fn == want_face)
    shown = set(BS.props_for(state))
    for pn in BS.ALL_PROPS:
        _show(pn, pn in shown)


# flat front-of-torso decals that read as a floating sliver when seen edge-on;
# hidden for side/walk renders so the profile silhouette stays clean.
SIDE_HIDE = ["Zip", "PocketL", "PocketR"]


def style_plain():
    """Neutral face, no props, no flat front decals (for side_idle / walk)."""
    if not BS:
        return
    for fn in BS.ALL_FACES:
        _show(fn, fn == "Face_neutral")
    for pn in BS.ALL_PROPS:
        _show(pn, False)
    for nm in SIDE_HIDE:
        _show(nm, False)


def render_to(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def render_cycle(state, action_name, nframes, side, fire=False):
    """Render `<state>1..<state>N` sampled across an action's cycle. `side` uses the
    profile view + plain styling (locomotion); otherwise the front view + the
    state's face/props. `fire` reveals the Hairfire prop (running with hair ablaze)."""
    if not set_action(action_name):
        print(f"  (skip {state}: no action '{action_name}')"); return
    face(side=side)
    if side:
        style_plain()
        if fire:
            _show("Hairfire", True)
    else:
        style(state)
    rng = bpy.data.actions[action_name].frame_range
    start, end = int(rng[0]), int(rng[1])
    span = max(end - start, 1)
    for i in range(nframes):
        f = start + round(span * i / nframes)   # excludes the duplicate end frame
        bpy.context.scene.frame_set(f)
        render_to(os.path.join(OUT, f"{state}{i+1}.png"))
    print(f"  rendered {state}1..{state}{nframes}")


def clean_out():
    """Remove stale PNGs so a state that switched still↔cycle never leaves orphans."""
    import glob
    for p in glob.glob(os.path.join(OUT, "*.png")):
        try: os.remove(p)
        except OSError: pass


def main():
    setup_render()
    clean_out()

    # Front emotion/pose STILLS (single frame).
    for state in FRONT:
        if not set_action(ACTION[state]):
            print(f"  (skip {state}: no action '{ACTION[state]}')"); continue
        face(side=False)
        style(state)
        bpy.context.scene.frame_set(bpy.data.actions[ACTION[state]].frame_range[0].__int__() + 1)
        render_to(os.path.join(OUT, f"{state}.png"))
        print(f"  rendered {state}")

    # Front ANIMATED gesture cycles (wave/panic/celebrate/…).
    for state, n in FRONT_CYCLE.items():
        render_cycle(state, state, n, side=False)

    # Side idle + the side locomotion cycles (walk + run).
    style_plain()
    if set_action("idle"):
        face(side=True)
        render_to(os.path.join(OUT, "side_idle.png")); print("  rendered side_idle")
    render_cycle("walk", "walk", WALK_FRAMES, side=True)
    render_cycle("run", "run", WALK_FRAMES, side=True)
    # Same locomotion cycles but with the hair ON FIRE (for "running with fire").
    render_cycle("walkfire", "walk", WALK_FRAMES, side=True, fire=True)
    render_cycle("runfire", "run", WALK_FRAMES, side=True, fire=True)
    print(f"DONE -> {OUT}")


if __name__ == "__main__":
    main()
