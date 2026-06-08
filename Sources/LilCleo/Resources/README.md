# Character sprites

Each character is a folder of PNGs under `characters/<id>/`, loaded at runtime by
`ImageCharacterView` via `Bundle.module`. To add a character, drop in a folder
here and register it in `Settings.characters` (Theme.swift).

## Expected files

| File                | View        | Notes |
|---------------------|-------------|-------|
| `hero.png`          | front       | default / idle portrait (also the fallback) |
| `side_idle.png`     | side, →     | standing, facing right |
| `walk1.png`…`walkN` | side, →     | walk cycle, 1…N frames (auto-detected, ≤16) |
| `run1.png`…`runN`   | side, →     | sprint cycle (falls back to walk if absent) |
| `<emotion>.png`     | front       | one per `Emotion` (happy, thinking, curious, angry, scared, …) |
| `<action>.png`      | front       | single-still gestures (point, shrug, coffee, …) |
| `<action>1..N.png`  | front       | **animated** gestures (wave, panic, celebrate, fistpump, clap, nod, headshake, dance, hairfire, jump) |

**Cycles are generic:** any `<state>1..N` set auto-animates in
`ImageCharacterView` (same path as the walk cycle); a state with just `<state>.png`
shows the still. On top of the sprite, a procedural motion layer adds per-action
shake/hop/sway/jitter/lean so even stills feel alive.

Side sprites must face **right**; `ImageCharacterView` mirrors them for leftward
travel. Missing states fall back to `side_idle` → `hero`, so a partial set still
runs. Transparent background, ~512×640.

Faces are swappable face-print objects in the rig (neutral/happy/sad/angry/
surprised/sleepy/love/thinking/curious/worried/dead/wink/laughing); which face +
props each state uses is data in `tools/blender/brick_states.py`.

These PNGs are generated from a Blender rig - see `tools/blender/` and the repo
root `CLAUDE.md` for the pipeline (`make brick`).
