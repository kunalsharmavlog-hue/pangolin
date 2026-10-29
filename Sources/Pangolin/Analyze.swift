import AppKit
import SwiftUI

struct DiskEntry: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    var size: Int64?
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

@MainActor
final class AnalyzeEngine: ObservableObject {
    @Published var trail: [URL] = [home]
    @Published var entries: [DiskEntry] = []
    @Published var pending = 0
    @Published var showHidden = false { didSet { cache = [:]; load() } }
    private var cache: [String: [DiskEntry]] = [:]
    private var task: Task<Void, Never>?
    private(set) var started = false

    /// macOS system areas Analyze never descends into from "/".
    private static let rootSkips: Set<String> = ["System", "private", "dev", "Volumes", "cores", "bin", "sbin", "usr", "etc", "var", "tmp", "opt"]

    var current: URL { trail.last ?? home }
    var total: Int64 { entries.reduce(0) { $0 + ($1.size ?? 0) } }

    func startIfNeeded() {
        guard !started else { return }
        started = true
        load()
    }

    func open(_ entry: DiskEntry) {
        guard entry.isDirectory else { return }
        trail.append(entry.url)
        load()
    }

    func jump(to index: Int) {
        trail = Array(trail.prefix(index + 1))
        load()
    }

    func setRoot(_ url: URL) {
        trail = [url]
        load()
    }

    func refresh() {
        cache[current.path] = nil
        load()
    }

    func load() {
        task?.cancel()
        let url = current
        if let cached = cache[url.path] {
            entries = cached
            pending = 0
            return
        }
        let hidden = showHidden
        let isRoot = url.path == "/"
        let kids = ((try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey],
                                                                   options: hidden ? [] : [.skipsHiddenFiles])) ?? [])
            .filter { !(isRoot && Self.rootSkips.contains($0.lastPathComponent)) }
        let initial: [DiskEntry] = kids.compactMap { u in
            let v = try? u.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if v?.isSymbolicLink == true { return nil }
            let dir = v?.isDirectory == true
            return DiskEntry(url: u, isDirectory: dir, size: dir ? nil : FileSizer.size(of: u))
        }
        entries = initial.sorted { ($0.size ?? 0) > ($1.size ?? 0) }
        let dirs = initial.filter(\.isDirectory).map(\.url)
        pending = dirs.count

        task = Task { [weak self] in
            await withTaskGroup(of: (String, Int64).self) { group in
                for dir in dirs {
                    group.addTask { (dir.path, FileSizer.size(of: dir)) }
                }
                for await (path, size) in group {
                    guard let self, !Task.isCancelled else { return }
                    if let i = self.entries.firstIndex(where: { $0.id == path }) { self.entries[i].size = size }
                    self.pending -= 1
                }
            }
            guard let self, !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45)) {
                self.entries.sort { ($0.size ?? 0) > ($1.size ?? 0) }
            }
            self.cache[url.path] = self.entries
        }
    }

    func trash(_ entry: DiskEntry) {
        guard FileOps.remove(entry.url, permanent: false) else { return }
        OpLog.write("analyze", "TRASHED", entry.url.path, bytes: entry.size ?? 0)
        withAnimation { entries.removeAll { $0.id == entry.id } }
        // Parent folder totals are now stale.
        cache = cache.filter { !entry.url.path.hasPrefix($0.key) }
        cache[current.path] = entries
    }
}

struct AnalyzeView: View {
    @EnvironmentObject var engine: AnalyzeEngine
    @State private var hovered: String?
    @State private var pendingTrash: DiskEntry?

