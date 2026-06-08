import SwiftUI

/// A small cartoon speech bubble that floats above Brick to narrate what just
/// happened ("battery low - 12% 🔋"). The copy comes from `EmotionEngine.message`,
/// set by reactions; this view just shows/hides it with a springy pop. Lives in its
/// own borderless overlay window managed by `AppDelegate` so it can overflow the
/// narrow character window.
struct SpeechBubbleHost: View {
    @ObservedObject var emotions: EmotionEngine

    var body: some View {
        ZStack(alignment: .bottom) {
            if let msg = emotions.message, !msg.isEmpty {
                SpeechBubble(text: msg)
                    .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.spring(response: 0.34, dampingFraction: 0.68), value: emotions.message)
        .allowsHitTesting(false)
    }
}

/// The bubble itself: a soft, frosted card with a small downward tail. Styled to
/// feel like a native macOS popover - translucent material, hairline border, light
/// shadow - rather than a loud comic balloon, and it sits a little above Brick so
/// it never overlaps him.
struct SpeechBubble: View {
    let text: String
    private let radius: CGFloat = 12

    var body: some View {
        VStack(spacing: -0.5) {
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
                )
            BubbleTail()
                .fill(.regularMaterial)
                .frame(width: 14, height: 7)
        }
        .frame(maxWidth: 210)
        .padding(.horizontal, 4)
    }
}

/// A small, soft downward-pointing tail for the bubble.
struct BubbleTail: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
