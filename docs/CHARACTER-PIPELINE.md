# Character pipeline

How Brick (and any future 3D character) goes from a Blender rig to the sprite
frames the app renders. Everything is self-contained under `tools/blender/` — no
external services or downloads.

```
build_brick.py ─► brick.blend ─► import_bvh.py (CMU walk) ─► render_states.py ─► Resources/characters/brick/*.png
   (mesh+rig+58 actions)            (mocap walk cycle)          (front stills + side walk)
```

Run it all with `make brick` (≈40s), or step by step (`make brick-build`,
`brick-walk`, `brick-render`, `brick-contact`). Requires Blender 4.5+/5.x at
`/Applications/Blender.app` (override with `BLENDER=...`).

## 1. Rig + poses — `build_brick.py`

Builds the minifig mesh (`bricklib.py`) and a 7-bone armature — `root, spine,
head, armL, armR, legL, legR` — with LEGO parts **rigidly bone-parented** (they
rotate at joints, they don't skin-deform). Then:

- `animate.py` authors every pose as a named **Action** (bone-local Euler
  keyframes). Action names match the app's state names exactly.
- `props.py` builds swappable printed faces (`Face_*`) and ~18 props/effects,
  parented to head/hand/spine bones, hidden by default.
- `brick_states.py` maps each state → which face + props to show.

Output: `tools/blender/brick.blend` (committed, ~300 KB).

**Add a pose:** add an Action in `animate.py` (+ a face/prop in `props.py` and a
mapping in `brick_states.py` if it needs new art), add the state name to the
`FRONT` list in `render_states.py`, then `make brick`.

## 2. Walk — real motion capture — `import_bvh.py`

The walk is **not** hand-keyed; it's a CMU mocap clip retargeted onto the rig.

- Source: `tools/blender/mocap/cmu_07_01.bvh` (CMU Graphics Lab, subject 07, a
  walk). The CMU skeleton's bone names (`Hips, Spine1, Head, Left/RightArm,
  Left/RightUpLeg`) are matched to Brick's bones.
- For each mapped bone, the per-frame local rotation is copied through a
  **calibrated axis map** into Brick's convention:
  - **Legs:** source X → Brick `rx` (fore/aft swing). Both rigs rest legs-down, so
    this maps cleanly.
  - **Arms/head:** source Z/X → Brick `rx`, but **mean-subtracted** ("dynamic"
    mode) — CMU rests arms held out sideways while Brick's hang down, so only the
    *oscillation* transfers; copying the raw delta would fold the arms through the
    body.
- `--loop 8`: autocorrelation finds one gait period (~128 frames at 120 fps) and
  resamples it into a seamless **8-frame loop** (frame 9 == frame 1), so the app's
  even 8-frame sampling cycles without a hitch. Gait phase is verified
  contralateral (arms swing opposite the same-side leg).

Re-deriving from a different clip: drop a `.bvh` in `mocap/` and
`blender -b tools/blender/brick.blend -P tools/blender/import_bvh.py -- --bvh <file> --name walk --loop 8 --save`.
Tune `AXIS_REMAP`/`DYNAMIC`/`GAIN` at the top of `import_bvh.py` per source rig.

## 3. Render — `render_states.py`

For each state, sets the Action, toggles the right face/props, and renders a
transparent PNG into `Sources/LilCleo/Resources/characters/<id>/`:

- Front emotion/gesture/prop stills (`hero`, `happy`, `walk`→front skipped, …).
- A **side** `side_idle` + `walk1..walk8` cycle. Side view faces **right** (+90°
  about Z, since Brick's front is −Y and screen-right is +X); the app mirrors for
  leftward travel. Flat front decals (`Zip`, pockets) are hidden in profile so the
  silhouette stays clean.

States whose Action is absent in the `.blend` are skipped, so you can render
incrementally.

## Notes

- Blender 5.x uses *layered/slotted* Actions; read fcurves via
  `action.layers[].strips[].channelbag(slot).fcurves` (not `action.fcurves`).
- `--loop` (not `--cycle`) avoids colliding with Blender's `--cycles-*` CLI args.
