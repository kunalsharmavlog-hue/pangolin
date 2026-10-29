import AppKit
import SwiftUI

struct OptimizeTask: Identifiable {
    enum Status: Equatable {
        case idle, running
        case done(String), skipped(String), failed(String)
    }

    enum Kind {
        case user(@Sendable () -> Status)
        case admin(String)
    }

    let id: String
    let title: String
    let detail: String
    let icon: String
    let group: String
    let kind: Kind
    var selected: Bool
    var status: Status = .idle

    var needsAdmin: Bool {
        if case .admin = kind { return true }
        return false
    }
}

enum OptimizeCatalog {
    static let groups = ["Refresh", "Repair", "Deep maintenance"]

    static func all() -> [OptimizeTask] {
        [
            OptimizeTask(id: "quicklook", title: "Rebuild Quick Look", detail: "Fixes missing, blank or stale thumbnails and previews.",
                         icon: "eye.fill", group: "Refresh", kind: .user {
                Shell.run("/usr/bin/qlmanage", ["-r", "cache"])
                let r = Shell.run("/usr/bin/qlmanage", ["-r"])
                return r.status == 0 ? .done("Previews rebuilt") : .failed("qlmanage failed")
            }, selected: true),
            OptimizeTask(id: "glitches", title: "Fix UI glitches", detail: "Restarts Notification Center, Spotlight UI and input switching.",
                         icon: "wand.and.stars", group: "Refresh", kind: .user {
                for p in ["NotificationCenter", "Spotlight", "TextInputMenuAgent", "TextInputSwitcher"] {
                    Shell.run("/usr/bin/killall", [p])
                }
                return .done("Refreshed")
            }, selected: true),
            OptimizeTask(id: "dock", title: "Refresh Dock & Launchpad", detail: "Clears stuck Dock icons and rebuilds Launchpad.",
                         icon: "dock.rectangle", group: "Refresh", kind: .user {
                Shell.run("/usr/bin/killall", ["Dock"])
                return .done("Dock restarted")
            }, selected: true),
            OptimizeTask(id: "finder", title: "Relaunch Finder & menu bar", detail: "Helps when Finder windows or menu bar icons hang.",
                         icon: "macwindow", group: "Refresh", kind: .user {
                Shell.run("/usr/bin/killall", ["Finder"])
                Shell.run("/usr/bin/killall", ["SystemUIServer"])
                return .done("Relaunched")
            }, selected: false),
            OptimizeTask(id: "quarantine", title: "Clear quarantine history", detail: "Wipes the log of every file you ever downloaded.",
                         icon: "clock.arrow.circlepath", group: "Repair", kind: .user {
                let db = home.appendingPathComponent("Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2").path
                guard FileManager.default.fileExists(atPath: db) else { return .skipped("No history") }
                let r = Shell.run("/usr/bin/sqlite3", [db, "DELETE FROM LSQuarantineEvent; VACUUM;"])
                return r.status == 0 ? .done("History cleared") : .skipped("Database busy")
            }, selected: true),
            OptimizeTask(id: "savedstate", title: "Clear stale window state", detail: "Removes saved windows of apps not opened in 30 days.",
                         icon: "rectangle.stack.badge.minus", group: "Repair", kind: .user {
                let dir = home.appendingPathComponent("Library/Saved Application State")
                let cutoff = Date().addingTimeInterval(-30 * 86_400)
                let stale = CleanCatalog.kids(dir).filter { (FileSizer.modified($0) ?? .distantFuture) < cutoff }
                let n = stale.filter { FileOps.remove($0, permanent: true) }.count
                return n > 0 ? .done("Removed \(n)") : .skipped("Nothing stale")
            }, selected: true),
            OptimizeTask(id: "agents", title: "Remove broken launch agents", detail: "Deletes startup entries pointing at apps that no longer exist.",
                         icon: "bolt.slash.fill", group: "Repair", kind: .user {
                let dir = home.appendingPathComponent("Library/LaunchAgents")
                var removed = 0
                for plist in CleanCatalog.kids(dir) where plist.pathExtension == "plist" {
                    guard let d = NSDictionary(contentsOf: plist) as? [String: Any] else { continue }
                    let program = d["Program"] as? String ?? (d["ProgramArguments"] as? [String])?.first
                    guard let program, program.hasPrefix("/"), !FileManager.default.fileExists(atPath: program) else { continue }
                    if let label = d["Label"] as? String { Shell.run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(label)"]) }
                    if FileOps.remove(plist, permanent: false) { removed += 1 }
                }
                return removed > 0 ? .done("Removed \(removed)") : .skipped("None broken")
            }, selected: true),
            OptimizeTask(id: "launchservices", title: "Rebuild “Open With” menu", detail: "Re-registers apps to remove duplicates and ghosts. Takes a minute.",
                         icon: "list.bullet.indent", group: "Repair", kind: .user {
                let ls = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
                let r = Shell.run(ls, ["-r", "-domain", "local", "-domain", "system", "-domain", "user"])
                return r.status == 0 ? .done("Rebuilt") : .failed("lsregister failed")
            }, selected: false),
            OptimizeTask(id: "fonts", title: "Reset font caches", detail: "Fixes garbled or missing fonts. Apps may need a relaunch.",
                         icon: "textformat", group: "Repair", kind: .user {
                let r = Shell.run("/usr/bin/atsutil", ["databases", "-removeUser"])
                return r.status == 0 ? .done("Font caches reset") : .skipped("Not available")
            }, selected: false),
            OptimizeTask(id: "diskimages", title: "Eject leftover disk images", detail: "Unmounts installer .dmg volumes that are still attached.",
                         icon: "eject.fill", group: "Repair", kind: .user {
                let r = Shell.run("/usr/bin/hdiutil", ["info", "-plist"])
                guard let plist = try? PropertyListSerialization.propertyList(from: Data(r.out.utf8), format: nil) as? [String: Any],
                      let images = plist["images"] as? [[String: Any]] else { return .skipped("None mounted") }
                var n = 0
                for image in images {
                    let entities = image["system-entities"] as? [[String: Any]] ?? []
                    if let dev = entities.compactMap({ $0["dev-entry"] as? String }).sorted().first,
                       Shell.run("/usr/bin/hdiutil", ["detach", dev]).status == 0 { n += 1 }
                }
                return n > 0 ? .done("Ejected \(n)") : .skipped("None mounted")
            }, selected: false),
            OptimizeTask(id: "dns", title: "Flush DNS cache", detail: "Fixes websites that won’t load after network changes.",
                         icon: "network", group: "Deep maintenance", kind: .admin("dscacheutil -flushcache; killall -HUP mDNSResponder"),
                         selected: true),
            OptimizeTask(id: "purge", title: "Free inactive memory", detail: "Releases cached RAM. Useful before heavy renders.",
                         icon: "memorychip.fill", group: "Deep maintenance", kind: .admin("/usr/sbin/purge"), selected: false),
            OptimizeTask(id: "periodic", title: "Run maintenance scripts", detail: "Runs the daily, weekly and monthly macOS housekeeping.",
                         icon: "calendar.badge.clock", group: "Deep maintenance",
                         kind: .admin("[ -x /usr/sbin/periodic ] && /usr/sbin/periodic daily weekly monthly"), selected: false),
            OptimizeTask(id: "spotlight", title: "Reindex Spotlight", detail: "Rebuilds search from scratch. Search is slow for a while.",
                         icon: "magnifyingglass", group: "Deep maintenance", kind: .admin("mdutil -E /"), selected: false),
        ]
    }
}

@MainActor
final class OptimizeEngine: ObservableObject {
    @Published var tasks = OptimizeCatalog.all()
    @Published var running = false
    @Published var finished = false

