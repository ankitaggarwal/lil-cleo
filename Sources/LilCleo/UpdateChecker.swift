import AppKit

/// Checks GitHub for the latest release and, if it's newer than this build, offers a
/// direct download. Dependency-free (just `URLSession`), works with ad-hoc signing -
/// the same lightweight approach as the sibling CopyStack app. Runs on launch + once
/// a day; a "Check for Updates…" menu item triggers a manual (non-silent) check.
enum UpdateChecker {
    /// GitHub "owner/repo" whose Releases are checked. Point this at the public repo
    /// you publish tagged DMG releases to.
    static let repo = "ankitaggarwal/lil-cleo"

    /// `silent` (automatic checks) shows nothing unless an update exists; when false
    /// (a manual check) it also reports "up to date" or a connection error.
    static func check(silent: Bool = true) {
        // Only meaningful for a packaged .app that carries a version; skip dev runs
        // (`swift run` has no Info.plist version) so they never get a spurious alert.
        guard let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            if !silent { DispatchQueue.main.async { showCouldNotCheck() } }
            return
        }

        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let page = json["html_url"] as? String else {
                if !silent { DispatchQueue.main.async { showCouldNotCheck() } }
                return
            }

            // Prefer a direct .dmg asset link; otherwise the release page.
            let assets = json["assets"] as? [[String: Any]] ?? []
            let downloadURL = assets
                .compactMap { $0["browser_download_url"] as? String }
                .first { $0.lowercased().hasSuffix(".dmg") } ?? page

            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag

            DispatchQueue.main.async {
                if latest.compare(current, options: .numeric) == .orderedDescending {
                    showUpdateAvailable(latest: latest, current: current, downloadURL: downloadURL)
                } else if !silent {
                    showUpToDate(current: current)
                }
            }
        }.resume()
    }

    private static func showUpdateAvailable(latest: String, current: String, downloadURL: String) {
        let alert = NSAlert()
        alert.messageText = "A new version of LilCleo is available"
        alert.informativeText = "You have \(current). Version \(latest) is available to download."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, let url = URL(string: downloadURL) {
            NSWorkspace.shared.open(url)
        }
    }

    private static func showUpToDate(current: String) {
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "LilCleo \(current) is the latest version."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func showCouldNotCheck() {
        let alert = NSAlert()
        alert.messageText = "Couldn't check for updates"
        alert.informativeText = "Please check your internet connection and try again."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
