import SwiftUI

struct CleanItem: Identifiable, Hashable {
    let url: URL
    let label: String
    var size: Int64
    var selected: Bool
    var contentsOnly: Bool
    var id: String { url.path }
}

struct CleanCategory: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let tint: Color
    /// Deleted outright (regenerable data) rather than moved to the Trash.
    let permanent: Bool
    var items: [CleanItem]

    var size: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectedSize: Int64 { items.reduce(0) { $0 + ($1.selected ? $1.size : 0) } }
    var selectionState: Bool? {
        let n = items.filter(\.selected).count
        return n == 0 ? false : (n == items.count ? true : nil)
    }

    mutating func toggleAll() {
        let target = selectionState != true
        for i in items.indices { items[i].selected = target }
    }
}

struct CleanCandidate {
    let url: URL
    let label: String
    var selected = true
    var contentsOnly = true
}

struct CleanSource: @unchecked Sendable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let tint: Color
    let permanent: Bool
    let gather: () -> [CleanCandidate]
}

enum CleanCatalog {
    static func L(_ p: String) -> URL { home.appendingPathComponent("Library/" + p) }
    static func H(_ p: String) -> URL { home.appendingPathComponent(p) }

    static func kids(_ url: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? [])
            .filter { ![".DS_Store", ".localized"].contains($0.lastPathComponent) }
    }

    static func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    static let browserCaches: [(String, String)] = [
        ("Google/Chrome", "Chrome"), ("com.apple.Safari", "Safari"), ("Firefox", "Firefox"),
        ("BraveSoftware", "Brave"), ("Microsoft Edge", "Edge"), ("Arc", "Arc"),
        ("company.thebrowser.Browser", "Arc"), ("com.operasoftware.Opera", "Opera"),
        ("com.vivaldi.Vivaldi", "Vivaldi"), ("ai.perplexity.comet", "Comet"),
    ]

    static let chromiumProfiles: [(String, String)] = [
        ("Google/Chrome", "Chrome"), ("BraveSoftware/Brave-Browser", "Brave"),
        ("Microsoft Edge", "Edge"), ("Arc/User Data", "Arc"),
    ]

    static let devCaches: [(URL, String, Bool)] = [
        (L("Developer/Xcode/DerivedData"), "Xcode DerivedData", true),
        (L("Developer/Xcode/iOS DeviceSupport"), "iOS DeviceSupport", true),
        (L("Developer/Xcode/Archives"), "Xcode Archives", false),
        (L("Developer/CoreSimulator/Caches"), "Simulator caches", true),
        (L("Caches/com.apple.dt.Xcode"), "Xcode cache", true),
        (L("Caches/Homebrew"), "Homebrew downloads", true),
        (L("Caches/Yarn"), "Yarn cache", true),
        (L("Caches/pip"), "pip cache", true),
        (L("Caches/pnpm"), "pnpm cache", true),
        (L("Caches/CocoaPods"), "CocoaPods cache", true),
        (L("Caches/JetBrains"), "JetBrains caches", true),
        (H(".npm/_cacache"), "npm cache", true),
        (H(".gradle/caches"), "Gradle cache", true),
        (H(".cargo/registry/cache"), "Cargo cache", true),
        (H("go/pkg/mod/cache"), "Go module cache", true),
        (H(".bun/install/cache"), "Bun cache", true),
        (H(".cache/uv"), "uv cache", true),
    ]

    static let creativeCaches: [(URL, String)] = [
        (L("Application Support/Adobe/Common/Media Cache Files"), "Adobe Media Cache Files"),
        (L("Application Support/Adobe/Common/Media Cache"), "Adobe Media Cache database"),
        (L("Application Support/Adobe/Common/Peak Files"), "Adobe Peak Files (audio waveforms)"),
        (L("Caches/Adobe"), "Adobe caches & After Effects disk cache"),
        (L("Caches/com.apple.FinalCut"), "Final Cut Pro cache"),
        (L("Caches/com.blackmagic-design.DaVinciResolve"), "DaVinci Resolve cache"),
        (L("Caches/com.apple.motionapp"), "Motion cache"),
    ]

    /// Cache folders covered by a more specific category, or that macOS needs left alone.
    static let skipInAppCaches: Set<String> = [
        "Google", "Firefox", "BraveSoftware", "Microsoft Edge", "com.apple.Safari", "Arc",
        "company.thebrowser.Browser", "com.operasoftware.Opera", "com.vivaldi.Vivaldi", "ai.perplexity.comet",
        "Homebrew", "Yarn", "pip", "pnpm", "CocoaPods", "JetBrains", "com.apple.dt.Xcode",
        "Adobe", "com.apple.FinalCut", "com.blackmagic-design.DaVinciResolve", "com.apple.motionapp",
        "com.kunal.pangolin", "CloudKit", "com.apple.bird", "com.apple.akd", "FamilyCircle",
        "com.apple.HomeKit", "com.apple.containermanagerd", "com.apple.ap.adprivacyd",
        "com.apple.Safari.SafeBrowsing", "com.apple.nsurlsessiond",
    ]

    static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg", "iso", "xip"]

    static func sources() -> [CleanSource] {
        [
            CleanSource(id: "apps", title: "App caches", detail: "Temporary files apps rebuild on their next launch.",
                        icon: "shippingbox.fill", tint: Theme.amber, permanent: true) {
                kids(L("Caches")).filter { !skipInAppCaches.contains($0.lastPathComponent) }.map { url in
                    let name = url.lastPathComponent
                    return CleanCandidate(url: url, label: AppLookup.pretty(name), selected: !name.hasPrefix("com.apple."))
                }
            },
            CleanSource(id: "browsers", title: "Browser caches", detail: "Cached pages, images and scripts. History, bookmarks and logins stay put.",
                        icon: "globe", tint: Theme.sky, permanent: true) {
                var out: [CleanCandidate] = []
                for (path, name) in browserCaches where exists(L("Caches/" + path)) {
                    out.append(CleanCandidate(url: L("Caches/" + path), label: "\(name) cache"))
                }
                for (base, name) in chromiumProfiles {
                    let root = L("Application Support/" + base)
                    for sub in ["GrShaderCache", "ShaderCache", "component_crx_cache"] where exists(root.appendingPathComponent(sub)) {
                        out.append(CleanCandidate(url: root.appendingPathComponent(sub), label: "\(name) · \(sub)"))
                    }
                    for profile in kids(root) where profile.lastPathComponent == "Default" || profile.lastPathComponent.hasPrefix("Profile ") {
                        for sub in ["Cache", "Code Cache", "GPUCache", "DawnGraphiteCache", "DawnWebGPUCache", "Service Worker/CacheStorage", "Service Worker/ScriptCache"] {
                            let url = profile.appendingPathComponent(sub)
                            if exists(url) { out.append(CleanCandidate(url: url, label: "\(name) · \(profile.lastPathComponent) · \(sub)")) }
                        }
                    }
                }
                return out
            },
            CleanSource(id: "creative", title: "Creative app caches", detail: "Premiere & After Effects media cache, peak files, Final Cut and Resolve caches. Quit those apps first.",
                        icon: "film.stack", tint: Theme.copper, permanent: true) {
                creativeCaches.filter { exists($0.0) }.map { CleanCandidate(url: $0.0, label: $0.1) }
            },
            CleanSource(id: "dev", title: "Developer junk", detail: "Xcode build data, simulator caches and package-manager downloads.",
                        icon: "hammer.fill", tint: Theme.violet, permanent: true) {
                devCaches.filter { exists($0.0) }.map { CleanCandidate(url: $0.0, label: $0.1, selected: $0.2) }
            },
            CleanSource(id: "logs", title: "Logs", detail: "Diagnostic chatter apps leave behind.",
                        icon: "doc.text.fill", tint: Theme.sand, permanent: true) {
                kids(L("Logs")).filter { !["DiagnosticReports", "Pangolin"].contains($0.lastPathComponent) }
                    .map { CleanCandidate(url: $0, label: AppLookup.pretty($0.lastPathComponent)) }
            },
            CleanSource(id: "crash", title: "Crash reports", detail: "Old crash, hang and spin reports.",
                        icon: "exclamationmark.triangle.fill", tint: Theme.rose, permanent: true) {
                kids(L("Logs/DiagnosticReports")).map { CleanCandidate(url: $0, label: $0.lastPathComponent, contentsOnly: false) }
            },
            CleanSource(id: "installers", title: "Installers", detail: "Disk images and packages lying around in Downloads and Desktop. Moved to the Trash.",
                        icon: "shippingbox.and.arrow.backward.fill", tint: Theme.teal, permanent: false) {
                let weekAgo = Date().addingTimeInterval(-7 * 86_400)
                return (kids(H("Downloads")) + kids(H("Desktop")))
                    .filter { installerExtensions.contains($0.pathExtension.lowercased()) }
                    .map { CleanCandidate(url: $0, label: $0.lastPathComponent, selected: (FileSizer.modified($0) ?? .distantPast) < weekAgo, contentsOnly: false) }
            },
            CleanSource(id: "mail", title: "Mail attachments", detail: "Attachments Mail already downloaded. They download again when opened.",
                        icon: "paperclip", tint: Theme.sky, permanent: false) {
                kids(L("Containers/com.apple.mail/Data/Library/Mail Downloads")).map { CleanCandidate(url: $0, label: $0.lastPathComponent, contentsOnly: false) }
            },
            CleanSource(id: "backups", title: "iPhone & iPad backups", detail: "Local device backups. Only remove ones you no longer need.",
                        icon: "iphone", tint: Theme.violet, permanent: false) {
                kids(L("Application Support/MobileSync/Backup")).map { url in
                    let info = NSDictionary(contentsOf: url.appendingPathComponent("Info.plist"))
                    let device = info?["Device Name"] as? String ?? url.lastPathComponent
                    let date = (info?["Last Backup Date"] as? Date).map { " · " + $0.formatted(date: .abbreviated, time: .omitted) } ?? ""
                    return CleanCandidate(url: url, label: device + date, selected: false, contentsOnly: false)
                }
            },
            CleanSource(id: "trash", title: "Trash", detail: "Files already in your Trash, emptied for good.",
                        icon: "trash.fill", tint: Theme.rose, permanent: true) {
                kids(H(".Trash")).map { CleanCandidate(url: $0, label: $0.lastPathComponent, contentsOnly: false) }
            },
        ]
    }

    static func measure(_ source: CleanSource) -> [CleanItem] {
        let candidates = source.gather()
        var sizes = [Int64](repeating: 0, count: candidates.count)
        sizes.withUnsafeMutableBufferPointer { buf in
            let base = buf.baseAddress
            DispatchQueue.concurrentPerform(iterations: candidates.count) { i in
                base?[i] = FileSizer.size(of: candidates[i].url)
            }
        }
        return zip(candidates, sizes)
            .compactMap { c, s in s > 0 ? CleanItem(url: c.url, label: c.label, size: s, selected: c.selected, contentsOnly: c.contentsOnly) : nil }
            .sorted { $0.size > $1.size }
    }
}

