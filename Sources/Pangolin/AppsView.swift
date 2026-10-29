import SwiftUI

struct AppsView: View {
    enum Tab: String, CaseIterable { case applications = "Applications", leftovers = "Leftovers", startup = "Startup" }

    @EnvironmentObject var engine: AppsEngine
    @State private var tab: Tab = .applications

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "Apps", subtitle: "Uninstall apps completely, dig up leftovers and tame startup items.",
                       icon: "square.grid.2x2.fill", tint: Theme.sky) {
                HStack(spacing: 4) {
                    ForEach(Tab.allCases, id: \.self) { t in
                        Button { withAnimation(.spring(response: 0.3)) { tab = t } } label: {
                            Text(t.rawValue)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(tab == t ? Color.black.opacity(0.8) : Theme.muted)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Capsule().fill(tab == t ? AnyShapeStyle(LinearGradient(colors: [Theme.sky, Theme.teal], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.clear)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(Capsule().fill(Color.white.opacity(0.05)))
                .overlay(Capsule().strokeBorder(Theme.stroke))
            }
            .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 18)

            Group {
                switch tab {
                case .applications: ApplicationsPane()
                case .leftovers: LeftoversPane()
                case .startup: StartupPane()
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = engine.toast {
                Text(toast)
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Capsule().fill(Theme.panel))
                    .overlay(Capsule().strokeBorder(Theme.sage.opacity(0.4)))
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        withAnimation { engine.toast = nil }
                    }
            }
        }
        .animation(.spring(response: 0.4), value: engine.toast)
    }
}

// MARK: - Applications

private struct ApplicationsPane: View {
    enum Sort: String, CaseIterable { case name = "Name", size = "Size", lastUsed = "Last used" }

    @EnvironmentObject var engine: AppsEngine
    @State private var query = ""
    @State private var sort: Sort = .size

    private var filtered: [InstalledApp] {
        let list = query.isEmpty ? engine.apps : engine.apps.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.bundleID.localizedCaseInsensitiveContains(query)
        }
        switch sort {
        case .name: return list
        case .size: return list.sorted { ($0.size ?? 0) > ($1.size ?? 0) }
        case .lastUsed: return list.sorted { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Theme.faint)
                        TextField("Search apps", text: $query).textFieldStyle(.plain).font(.system(size: 13))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))
                    Picker("", selection: $sort) {
                        ForEach(Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
                .padding(12)
                Rectangle().fill(Theme.stroke).frame(height: 1)
                if engine.loadingApps && engine.apps.isEmpty {
                    ProgressView().padding(40)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filtered) { app in
                                AppRow(app: app, selected: engine.selectedID == app.id) {
                                    Task { await engine.select(app) }
                                }
                                .scrollReveal()
                            }
                        }
                        .padding(6)
                    }
.scrollProgressRail()
                }
            }
            .frame(width: 370)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke))

            AppDetail()
        }
        .padding(.horizontal, 28).padding(.bottom, 24)
        .task { if engine.apps.isEmpty { await engine.loadApps() } }
    }
}

