import AppKit

/// The "Cycle all states" demo: steps through every emotion + action on a timer so
/// the full repertoire can be showcased. Driven by `CLEO_DEMO` or the menu toggle.
extension AppDelegate {
    /// Ordered showcase: each emotion (as a face) then each action (as a pose).
    var demoStates: [(label: String, emotion: Emotion?, action: Action?)] {
        var s: [(String, Emotion?, Action?)] = Emotion.allCases.map { ("\($0.label) (mood)", $0, nil) }
        s += Action.allCases.filter { $0 != .idle }.map { ("\($0.label) (action)", nil, $0) }
        return s
    }

    func startDemo() {
        guard !demoMode else { return }
        demoMode = true
        emotions.autopilot = false
        systemMonitor.stop()
        demoIndex = 0
        stepDemo()
        let t = Timer(timeInterval: 2.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.stepDemo() }
        }
        RunLoop.main.add(t, forMode: .common)
        demoTimer = t
    }

    func stopDemo() {
        demoMode = false
        demoTimer?.invalidate(); demoTimer = nil
        emotions.autopilot = true
        emotions.setLocomotion(walking: false)
        beginStroll(seconds: Double.random(in: 60...90))
        if settings.reactToSystem { systemMonitor.start() }
    }

    func stepDemo() {
        let item = demoStates[demoIndex % demoStates.count]
        demoIndex += 1
        if let a = item.action {
            if a.isLocomotion {
                emotions.setLocomotion(walking: true, running: a == .run)
                emotions.say("\(item.label) →", for: 2.6)
            } else {
                emotions.setLocomotion(walking: false)
                emotions.perform(a, for: 2.1, message: item.label)
            }
        } else if let e = item.emotion {
            emotions.setLocomotion(walking: false)
            emotions.flash(e, for: 2.4)
            emotions.say(e.bubble, for: 2.6)
        }
    }
}
