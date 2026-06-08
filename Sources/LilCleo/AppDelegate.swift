import AppKit
import SwiftUI
import ApplicationServices

/// Borderless window that is allowed to become key so SwiftUI gestures inside
/// it (tapping Cleo) receive events even though the app is an accessory.
final class CharacterWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Core collaborators. (Properties are `internal` so the focused extensions in
    // AppDelegate+Wander/+Demo can reach them; the type itself stays self-contained.)
    let settings = Settings()
    let emotions = EmotionEngine()
    lazy var systemMonitor = SystemMonitor(engine: emotions, settings: settings)

    var characterWindow: CharacterWindow!
    var bubbleWindow: NSWindow!
    var expressPanel: NSPanel?
    var statusItem: NSStatusItem!

    // Bubble overlay size (sits above Brick, narrow window can't contain it).
    let bubbleSize = NSSize(width: 240, height: 92)

    // Character window size, scaled by Settings.scale (base = 80% of the original).
    let baseCharSize = NSSize(width: 112, height: 157)
    var charSize: NSSize {
        NSSize(width: baseCharSize.width * CGFloat(settings.scale),
               height: baseCharSize.height * CGFloat(settings.scale))
    }
    // How far Brick's feet sit above the window's bottom edge; scales with size.
    var footInset: CGFloat { 18 * CGFloat(settings.scale) }

    // Wander state: Brick strolls along the dock when he's in the mood.
    var wanderTimer: Timer?
    var walkDir: CGFloat = 1          // +1 right, -1 left
    var panicDir: CGFloat = 1         // +1 right, -1 left - direction of the on-fire run
    var pauseFrames = 0               // >0 means standing still
    var walkSpeed: CGFloat { 1.1 * CGFloat(settings.scale) }

    // Cached dock-pill x-range (the centered icon strip), refreshed periodically.
    var dockRange: ClosedRange<CGFloat>?
    var dockProbedAt = Date.distantPast

    // Activity state machine: stroll for ~1–1.5 min, then quietly nap in a corner
    // (do-not-disturb); wake on a real reaction, react, walk a bit, nap in the
    // OTHER corner.
    enum Activity { case strolling, toCorner, resting, reacting }
    var activity: Activity = .strolling
    var strollEndsAt = Date()
    var restCorner: CGFloat = 1        // which corner he last napped in (+1 right)
    var cornerTargetX: CGFloat = 0
    var lastReactionSeen: Date?
    var restStartedAt = Date()
    var runMode = false               // true → stroll as a run (from the menu)
    var brickX: CGFloat = 0           // authoritative sub-pixel x of the character window
    var filming = false               // true while the scripted demo reel is playing
    private var updateTimer: Timer?   // daily GitHub-release update check

    // Demo cycler: steps through every emotion + action on a timer (for showcasing).
    var demoTimer: Timer?
    var demoIndex = 0
    var demoMode = false
    var sizeMenuItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupCharacterWindow()
        setupBubbleWindow()
        startWandering()
        setupShowreelHotkey()
        let env = ProcessInfo.processInfo.environment
        let pinned = env["CLEO_ACTION"] != nil || env["CLEO_EMOTION"] != nil
        if env["CLEO_DEMO"] != nil {
            startDemo()   // showcase mode: cycle through every state
        } else if pinned {
            // Screenshot/test mode: hold the pinned state centered (no wander, no
            // greeting, no system reactions). `emotions.autopilot` is false here.
        } else {
            beginStroll(seconds: Double.random(in: 60...90))   // first walk, then he naps
            if settings.reactToSystem { systemMonitor.start() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.emotions.react(.greeting)   // say hello on first appearance
            }
        }
        if env["CLEO_EXPRESS"] != nil {   // test hook: open the picker on launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.toggleExpress() }
        }
        if env["CLEO_REEL"] != nil {      // auto-play the demo reel on launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.playShowreel() }
        }

        // Check GitHub for a newer release on launch, then once a day.
        UpdateChecker.check()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            UpdateChecker.check()
        }
    }

    // MARK: Menu-bar control (the app has no dock icon of its own)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🫧"

        let menu = NSMenu()
        menu.addItem(withTitle: "Express…", action: #selector(toggleExpress), keyEquivalent: "e").target = self
        menu.addItem(.separator())

        // Size picker.
        let sizeMenu = NSMenu()
        sizeMenuItems = []
        for (name, val) in Settings.sizePresets {
            let item = NSMenuItem(title: name, action: #selector(pickSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = val
            item.state = (abs(settings.scale - val) < 0.001) ? .on : .off
            sizeMenu.addItem(item)
            sizeMenuItems.append(item)
        }
        let sizeRoot = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeRoot.submenu = sizeMenu
        menu.addItem(sizeRoot)

        // Character switcher - only when more than one ships.
        if Settings.characters.count > 1 {
            let charMenu = NSMenu()
            for c in Settings.characters {
                let item = NSMenuItem(title: c.name, action: #selector(pickCharacter(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = c.id
                item.state = (settings.character == c.id) ? .on : .off
                charMenu.addItem(item)
            }
            let charRoot = NSMenuItem(title: "Character", action: nil, keyEquivalent: "")
            charRoot.submenu = charMenu
            menu.addItem(charRoot)
        }

        let reactItem = NSMenuItem(title: "React to system", action: #selector(toggleReactToSystem), keyEquivalent: "")
        reactItem.target = self
        reactItem.state = settings.reactToSystem ? .on : .off
        menu.addItem(reactItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quit LilCleo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func checkForUpdates() { UpdateChecker.check(silent: false) }

    // MARK: Cleo's floating window

    private func setupCharacterWindow() {
        let window = CharacterWindow(
            contentRect: NSRect(origin: .zero, size: charSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true

        let root = CleoRenderer(settings: settings, emotions: emotions)
        window.contentView = NSHostingView(rootView: root)
        characterWindow = window

        positionCharacterWindow()
        window.orderFrontRegardless()
    }

    private func positionCharacterWindow() {
        guard let screen = NSScreen.main else { return }
        let x = screen.visibleFrame.midX - charSize.width / 2
        brickX = x
        characterWindow.setFrameOrigin(NSPoint(x: x, y: dockTopY(screen) - footInset))
        positionBubble()
    }

    // MARK: Speech bubble overlay (sits above Brick)

    private func setupBubbleWindow() {
        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: bubbleSize),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        w.ignoresMouseEvents = true     // never steals clicks; purely decorative
        w.contentView = NSHostingView(rootView: SpeechBubbleHost(emotions: emotions))
        bubbleWindow = w
        positionBubble()
        w.orderFrontRegardless()
    }

    /// Center the bubble window above Brick, floating clearly above his head (the
    /// tail points down toward him with a comfortable gap - no overlap).
    func positionBubble() {
        guard let cw = characterWindow, let bw = bubbleWindow else { return }
        let cf = cw.frame
        var x = cf.midX - bubbleSize.width / 2
        var y = cf.maxY + 6     // sit above the window top so it clears his head
        if let vf = NSScreen.main?.visibleFrame {
            x = min(max(vf.minX + 4, x), vf.maxX - bubbleSize.width - 4)
            y = min(y, vf.maxY - bubbleSize.height - 4)
        }
        bw.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: Express picker dispatch (called by the picker's emoji buttons)

    /// Show a mood's face + its bubble line.
    func expressEmotion(_ e: Emotion) {
        emotions.trigger(emotion: e, message: e.bubble, hold: 3.5, intensity: .alert)
    }

    /// Play an action. Locomotion resumes strolling so the wander loop actually moves
    /// the window (otherwise he'd just march in place).
    func expressAction(_ a: Action) {
        if a.isLocomotion {
            emotions.wake()
            beginStroll(seconds: 60)
            runMode = (a == .run)
            emotions.setLocomotion(walking: true, running: a == .run)
        } else {
            emotions.perform(a)
        }
    }

    /// Fire a named event reaction (face + pose + bubble).
    func expressEvent(_ type: String) { emotions.react(.named(type)) }

    @objc private func pickSize(_ sender: NSMenuItem) {
        guard let v = sender.representedObject as? Double else { return }
        settings.scale = v
        sizeMenuItems.forEach { $0.state = (($0.representedObject as? Double) == v) ? .on : .off }
        applyScale()
    }

    /// Resize the character (and bubble) window to the current scale and re-plant
    /// his feet on the dock.
    private func applyScale() {
        guard let screen = NSScreen.main else { return }
        characterWindow.setContentSize(charSize)
        let (minX, maxX) = walkBounds(screen: screen, width: charSize.width)
        let x = min(max(brickX, minX), maxX)
        brickX = x
        characterWindow.setFrameOrigin(NSPoint(x: x, y: dockTopY(screen) - footInset))
        positionBubble()
    }

    @objc private func toggleReactToSystem(_ sender: NSMenuItem) {
        settings.reactToSystem.toggle()
        sender.state = settings.reactToSystem ? .on : .off
        if settings.reactToSystem { systemMonitor.start() } else { systemMonitor.stop() }
    }

    @objc private func pickCharacter(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        settings.character = id
        sender.menu?.items.forEach { $0.state = ($0.representedObject as? String == id) ? .on : .off }
    }

    // MARK: Express picker panel

    @objc private func toggleExpress() {
        if let panel = expressPanel, panel.isVisible { panel.orderOut(nil); return }
        let panel = expressPanel ?? makeExpressPanel()
        expressPanel = panel
        positionPanel(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func makeExpressPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 460),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.closeButton)?.isHidden = true

        let view = ExpressView(
            onEmotion: { [weak self] e in self?.expressEmotion(e) },
            onAction:  { [weak self] a in self?.expressAction(a) },
            onEvent:   { [weak self] t in self?.expressEvent(t) }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 16
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting
        return panel
    }

    /// Center a utility panel above Brick, clamped to the screen.
    private func positionPanel(_ panel: NSPanel) {
        let cw = characterWindow.frame
        let pw = panel.frame.size
        var x = cw.midX - pw.width / 2
        var y = cw.maxY + 8
        if let vf = NSScreen.main?.visibleFrame {
            x = min(max(vf.minX + 8, x), vf.maxX - pw.width - 8)
            y = min(y, vf.maxY - pw.height - 8)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
