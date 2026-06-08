import SwiftUI

/// Chooses how Cleo is drawn:
///   • illustrated **sprites** for the selected character (the normal path), else
///   • the built-in **SwiftUI vector** character as a no-asset fallback.
///
/// Either way the same `EmotionEngine` drives it, so the renderer is a swappable
/// detail.
struct CleoRenderer: View {
    @ObservedObject var settings: Settings
    @ObservedObject var emotions: EmotionEngine

    var body: some View {
        if ImageCharacterView.assetsAvailable {
            ImageCharacterView(settings: settings, emotions: emotions)
        } else {
            CharacterView(settings: settings, emotions: emotions)
        }
    }
}
