import AppKit
import Carbon.HIToolbox

// Kept alive for the app's lifetime so the Carbon hotkey stays registered.
private var showreelHotKeyRef: EventHotKeyRef?
private var showreelHandlerRef: EventHandlerRef?

/// A scripted, camera-ready demo reel for showing the project off (e.g. a LinkedIn
/// video): Brick strolls, naps in a corner, his memory pins the meter, things
/// overheat, and he bolts across the screen with his hair ablaze. Triggered by the
/// secret shortcut ⌃⌥⌘R.
extension AppDelegate {

    /// Register the secret system-wide hotkey ⌃⌥⌘R via Carbon `RegisterEventHotKey`.
    /// Unlike `NSEvent` monitors this fires globally (even when LilCleo isn't the
    /// front app) and needs NO Accessibility / Input-Monitoring permission.
    func setupShowreelHotkey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if hkID.id == 1 {
                DispatchQueue.main.async { (NSApp.delegate as? AppDelegate)?.playShowreel() }
            }
            return noErr
        }, 1, &eventType, nil, &showreelHandlerRef)

        let id = EventHotKeyID(signature: OSType(0x4C434C52), id: 1)   // 'LCLR'
        let mods = UInt32(controlKey | optionKey | cmdKey)            // ⌃⌥⌘
        RegisterEventHotKey(UInt32(kVK_ANSI_R), mods, id,
                            GetApplicationEventTarget(), 0, &showreelHotKeyRef)
    }

    @objc func playShowreel() {
        guard !filming else { return }
        filming = true
        if demoMode { stopDemo() }
        emotions.autopilot = false
        systemMonitor.stop()
        Task { @MainActor in
            await runReel()
            emotions.hairOnFire = false
            filming = false
            emotions.autopilot = true
            if settings.reactToSystem { systemMonitor.start() }
            beginStroll(seconds: 8)
        }
    }

    // MARK: The script
    //
    // A natural "day in the life": he mostly just pads around quietly (no speech),
    // rests in a corner, wanders again — and only *speaks up* when something real
    // happens on the machine (CPU spike, memory filling), worries for a while, then
    // calms down as it recovers. Movement eases in/out and he stands before he sits.

    private func runReel() async {
        emotions.facing = 1

        // 1. Just strolling around for a while — quiet, no bubble (~12s).
        await settle(0.4)
        await filmStroll(seconds: 12)
        await settle(0.6)

        // 2. Settle into the corner for a short rest (~5s, still quiet).
        emotions.rest(.sit)
        await beat(5.0)

        // 3. Get up and amble a few seconds more (quiet).
        emotions.wake(); await settle(0.5)
        await filmStroll(seconds: 3)
        await settle(0.7)

        // 4. Memory starts climbing — first a wary glance…
        emotions.perform(.sweating, emotion: .nervous, for: 2.6, message: "memory's creeping up… 📈")
        await beat(2.6)

        // 5. …then it pins the meter.
        emotions.perform(.panic, emotion: .scared, for: 2.6, message: "RAM at 88% 😬")
        await beat(2.6)

        // 6. It boils over — hair on fire — then he bolts across the screen ablaze.
        emotions.hairOnFire = true
        emotions.perform(.onFire, emotion: .scared, for: 1.8, message: "🔥 it's overheating! 🔥")
        await beat(1.8)
        emotions.facing = 1; await beat(0.25)
        emotions.say("🔥 aaaah! 🔥", for: 3)
        await filmWalk(toFraction: 0.95, running: true, seconds: 3.2)
        await settle(0.4)
        emotions.hairOnFire = false
    }

    // MARK: Helpers

    private func beat(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Come to a natural stop: drop out of locomotion to a standing idle and hold.
    private func settle(_ seconds: Double) async {
        emotions.forceWalk(running: false)        // clear any in-flight gesture/run…
        emotions.setLocomotion(walking: false)    // …then stand (action → idle)
        await beat(seconds)
    }

    /// Free strolling for `seconds`: pace at a comfortable, roughly-constant speed,
    /// turning around at the edges, easing in at the start and out at the end so he
    /// doesn't snap into or out of motion.
    private func filmStroll(seconds: Double) async {
        guard let screen = NSScreen.main else { return }
        let (minX, maxX) = walkBounds(screen: screen, width: charSize.width)
        let y = dockTopY(screen) - footInset
        let speed = walkSpeed * 1.4
        emotions.forceWalk(running: false)
        var dir: CGFloat = brickX < (minX + maxX) / 2 ? 1 : -1
        let steps = max(1, Int(seconds * 50))
        for i in 0..<steps {
            let ramp = CGFloat(min(1.0, min(Double(i), Double(steps - i)) / 18.0))   // ease ends
            var nx = brickX + dir * speed * ramp
            if nx <= minX { nx = minX; dir = 1 }
            else if nx >= maxX { nx = maxX; dir = -1 }
            emotions.facing = dir
            place(nx, y)
            try? await Task.sleep(nanoseconds: 20_000_000)   // ~50 fps
        }
    }

    /// Walk/run the window to a fraction of the pacing range over `seconds`, with
    /// **ease-in-out** velocity (smoothstep) so he accelerates and decelerates like a
    /// real character instead of snapping to constant speed. `brickX` stays the
    /// authoritative sub-pixel position.
    private func filmWalk(toFraction f: CGFloat, running: Bool, seconds: Double) async {
        guard let screen = NSScreen.main else { return }
        let (minX, maxX) = walkBounds(screen: screen, width: charSize.width)
        let target = minX + (maxX - minX) * max(0, min(1, f))
        let y = dockTopY(screen) - footInset
        let start = brickX
        emotions.facing = target >= start ? 1 : -1
        emotions.forceWalk(running: running)
        let steps = max(1, Int(seconds * 50))
        for i in 0...steps {
            let p = CGFloat(i) / CGFloat(steps)
            let eased = p * p * (3 - 2 * p)        // smoothstep: ease in + ease out
            place(start + (target - start) * eased, y)
            try? await Task.sleep(nanoseconds: 20_000_000)   // ~50 fps
        }
    }
}
