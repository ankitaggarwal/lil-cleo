import AppKit
import ApplicationServices

/// The dock-stroll behavior: an activity state machine that walks Brick along the
/// dock, rests him quietly in a corner after a while, and wakes him to react when
/// something happens. Window movement is tracked in `brickX` (sub-pixel) because
/// `NSWindow` origins are pixel-rounded - accumulating there is what lets slow steps
/// add up instead of rounding away to nothing.
extension AppDelegate {
    func startWandering() {
        let timer = Timer(timeInterval: 1.0 / 50.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.stepWander() }
        }
        RunLoop.main.add(timer, forMode: .common)
        wanderTimer = timer
    }

    func stepWander() {
        positionBubble()   // keep the speech bubble glued above Brick every frame
        if demoMode || filming { return }   // a scripted sequence owns his movement
        if !emotions.autopilot { return }   // pinned (CLEO_ACTION/EMOTION): hold centered
        guard let screen = NSScreen.main, characterWindow.isVisible else {
            emotions.setLocomotion(walking: false)
            return
        }

        // The window is user-draggable; if it moved while we weren't placing it
        // (a drag during a pause or corner nap), adopt the new x so he carries on
        // from where he was dropped instead of teleporting back to the stale brickX.
        let actualX = characterWindow.frame.origin.x
        if abs(actualX - brickX.rounded()) > 1 { brickX = actualX }

        // Machine overloaded (CPU and/or RAM pegged): forget the calm state machine and
        // bolt back and forth across the dock, hair ablaze, until both signals recover.
        if emotions.inEmergency {
            let w = characterWindow.frame.size.width
            let (minX, maxX) = walkBounds(screen: screen, width: w)
            let y = dockTopY(screen) - footInset
            let speed = walkSpeed * 2.4
            var nx = brickX + panicDir * speed
            if nx <= minX { nx = minX; panicDir = 1 }
            else if nx >= maxX { nx = maxX; panicDir = -1 }
            emotions.facing = panicDir
            emotions.setLocomotion(walking: true, running: true)
            place(nx, y)
            activity = .reacting   // when the fire's out, settle then resume strolling
            return
        }

        // Any real reaction interrupts what he's doing: stop, turn front, and emote
        // (a mood face only shows from the front - while walking he's in profile).
        if let t = emotions.lastReactionAt, t != lastReactionSeen {
            lastReactionSeen = t
            emotions.wake()
            emotions.facing = 1
            activity = .reacting
        }

        let w = characterWindow.frame.size.width
        let (minX, maxX) = walkBounds(screen: screen, width: w)
        let y = dockTopY(screen) - footInset

        switch activity {
        case .reacting:
            // Stand and let the reaction play out; once it settles, take a short walk.
            emotions.setLocomotion(walking: false)
            if reactionSettled { beginStroll(seconds: Double.random(in: 30...55)) }

        case .strolling:
            if emotions.wantsToWander {
                strollStep(minX: minX, maxX: maxX, y: y)
            } else {
                emotions.setLocomotion(walking: false)   // a rooted mood; still counts time
            }
            if Date() >= strollEndsAt { startGoToCorner(minX: minX, maxX: maxX) }

        case .toCorner:
            guard emotions.wantsToWander else { emotions.setLocomotion(walking: false); break }
            let target = min(max(cornerTargetX, minX), maxX)
            if walkToward(target, y: y, minX: minX, maxX: maxX,
                          cruise: walkSpeed, running: false) {
                enterRest(leftCorner: target <= minX + 1)
            }

        case .resting:
            emotions.setLocomotion(walking: false)
            // Sit first, then drift to sleep after a bit - quiet, do-not-disturb.
            if emotions.action == .sit, Date().timeIntervalSince(restStartedAt) > 14 {
                emotions.rest(.sleep)
            }
        }
    }

    /// True once a reaction has fully decayed back to a calm idle.
    var reactionSettled: Bool {
        !emotions.performingGesture && emotions.emotion == .idle && emotions.action == .idle
    }

    /// Begin a stroll that lasts `seconds`, after which Brick heads for a corner.
    func beginStroll(seconds: Double) {
        activity = .strolling
        strollEndsAt = Date().addingTimeInterval(seconds)
        runMode = false   // natural strolls walk; the menu's "Run" re-sets this
        strollTargetX = nil
        strollSpeed = 0
        dwellUntil = .distantPast
    }

    /// One frame of free ambling: walk to a chosen spot (eased in and out), linger
    /// there a moment, then pick somewhere new. Destination-based movement reads as
    /// intentional; the old constant-speed wall-bounce read as a screensaver.
    func strollStep(minX: CGFloat, maxX: CGFloat, y: CGFloat) {
        if Date() < dwellUntil { emotions.setLocomotion(walking: false); return }
        let target = min(max(strollTargetX ?? pickStrollTarget(minX: minX, maxX: maxX), minX), maxX)
        strollTargetX = target
        let cruise = walkSpeed * cruiseFactor * (runMode ? 2.4 : 1)
        if walkToward(target, y: y, minX: minX, maxX: maxX, cruise: cruise, running: runMode) {
            strollTargetX = nil
            emotions.setLocomotion(walking: false)
            // Linger between legs; now and then a longer "noticed something" stand.
            let dwell = Int.random(in: 0..<6) == 0 ? Double.random(in: 3.5...6.0)
                                                   : Double.random(in: 0.7...2.6)
            dwellUntil = Date().addingTimeInterval(runMode ? dwell * 0.25 : dwell)
        }
    }

    /// One eased step toward `target`: accelerate from rest (~0.6 s to cruise),
    /// hold cruise, brake into the stop - and never about-face at speed (heading
    /// the wrong way brakes to a halt first, then turns standing). Returns true
    /// on arrival.
    func walkToward(_ target: CGFloat, y: CGFloat, minX: CGFloat, maxX: CGFloat,
                    cruise: CGFloat, running: Bool) -> Bool {
        let dist = abs(target - brickX)
        if dist <= max(strollSpeed, 1) {
            strollSpeed = 0
            place(target, y)
            return true
        }
        let dir: CGFloat = (target > brickX) ? 1 : -1
        let accel = cruise / 30
        // Moving away from the target: bleed off speed along the old heading first.
        if dir != emotions.facing, strollSpeed > accel {
            strollSpeed = max(0, strollSpeed - accel * 2)
            place(min(max(brickX + emotions.facing * strollSpeed, minX), maxX), y)
            return false
        }
        // Ease out over the last stretch, ease in from rest, cruise in between.
        let brakeDist = cruise * 18
        let desired = dist < brakeDist ? max(cruise * dist / brakeDist, cruise * 0.25) : cruise
        strollSpeed = min(desired, strollSpeed + accel)
        emotions.facing = dir
        emotions.setLocomotion(walking: true, running: running)
        place(min(max(brickX + dir * strollSpeed, minX), maxX), y)
        return false
    }

    /// Somewhere new to amble to: usually a modest hop, occasionally a long cross,
    /// with the direction weighted toward open space so he doesn't hug an edge.
    /// Each leg also gets its own pace (`cruiseFactor`).
    func pickStrollTarget(minX: CGFloat, maxX: CGFloat) -> CGFloat {
        cruiseFactor = CGFloat.random(in: 0.85...1.15)
        let span = maxX - minX
        guard span > 8 else { return minX }
        let long = Int.random(in: 0..<5) == 0
        let hop = span * (long ? CGFloat.random(in: 0.45...0.85)
                               : CGFloat.random(in: 0.12...0.40))
        let roomR = maxX - brickX, roomL = brickX - minX
        let dir: CGFloat = CGFloat.random(in: 0..<max(roomL + roomR, 1)) < roomR ? 1 : -1
        return min(max(brickX + dir * hop, minX), maxX)
    }

    /// Move Brick to `nx`, tracking the authoritative sub-pixel x in `brickX`.
    func place(_ nx: CGFloat, _ y: CGFloat) {
        brickX = nx
        characterWindow.setFrameOrigin(NSPoint(x: nx.rounded(), y: y))
    }

    /// Head to the corner OPPOSITE the last nap so he alternates sides.
    func startGoToCorner(minX: CGFloat, maxX: CGFloat) {
        cornerTargetX = (restCorner > 0) ? minX : maxX   // opposite of last corner
        activity = .toCorner
    }

    /// Settle into a quiet corner nap (sit now; sleep follows in `stepWander`).
    func enterRest(leftCorner: Bool) {
        activity = .resting
        restStartedAt = Date()
        restCorner = leftCorner ? -1 : 1
        emotions.facing = 1
        emotions.rest(.sit)
    }

    // MARK: Dock geometry

    /// Horizontal limits Brick paces between. Prefer the exact Dock icon-strip
    /// (needs Accessibility). Without it, fall back to a **centered band** roughly
    /// over the Dock - NOT the whole screen - so he never strays out to the edges
    /// (and so "go to a corner" parks him by the Dock, not at the screen edge).
    func walkBounds(screen: NSScreen, width: CGFloat) -> (CGFloat, CGFloat) {
        if let r = dockPillXRange() {
            return (r.lowerBound, max(r.lowerBound, r.upperBound - width))
        }
        let vf = screen.visibleFrame
        let band = vf.width * 0.28                 // ~56% centered band ≈ typical Dock
        let lo = vf.midX - band
        let hi = vf.midX + band
        return (lo, max(lo, hi - width))
    }

    /// Screen-y of the top of the dock (where Brick's feet rest).
    func dockTopY(_ screen: NSScreen) -> CGFloat { screen.visibleFrame.minY }

    /// The centered dock icon strip's x-range, via the Accessibility API. Returns
    /// nil if the app isn't trusted for Accessibility (then we fall back to the
    /// full screen width) - grant it in System Settings ▸ Privacy ▸ Accessibility
    /// to make Brick hug the dock. Cached and refreshed every ~2s.
    func dockPillXRange() -> ClosedRange<CGFloat>? {
        if Date().timeIntervalSince(dockProbedAt) < 2 { return dockRange }
        dockProbedAt = Date()
        dockRange = nil
        guard AXIsProcessTrusted(),
              let dock = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        var kids: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &kids) == .success,
              let arr = kids as? [AXUIElement] else { return nil }
        for el in arr {
            var role: AnyObject?
            AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role)
            guard role as? String == (kAXListRole as String) else { continue }
            var pos: AnyObject?, sz: AnyObject?
            guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &pos) == .success,
                  AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sz) == .success else { continue }
            var p = CGPoint.zero, s = CGSize.zero
            AXValueGetValue(pos as! AXValue, .cgPoint, &p)
            AXValueGetValue(sz as! AXValue, .cgSize, &s)
            if s.width > s.height { dockRange = p.x ... (p.x + s.width) }  // horizontal dock
        }
        return dockRange
    }
}
