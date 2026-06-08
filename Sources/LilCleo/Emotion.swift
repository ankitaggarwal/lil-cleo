import SwiftUI
import Combine

/// The emotional repertoire Brick can express. This enum is the *renderer-agnostic*
/// contract: each case maps to a front sprite (`happy.png`, …) for the illustrated
/// character and to face traits for the SwiftUI vector fallback. Every case must
/// read instantly at thumbnail size and carry its own face — no two should look
/// alike. Add a case here + a face in `tools/blender/props.py` to grow the set.
enum Emotion: String, CaseIterable, Identifiable {
    case idle        // calm, gentle breathing
    case happy       // warm smile, soft eyes
    case excited     // wide eyes, fast bounce, sparkles
    case thinking    // gazes up, flat mouth, slow blink
    case curious     // one brow up, leans in
    case sad         // droops, downturned eyes
    case crying      // tears, scrunched
    case angry       // down brows, frown
    case surprised   // wide eyes, "O" mouth
    case scared      // wide eyes, recoil
    case nervous     // worried brows, fidget
    case confused    // tilted, "?"
    case proud       // chest out, smug-happy
    case love        // heart eyes
    case bored       // half-lidded, slumped
    case relieved    // soft exhale smile
    case embarrassed // looks away, blush
    case determined  // focused brows
    case smug        // half smile, raised brow
    case laughing    // big open laugh
    case tired       // yawning, droopy
    case sleeping    // eyes closed, zzz

    var id: String { rawValue }

    /// Friendly label for menus / debugging.
    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// The front sprite basename that carries this mood's face. Usually the raw
    /// value; a few moods borrow the nearest rendered face.
    var sprite: String {
        switch self {
        case .idle:  "hero"
        case .tired: "yawn"
        default:     rawValue
        }
    }

    /// A short, friendly line Brick "says" when he slips into this mood. Used by
    /// the speech bubble when an event doesn't supply its own copy.
    var bubble: String {
        switch self {
        case .idle:        "just hangin' out 🫧"
        case .happy:       "feelin' good!"
        case .excited:     "ooh ooh ooh! ✨"
        case .thinking:    "hmm, let me think… 🤔"
        case .curious:     "ooh, what's this? 👀"
        case .sad:         "aw, bummer…"
        case .crying:      "this is too much 😭"
        case .angry:       "grrr! 😤"
        case .surprised:   "whoa!"
        case .scared:      "eep! that's scary 😨"
        case .nervous:     "uh… this is fine. probably."
        case .confused:    "wait, what? 🤨"
        case .proud:       "nailed it 😎"
        case .love:        "aw, I love this 💖"
        case .bored:       "…anything happening?"
        case .relieved:    "phew, all good 😌"
        case .embarrassed: "oops 🙈"
        case .determined:  "let's do this 💪"
        case .smug:        "told ya 😏"
        case .laughing:    "hahaha! 😂"
        case .tired:       "*yawn* so sleepy…"
        case .sleeping:    "zzz…"
        }
    }

    /// An emoji that stands in for this mood in the Express picker.
    var emoji: String {
        switch self {
        case .idle: "🫧"; case .happy: "😄"; case .excited: "🤩"; case .thinking: "🤔"
        case .curious: "👀"; case .sad: "😢"; case .crying: "😭"; case .angry: "😠"
        case .surprised: "😲"; case .scared: "😨"; case .nervous: "😰"; case .confused: "😕"
        case .proud: "😎"; case .love: "😍"; case .bored: "😑"; case .relieved: "😌"
        case .embarrassed: "😳"; case .determined: "💪"; case .smug: "😏"; case .laughing: "😂"
        case .tired: "🥱"; case .sleeping: "😴"
        }
    }