    private var volumes: [URL] {
        FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey], options: [.skipHiddenVolumes]) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "Analyze", subtitle: "See what’s eating your disk, folder by folder.",
                       icon: "chart.pie.fill", tint: Theme.violet) {
                HStack(spacing: 8) {
                    Menu {
                        Button("Home folder") { engine.setRoot(home) }
                        Button("Macintosh HD") { engine.setRoot(URL(fileURLWithPath: "/")) }
                        Divider()
                        ForEach(volumes.filter { $0.path != "/" }, id: \.self) { v in
                            Button(v.lastPathComponent) { engine.setRoot(v) }
                        }
                        Divider()
                        Button("Choose folder…") { chooseFolder() }
                    } label: {
                        Label("Location", systemImage: "externaldrive")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .buttonStyle(GhostButtonStyle())
                    Toggle("Hidden", isOn: $engine.showHidden).toggleStyle(.switch).controlSize(.small).tint(Theme.violet)
                        .foregroundStyle(Theme.muted)
                    IconButton(symbol: "arrow.clockwise", help: "Rescan this folder") { engine.refresh() }
                }
            }
            .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 14)

            breadcrumbs.padding(.horizontal, 28).padding(.bottom, 12)

            HStack(alignment: .top, spacing: 16) {
                list
                chartCard.frame(width: 300)
            }
            .padding(.horizontal, 28).padding(.bottom, 24)
        }
        .onAppear { engine.startIfNeeded() }
        .alert("Move “\(pendingTrash?.name ?? "")” to the Trash?", isPresented: Binding(get: { pendingTrash != nil }, set: { if !$0 { pendingTrash = nil } })) {
            Button("Move to Trash", role: .destructive) { if let e = pendingTrash { engine.trash(e) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(Bytes.format(pendingTrash?.size ?? 0)) · you can restore it from the Trash.")
        }
    }

    private var breadcrumbs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(engine.trail.enumerated()), id: \.offset) { i, url in
                    if i > 0 { Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.faint) }
                    Button {
                        engine.jump(to: i)
                    } label: {
                        Text(i == 0 ? (url.path == home.path ? "Home" : url.path == "/" ? "Macintosh HD" : url.lastPathComponent) : url.lastPathComponent)
                            .font(.system(size: 12.5, weight: i == engine.trail.count - 1 ? .semibold : .regular))
                            .foregroundStyle(i == engine.trail.count - 1 ? Theme.text : Theme.muted)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(i == engine.trail.count - 1 ? Theme.violet.opacity(0.18) : .clear))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var list: some View {
        let biggest = max(engine.entries.compactMap(\.size).max() ?? 1, 1)
        return VStack(spacing: 0) {
            HStack {
                Text("\(engine.entries.count) items").font(.system(size: 11.5)).foregroundStyle(Theme.muted)
                Spacer()
                if engine.pending > 0 {
                    ProgressView().controlSize(.mini)
                    Text("sizing \(engine.pending) folder\(engine.pending == 1 ? "" : "s")…").font(.system(size: 11.5)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Rectangle().fill(Theme.stroke).frame(height: 1)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if engine.entries.isEmpty {
                        EmptyNote(icon: "folder", title: "Nothing here", detail: "This folder is empty or Pangolin can’t read it.")
                    }
                    ForEach(Array(engine.entries.enumerated()), id: \.element.id) { i, entry in
                        row(entry, index: i, biggest: biggest)
                            .scrollReveal()
                    }
                }
                .padding(.vertical, 4)
            }
.scrollProgressRail()
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke))
    }

    private func row(_ entry: DiskEntry, index: Int, biggest: Int64) -> some View {
        let tint = index < 8 ? Theme.palette[index] : Theme.faint
        let fraction = Double(entry.size ?? 0) / Double(biggest)
        let share = engine.total > 0 ? Double(entry.size ?? 0) / Double(engine.total) : 0
        let isHover = hovered == entry.id
        return HStack(spacing: 12) {
            FileIcon(url: entry.url, size: 24)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(entry.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text).lineLimit(1)
                    Spacer()
                    if let size = entry.size {
                        Text(Fmt.percent(share)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.faint)
                        Text(Bytes.format(size)).font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.text).frame(width: 84, alignment: .trailing)
                    } else {
                        Text("sizing…").font(.system(size: 11)).foregroundStyle(Theme.faint).frame(width: 84, alignment: .trailing)
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.05))
                        Capsule()
                            .fill(LinearGradient(colors: [tint, tint.opacity(0.55)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(3, geo.size.width * fraction))
                    }
                }
                .frame(height: 5)
            }
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                .foregroundStyle(entry.isDirectory ? Theme.faint : .clear)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(isHover ? Color.white.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .onHover { hovered = $0 ? entry.id : (hovered == entry.id ? nil : hovered) }
        .onTapGesture {
            if entry.isDirectory { engine.open(entry) } else { FileOps.reveal(entry.url) }
        }
        .contextMenu {
            if entry.isDirectory { Button("Open") { engine.open(entry) } }
            Button("Reveal in Finder") { FileOps.reveal(entry.url) }
            Button("Open with default app") { NSWorkspace.shared.open(entry.url) }
            Divider()
            Button("Move to Trash…", role: .destructive) { pendingTrash = entry }
        }
    }

    private struct Slice: Identifiable {
        let id: String
        let name: String
        let size: Int64
        let color: Color
    }

    private var slices: [Slice] {
        let sized = engine.entries.filter { ($0.size ?? 0) > 0 }.sorted { ($0.size ?? 0) > ($1.size ?? 0) }
        var out = sized.prefix(7).enumerated().map { i, e in Slice(id: e.id, name: e.name, size: e.size ?? 0, color: Theme.palette[i]) }
        let rest = sized.dropFirst(7).reduce(Int64(0)) { $0 + ($1.size ?? 0) }
        if rest > 0 { out.append(Slice(id: "other", name: "Everything else", size: rest, color: Color.white.opacity(0.18))) }
        return out
    }

    /// Hand-drawn ring chart; Swift Charts' SectorMark traps on tiny or single slices.
    private var donut: some View {
        let parts = slices
        let total = max(parts.reduce(0.0) { $0 + Double($1.size) }, 1)
        var starts: [Double] = []
        var running = 0.0
        for p in parts {
            starts.append(running)
            running += Double(p.size) / total
        }
        return ZStack {
            Circle().stroke(Color.white.opacity(0.06), lineWidth: 24)
            ForEach(Array(parts.enumerated()), id: \.element.id) { i, part in
                let start = starts[i]
                let end = start + Double(part.size) / total
                Circle()
                    .trim(from: start, to: max(start, end - (parts.count > 1 ? 0.004 : 0)))
                    .stroke(part.color, style: StrokeStyle(lineWidth: 24, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: part.color.opacity(0.55), radius: 6)
            }
        }
        .padding(16)
        .animation(.easeInOut(duration: 0.6), value: parts.map(\.size))
    }

    private var chartCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardTitle(title: "Breakdown", icon: "chart.pie", tint: Theme.violet)
                ZStack {
                    donut
                    VStack(spacing: 2) {
                        Text(Bytes.format(engine.total)).font(Theme.rounded(20, .bold)).foregroundStyle(Theme.text)
                        Text(engine.current.lastPathComponent.isEmpty ? "Macintosh HD" : engine.current.lastPathComponent)
                            .font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1).frame(maxWidth: 120)
                    }
                }
                .frame(height: 230)
                VStack(spacing: 7) {
                    ForEach(slices) { s in
                        HStack(spacing: 8) {
                            Circle().fill(s.color).frame(width: 8, height: 8)
                            Text(s.name).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                            Spacer()
                            Text(Bytes.format(s.size)).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.text)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Analyze"
        if panel.runModal() == .OK, let url = panel.url { engine.setRoot(url) }
    }
}
