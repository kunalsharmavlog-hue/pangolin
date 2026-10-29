import AppKit
import SwiftUI

struct Artifact: Identifiable, Hashable {
    let url: URL
    let kind: String
    var size: Int64
    let modified: Date?
    var selected: Bool
    var id: String { url.path }
    var project: URL { url.deletingLastPathComponent() }
}

@MainActor
final class PurgeEngine: ObservableObject {
    enum Phase { case idle, scanning, results, purging, done }

    @Published var roots: [URL] = [home]
    @Published var phase: Phase = .idle
    @Published var status = ""
    @Published var artifacts: [Artifact] = []
    @Published var freed: Int64 = 0
    @Published var progress: Double = 0

    var selectedSize: Int64 { artifacts.filter(\.selected).reduce(0) { $0 + $1.size } }

    func addRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        if panel.runModal() == .OK {
            for url in panel.urls where !roots.contains(url) { roots.append(url) }
        }
    }

    func scan() async {
        withAnimation { phase = .scanning }
        artifacts = []
        let roots = self.roots
        let found = await Task.detached(priority: .userInitiated) { [weak self] in
            Self.findArtifacts(in: roots) { path in
                Task { @MainActor in self?.status = path }
            }
        }.value
        artifacts = found
        withAnimation(.spring(response: 0.5)) { phase = .results }
    }

    func purge() async {
        let picked = artifacts.filter(\.selected)
        withAnimation { phase = .purging }
        freed = 0
        for (i, a) in picked.enumerated() {
            status = a.project.lastPathComponent + "/" + a.kind
            if await Task.detached(operation: { FileOps.remove(a.url, permanent: true) }).value {
                freed += a.size
                OpLog.write("purge", "DELETED", a.url.path, bytes: a.size)
                artifacts.removeAll { $0.id == a.id }
            }
            progress = Double(i + 1) / Double(picked.count)
        }
        withAnimation(.spring(response: 0.5)) { phase = .done }
    }

    /// Build output a project can always regenerate, keyed by folder name, with the file that proves it's a project.
    nonisolated static let rules: [String: [String]] = [
        "node_modules": ["package.json"],
        ".next": ["package.json"], ".nuxt": ["package.json"], ".svelte-kit": ["package.json"],
        ".turbo": ["package.json"], ".parcel-cache": ["package.json"], ".angular": ["package.json"],
        "target": ["Cargo.toml", "pom.xml"],
        "build": ["build.gradle", "build.gradle.kts", "CMakeLists.txt", "pubspec.yaml"],
        ".gradle": ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"],
        "Pods": ["Podfile"],
        ".dart_tool": ["pubspec.yaml"],
        "vendor": ["composer.json"],
        ".venv": ["pyproject.toml", "requirements.txt", "setup.py"],
        "venv": ["pyproject.toml", "requirements.txt", "setup.py"],
        "DerivedData": [],
    ]

    nonisolated static let skipAtHome: Set<String> = [
        "Library", "Movies", "Music", "Pictures", "Applications", ".Trash", "Creative Cloud Files",
        "iCloud Drive (Archive)", "Public", ".cache", ".npm", ".cargo", ".rustup", ".gradle", "go",
    ]

    nonisolated static func findArtifacts(in roots: [URL], progress: @escaping (String) -> Void) -> [Artifact] {
        let fm = FileManager.default
        var found: [URL: String] = [:]
        for root in roots {
            guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                                             options: [.skipsPackageDescendants], errorHandler: { _, _ in true }) else { continue }
            var count = 0
            for case let url as URL in walker {
                let name = url.lastPathComponent
                if walker.level == 1 && root.path == home.path && skipAtHome.contains(name) {
                    walker.skipDescendants()
                    continue
                }
                guard let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                      v.isDirectory == true, v.isSymbolicLink != true else { continue }
                count += 1
                if count % 400 == 0 { progress(Fmt.tilde(url)) }
                if walker.level > 8 { walker.skipDescendants(); continue }

                if let markers = rules[name] {
                    let parent = url.deletingLastPathComponent()
                    let isProject = markers.isEmpty || markers.contains { fm.fileExists(atPath: parent.appendingPathComponent($0).path) }
                    let isVenv = name.hasSuffix("venv") ? fm.fileExists(atPath: url.appendingPathComponent("pyvenv.cfg").path) : true
                    if isProject && isVenv { found[url] = name }
                    walker.skipDescendants()
                    continue
                }
                if name.hasPrefix(".") && name != ".config" { walker.skipDescendants() }
            }
        }
        progress("Measuring \(found.count) folders")
        let urls = Array(found.keys)
        var sizes = [Int64](repeating: 0, count: urls.count)
        sizes.withUnsafeMutableBufferPointer { buf in
            let base = buf.baseAddress
            DispatchQueue.concurrentPerform(iterations: urls.count) { i in base?[i] = FileSizer.size(of: urls[i]) }
        }
        let weekAgo = Date().addingTimeInterval(-7 * 86_400)
        return zip(urls, sizes).compactMap { url, size in
            guard size > 1_000_000 else { return nil }
            let modified = FileSizer.modified(url.deletingLastPathComponent())
            return Artifact(url: url, kind: found[url] ?? url.lastPathComponent, size: size, modified: modified,
                            selected: (modified ?? .distantPast) < weekAgo)
        }
        .sorted { $0.size > $1.size }
    }
}