    /// Extra words (beyond `label`) that should match this mood when searching.
    var searchTerms: [String] {
        let extra: [String]
        switch self {
        case .idle: extra = ["chill", "relax"]
        case .happy: extra = ["smile", "glad", "yay"]
        case .excited: extra = ["hyped", "woo", "yay"]
        case .thinking: extra = ["hmm", "ponder"]
        case .curious: extra = ["what", "ooh", "interested"]
        case .sad: extra = ["down", "bummer", "blue"]
        case .crying: extra = ["cry", "tears", "sob"]
        case .angry: extra = ["mad", "grr", "furious"]
        case .surprised: extra = ["whoa", "wow", "shock"]
        case .scared: extra = ["fear", "yikes", "afraid"]
        case .nervous: extra = ["worried", "anxious"]
        case .confused: extra = ["huh", "what"]
        case .proud: extra = ["nailed", "cool"]
        case .love: extra = ["heart", "adore"]
        case .bored: extra = ["meh", "dull"]
        case .relieved: extra = ["phew", "calm"]
        case .embarrassed: extra = ["oops", "shy", "blush"]
        case .determined: extra = ["focus", "grit"]
        case .smug: extra = ["smirk", "told you"]
        case .laughing: extra = ["lol", "haha", "funny"]
        case .tired: extra = ["yawn", "sleepy"]
        case .sleeping: extra = ["sleep", "zzz", "nap"]
        }
        return [rawValue, label.lowercased()] + extra
    }

    // MARK: - Visual traits (read by the vector fallback in CharacterView)

    /// Vertical eye-openness, 0 (shut) … 1 (wide).
    var eyeOpenness: CGFloat {
        switch self {
        case .sleeping, .tired: 0.0
        case .bored: 0.45
        case .sad, .crying: 0.55
        case .thinking: 0.7
        case .excited, .surprised, .scared: 1.2
        case .curious: 1.0
        default: 1.0
        }
    }

    /// Where the eyes look, in local points. Thinking glances up-and-away.
    var gaze: CGSize {
        switch self {
        case .thinking: CGSize(width: 3, height: -3)
        case .curious: CGSize(width: 2, height: -1)
        case .embarrassed, .smug: CGSize(width: 4, height: -1)
        case .sad, .crying: CGSize(width: 0, height: 2)
        default: .zero
        }
    }

    /// Mouth curvature: +1 big smile, 0 neutral, -1 frown.
    var mouthCurve: CGFloat {
        switch self {
        case .happy, .relieved, .proud: 0.9
        case .excited, .laughing: 1.0
        case .love: 0.85
        case .smug: 0.5
        case .sad, .crying, .scared: -0.8
        case .angry: -0.7
        case .nervous, .confused: -0.3
        case .bored: -0.1
        case .curious: 0.3
        case .sleeping, .tired: 0.15
        case .thinking, .determined, .surprised, .embarrassed: -0.05
        case .idle: 0.35
        }
    }

    /// Mouth openness, 0 (line) … 1 (open "o"). Excited gasps; sleeping breathes.
    var mouthOpen: CGFloat {
        switch self {
        case .laughing, .surprised, .scared: 0.85
        case .excited: 0.8
        case .tired: 0.7
        case .sleeping: 0.25
        case .happy, .crying: 0.2
        default: 0.0
        }
    }

    /// Head/body tilt in degrees. Curiosity and confusion tip the head.
    var tilt: Double {
        switch self {
        case .curious: 8
        case .confused: 10
        case .smug: -6
        case .thinking: -5
        case .sad, .crying, .bored, .embarrassed: 4
        default: 0
        }
    }

    /// Cheek-blush intensity, 0…1. Joy and embarrassment flush the cheeks.
    var blush: CGFloat {
        switch self {
        case .embarrassed: 0.95
        case .excited, .love: 0.85
        case .happy, .laughing: 0.6
        case .curious, .proud: 0.5
        case .sad, .crying: 0.12
        default: 0.35
        }
    }

    /// Idle-motion profile: amplitude (pts) and period (s) of the vertical bob.
    var bob: (amplitude: CGFloat, period: Double) {
        switch self {
        case .excited, .laughing: (10, 0.5)
        case .sleeping, .tired: (3, 3.6)   // slow, deep "breaths"
        case .sad, .crying, .bored: (2, 2.8)
        case .thinking, .determined: (4, 2.0)
        case .curious, .surprised: (5, 1.3)
        default: (6, 1.6)                  // idle / happy
        }
    }

    /// Seconds between blinks. Sleeping never blinks; thinking blinks slowly.
    var blinkInterval: Double? {
        switch self {
        case .sleeping, .tired: nil
        case .thinking, .bored: 4.6
        case .excited, .surprised, .scared: 2.4
        default: 3.4
        }
    }

    /// Decorative particle shown above the head, if any.
    enum Particle { case sparkles, zzz }
    var particle: Particle? {
        switch self {
        case .excited, .love, .proud: .sparkles
        case .sleeping, .tired: .zzz
        default: nil
        }
    }
}