private struct AppRow: View {
    let app: InstalledApp
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                FileIcon(url: app.url, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    Text(app.lastUsed.map { "Used " + Fmt.relative($0) } ?? "No recent use")
                        .font(.system(size: 11)).foregroundStyle(Theme.faint).lineLimit(1)
                }
                Spacer()
                if let size = app.size {
                    Text(Bytes.format(size)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.muted)
                } else {
                    ProgressView().controlSize(.mini)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(selected ? Theme.sky.opacity(0.16) : hover ? Color.white.opacity(0.04) : .clear))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(selected ? Theme.sky.opacity(0.35) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

private struct AppDetail: View {
    @EnvironmentObject var engine: AppsEngine
    @State private var confirm = false

    var body: some View {
        Group {
            if let app = engine.selectedApp {
                detail(app)
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    DotGlobe().frame(width: 110, height: 110)
                    Text("Pick an app").font(Theme.rounded(20, .bold)).foregroundStyle(Theme.text)
                    Text("Pangolin finds its support files, caches, containers, preferences and startup agents so nothing is left behind.")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 360)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke))
    }

    private func detail(_ app: InstalledApp) -> some View {
        let leftoverSize = engine.leftovers.filter(\.selected).reduce(Int64(0)) { $0 + $1.size }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 18) {
                FileIcon(url: app.url, size: 84).shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                VStack(alignment: .leading, spacing: 5) {
                    Text(app.name).font(Theme.rounded(24, .bold)).foregroundStyle(Theme.text)
                    Text([app.version.isEmpty ? nil : "Version \(app.version)", app.bundleID].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).textSelection(.enabled)
                    HStack(spacing: 6) {
                        Chip(text: Bytes.format(app.size ?? 0), tint: Theme.sky)
                        Chip(text: app.lastUsed.map { "Used " + Fmt.relative($0) } ?? "No recent use", tint: Theme.muted)
                    }
                }
                Spacer()
                IconButton(symbol: "magnifyingglass", help: "Reveal in Finder") { FileOps.reveal(app.url) }
            }
            .padding(22)

            Rectangle().fill(Theme.stroke).frame(height: 1)

            HStack {
                Text("LEFTOVERS").font(.system(size: 11, weight: .bold)).kerning(1.1).foregroundStyle(Theme.muted)
                if engine.findingLeftovers { ProgressView().controlSize(.mini) }
                Spacer()
                Text("\(engine.leftovers.count) found · \(Bytes.format(leftoverSize)) selected")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 0) {
                    if !engine.findingLeftovers && engine.leftovers.isEmpty {
                        Text("No leftovers outside the app bundle.").font(.system(size: 12.5)).foregroundStyle(Theme.faint).padding(20)
                    }
                    ForEach($engine.leftovers) { $item in
                        LeftoverRow(item: $item)
                    }
                }
                .padding(.horizontal, 10)
            }
.scrollProgressRail()

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("TOTAL TO REMOVE").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(Theme.muted)
                    Text(Bytes.format((app.size ?? 0) + leftoverSize)).font(Theme.rounded(22, .bold)).foregroundStyle(Theme.text)
                }
                Spacer()
                if app.protected {
                    Chip(text: "Protected by macOS", tint: Theme.muted)
                } else {
                    Button { confirm = true } label: {
                        Label(engine.uninstalling ? "Removing…" : "Uninstall", systemImage: "trash.fill")
                    }
                    .buttonStyle(GlowButtonStyle(colors: [Theme.rose, Theme.copper]))
                    .disabled(engine.uninstalling || engine.findingLeftovers)
                }
            }
            .padding(18)
            .background(Color.white.opacity(0.03))
        }
        .alert("Uninstall \(app.name)?", isPresented: $confirm) {
            Button("Uninstall", role: .destructive) { Task { await engine.uninstall(app) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The app and \(engine.leftovers.filter(\.selected).count) leftover items move to the Trash. The app will be quit if it’s running.")
        }
    }
}

private struct LeftoverRow: View {
    @Binding var item: Leftover
    @State private var hover = false

    var body: some View {
        HStack(spacing: 11) {
            CheckBox(state: item.selected) { item.selected.toggle() }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.url.lastPathComponent).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Theme.text).lineLimit(1)
                    Chip(text: item.kind, tint: item.url.path.hasPrefix("/Library") ? Theme.amber : Theme.sky)
                }
                Text(Fmt.tilde(item.url.deletingLastPathComponent())).font(.system(size: 10.5)).foregroundStyle(Theme.faint)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            IconButton(symbol: "magnifyingglass", help: "Reveal in Finder") { FileOps.reveal(item.url) }.opacity(hover ? 1 : 0)
            Text(Bytes.format(item.size)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.muted)
                .frame(width: 76, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10).fill(hover ? Color.white.opacity(0.04) : .clear))
        .onHover { hover = $0 }
    }
}

// MARK: - Leftovers of deleted apps

private struct LeftoversPane: View {
    @EnvironmentObject var engine: AppsEngine
    @State private var expanded: Set<String> = []
    @State private var confirm = false

    private var selectedSize: Int64 {
        engine.orphans.reduce(0) { $0 + $1.items.filter(\.selected).reduce(0) { $0 + $1.size } }
    }

