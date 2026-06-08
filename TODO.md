# TODO

Backlog of known gaps. See `CLAUDE.md` for architecture and the Blender pipeline.

## Done - expressive reactions (was items 1 & 2)

- ✅ **Each action is unique & animated.** `logicalState` is now a 1:1 lookup via
  `Action.sprite`/`Emotion.sprite` (no more jump=cheer=celebrate / shake=panic
  collapsing). Front gestures (wave/panic/celebrate/fistpump/clap/nod/headshake/
  dance/hairfire/jump) render as multi-frame cycles, plus a side `run` cycle, and a
  procedural motion layer in `ImageCharacterView` adds shake/hop/sway/jitter/lean.
- ✅ **Distinct face per emotion.** New face prints (`thinking`, `curious`,
  `worried`, `dead`/x-eyes, `wink`, `laughing`) in `props.py`, mapped in
  `brick_states.py`. `thinking`/`curious`/`nervous`/`confused` no longer fall back
  to the neutral smile. Hair-fire flames enlarged to read as real cartoon fire.
- ✅ **Reactions driven by events.** `SystemMonitor` watches native signals
  (CPU/thermal/battery/memory/disk/network/idle/time); `EventServer` exposes a
  loopback HTTP endpoint so other apps can drive Brick; every reaction shows a
  speech bubble (`SpeechBubble`). Walking is the only un-triggered state.

## Backlog / next

- **External inbound event API (redesign).** The first version was a loopback HTTP
  server (`EventServer`, `127.0.0.1:51017`). **Removed** before release - a localhost
  server is a poor fit for a shipped consumer app:
  - port conflicts (the chosen port may already be taken → silent failure),
  - any local webpage can `fetch()` localhost (CSRF-style abuse),
  - App Sandbox needs the network-server entitlement; firewall/Gatekeeper friction,
  - generally an odd shape for a desktop toy.

  Pick a macOS-native, no-network mechanism instead (evaluate, then implement one):
  - **`DistributedNotificationCenter`** - other apps post a named notification, Brick
    observes it. No port, no entitlement, multi-user safe. *Likely best.*
  - **URL scheme** `lilcleo://event?type=…` - `open` from any script/app (needs a
    proper `.app` bundle + Info.plist `CFBundleURLTypes`; SwiftPM exe alone can't
    register one).
  - **Watched folder / named pipe**, or a small `lilcleo event <type>` **CLI** that
    forwards to the running instance.
  - **Push (APNs)** only if remote/cloud triggering is ever wanted - wrong fit for
    local "system is hot" events.
  The reaction layer (`CleoEvent.react`) is already decoupled, so any transport just
  needs to parse → call `engine.react(...)`.

- **Per-character event copy & voices.** Bubble lines are currently global; let each
  character ship its own phrasing.
- **More side-profile actions.** Only walk/run travel in profile; sit/sleep/etc. are
  front-only. A few profile gestures would make the dock stroll richer.
- **Config UI.** Expose CLI command, event port, and which signals are active in a
  small settings panel (today: menu toggles + `Theme.swift`).
- **Auth/secret for the event server.** It's loopback-only; if ever exposed, add a
  shared-token check.
- **Optional sound** on big reactions (off by default).