/// What Brick's *body* is doing, independent of his facial mood. Locomotion
/// actions (walk/run) loop and travel; the rest are one-shot gestures or "story"
/// poses that decay back to a resting pose. Each maps 1:1 to a sprite state so no
/// two actions collapse onto the same picture (the old jump=cheer=celebrate bug).
/// Pose math for the vector fallback lives in `Action+Pose` (Puppet.swift).
enum Action: String, CaseIterable, Identifiable {
    // Core + locomotion
    case idle
    case walk
    case run
    case sit
    case jump
    case point
    case wave
    case sleep
    case think
    case panic
    case celebrate
    case cheer
    case shake        // frustrated shimmy — "blocked / stuck"

    // Gestures & reactions
    case clap
    case nod
    case headshake
    case bow
    case dance
    case yawn
    case peace
    case fistpump
    case salute
    case facepalm
    case shrug
    case thumbsup

    // "Story" prop / effect poses
    case onFire       // hair on fire — overwhelmed / overheating
    case coffee
    case idea
    case debug
    case fixing
    case trophy
    case party
    case raincloud
    case headphones
    case reading
    case coding
    case glitch
    case loading
    case sweating
    case meditate
    case clipboard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .onFire: "On Fire"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    /// The sprite state this action renders. If a `<sprite>1..N` cycle is bundled
    /// the renderer animates it; otherwise it shows the single still. A few actions
    /// borrow the nearest rendered pose so each still reads distinctly.
    var sprite: String {
        switch self {
        case .idle:      "side_idle"
        case .think:     "thinking"
        case .sleep:     "sleeping"
        case .cheer:     "fistpump"    // distinct from celebrate's V-jump
        case .shake:     "headshake"   // frustrated head-shake, distinct from panic
        case .onFire:    "hairfire"
        default:         rawValue
        }
    }

    /// An emoji that stands in for this action in the Express picker.
    var emoji: String {
        switch self {
        case .idle: "🧍"; case .walk: "🚶"; case .run: "🏃"; case .sit: "🪑"; case .jump: "🤸"
        case .point: "👉"; case .wave: "👋"; case .sleep: "😴"; case .think: "🤔"
        case .panic: "😱"; case .celebrate: "🎉"; case .cheer: "🙌"; case .shake: "🙅"
        case .clap: "👏"; case .nod: "🙆"; case .headshake: "🙅"; case .bow: "🙇"
        case .dance: "🕺"; case .yawn: "🥱"; case .peace: "✌️"; case .fistpump: "💪"
        case .salute: "🫡"; case .facepalm: "🤦"; case .shrug: "🤷"; case .thumbsup: "👍"
        case .onFire: "🔥"; case .coffee: "☕️"; case .idea: "💡"; case .debug: "🔍"
        case .fixing: "🔧"; case .trophy: "🏆"; case .party: "🥳"; case .raincloud: "🌧️"
        case .headphones: "🎧"; case .reading: "📖"; case .coding: "💻"; case .glitch: "⚡️"
        case .loading: "⏳"; case .sweating: "😅"; case .meditate: "🧘"; case .clipboard: "📋"
        }
    }

    /// Extra words (beyond `label`) that should match this action when searching.
    var searchTerms: [String] {
        let extra: [String]
        switch self {
        case .walk: extra = ["stroll"]
        case .run: extra = ["sprint"]
        case .jump: extra = ["hop", "leap"]
        case .wave: extra = ["hello", "hi", "bye"]
        case .panic: extra = ["freak", "ahh"]
        case .celebrate: extra = ["yay", "woo"]
        case .cheer: extra = ["hooray", "yay"]
        case .shake: extra = ["no", "stuck", "blocked"]
        case .clap: extra = ["applause"]
        case .nod: extra = ["yes"]
        case .headshake: extra = ["no"]
        case .bow: extra = ["thanks"]
        case .dance: extra = ["boogie"]
        case .peace: extra = ["victory"]
        case .fistpump: extra = ["yes", "win"]
        case .salute: extra = ["respect"]
        case .facepalm: extra = ["ugh", "fail"]
        case .shrug: extra = ["dunno", "idk"]
        case .thumbsup: extra = ["ok", "good", "like"]
        case .onFire: extra = ["fire", "burning", "overheat", "error"]
        case .coffee: extra = ["break", "mug", "caffeine"]
        case .idea: extra = ["aha", "lightbulb"]
        case .debug: extra = ["bug", "inspect"]
        case .fixing: extra = ["repair", "wrench"]
        case .trophy: extra = ["win", "award"]
        case .party: extra = ["celebrate"]
        case .raincloud: extra = ["gloom", "rain"]
        case .headphones: extra = ["music", "focus"]
        case .reading: extra = ["book", "study"]
        case .coding: extra = ["code", "laptop", "work"]
        case .glitch: extra = ["bug", "error", "broken"]
        case .loading: extra = ["wait", "spinner"]
        case .sweating: extra = ["stress"]
        case .meditate: extra = ["zen", "calm", "breathe"]
        case .clipboard: extra = ["task", "todo", "notes"]
        default: extra = []
        }
        return [rawValue, label.lowercased()] + extra
    }