struct PurgeView: View {
    @EnvironmentObject var engine: PurgeEngine
    @State private var confirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "Purge", subtitle: "Reclaim space from node_modules, build folders and virtualenvs in old projects.",
                       icon: "hammer.fill", tint: Theme.rose) {
                if engine.phase == .results {
                    Button { Task { await engine.scan() } } label: { Label("Rescan", systemImage: "arrow.clockwise") }
                        .buttonStyle(GhostButtonStyle())
                }
            }
            .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 14)

            rootsBar.padding(.horizontal, 28).padding(.bottom, 12)

            switch engine.phase {
            case .idle:
                ScanHero(title: "Hunt for build junk",
                         subtitle: "Dependencies and build output in projects you haven’t touched in a while. Your code is never touched; everything here can be reinstalled.",
                         button: "Scan projects", tint: Theme.rose) { Task { await engine.scan() } }
            case .scanning:
                ScanHero(title: "Sniffing projects…", subtitle: "Walking your folders for build output.",
                         tint: Theme.rose, scanning: true, status: engine.status)
            case .results:
                results
            case .purging:
                ProgressHero(title: "Purging…", status: engine.status, progress: engine.progress, tint: Theme.rose)
            case .done:
                DoneHero(headline: Bytes.format(engine.freed) + " freed",
                         detail: "Run npm install, cargo build or pip install in a project to bring its dependencies back.") {
                    withAnimation { engine.phase = .results }
                }
            }
        }
        .alert("Delete \(Bytes.format(engine.selectedSize)) of build artifacts?", isPresented: $confirm) {
            Button("Delete", role: .destructive) { Task { await engine.purge() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("These folders are deleted permanently. Each project can rebuild them.")
        }
    }

    private var rootsBar: some View {
        HStack(spacing: 8) {
            Text("Scan in").font(.system(size: 12)).foregroundStyle(Theme.muted)
            ForEach(engine.roots, id: \.self) { root in
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill").font(.system(size: 10)).foregroundStyle(Theme.rose)
                    Text(root.path == home.path ? "Home" : root.lastPathComponent).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text)
                    if engine.roots.count > 1 {
                        Button { engine.roots.removeAll { $0 == root } } label: {
                            Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.faint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.06)))
            }
            Button { engine.addRoot() } label: { Label("Add folder", systemImage: "plus") }
                .buttonStyle(GhostButtonStyle())
                .disabled(engine.phase == .scanning)
        }
    }

    private var results: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 6) {
                    if engine.artifacts.isEmpty {
                        EmptyNote(icon: "leaf", title: "No build junk", detail: "No dependency or build folders over 1 MB were found here.")
                    }
                    ForEach($engine.artifacts) { $a in ArtifactRow(artifact: $a).scrollReveal() }
                }
                .padding(.horizontal, 28).padding(.bottom, 20)
            }
.scrollProgressRail()
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("SELECTED").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(Theme.muted)
                    Text(Bytes.format(engine.selectedSize)).font(Theme.rounded(22, .bold)).foregroundStyle(Theme.text)
                }
                Text("Projects edited in the last week are left unticked.").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.leading, 12)
                Spacer()
                Button { confirm = true } label: { Label("Purge", systemImage: "flame.fill") }
                    .buttonStyle(GlowButtonStyle(colors: [Theme.rose, Theme.copper], large: true))
                    .disabled(engine.selectedSize == 0)
            }
            .padding(.horizontal, 28).padding(.vertical, 14)
            .background(Theme.panel.opacity(0.92))
            .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 1) }
        }
    }
}

private struct ArtifactRow: View {
    @Binding var artifact: Artifact
    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            CheckBox(state: artifact.selected) { artifact.selected.toggle() }
            TintIcon(symbol: icon, tint: Theme.rose, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(artifact.project.lastPathComponent).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    Chip(text: artifact.kind, tint: Theme.rose)
                }
                Text(Fmt.tilde(artifact.project) + " · edited " + Fmt.relative(artifact.modified))
                    .font(.system(size: 11)).foregroundStyle(Theme.faint).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            IconButton(symbol: "magnifyingglass", help: "Reveal in Finder") { FileOps.reveal(artifact.url) }.opacity(hover ? 1 : 0)
            Text(Bytes.format(artifact.size)).font(Theme.rounded(14, .bold)).foregroundStyle(Theme.text).frame(width: 84, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(hover ? Theme.cardHover : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke))
        .onHover { hover = $0 }
    }

    private var icon: String {
        switch artifact.kind {
        case "node_modules", ".next", ".nuxt", ".svelte-kit", ".turbo", ".parcel-cache", ".angular": return "shippingbox.fill"
        case ".venv", "venv": return "chevron.left.forwardslash.chevron.right"
        case "target": return "gearshape.2.fill"
        default: return "hammer.fill"
        }
    }
}