    var selectedCount: Int { tasks.filter(\.selected).count }

    func run() async {
        running = true
        finished = false
        for i in tasks.indices { tasks[i].status = tasks[i].selected ? .idle : tasks[i].status }

        for i in tasks.indices where tasks[i].selected {
            guard case .user(let job) = tasks[i].kind else { continue }
            tasks[i].status = .running
            let result = await Task.detached(priority: .userInitiated) { job() }.value
            withAnimation { tasks[i].status = result }
            OpLog.write("optimize", "\(result)", tasks[i].id)
        }

        let adminIdx = tasks.indices.filter { tasks[$0].selected && tasks[$0].needsAdmin }
        if !adminIdx.isEmpty {
            let script = adminIdx.compactMap { i -> String? in
                if case .admin(let s) = tasks[i].kind { return "(\(s)) || true" }
                return nil
            }.joined(separator: "; ")
            adminIdx.forEach { tasks[$0].status = .running }
            let (ok, out) = await Task.detached(priority: .userInitiated) { Shell.runAdmin(script) }.value
            for i in adminIdx {
                withAnimation {
                    tasks[i].status = ok ? .done("Completed") : .failed(out.contains("-128") ? "Admin access not granted" : "Failed")
                }
                OpLog.write("optimize", ok ? "RAN" : "FAILED", tasks[i].id)
            }
        }
        running = false
        finished = true
    }
}

struct OptimizeView: View {
    @EnvironmentObject var engine: OptimizeEngine
    @EnvironmentObject var monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "Optimize", subtitle: "Tune-ups that fix glitches, refresh services and tidy system databases.",
                       icon: "bolt.heart.fill", tint: Theme.sage) {
                Button { Task { await engine.run() } } label: {
                    Label(engine.running ? "Working…" : "Run \(engine.selectedCount) task\(engine.selectedCount == 1 ? "" : "s")",
                          systemImage: "bolt.fill")
                }
                .buttonStyle(GlowButtonStyle(colors: [Theme.sage, Theme.teal]))
                .disabled(engine.running || engine.selectedCount == 0)
            }
            .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    insights
                    ForEach(OptimizeCatalog.groups, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(group.uppercased()).font(.system(size: 11, weight: .bold)).kerning(1.1).foregroundStyle(Theme.muted)
                                if group == "Deep maintenance" { Chip(text: "asks for your password once", tint: Theme.amber) }
                            }
                            VStack(spacing: 0) {
                                ForEach($engine.tasks) { $task in
                                    if task.group == group {
                                        OptimizeRow(task: $task, disabled: engine.running)
                                            .scrollReveal()
                                    }
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
                        }
                    }
                }
                .padding(.horizontal, 28).padding(.bottom, 28)
            }