    /// Looping locomotion (true) vs a gesture/pose that auto-returns (false).
    var isLocomotion: Bool { self == .walk || self == .run }

    /// Actions whose phase should loop continuously (idle sway, waving, dancing…)
    /// rather than play once and stop (jump, point).
    var oscillates: Bool {
        switch self {
        case .jump, .point, .bow, .salute, .thumbsup, .peace, .fistpump,
             .facepalm, .shrug, .idea, .trophy:
            return false
        default:
            return true
        }
    }

    /// While performing this, Brick stays put rather than wandering.
    var rootsInPlace: Bool { !isLocomotion }

    /// Default seconds a one-shot gesture/pose plays before returning to rest.
    var defaultDuration: Double {
        switch self {
        case .jump: 0.9
        case .wave, .salute, .peace, .thumbsup: 1.8
        case .cheer, .clap, .nod, .headshake, .fistpump: 1.6
        case .panic, .onFire, .sweating: 2.6
        case .celebrate, .party, .dance, .trophy: 2.4
        case .point, .shrug, .facepalm: 1.4
        case .shake: 1.6
        case .think, .sit, .sleep, .reading, .coding, .meditate, .loading: 3.0
        case .coffee, .idea, .debug, .fixing, .clipboard, .headphones, .raincloud, .glitch: 2.8
        default: 1.6
        }
    }

    /// Animation period (s) of one cycle for looping/oscillating actions.
    var cyclePeriod: Double {
        switch self {
        case .walk: 0.9
        case .run: 0.5
        case .panic, .onFire: 0.22
        case .wave: 0.5
        case .cheer, .clap, .fistpump: 0.45
        case .jump: 0.9
        case .shake, .headshake: 0.32
        case .nod: 0.5
        case .celebrate, .dance, .party: 0.6
        case .sweating, .glitch: 0.4
        default: 2.4
        }
    }
}

// MARK: - Reaction intensity

/// How insistent a reaction is. Higher intensities can't be stomped by lower ones
/// while they're on screen — so a "hair on fire" alert isn't interrupted by an
/// ambient idle fidget.
enum Intensity: Int, Comparable {
    case ambient = 0   // idle fidgets, drifting to sleep
    case info    = 1   // gentle nudges (greeting, late-night)
    case alert   = 2   // notable (build failed, battery low)
    case critical = 3  // urgent (on fire, out of memory)
    static func < (a: Intensity, b: Intensity) -> Bool { a.rawValue < b.rawValue }
}

/// High-level events a host app (or LilCleo's own SystemMonitor / EventServer) can
/// fire to make Brick react. This is the integration surface: map your domain
/// events to these, or use `.custom` to drive any emotion/action/message directly.
enum CleoEvent {
    case taskCompleted      // 🎉 celebrate
    case taskAssigned       // 👉 point
    case greeting           // 👋 wave hello
    case buildFailed        // 😱 panic
    case buildPassed        // 😌 relieved + thumbsup
    case testsFailed        // 😖 facepalm
    case testsPassed        // 💪 fistpump
    case deploying          // ⏳ loading
    case deployed           // 🏆 trophy
    case overdue            // 😰 sweating
    case inProgress         // 🤔 thinking
    case working            // 💻 coding
    case allClear           // 😌 happy
    case idleLong           // 😴 sleep
    case error              // 🔥 on fire
    case attention          // 👋 wave to get attention
    case prMerged           // 🏆 PR merged
    case gitPushed          // 🚀 pushed
    case compiling          // ⏳ building/compiling
    case newMessage         // 📬 incoming message
    case meeting            // ⏰ meeting soon
    case focusMode          // 🎧 heads-down focus
    case rateLimited        // ⏳ waiting on a rate limit
    case coffeeBreak        // ☕️ break time
    case waiting            // ⏳ generic "hold on"
    /// Drive any reaction directly (host-supplied face/action/message).
    case custom(emotion: Emotion?, action: Action?, message: String?, intensity: Intensity)