    var body: some View {
        if engine.scanningOrphans {
            ScanHero(title: "Digging…", subtitle: "Looking for data left behind by apps you already deleted.",
                     tint: Theme.sky, scanning: true, status: "Checking containers, caches and preferences")
        } else if !engine.orphansScanned {
            ScanHero(title: "Ghosts of apps past",
                     subtitle: "Dragging an app to the Trash leaves its containers, caches and preferences behind. Pangolin sniffs them out.",
                     button: "Find leftovers", tint: Theme.sky) {
                Task {
                    if engine.apps.isEmpty { await engine.loadApps() }
                    await engine.scanOrphans()
                }
            }
        } else {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if engine.orphans.isEmpty {
                            EmptyNote(icon: "leaf", title: "No leftovers", detail: "Every bit of app data on this Mac belongs to an installed app.")
                        }
                        ForEach($engine.orphans) { $group in
                            orphanCard($group)
                                .scrollReveal()
                        }
                    }
                    .padding(.horizontal, 28).padding(.bottom, 20)
                }
.scrollProgressRail()
                HStack {
                    Text("Nothing is selected by default. Review each one before removing.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    Spacer()
                    Button { Task { await engine.scanOrphans() } } label: { Label("Rescan", systemImage: "arrow.clockwise") }
                        .buttonStyle(GhostButtonStyle())
                    Button { confirm = true } label: { Label("Remove \(Bytes.format(selectedSize))", systemImage: "trash") }
                        .buttonStyle(GlowButtonStyle(colors: [Theme.sky, Theme.teal]))
                        .disabled(selectedSize == 0)
                }
                .padding(.horizontal, 28).padding(.vertical, 14)
                .background(Theme.panel.opacity(0.92))
                .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 1) }
            }
            .alert("Move \(Bytes.format(selectedSize)) of leftovers to the Trash?", isPresented: $confirm) {
                Button("Move to Trash", role: .destructive) { Task { _ = await engine.removeOrphans() } }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func orphanCard(_ group: Binding<OrphanGroup>) -> some View {
        let g = group.wrappedValue
        let open = expanded.contains(g.id)
        let recent = (g.lastTouched ?? .distantPast) > Date().addingTimeInterval(-7 * 86_400)
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                CheckBox(state: g.selectionState) {
                    let target = g.selectionState != true
                    for i in group.wrappedValue.items.indices { group.wrappedValue.items[i].selected = target }
                }
                TintIcon(symbol: "app.dashed", tint: Theme.sky, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(g.bundleID).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                        if recent { Chip(text: "active recently", tint: Theme.amber) }
                    }
                    Text("\(g.items.count) location\(g.items.count == 1 ? "" : "s") · last touched \(Fmt.relative(g.lastTouched))")
                        .font(.system(size: 11.5)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Text(Bytes.format(g.size)).font(Theme.rounded(15, .bold)).foregroundStyle(Theme.text)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.faint)
                    .rotationEffect(.degrees(open ? 90 : 0))
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    if open { expanded.remove(g.id) } else { expanded.insert(g.id) }
                }
            }
            if open {
                Rectangle().fill(Theme.stroke).frame(height: 1)
                VStack(spacing: 0) {
                    ForEach(group.items) { $item in LeftoverRow(item: $item) }
                }
                .padding(.vertical, 6).padding(.leading, 34).padding(.trailing, 6)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
    }
}

// MARK: - Startup

private struct StartupPane: View {
    @EnvironmentObject var engine: AppsEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    TintIcon(symbol: "power", tint: Theme.amber, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Background launch items").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                        Text("Agents and daemons that start automatically. Turning one off stops it at the next login. System items ask for your password.")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button("Login Items Settings") { Permissions.openLoginItems() }.buttonStyle(GhostButtonStyle())
                    IconButton(symbol: "arrow.clockwise", help: "Reload") { Task { await engine.loadStartup() } }
                }
                if engine.loadingStartup && engine.startup.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(30) }
                ForEach([StartupItem.Domain.user, .agent, .daemon], id: \.self) { domain in
                    let items = engine.startup.filter { $0.domain == domain }
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(domain.rawValue.uppercased()) · \(items.count)").font(.system(size: 11, weight: .bold)).kerning(1.1).foregroundStyle(Theme.muted)
                            VStack(spacing: 0) {
                                ForEach(items) { item in StartupRow(item: item).scrollReveal() }
                            }
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
                        }
                    }
                }
            }
            .padding(.horizontal, 28).padding(.bottom, 24)
        }
.scrollProgressRail()
        .task { if engine.startup.isEmpty { await engine.loadStartup() } }
    }
}

private struct StartupRow: View {
    @EnvironmentObject var engine: AppsEngine
    let item: StartupItem
    @State private var hover = false

    var body: some View {
        let missing = item.program.hasPrefix("/") && !FileManager.default.fileExists(atPath: item.program)
        HStack(spacing: 12) {
            TintIcon(symbol: item.domain == .daemon ? "gearshape.2.fill" : "bolt.fill",
                     tint: item.enabled ? (item.domain == .daemon ? Theme.amber : Theme.sage) : Theme.faint, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.label).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text).lineLimit(1)
                    if missing { Chip(text: "app missing", tint: Theme.rose) }
                }
                Text(item.program.isEmpty ? Fmt.tilde(item.url) : Fmt.tilde(URL(fileURLWithPath: item.program)))
                    .font(.system(size: 10.5)).foregroundStyle(Theme.faint).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            IconButton(symbol: "magnifyingglass", help: "Reveal plist in Finder") { FileOps.reveal(item.url) }.opacity(hover ? 1 : 0)
            IconButton(symbol: "trash", help: "Remove this item", tint: Theme.rose) { Task { await engine.removeStartup(item) } }.opacity(hover ? 1 : 0)
            Toggle("", isOn: Binding(get: { item.enabled }, set: { on in Task { await engine.setEnabled(item, on) } }))
                .toggleStyle(.switch).controlSize(.small).tint(Theme.sage).labelsHidden()
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(hover ? Color.white.opacity(0.03) : .clear)
        .onHover { hover = $0 }
    }
}
