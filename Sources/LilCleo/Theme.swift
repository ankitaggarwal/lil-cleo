import SwiftUI

/// The single visual palette for Cleo's chat panel and vector fallback.
enum Palette {
    static let bodyTop   = Color(red: 1.00, green: 0.78, blue: 0.66)
    static let bodyBottom = Color(red: 0.98, green: 0.55, blue: 0.55)
    static let accent    = Color(red: 0.86, green: 0.34, blue: 0.42)
    static let panelBG   = Color(red: 0.16, green: 0.10, blue: 0.12)
    static let bubbleBG  = Color.white.opacity(0.96)
    static let text      = Color(red: 0.18, green: 0.10, blue: 0.12)
}

/// App-wide observable settings.
@MainActor
final class Settings: ObservableObject {
    /// When on, Brick reacts to real system signals (CPU/thermal/battery/memory/
    /// disk/network/idle/time) via `SystemMonitor`. Persisted across launches.
    @Published var reactToSystem: Bool = UserDefaults.standard.object(forKey: "cleo.reactToSystem") as? Bool ?? true {
        didSet { UserDefaults.standard.set(reactToSystem, forKey: "cleo.reactToSystem") }
    }

    /// Overall character size multiplier (1.0 = regular). Drives the window size,
    /// sprite scale, and motion amplitude. Persisted across launches; `CLEO_SCALE`
    /// overrides for screenshots/testing.
    @Published var scale: Double = {
        if let raw = ProcessInfo.processInfo.environment["CLEO_SCALE"], let v = Double(raw) { return v }
        return UserDefaults.standard.object(forKey: "cleo.scale") as? Double ?? 1.0
    }() {
        didSet { UserDefaults.standard.set(scale, forKey: "cleo.scale") }
    }

    /// Preset sizes shown in the menu. (label, multiplier)
    static let sizePresets: [(name: String, value: Double)] = [
        ("Small (−30%)", 0.7), ("Regular", 1.0), ("Large (+30%)", 1.3), ("Huge (+60%)", 1.6),
    ]

    /// Selected character (a folder of sprites under Resources/characters/<id>/).
    /// Persisted across launches. `CLEO_CHARACTER=<id>` overrides for screenshots.
    @Published var character: String = {
        let ids = Settings.characters.map(\.id)
        if let env = ProcessInfo.processInfo.environment["CLEO_CHARACTER"],
           ids.contains(env) { return env }
        let saved = UserDefaults.standard.string(forKey: "cleo.character")
        return saved.flatMap { ids.contains($0) ? $0 : nil } ?? Settings.characters[0].id
    }() {
        didSet { UserDefaults.standard.set(character, forKey: "cleo.character") }
    }

    /// Characters rigged in Blender and rendered to sprite states via
    /// `tools/blender/render_states.py`. "Brick" is a LEGO minifig whose walk is a
    /// real CMU mocap clip retargeted onto the rig (see tools/blender/import_bvh.py).
    static let characters: [(id: String, name: String)] = [
        ("brick", "Brick (3D)")
    ]
}