    /// Parse an event from the string `type` used by the HTTP endpoint / menu.
    /// Unknown types fall back to `.custom` carrying just the message.
    static func named(_ type: String, text: String? = nil,
                      emotion: Emotion? = nil, action: Action? = nil) -> CleoEvent {
        switch type.lowercased() {
        case "taskcompleted", "done", "complete": return .taskCompleted
        case "taskassigned", "assigned":          return .taskAssigned
        case "greeting", "hello", "hi":           return .greeting
        case "buildfailed", "build_failed":       return .buildFailed
        case "buildpassed", "build_passed":       return .buildPassed
        case "testsfailed", "tests_failed":       return .testsFailed
        case "testspassed", "tests_passed":       return .testsPassed
        case "deploying", "deploy":               return .deploying
        case "deployed":                          return .deployed
        case "overdue", "late":                   return .overdue
        case "inprogress", "thinking":            return .inProgress
        case "working", "coding":                 return .working
        case "allclear", "clear":                 return .allClear
        case "idle", "idlelong":                  return .idleLong
        case "error", "onfire", "fire":           return .error
        case "attention", "notify", "ping":       return .attention
        case "prmerged", "merged", "pr":          return .prMerged
        case "gitpushed", "pushed", "push":       return .gitPushed
        case "compiling", "building":             return .compiling
        case "newmessage", "message", "mail":     return .newMessage
        case "meeting", "calendar":               return .meeting
        case "focus", "focusmode":                return .focusMode
        case "ratelimited", "ratelimit":          return .rateLimited
        case "coffee", "break", "coffeebreak":    return .coffeeBreak
        case "waiting", "wait", "loading":        return .waiting
        default:
            return .custom(emotion: emotion, action: action, message: text,
                           intensity: .alert)
        }
    }
}

/// Drives Brick's emotional state from app events and the passage of time, and
/// auto-decays transient feelings back toward calm. This is the brain that the
/// renderer (sprite or vector) subscribes to.
@MainActor
final class EmotionEngine: ObservableObject {
    @Published private(set) var emotion: Emotion = .idle

    /// The body action Brick is performing (independent of his facial mood).
    @Published private(set) var action: Action = .idle

    /// A short line shown in the speech bubble, or nil to hide it. Set by reactions
    /// so the user gets context ("battery low — 12% 🔋").
    @Published private(set) var message: String?

    /// Timestamp of the last real reaction (event/system/poke — anything routed
    /// through `trigger`). The wander controller watches this to wake Brick from a
    /// corner nap when something actually happens.
    @Published private(set) var lastReactionAt: Date?

    /// When true, the renderer overlays flames on his head regardless of the current
    /// sprite — so he can, say, *run* with his hair on fire (demo reel).
    @Published var hairOnFire = false

    /// True while the machine is overloaded (CPU and/or RAM pegged). Brick bolts
    /// back and forth with his hair ablaze and *stays* that way until both signals
    /// recover. Read by the wander loop, which takes over locomotion while it's set.
    @Published var inEmergency = false

    /// Locomotion state, driven by the window-level wander controller and read by
    /// the renderer for the walk cycle + horizontal flip.
    @Published var isWalking = false
    @Published var facing: CGFloat = 1   // +1 faces right, -1 faces left

    // MARK: Personality — a lightweight "alive over the workday" model.
    /// 0 (exhausted) … 1 (energized). Drains with work, recovers on breaks.
    @Published private(set) var energy: Double = 0.7

    /// Blink slows when tired — read by the renderer to scale blink cadence.
    var blinkMultiplier: Double { 1.5 - 0.7 * energy }   // 0.8 (fresh) … 1.5 (tired)

    /// Whether Brick is allowed to stroll. He holds still during rooted actions
    /// (sit/sleep/think/cheer/…) and gloomy/sleepy moods.
    var wantsToWander: Bool {
        if performingGesture { return false }
        if action.rootsInPlace && action != .idle { return false }
        switch emotion {
        case .thinking, .sleeping, .tired, .sad, .crying, .scared, .bored: return false
        default: return true
        }
    }

