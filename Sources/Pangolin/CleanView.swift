import SwiftUI

struct CleanView: View {
    @EnvironmentObject var engine: CleanEngine
    @EnvironmentObject var monitor: SystemMonitor
    @State private var confirm = false
    @State private var hasFDA = Permissions.hasFullDiskAccess

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "Clean", subtitle: "Sniff out caches, logs and leftovers burrowed across your Mac.",
                       icon: "sparkles", tint: Theme.amber) {
                if engine.phase == .results {
                    Button { Task { await engine.scan() } } label: { Label("Rescan", systemImage: "arrow.clockwise") }
                        .buttonStyle(GhostButtonStyle())
                }
            }
            .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 18)

            content
        }
        .alert("Clean \(Bytes.format(engine.totalSelected))?", isPresented: $confirm) {
            Button("Clean", role: .destructive) {
                Task {
                    await engine.clean()
                    monitor.refreshDisk()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(engine.safeMode
                 ? "Everything goes to the Trash so you can put it back."
                 : "Caches, logs and the Trash are deleted for good (apps rebuild caches). Installers, attachments and backups go to the Trash.")
        }
        .onAppear { hasFDA = Permissions.hasFullDiskAccess }
    }

    @ViewBuilder private var content: some View {
        switch engine.phase {
        case .idle:
            ScanHero(title: "Ready to forage",
                     subtitle: "Pangolin digs through app & browser caches, logs, developer junk, Premiere/After Effects media caches, old installers and the Trash.",
                     button: "Scan for junk") { Task { await engine.scan() } }
        case .scanning:
            ScanHero(title: Bytes.format(engine.totalFound), subtitle: "of junk found so far", scanning: true,
                     status: "Sniffing through \(engine.status)…")
        case .results:
            results
        case .cleaning:
            ProgressHero(title: "Gobbling up junk…", status: engine.status, progress: engine.progress)
        case .done:
            DoneHero(headline: Bytes.format(engine.freed + engine.trashed) + " cleared",
                     detail: doneDetail) { engine.reset() }
        }
    }

    private var doneDetail: String {
        var parts = ["\(engine.cleanedCount) items cleaned."]
        if engine.trashed > 0 { parts.append("\(Bytes.format(engine.trashed)) moved to the Trash.") }
        if engine.failures > 0 { parts.append("\(engine.failures) were in use or protected and were skipped.") }
        parts.append("\(Bytes.format(monitor.diskFree)) now free.")
        return parts.joined(separator: " ")
    }

    private var results: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if !hasFDA { AccessBanner().padding(.bottom, 4) }
                    if engine.categories.isEmpty {
                        EmptyNote(icon: "leaf", title: "Spotless", detail: "Nothing worth cleaning right now.")
                    }
                    ForEach($engine.categories) { $category in
                        CategoryCard(category: $category)
                            .scrollReveal()
                    }
                }
                .padding(.horizontal, 28).padding(.bottom, 20)
            }
.scrollProgressRail()
            cleanBar
        }
    }

    private var cleanBar: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 1) {
                Text("SELECTED").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(Theme.muted)
                Text(Bytes.format(engine.totalSelected)).font(Theme.rounded(24, .bold)).foregroundStyle(Theme.text)
                    .monospacedDigit().contentTransition(.numericText())
            }
            Text("of \(Bytes.format(engine.totalFound)) found").font(.system(size: 12.5)).foregroundStyle(Theme.muted)
            Spacer()
            Toggle(isOn: $engine.safeMode) {
                Text("Safe mode: move everything to Trash").font(.system(size: 12.5)).foregroundStyle(Theme.muted)
            }
            .toggleStyle(.switch).controlSize(.small).tint(Theme.amber)
            Button { confirm = true } label: { Label("Clean", systemImage: "sparkles") }
                .buttonStyle(GlowButtonStyle(large: true))
                .disabled(engine.totalSelected == 0)
        }
        .padding(.horizontal, 28).padding(.vertical, 16)
        .background(Theme.panel.opacity(0.92))
        .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }
}

private struct CategoryCard: View {
    @Binding var category: CleanCategory
    @State private var expanded = false
    @State private var hover = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CheckBox(state: category.selectionState) { category.toggleAll() }
                TintIcon(symbol: category.icon, tint: category.tint, size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(category.title).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Theme.text)
                        if !category.permanent { Chip(text: "to Trash", tint: Theme.teal) }
                    }
                    Text(category.detail).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 12)
                Text("\(category.items.count) item\(category.items.count == 1 ? "" : "s")")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.faint)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Bytes.format(category.size)).font(Theme.rounded(16, .bold)).foregroundStyle(Theme.text).monospacedDigit()
                    if category.selectedSize != category.size {
                        Text("\(Bytes.format(category.selectedSize)) selected").font(.system(size: 10.5)).foregroundStyle(Theme.amber)
                    }
                }
                .frame(minWidth: 90, alignment: .trailing)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.faint)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { expanded.toggle() } }

            if expanded {
                Rectangle().fill(Theme.stroke).frame(height: 1)
                LazyVStack(spacing: 0) {
                    ForEach($category.items) { $item in
                        CleanItemRow(item: $item, tint: category.tint)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(hover ? Theme.cardHover : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(expanded ? category.tint.opacity(0.3) : Theme.stroke))
        .onHover { hover = $0 }
    }
}

private struct CleanItemRow: View {
    @Binding var item: CleanItem
    let tint: Color
    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            CheckBox(state: item.selected) { item.selected.toggle() }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.label).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Theme.text).lineLimit(1)
                Text(Fmt.tilde(item.url)).font(.system(size: 10.5)).foregroundStyle(Theme.faint).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            IconButton(symbol: "magnifyingglass", help: "Reveal in Finder") { FileOps.reveal(item.url) }
                .opacity(hover ? 1 : 0)
            Text(Bytes.format(item.size)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.muted)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.leading, 48).padding(.trailing, 40).padding(.vertical, 5)
        .background(hover ? Color.white.opacity(0.03) : .clear)
        .onHover { hover = $0 }
    }
}
