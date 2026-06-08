import SwiftUI

/// Live wrapper around the `CharacterBody` puppet: supplies the animation clock
/// (per-action phase), blinking, the thinking bubble, mood particles, and
/// hover/tap interaction. All actual drawing lives in `CharacterBody` (Puppet.swift)
/// so the same art renders headlessly for screenshots.
struct CharacterView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var emotions: EmotionEngine

    @State private var blink = false
    @State private var hovering = false
    @State private var sinceBlink: Double = 0
    @State private var phrase = ThinkingPhrases.random()
    @State private var actionStart = Date()

    private let heartbeat = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    private let phraseTimer = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()

    private var emotion: Emotion { emotions.emotion }
    private var action: Action { emotions.action }

    var body: some View {
        VStack(spacing: 4) {
            bubble
                .opacity(emotion == .thinking ? 1 : 0)
                .scaleEffect(emotion == .thinking ? 1 : 0.6, anchor: .bottom)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: emotion)

            ZStack {
                puppet
                particles
            }
            .scaleEffect(x: emotions.facing, y: 1)
            .scaleEffect(hovering ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hovering)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: emotions.facing)
            .contentShape(Rectangle())
            .onTapGesture { emotions.perform(.jump, for: 0.9) }   // a playful hop when clicked
            .onHover { h in hovering = h; if h { emotions.poke() } }
        }
        .frame(width: 140, height: 196, alignment: .bottom)
        .onReceive(heartbeat) { _ in tickHeartbeat() }
        .onReceive(phraseTimer) { _ in if emotion == .thinking { phrase = ThinkingPhrases.random() } }
        .onChange(of: action) { _, _ in actionStart = Date() }
    }

    /// The animated puppet. Phase is elapsed-time based and resets when the action
    /// changes, so one-shots (jump) start clean and loops (walk) stay smooth.
    private var puppet: some View {
        TimelineView(.animation) { tl in
            let elapsed = tl.date.timeIntervalSince(actionStart)
            let period = action.cyclePeriod
            let raw = elapsed / period
            let phase: CGFloat = action.isLocomotion || action.oscillates
                ? CGFloat(raw.truncatingRemainder(dividingBy: 1))     // loop
                : CGFloat(min(max(raw, 0), 1))                        // one-shot
            CharacterBody(emotion: emotion, action: action, phase: phase,
                          blink: blink)
        }
    }

    // MARK: Heartbeat (blink + ambient drift)

    private func tickHeartbeat() {
        emotions.tickAmbient()
        guard let base = emotion.blinkInterval else { return }
        sinceBlink += 0.2
        if sinceBlink >= base * emotions.blinkMultiplier { sinceBlink = 0; doBlink() }
    }

    private func doBlink() {
        withAnimation(.easeInOut(duration: 0.09)) { blink = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            withAnimation(.easeInOut(duration: 0.09)) { blink = false }
        }
    }

    // MARK: Particles + bubble

    @ViewBuilder private var particles: some View {
        switch emotion.particle {
        case .sparkles: Sparkles(color: Palette.accent).offset(y: -70)
        case .zzz:      SleepZs(color: Palette.text).offset(x: 24, y: -64)
        case .none:     EmptyView()
        }
    }

    private var bubble: some View {
        HStack(spacing: 6) {
            Text(phrase)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.text)
            ThinkingDots(color: Palette.accent)
        }
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Palette.bubbleBG).shadow(color: .black.opacity(0.18), radius: 5, y: 3))
        .fixedSize()
    }
}

// MARK: - Shared shapes & particles

/// A morphable mouth: `curve` bends it from frown (-1) to smile (+1); `open`
/// rounds it into an "o". Animatable so emotion changes tween smoothly.
struct MouthShape: Shape {
    var curve: CGFloat
    var open: CGFloat
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(curve, open) }
        set { curve = newValue.first; open = newValue.second }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        if open > 0.4 {
            let oh = h * open
            p.addEllipse(in: CGRect(x: w * 0.18, y: (h - oh) / 2, width: w * 0.64, height: oh))
        } else {
            let mid = CGPoint(x: w * 0.5, y: h * 0.5 + curve * h * 0.45)
            p.move(to: CGPoint(x: w * 0.12, y: h * 0.5))
            p.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.5), control: mid)
        }
        return p
    }
}

/// An upward smiling-eye crescent (⌒).
struct EyeCrescent: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.height))
        p.addQuadCurve(to: CGPoint(x: rect.width, y: rect.height),
                       control: CGPoint(x: rect.width / 2, y: -rect.height * 0.6))
        return p
    }
}

struct Sparkles: View {
    let color: Color
    @State private var on = false
    private let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 10) { spark(0.0); spark(0.25); spark(0.5) }
            .onReceive(timer) { _ in withAnimation(.easeInOut(duration: 0.5)) { on.toggle() } }
    }
    private func spark(_ phase: CGFloat) -> some View {
        Image(systemName: "sparkle").font(.system(size: 9)).foregroundStyle(color)
            .opacity(on ? 1 : 0.2).scaleEffect(on ? 1 : 0.6).offset(y: phase * -6)
    }
}

struct SleepZs: View {
    let color: Color
    @State private var rise = false
    private let timer = Timer.publish(every: 1.4, on: .main, in: .common).autoconnect()
    var body: some View {
        ZStack {
            z(9, 0, 0); z(12, 8, -10); z(15, 18, -22)
        }
        .opacity(rise ? 0.9 : 0.3)
        .onReceive(timer) { _ in withAnimation(.easeInOut(duration: 1.3)) { rise.toggle() } }
    }
    private func z(_ size: CGFloat, _ dx: CGFloat, _ dy: CGFloat) -> some View {
        Text("z").font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(color.opacity(0.7)).offset(x: dx, y: rise ? dy - 6 : dy)
    }
}

struct ThinkingDots: View {
    let color: Color
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(color).frame(width: 4, height: 4).opacity(phase == i ? 1 : 0.3)
            }
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

enum ThinkingPhrases {
    static let list = ["hmm…", "thinking…", "noodling…", "one sec…",
                       "cooking…", "let me see…", "brewing…", "poking around…"]
    static func random() -> String { list.randomElement() ?? "thinking…" }
}
