import SwiftUI

/// A small, Apple-style picker for triggering any of Brick's moods, actions, or
/// event reactions - a search field over an emoji grid, so the full repertoire is
/// reachable without a 60-row menu. Hosted in a floating panel by `AppDelegate`.
struct ExpressView: View {
    var onEmotion: (Emotion) -> Void
    var onAction: (Action) -> Void
    var onEvent: (String) -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    /// Friendly event scenarios (label, emoji, type, extra search words).
    struct EventItem: Identifiable {
        let id = UUID()
        let label: String, emoji: String, type: String, terms: [String]
    }
    static let events: [EventItem] = [
        .init(label: "Greeting", emoji: "👋", type: "greeting", terms: ["hi", "hello"]),
        .init(label: "Task done", emoji: "🎉", type: "taskCompleted", terms: ["complete", "finished"]),
        .init(label: "Build failed", emoji: "😱", type: "buildFailed", terms: ["error", "broken"]),
        .init(label: "Build passed", emoji: "✅", type: "buildPassed", terms: ["green", "ok"]),
        .init(label: "Tests failed", emoji: "😖", type: "testsFailed", terms: ["red"]),
        .init(label: "Tests passed", emoji: "💪", type: "testsPassed", terms: ["green"]),
        .init(label: "Deploying", emoji: "⏳", type: "deploying", terms: ["ship"]),
        .init(label: "Deployed", emoji: "🚀", type: "deployed", terms: ["shipped", "live"]),
        .init(label: "PR merged", emoji: "🏆", type: "prMerged", terms: ["pull request"]),
        .init(label: "Pushed", emoji: "🚀", type: "gitPushed", terms: ["git", "main"]),
        .init(label: "Compiling", emoji: "⏳", type: "compiling", terms: ["build"]),
        .init(label: "New message", emoji: "📬", type: "newMessage", terms: ["mail", "inbox"]),
        .init(label: "Meeting", emoji: "📅", type: "meeting", terms: ["calendar"]),
        .init(label: "Focus mode", emoji: "🎧", type: "focusMode", terms: ["headphones"]),
        .init(label: "Coffee break", emoji: "☕️", type: "coffeeBreak", terms: ["rest"]),
        .init(label: "Overdue", emoji: "⏰", type: "overdue", terms: ["late"]),
        .init(label: "All clear", emoji: "😌", type: "allClear", terms: ["good"]),
        .init(label: "On fire", emoji: "🔥", type: "error", terms: ["error", "panic"]),
    ]

    private let cols = [GridItem(.adaptive(minimum: 72), spacing: 8)]

    private var moods: [Emotion] {
        query.isEmpty ? Emotion.allCases : Emotion.allCases.filter { match($0.searchTerms) }
    }
    private var actions: [Action] {
        let all = Action.allCases.filter { $0 != .idle }
        return query.isEmpty ? all : all.filter { match($0.searchTerms) }
    }
    private var eventsFiltered: [EventItem] {
        query.isEmpty ? Self.events
            : Self.events.filter { match([$0.label.lowercased(), $0.type] + $0.terms) }
    }
    private var hasResults: Bool { !moods.isEmpty || !actions.isEmpty || !eventsFiltered.isEmpty }

    private func match(_ terms: [String]) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        return terms.contains { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search moods, actions…", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.quaternary))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if query.isEmpty {
                        section("Suggestions") {
                            grid(suggestions)
                        }
                    }
                    if !moods.isEmpty {
                        section("Moods") { grid(moods.map(Pick.mood)) }
                    }
                    if !actions.isEmpty {
                        section("Actions") { grid(actions.map(Pick.act)) }
                    }
                    if !eventsFiltered.isEmpty {
                        section("Events") { grid(eventsFiltered.map(Pick.event)) }
                    }
                    if !hasResults {
                        Text("No matches for “\(query)”")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).padding(.top, 24)
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .padding(12)
        .frame(width: 360, height: 460)
        .background(.regularMaterial)
        .onAppear { searchFocused = true }
    }

    // A curated quick set shown when the search is empty.
    private var suggestions: [Pick] {
        [.act(.wave), .mood(.happy), .act(.celebrate), .mood(.thinking),
         .mood(.love), .act(.coffee), .act(.panic), .mood(.sleeping)]
    }

    // MARK: - Building blocks

    private enum Pick: Identifiable {
        case mood(Emotion), act(Action), event(EventItem)
        var id: String {
            switch self {
            case .mood(let e): "m_\(e.rawValue)"
            case .act(let a): "a_\(a.rawValue)"
            case .event(let e): "e_\(e.type)"
            }
        }
        var emoji: String {
            switch self { case .mood(let e): e.emoji; case .act(let a): a.emoji; case .event(let e): e.emoji }
        }
        var label: String {
            switch self { case .mood(let e): e.label; case .act(let a): a.label; case .event(let e): e.label }
        }
    }

    @ViewBuilder private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                .padding(.leading, 2)
            content()
        }
    }

    private func grid(_ picks: [Pick]) -> some View {
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(picks) { pick in
                Button { fire(pick) } label: { cell(pick) }
                    .buttonStyle(EmojiButtonStyle())
            }
        }
    }

    private func cell(_ pick: Pick) -> some View {
        VStack(spacing: 3) {
            Text(pick.emoji).font(.system(size: 26))
            Text(pick.label).font(.system(size: 10)).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(width: 70, height: 60)
    }

    private func fire(_ pick: Pick) {
        switch pick {
        case .mood(let e): onEmotion(e)
        case .act(let a): onAction(a)
        case .event(let e): onEvent(e.type)
        }
    }
}

/// Soft rounded highlight on hover/press - feels like the native emoji picker.
private struct EmojiButtonStyle: ButtonStyle {
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hover || configuration.isPressed ? Color.primary.opacity(0.12) : .clear))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.12), value: hover)
    }
}
