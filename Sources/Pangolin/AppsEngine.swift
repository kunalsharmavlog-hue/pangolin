import AppKit
import CoreServices
import SwiftUI

struct InstalledApp: Identifiable, Hashable {
    let url: URL
    let name: String
    let bundleID: String
    let version: String
    var size: Int64?
    let lastUsed: Date?
    let protected: Bool
    var id: String { url.path }
}

struct Leftover: Identifiable, Hashable {
    let url: URL
    let kind: String
    var size: Int64
    var selected: Bool
    var id: String { url.path }
}

struct OrphanGroup: Identifiable, Hashable {
    let bundleID: String
    var items: [Leftover]
    let lastTouched: Date?
    var id: String { bundleID }
    var size: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectionState: Bool? {
        let n = items.filter(\.selected).count
        return n == 0 ? false : (n == items.count ? true : nil)
    }
}

struct StartupItem: Identifiable, Hashable {
    enum Domain: String { case user = "Just you", agent = "All users", daemon = "System" }
    let url: URL
    let label: String
    let program: String
    let domain: Domain
    var enabled: Bool
    var id: String { url.path }
}

@MainActor
final class AppsEngine: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var loadingApps = false
    @Published var selectedID: String?
    @Published var leftovers: [Leftover] = []
    @Published var findingLeftovers = false
    @Published var uninstalling = false

    @Published var orphans: [OrphanGroup] = []
    @Published var scanningOrphans = false
    @Published var orphansScanned = false

    @Published var startup: [StartupItem] = []
    @Published var loadingStartup = false

    @Published var toast: String?

    var selectedApp: InstalledApp? { apps.first { $0.id == selectedID } }

    // MARK: Applications

    func loadApps() async {
        guard !loadingApps else { return }
        loadingApps = true
        let found = await Task.detached(priority: .userInitiated) { Self.scanApps() }.value
        apps = found
        loadingApps = false
        await withTaskGroup(of: (String, Int64).self) { group in
            for app in found {
                group.addTask { (app.id, FileSizer.size(of: app.url)) }
            }
            for await (id, size) in group {
                if let i = apps.firstIndex(where: { $0.id == id }) { apps[i].size = size }
            }
        }
    }

    func select(_ app: InstalledApp) async {
        selectedID = app.id
        leftovers = []
        findingLeftovers = true
        let installed = Set(apps.map(\.bundleID))
        let found = await Task.detached(priority: .userInitiated) {
            Self.findLeftovers(bundleID: app.bundleID, name: app.name, otherIDs: installed.subtracting([app.bundleID]))
        }.value
        guard selectedID == app.id else { return }
        leftovers = found
        findingLeftovers = false
    }

    func uninstall(_ app: InstalledApp) async {
        uninstalling = true
        for running in NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID) {
            running.terminate()
        }
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        let targets = [app.url] + leftovers.filter(\.selected).map(\.url)
        var failed = await Task.detached { targets.filter { !FileOps.remove($0, permanent: false) } }.value
        if !failed.isEmpty, await Task.detached(operation: { [failed] in FileOps.adminTrash(failed) }).value {
            failed = []
        }
        for t in targets where !failed.contains(t) {
            OpLog.write("uninstall", "TRASHED", t.path)
        }
        let total = (app.size ?? 0) + leftovers.filter(\.selected).reduce(0) { $0 + $1.size }
        if failed.contains(app.url) {
            toast = "Couldn’t remove \(app.name). It may be protected by macOS."
        } else {
            withAnimation { apps.removeAll { $0.id == app.id } }
            selectedID = nil
            leftovers = []
            toast = "\(app.name) and \(targets.count - 1) leftover\(targets.count == 2 ? "" : "s") moved to the Trash · \(Bytes.format(total))"
        }
        uninstalling = false
    }

    nonisolated static func scanApps() -> [InstalledApp] {
        let fm = FileManager.default
        let roots = [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")]
        var bundles: [URL] = []
        for root in roots {
            for item in (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] {
                if item.pathExtension == "app" {
                    bundles.append(item)
                } else if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    // Vendor folders such as "Adobe After Effects 2025/" hold the .app one level down.
                    for inner in (try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)) ?? [] where inner.pathExtension == "app" {
                        bundles.append(inner)
                    }
                }
            }
        }
        return bundles.compactMap { url in
            guard let bundle = Bundle(url: url) else { return nil }
            let id = bundle.bundleIdentifier ?? ""
            let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                ?? url.deletingPathExtension().lastPathComponent
            let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            var lastUsed: Date?
            if let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) {
                lastUsed = MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
            }
            let protected = id == "com.apple.Safari" || id == "com.kunal.pangolin"
            return InstalledApp(url: url, name: name, bundleID: id, version: version, size: nil, lastUsed: lastUsed, protected: protected)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Library folders where apps leave support files, caches and preferences.
    nonisolated static let leftoverPlaces: [(String, String)] = [
        ("Library/Application Support", "Support files"), ("Library/Caches", "Cache"), ("Library/Containers", "Sandbox container"),
        ("Library/Group Containers", "Shared container"), ("Library/Preferences", "Preferences"), ("Library/Preferences/ByHost", "Preferences"),
        ("Library/Saved Application State", "Window state"), ("Library/Logs", "Logs"), ("Library/HTTPStorages", "Web storage"),
        ("Library/WebKit", "Web data"), ("Library/Cookies", "Cookies"), ("Library/LaunchAgents", "Startup agent"),
        ("Library/Application Scripts", "Scripts"),
    ]

    nonisolated static let systemLeftoverPlaces: [(String, String)] = [
        ("/Library/Application Support", "Support files (all users)"), ("/Library/LaunchAgents", "Startup agent (all users)"),
        ("/Library/LaunchDaemons", "Background daemon"), ("/Library/PrivilegedHelperTools", "Privileged helper"),
        ("/Library/Preferences", "Preferences (all users)"), ("/Library/Caches", "Cache (all users)"),
    ]

    nonisolated static func findLeftovers(bundleID: String, name: String, otherIDs: Set<String>) -> [Leftover] {
        let fm = FileManager.default
        let id = bundleID.lowercased()
        let appName = name.lowercased()
        let others = otherIDs.map { $0.lowercased() }.filter { !$0.isEmpty && $0.hasPrefix(id + ".") }

        func matches(_ entry: String, nameAllowed: Bool) -> Bool {
            let e = entry.lowercased()
            if !id.isEmpty {
                // Belongs to a different installed app with a longer ID (e.g. Chrome vs Chrome Canary).
                if others.contains(where: { e == $0 || e.hasPrefix($0 + ".") }) { return false }
                if e == id || e.hasPrefix(id + ".") || e.hasSuffix("." + id) { return true }
            }
            return nameAllowed && appName.count >= 3 && e == appName
        }

        var found: [(URL, String)] = []
        for (place, kind) in leftoverPlaces {
            let dir = home.appendingPathComponent(place)
            let nameAllowed = ["Library/Application Support", "Library/Caches", "Library/Logs"].contains(place)
            for entry in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] where matches(entry, nameAllowed: nameAllowed) {
                found.append((dir.appendingPathComponent(entry), kind))
            }
        }
        for (place, kind) in systemLeftoverPlaces {
            let nameAllowed = place == "/Library/Application Support"
            for entry in (try? fm.contentsOfDirectory(atPath: place)) ?? [] where matches(entry, nameAllowed: nameAllowed) {
                found.append((URL(fileURLWithPath: place).appendingPathComponent(entry), kind))
            }
        }
        // Sandboxed apps keep caches under /private/var/folders.
        if !id.isEmpty {
            let darwinCache = URL(fileURLWithPath: NSTemporaryDirectory()).deletingLastPathComponent().appendingPathComponent("C/" + bundleID)
            if fm.fileExists(atPath: darwinCache.path) { found.append((darwinCache, "Temporary cache")) }
        }
        return found.map { Leftover(url: $0.0, kind: $0.1, size: FileSizer.size(of: $0.0), selected: true) }
            .sorted { $0.size > $1.size }
    }

    // MARK: Orphaned leftovers

    func scanOrphans() async {
        scanningOrphans = true
        let installed = Set(apps.map { $0.bundleID.lowercased() })
        let found = await Task.detached(priority: .userInitiated) { Self.findOrphans(installed: installed) }.value
        withAnimation { orphans = found }
        scanningOrphans = false
        orphansScanned = true
    }

    func removeOrphans() async -> Int64 {
        let picked = orphans.flatMap { $0.items.filter(\.selected) }
        let failed = await Task.detached { picked.filter { !FileOps.remove($0.url, permanent: false) } }.value
        let freed = picked.filter { !failed.contains($0) }.reduce(0) { $0 + $1.size }
        picked.filter { !failed.contains($0) }.forEach { OpLog.write("leftovers", "TRASHED", $0.url.path, bytes: $0.size) }
        withAnimation {
            for g in orphans.indices { orphans[g].items.removeAll { $0.selected && !failed.contains($0) } }
            orphans.removeAll { $0.items.isEmpty }
        }
        toast = "Moved \(Bytes.format(freed)) of leftovers to the Trash" + (failed.isEmpty ? "" : " · \(failed.count) skipped")
        return freed
    }

    nonisolated static func findOrphans(installed: Set<String>) -> [OrphanGroup] {
        let fm = FileManager.default
        var groups: [String: [Leftover]] = [:]
        var touched: [String: Date] = [:]
        var verdicts: [String: Bool] = [:]

        func isInstalled(_ id: String) -> Bool {
            if let v = verdicts[id] { return v }
            var candidate = id
            var result = false
            while candidate.split(separator: ".").count >= 2 {
                if installed.contains(candidate) || NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate) != nil {
                    result = true
                    break
                }
                guard let dot = candidate.lastIndex(of: ".") else { break }
                candidate = String(candidate[..<dot])
            }
            if !result { result = installed.contains { $0.hasPrefix(id + ".") } }
            verdicts[id] = result
            return result
        }

        let places = leftoverPlaces.filter { !["Library/LaunchAgents", "Library/Group Containers", "Library/Preferences/ByHost"].contains($0.0) }
        for (place, kind) in places {
            let dir = home.appendingPathComponent(place)
            for entry in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] {
                var id = entry
                for ext in [".plist", ".savedState", ".binarycookies"] where id.hasSuffix(ext) { id = String(id.dropLast(ext.count)) }
                let lower = id.lowercased()
                guard AppLookup.looksLikeBundleID(id),
                      !lower.hasPrefix("com.apple."), !lower.hasPrefix("group."), !lower.hasPrefix("systemgroup."),
                      !lower.hasPrefix("com.kunal.pangolin"), !isInstalled(lower) else { continue }
                let url = dir.appendingPathComponent(entry)
                groups[lower, default: []].append(Leftover(url: url, kind: kind, size: FileSizer.size(of: url), selected: false))
                if let m = FileSizer.modified(url) { touched[lower] = max(touched[lower] ?? .distantPast, m) }
            }
        }
        return groups.map { OrphanGroup(bundleID: $0.key, items: $0.value.sorted { $0.size > $1.size }, lastTouched: touched[$0.key]) }
            .filter { $0.size > 0 }
            .sorted { $0.size > $1.size }
    }

    // MARK: Startup items

    func loadStartup() async {
        loadingStartup = true
        startup = await Task.detached(priority: .userInitiated) { Self.scanStartup() }.value
        loadingStartup = false
    }

    func setEnabled(_ item: StartupItem, _ on: Bool) async {
        let uid = getuid()
        let ok: Bool = await Task.detached {
            let label = item.label, path = item.url.path
            switch item.domain {
            case .user, .agent:
                let target = "gui/\(uid)/\(label)"
                if on {
                    Shell.run("/bin/launchctl", ["enable", target])
                    Shell.run("/bin/launchctl", ["bootstrap", "gui/\(uid)", path])
                    return true
                }
                let r = Shell.run("/bin/launchctl", ["disable", target])
                Shell.run("/bin/launchctl", ["bootout", target])
                return r.status == 0
            case .daemon:
                let q = Shell.quote(label), p = Shell.quote(path)
                let script = on
                    ? "launchctl enable system/\(q); launchctl bootstrap system \(p) || true"
                    : "launchctl disable system/\(q); launchctl bootout system/\(q) || true"
                return Shell.runAdmin(script).ok
            }
        }.value
        if ok, let i = startup.firstIndex(of: item) {
            withAnimation { startup[i].enabled = on }
            OpLog.write("startup", on ? "ENABLED" : "DISABLED", item.label)
        } else if !ok {
            toast = "Couldn’t change \(item.label)"
        }
    }

    func removeStartup(_ item: StartupItem) async {
        if item.enabled { await setEnabled(item, false) }
        if FileOps.remove(item.url, permanent: false) || FileOps.adminTrash([item.url]) {
            withAnimation { startup.removeAll { $0.id == item.id } }
            OpLog.write("startup", "TRASHED", item.url.path)
        }
    }

    nonisolated static func scanStartup() -> [StartupItem] {
        let uid = getuid()
        func disabled(_ domain: String) -> Set<String> {
            let out = Shell.run("/bin/launchctl", ["print-disabled", domain]).out
            var set = Set<String>()
            for line in out.split(separator: "\n") where line.contains("=> disabled") || line.contains("=> true") {
                if let q1 = line.firstIndex(of: "\""), let q2 = line[line.index(after: q1)...].firstIndex(of: "\"") {
                    set.insert(String(line[line.index(after: q1)..<q2]))
                }
            }
            return set
        }
        let guiDisabled = disabled("gui/\(uid)")
        let systemDisabled = disabled("system")
        let sources: [(URL, StartupItem.Domain)] = [
            (home.appendingPathComponent("Library/LaunchAgents"), .user),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), .agent),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), .daemon),
        ]
        var items: [StartupItem] = []
        for (dir, domain) in sources {
            for plist in CleanCatalog.kids(dir) where plist.pathExtension == "plist" {
                let d = NSDictionary(contentsOf: plist) as? [String: Any] ?? [:]
                let label = d["Label"] as? String ?? plist.deletingPathExtension().lastPathComponent
                let program = d["Program"] as? String ?? (d["ProgramArguments"] as? [String])?.first ?? ""
                let off = (d["Disabled"] as? Bool ?? false) || (domain == .daemon ? systemDisabled : guiDisabled).contains(label)
                items.append(StartupItem(url: plist, label: label, program: program, domain: domain, enabled: !off))
            }
        }
        return items.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }
}