    /// If true, ambient logic (idle → drowsy → sleep) runs automatically.
    var autopilot = true

    /// True while a one-shot gesture (jump/wave/…) owns the body and locomotion
    /// updates should be ignored.
    private(set) var performingGesture = false

    init() {
        // Debug aid: `CLEO_EMOTION=excited swift run` pins a feeling for screenshots.
        if let raw = ProcessInfo.processInfo.environment["CLEO_EMOTION"],
           let pinned = Emotion(rawValue: raw) {
            emotion = pinned
            autopilot = false
        }
        if let raw = ProcessInfo.processInfo.environment["CLEO_ACTION"],
           let pinned = Action(rawValue: raw) {
            action = pinned
            autopilot = false
        }
    }

    private var decayTask: Task<Void, Never>?
    private var gestureTask: Task<Void, Never>?
    private var messageTask: Task<Void, Never>?
    private var idleSince = Date()

    // Intensity gate: a reaction below `lockIntensity` is ignored until `lockedUntil`.
    private var lockIntensity: Intensity = .ambient
    private var lockedUntil = Date.distantPast

    // MARK: - Intensity gating

    /// Whether a reaction of the given intensity is allowed to take over right now.
    private func canInterrupt(_ i: Intensity) -> Bool {
        Date() >= lockedUntil || i >= lockIntensity
    }

    private func hold(_ i: Intensity, for seconds: Double) {
        lockIntensity = i
        lockedUntil = Date().addingTimeInterval(seconds)
    }

    // MARK: - Emotions

    /// Manually set an emotion. `sticky` holds it until changed; otherwise it
    /// will be allowed to decay.
    func set(_ e: Emotion, sticky: Bool = false) {
        decayTask?.cancel()
        withAnimationIfPossible { emotion = e }
        idleSince = Date()
        if !sticky { scheduleAmbientDecay() }
    }

