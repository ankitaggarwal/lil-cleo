import SwiftUI
import AppKit

/// Renders the selected character from high-fidelity illustrated sprites
/// (Resources/characters/<id>/<state>.png). Driven by the same `EmotionEngine`:
///   • locomotion → a side-profile cycle (walk1…/run1…), facing travel
///   • a mood/gesture → the matching front sprite (1:1, no collapsing)
/// Every state is mapped to its OWN sprite via `Action.sprite` / `Emotion.sprite`,
/// and any `<state>1..N` set auto-animates as a cycle. On top of the sprite a
/// lightweight **procedural motion layer** (shake / hop / sway / jitter / lean)
/// gives each action a distinct, exaggerated sense of life even when its sprite is
/// a single still. Expression changes cross-dissolve so they feel smooth.
struct ImageCharacterView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var emotions: EmotionEngine

    private static let walkFPS = 6.5

    /// Are illustrated sprites bundled for the default character?
    static var assetsAvailable: Bool { sprite(Settings.characters[0].id, "hero") != nil }

    var body: some View {
        let s = CGFloat(settings.scale)
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let state = logicalState
            let m = motion(for: emotions.action, emotion: emotions.emotion, t: t, state: state)

            ZStack {
                layer(for: state, t: t)
                    .id(state)
                    .transition(.opacity)
            }
            .frame(width: 110 * s, height: 147 * s, alignment: .bottom)
            .rotationEffect(.degrees(m.rot), anchor: .bottom)             // sprite-local lean/shake
            .scaleEffect(x: emotions.facing * m.sx, y: m.sy, anchor: .bottom)  // travel flip + squash
            .offset(x: m.dx * s, y: m.dy * s)                            // screen-space hop/jitter (scales)
            .animation(.easeInOut(duration: 0.3), value: state)
            .contentShape(Rectangle())
            .onTapGesture { emotions.perform(.jump, for: 0.9) }   // a playful hop when clicked
            .onHover { if $0 { emotions.poke() } }
        }
        .frame(width: 112 * s, height: 150 * s, alignment: .bottom)
    }

    /// The sprite shown for a logical state. Any `<state>1..N` set cycles by time;
    /// otherwise the single still is shown. Falls back side_idle → hero so a state
    /// that wasn't rendered never shows blank.
    @ViewBuilder private func layer(for state: String, t: TimeInterval) -> some View {
        let char = settings.character
        let frames = Self.frameCount(char, state)
        let fps = (state == "run") ? Self.walkFPS * 1.6 : Self.walkFPS
        let name = frames > 0 ? "\(state)\(Int(t * fps) % frames + 1)" : state
        if let img = Self.sprite(char, name) ?? Self.sprite(char, "side_idle")
            ?? Self.sprite(char, "hero") {
            Image(nsImage: img).resizable().interpolation(.high).scaledToFit()
        } else {
            Color.clear
        }
    }

    /// Map (action, mood) to a logical sprite state — a trivial 1:1 lookup now that
    /// each `Action`/`Emotion` carries its own `sprite`. No more collapsing several
    /// actions onto one picture.
    private var logicalState: String {
        let a = emotions.action
        switch a {
        case .idle:
            // Idle body: show the current mood's face; if there's no mood either,
            // show the side profile / walk cycle for the dock stroll.
            if emotions.emotion == .idle { return emotions.isWalking ? fireVariant("walk") : "side_idle" }
            return emotions.emotion.sprite
        case .walk:
            return fireVariant("walk")
        case .run:
            // Use a dedicated side run cycle if rendered, else reuse walk (sped up).
            return fireVariant(Self.frameCount(settings.character, "run") > 0 ? "run" : "walk")
        default:
            return a.sprite
        }
    }

    /// When `hairOnFire` is set, swap a locomotion cycle for its baked fire variant
    /// (`walkfire`/`runfire`) so he runs with real rendered flames — falling back to
    /// the plain cycle if the fire sprites aren't bundled.
    private func fireVariant(_ base: String) -> String {
        guard emotions.hairOnFire else { return base }
        let fire = (base == "run") ? "runfire" : "walkfire"
        return Self.frameCount(settings.character, fire) > 0 ? fire : base
    }

    // MARK: - Procedural motion

    /// A frame's worth of extra transform layered on top of the sprite.
    private struct Motion { var dx: CGFloat = 0, dy: CGFloat = 0, rot: Double = 0
                            var sx: CGFloat = 1, sy: CGFloat = 1 }

    /// Exaggerated, cartoon motion per action so each reads distinctly in flight —
    /// panic shakes, jump arcs, celebrate bounces, on-fire jitters, run leans in.
    private func motion(for a: Action, emotion e: Emotion, t: TimeInterval, state: String) -> Motion {
        var m = Motion()
        func s(_ f: Double) -> CGFloat { CGFloat(sin(t * f)) }
        func bounce(_ f: Double) -> CGFloat { CGFloat(abs(sin(t * f))) }
        switch a {
        case .walk:
            m.dy = -bounce(.pi * Self.walkFPS / 2) * 2.5
        case .run:
            m.dy = -bounce(.pi * Self.walkFPS / 1.1) * 4.5
            m.rot = 7                                   // lean into travel (flipped with facing)
            m.dx = s(.pi * Self.walkFPS / 1.1) * 1.5
        case .panic, .onFire:
            m.dx = s(34) * 5.5                          // frantic shudder
            m.dy = -bounce(17) * 4
            m.rot = Double(s(31)) * 3.5
        case .shake, .headshake, .glitch:
            m.dx = s(26) * 5
            m.rot = Double(s(26)) * 2.5
        case .sweating:
            m.dx = s(20) * 2.5
            m.dy = -bounce(2.2) * 1.5
        case .jump:
            // The sprite cycle already lifts him off the ground; add a small extra
            // hop (kept under the window's headroom so it doesn't clip).
            let h = bounce(5.5); m.dy = -h * 16; m.sy = 1 + 0.08 * h
        case .celebrate, .cheer, .fistpump, .party, .trophy:
            let h = bounce(7); m.dy = -h * 12; m.sy = 1 + 0.06 * h
        case .dance:
            m.dx = s(7) * 6; m.rot = Double(s(7)) * 6
        case .nod:
            m.dy = -bounce(7) * 3
        case .clap:
            m.sx = 1 + 0.03 * bounce(10)
        case .wave, .salute, .peace:
            m.rot = Double(s(5)) * 2
        default:
            // Idle breathing, tuned by the mood's bob profile.
            let (amp, period) = e.bob
            m.dy = CGFloat(sin(t * 2 * .pi / period)) * amp * 0.28
        }
        return m
    }

    // MARK: - Sprite loading

    /// Cached count of `<state>1..N` cycle frames for a character (0 = no cycle,
    /// i.e. a single still). Generalizes the old walk-only counter.
    private static var frameCounts: [String: Int] = [:]
    static func frameCount(_ character: String, _ state: String) -> Int {
        let key = "\(character)/\(state)"
        if let n = frameCounts[key] { return n }
        var n = 0
        while n < 16, sprite(character, "\(state)\(n + 1)") != nil { n += 1 }
        frameCounts[key] = n
        return n
    }

    /// Number of side-walk frames bundled (walk1…walkN), ≥1. Kept for Gallery's
    /// sprite-walk GIF renderer.
    static func walkFrameCount(_ character: String) -> Int {
        max(frameCount(character, "walk"), 1)
    }

    /// Load a bundled sprite for a character + state.
    static func sprite(_ character: String, _ name: String) -> NSImage? {
        let b = Bundle.module
        let url = b.url(forResource: name, withExtension: "png", subdirectory: "characters/\(character)")
            ?? b.url(forResource: "characters/\(character)/\(name)", withExtension: "png")
        guard let url, let img = NSImage(contentsOf: url) else { return nil }
        return img
    }
}