.scrollProgressRail()
        }
    }

    private var insights: some View {
        HStack(spacing: 12) {
            insight("Uptime", Fmt.duration(monitor.uptime), monitor.uptime > 7 * 86_400 ? "A restart would help" : "Recently restarted",
                    "power", monitor.uptime > 7 * 86_400 ? Theme.amber : Theme.sage)
            insight("Memory pressure", monitor.pressureLevel >= 2 ? "Elevated" : "Normal",
                    "\(Bytes.format(Int64(monitor.memUsed))) in use", "memorychip", monitor.pressureLevel >= 2 ? Theme.amber : Theme.sage)
            insight("Free space", Bytes.format(monitor.diskFree), "\(Fmt.percent(1 - monitor.diskRatio)) of disk",
                    "internaldrive", monitor.diskRatio > 0.85 ? Theme.rose : Theme.sage)
        }
    }

    private func insight(_ title: String, _ value: String, _ note: String, _ icon: String, _ tint: Color) -> some View {
        Card(padding: 14) {
            HStack(spacing: 12) {
                TintIcon(symbol: icon, tint: tint, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 11)).foregroundStyle(Theme.muted)
                    Text(value).font(Theme.rounded(17, .bold)).foregroundStyle(Theme.text)
                    Text(note).font(.system(size: 11)).foregroundStyle(tint)
                }
            }
        }
    }
}

private struct OptimizeRow: View {
    @Binding var task: OptimizeTask
    let disabled: Bool
    @State private var hover = false

    var body: some View {
        HStack(spacing: 14) {
            CheckBox(state: task.selected) { if !disabled { task.selected.toggle() } }
            TintIcon(symbol: task.icon, tint: task.needsAdmin ? Theme.amber : Theme.sage, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(task.title).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.text)
                    if task.needsAdmin { Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(Theme.amber) }
                }
                Text(task.detail).font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            Spacer()
            statusView
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(hover ? Color.white.opacity(0.03) : .clear)
        .onHover { hover = $0 }
    }

    @ViewBuilder private var statusView: some View {
        switch task.status {
        case .idle: EmptyView()
        case .running: ProgressView().controlSize(.small)
        case .done(let s): Chip(text: "✓ " + s, tint: Theme.sage)
        case .skipped(let s): Chip(text: s, tint: Theme.muted)
        case .failed(let s): Chip(text: s, tint: Theme.rose)
        }
    }
}