    /// Show an emotion briefly, then fall back to idle.
    func flash(_ e: Emotion, for seconds: Double) {
        decayTask?.cancel()
        withAnimationIfPossible { emotion = e }
        idleSince = Date()
        decayTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.set(.idle)
        }
    }

    /// Show a speech-bubble line, then clear it after `seconds`.
    func say(_ text: String?, for seconds: Double = 4) {
        messageTask?.cancel()
        withAnimationIfPossible { message = text }
        guard text != nil else { return }
        messageTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.withAnimationIfPossible { self.message = nil }
        }
    }

    /// Nudge from user interaction (hover, tap) — perks Brick up.
    func poke() { trigger(emotion: .curious, message: nil, hold: 1.6, intensity: .info) }

    /// Settle into a still resting pose (sit/sleep) without the one-shot gesture
    /// machinery, so a fresh reaction can cleanly take over. Used by the corner-nap.
    func rest(_ a: Action) {
        gestureTask?.cancel()
        performingGesture = false
        withAnimationIfPossible { action = a }
    }

    /// Stand back up from a resting pose so a new reaction's face shows upright.
    func wake() {
        if action == .sit || action == .sleep {
            withAnimationIfPossible { action = isWalking ? .walk : .idle }
        }
    }

    // MARK: - Body actions

    /// Force locomotion immediately, cancelling any in-flight gesture. Used by the
    /// demo reel where the script owns the timeline.
    func forceWalk(running: Bool) {
        gestureTask?.cancel()
        performingGesture = false
        isWalking = true
        withAnimationIfPossible { action = running ? .run : .walk }
    }

    // MARK: - Overload emergency (CPU/RAM pegged → run with hair on fire)

    /// Enter the sustained "everything's on fire" panic: flames on, scared face, and
    /// the wander loop takes over to run him back and forth. Held at critical
    /// intensity so nothing trivial stomps it. Stays until `endEmergency()`.
    func beginEmergency(message: String) {
        gestureTask?.cancel()
        performingGesture = false
        inEmergency = true
        hairOnFire = true
        isWalking = true
        lastReactionAt = Date()
        hold(.critical, for: 5.0)
        withAnimationIfPossible { emotion = .scared; action = .run }
        say(message, for: 6)
    }

    /// Keep the panic alive while still overloaded so its bubble + intensity lock
    /// never decay away between polls.
    func sustainEmergency(message: String) {
        guard inEmergency else { return }
        hold(.critical, for: 5.0)
        lastReactionAt = Date()
        say(message, for: 6)
    }

    /// Leave the emergency once CPU *and* RAM have recovered: douse the flames, drop
    /// the intensity lock, and breathe a relieved sigh on the way back to calm.
    func endEmergency(message: String) {
        guard inEmergency else { return }
        inEmergency = false
        hairOnFire = false
        isWalking = false
        lockIntensity = .ambient
        lockedUntil = .distantPast
        flash(.relieved, for: 2.5)
        say(message, for: 3)
    }

    /// Set the looping locomotion from the wander loop. Ignored while a one-shot
    /// gesture is playing so it can finish cleanly.
    func setLocomotion(walking: Bool, running: Bool = false) {
        isWalking = walking
        guard !performingGesture else { return }
        let next: Action = running ? .run : (walking ? .walk : .idle)
        if action != next { withAnimationIfPossible { action = next } }
    }

    /// Play a one-shot gesture (optionally with a matching face + bubble), then
    /// return to the resting locomotion pose.
    func perform(_ gesture: Action, emotion e: Emotion? = nil,
                 for seconds: Double? = nil, message: String? = nil) {
        gestureTask?.cancel()
        performingGesture = !gesture.isLocomotion
        idleSince = Date()
        withAnimationIfPossible {
            action = gesture
            if let e { emotion = e }
        }
        if let message { say(message, for: (seconds ?? gesture.defaultDuration) + 1.2) }
        guard !gesture.isLocomotion else { return }
        let dur = seconds ?? gesture.defaultDuration
        gestureTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(dur * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.performingGesture = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                self.action = self.isWalking ? .walk : .idle
            }
            if e != nil { self.set(.idle) }
        }
    }

    // MARK: - The one entry point reactions go through

    /// Drive a reaction: optional face, optional body action, optional bubble line,
    /// gated by intensity so urgent states aren't stomped by trivial ones. This is
    /// what `react`, the SystemMonitor, and the EventServer all funnel into.
    func trigger(emotion e: Emotion? = nil, action a: Action? = nil,
                 message: String? = nil, hold seconds: Double = 2.6,
                 intensity: Intensity = .alert) {
        guard canInterrupt(intensity) else { return }
        hold(intensity, for: seconds)
        lastReactionAt = Date()
        if let a {
            perform(a, emotion: e, for: a.isLocomotion ? nil : seconds, message: message)
        } else {
            if let e { flash(e, for: seconds) }
            say(message ?? e?.bubble, for: seconds + 1.2)
        }
    }

    /// Map a host-app / system event to a reaction. The one call a host needs.
    /// `message` overrides the event's default bubble copy (e.g. a custom line sent
    /// from the HTTP endpoint), so callers can say anything while keeping the
    /// curated face + pose for the event type.
    func react(_ event: CleoEvent, message override: String? = nil) {
        switch event {
        case .taskCompleted:
            nudge(energy: 0.12); trigger(emotion: .excited, action: .celebrate, message: "task done! 🎉", hold: 2.4, intensity: .alert)
        case .taskAssigned:
            trigger(emotion: .determined, action: .point, message: "got a new task 👉", hold: 1.8, intensity: .info)
        case .greeting:
            nudge(energy: 0.05); trigger(emotion: .happy, action: .wave, message: "hey there! 👋", hold: 1.8, intensity: .info)
        case .buildFailed:
            nudge(energy: -0.18); trigger(emotion: .scared, action: .panic, message: "build failed! 😱", hold: 2.8, intensity: .alert)
        case .buildPassed:
            nudge(energy: 0.08); trigger(emotion: .relieved, action: .thumbsup, message: "build's green ✅", hold: 1.8, intensity: .info)
        case .testsFailed:
            nudge(energy: -0.12); trigger(emotion: .sad, action: .facepalm, message: "tests are red 😖", hold: 2.2, intensity: .alert)
        case .testsPassed:
            nudge(energy: 0.08); trigger(emotion: .proud, action: .fistpump, message: "all tests pass! 💪", hold: 1.8, intensity: .info)
        case .deploying:
            trigger(emotion: .nervous, action: .loading, message: "deploying… 🤞", hold: 3.0, intensity: .info)
        case .deployed:
            nudge(energy: 0.1); trigger(emotion: .proud, action: .trophy, message: "shipped it! 🚀", hold: 2.4, intensity: .alert)
        case .overdue:
            nudge(energy: -0.1); trigger(emotion: .nervous, action: .sweating, message: "this one's overdue ⏰", hold: 2.4, intensity: .alert)
        case .inProgress:
            trigger(emotion: .thinking, action: .think, message: "on it… 🤔", hold: 3.0, intensity: .info)
        case .working:
            trigger(emotion: .determined, action: .coding, message: "heads down 💻", hold: 3.0, intensity: .info)
        case .allClear:
            nudge(energy: 0.06); trigger(emotion: .happy, message: "all good 😌", hold: 2.0, intensity: .info)
        case .idleLong:
            trigger(emotion: .sleeping, action: .sleep, message: "zzz…", hold: 6.0, intensity: .ambient)
        case .error:
            nudge(energy: -0.2); trigger(emotion: .scared, action: .onFire, message: "everything's on fire! 🔥", hold: 3.0, intensity: .critical)
        case .attention:
            trigger(emotion: .curious, action: .wave, message: "psst — over here! 👋", hold: 2.0, intensity: .info)
        case .prMerged:
            nudge(energy: 0.1); trigger(emotion: .proud, action: .trophy, message: "PR merged! 🏆", hold: 2.4, intensity: .alert)
        case .gitPushed:
            trigger(emotion: .determined, action: .fistpump, message: "pushed to main 🚀", hold: 1.8, intensity: .info)
        case .compiling:
            trigger(emotion: .thinking, action: .loading, message: "compiling… ⏳", hold: 3.0, intensity: .info)
        case .newMessage:
            trigger(emotion: .curious, action: .point, message: "you've got a message 📬", hold: 2.0, intensity: .info)
        case .meeting:
            nudge(energy: -0.05); trigger(emotion: .nervous, action: .clipboard, message: "meeting soon ⏰", hold: 2.6, intensity: .alert)
        case .focusMode:
            trigger(emotion: .determined, action: .headphones, message: "focus mode on 🎧", hold: 3.0, intensity: .info)
        case .rateLimited:
            trigger(emotion: .bored, action: .sit, message: "waiting on rate limit… ⏳", hold: 3.0, intensity: .info)
        case .coffeeBreak:
            nudge(energy: 0.12); trigger(emotion: .relieved, action: .coffee, message: "coffee break ☕️", hold: 2.6, intensity: .info)
        case .waiting:
            trigger(emotion: .bored, action: .loading, message: "hold on… ⏳", hold: 2.6, intensity: .info)
        case let .custom(e, a, msg, intensity):
            trigger(emotion: e, action: a, message: msg, hold: 2.8, intensity: intensity)
        }
        // A caller-supplied line wins over the event's default bubble copy.
        if let override, !override.isEmpty { say(override, for: 5) }
    }

    /// Adjust energy, clamped to 0…1.
    func nudge(energy de: Double) {
        energy = min(1, max(0, energy + de))
    }

    private var lastFidget = Date()

    /// Called by an ambient timer (see CharacterView) to let Brick drift toward
    /// sleep when alone, recover energy on breaks, and fidget so he feels alive.
    func tickAmbient() {
        guard autopilot else { return }
        // Energy slowly recovers while idle (a "break").
        if emotion == .idle && !performingGesture {
            energy = min(1, energy + 0.0008)
        }
        guard emotion == .idle, !performingGesture, canInterrupt(.ambient) else { return }
        let alone = Date().timeIntervalSince(idleSince)
        if alone > 60 { withAnimationIfPossible { emotion = .sleeping }; return }

        // Occasional ambient fidget so he's never frozen (roughly every 8–16s).
        let sinceFidget = Date().timeIntervalSince(lastFidget)
        if sinceFidget > 8, Double.random(in: 0..<1) < 0.012 {
            lastFidget = Date()
            switch Int.random(in: 0..<3) {
            case 0: flash(.curious, for: 1.4)                            // a glance
            case 1: perform(.sit, for: 2.4)                              // settle a moment
            default: flash(energy > 0.6 ? .happy : .idle, for: 1.2)      // a little look
            }
        }
    }

    private func scheduleAmbientDecay() {
        decayTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled, self.emotion != .sleeping else { return }
            self.set(.idle)
        }
    }

    private func withAnimationIfPossible(_ body: () -> Void) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { body() }
    }
}
