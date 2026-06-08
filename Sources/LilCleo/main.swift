import AppKit

// Headless render mode: `CLEO_RENDER=/tmp/cleo.png swift run LilCleo` rasterizes
// the character gallery to a PNG (no GUI) and exits. Used for visual iteration.
if let out = ProcessInfo.processInfo.environment["CLEO_RENDER"] {
    let ok = MainActor.assumeIsolated { GalleryRenderer.render(to: out) }
    FileHandle.standardError.write(Data((ok ? "rendered \(out)\n" : "render failed\n").utf8))
    exit(ok ? 0 : 1)
}
// CLEO_STRIP=walk CLEO_STRIP_OUT=/tmp/strip.png renders one action's cycle.
if let act = ProcessInfo.processInfo.environment["CLEO_STRIP"], let a = Action(rawValue: act) {
    let out = ProcessInfo.processInfo.environment["CLEO_STRIP_OUT"] ?? "/tmp/cleo_strip.png"
    let ok = MainActor.assumeIsolated { GalleryRenderer.renderStrip(a, to: out) }
    FileHandle.standardError.write(Data((ok ? "rendered \(out)\n" : "render failed\n").utf8))
    exit(ok ? 0 : 1)
}
// CLEO_SPRITE_GIF=<file> renders the bundled sprite walk cycle for CLEO_CHARACTER
// (default brick) to an animated GIF - verifies sprite bundling + in-app cycling.
if let out = ProcessInfo.processInfo.environment["CLEO_SPRITE_GIF"] {
    let char = ProcessInfo.processInfo.environment["CLEO_CHARACTER"] ?? "brick"
    let ok = MainActor.assumeIsolated {
        GalleryRenderer.renderSpriteWalkGIF(character: char, to: out)
    }
    FileHandle.standardError.write(Data((ok ? "rendered \(out)\n" : "render failed\n").utf8))
    exit(ok ? 0 : 1)
}
// CLEO_GIF=<dir> renders showcase animated GIFs (walk, run, celebrate, panic, and
// a "task completed" idle→celebrate→idle sequence).
if let dir = ProcessInfo.processInfo.environment["CLEO_GIF"] {
    typealias B = GalleryRenderer.Beat
    let jobs: [(String, [B])] = [
        ("walk", [B(action: .walk, emotion: .idle, frames: 24)]),
        ("run", [B(action: .run, emotion: .excited, frames: 16)]),
        ("celebrate", [B(action: .celebrate, emotion: .excited, frames: 28)]),
        ("panic", [B(action: .panic, emotion: .sad, frames: 20)]),
        ("task-completed", [
            B(action: .idle, emotion: .idle, frames: 10),
            B(action: .celebrate, emotion: .excited, frames: 40),
            B(action: .idle, emotion: .happy, frames: 14),
        ]),
        ("build-failed", [
            B(action: .idle, emotion: .idle, frames: 10),
            B(action: .panic, emotion: .sad, frames: 36),
            B(action: .sit, emotion: .sad, frames: 16),
        ]),
    ]
    var allOK = true
    for (name, beats) in jobs {
        let out = "\(dir)/cleo-\(name).gif"
        let ok = MainActor.assumeIsolated { GalleryRenderer.renderGIF(beats, to: out) }
        FileHandle.standardError.write(Data((ok ? "rendered \(out)\n" : "FAILED \(out)\n").utf8))
        allOK = allOK && ok
    }
    exit(allOK ? 0 : 1)
}

let app = NSApplication.shared
// The delegate is main-actor isolated; top-level code runs on the main thread.
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
// Accessory: no dock icon, no menu bar app menu - Cleo lives in the dock area
// and is controlled from her status-bar item.
app.setActivationPolicy(.accessory)
app.run()