@MainActor
final class CleanEngine: ObservableObject {
    enum Phase { case idle, scanning, results, cleaning, done }

    @Published var phase: Phase = .idle
    @Published var status = ""
    @Published var categories: [CleanCategory] = []
    @Published var progress: Double = 0
    @Published var safeMode = false
    @Published var freed: Int64 = 0
    @Published var trashed: Int64 = 0
    @Published var cleanedCount = 0
    @Published var failures = 0

    var totalFound: Int64 { categories.reduce(0) { $0 + $1.size } }
    var totalSelected: Int64 { categories.reduce(0) { $0 + $1.selectedSize } }

    func scan() async {
        withAnimation(.easeInOut) { phase = .scanning }
        categories = []
        for source in CleanCatalog.sources() {
            status = source.title.lowercased()
            let items = await Task.detached(priority: .userInitiated) { CleanCatalog.measure(source) }.value
            guard !items.isEmpty else { continue }
            categories.append(CleanCategory(id: source.id, title: source.title, detail: source.detail, icon: source.icon,
                                            tint: source.tint, permanent: source.permanent, items: items))
        }
        categories.sort { $0.size > $1.size }
        withAnimation(.spring(response: 0.5)) { phase = .results }
    }

    func clean() async {
        let jobs: [(CleanItem, Bool)] = categories.flatMap { c in
            c.items.filter(\.selected).map { ($0, c.id == "trash" || (c.permanent && !safeMode)) }
        }
        guard !jobs.isEmpty else { return }
        withAnimation { phase = .cleaning }
        progress = 0; freed = 0; trashed = 0; cleanedCount = 0; failures = 0

        for (n, job) in jobs.enumerated() {
            let (item, permanent) = job
            status = item.label
            let removed: Int64? = await Task.detached(priority: .userInitiated) {
                guard FileOps.remove(item.url, permanent: permanent, contentsOnly: item.contentsOnly) else { return nil }
                return item.contentsOnly ? item.size - FileSizer.size(of: item.url) : item.size
            }.value
            if let removed {
                if permanent { freed += removed } else { trashed += removed }
                cleanedCount += 1
                OpLog.write("clean", permanent ? "DELETED" : "TRASHED", item.url.path, bytes: removed)
            } else {
                failures += 1
                OpLog.write("clean", "FAILED", item.url.path, bytes: item.size)
            }
            progress = Double(n + 1) / Double(jobs.count)
        }
        categories = []
        withAnimation(.spring(response: 0.5)) { phase = .done }
    }

    func reset() {
        withAnimation { phase = .idle }
    }
}
