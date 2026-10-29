import SwiftUI

enum Pane: String, CaseIterable, Identifiable {
    case status, clean, optimize, analyze, apps, purge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status: return "Status"
        case .clean: return "Clean"
        case .optimize: return "Optimize"
        case .analyze: return "Analyze"
        case .apps: return "Apps"
        case .purge: return "Purge"
        }
    }

    var icon: String {
        switch self {
        case .status: return "waveform.path.ecg"
        case .clean: return "sparkles"
        case .optimize: return "bolt.heart.fill"
        case .analyze: return "chart.pie.fill"
        case .apps: return "square.grid.2x2.fill"
        case .purge: return "hammer.fill"
        }
    }

    var tint: Color {
        switch self {
        case .status: return Theme.teal
        case .clean: return Theme.amber
        case .optimize: return Theme.sage
        case .analyze: return Theme.violet
        case .apps: return Theme.sky
        case .purge: return Theme.rose
        }
    }
}

@MainActor
final class Router: ObservableObject {
    @Published var pane: Pane = Pane.allCases.first { Dbg.has("pane=" + $0.rawValue) } ?? .status

    func go(_ next: Pane) {
        guard next != pane else { return }
        withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) { pane = next }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct PangolinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var router = Router()
    @StateObject private var monitor = SystemMonitor()
    @StateObject private var cleaner = CleanEngine()
    @StateObject private var optimizer = OptimizeEngine()
    @StateObject private var analyzer = AnalyzeEngine()
    @StateObject private var apps = AppsEngine()
    @StateObject private var purger = PurgeEngine()
    @StateObject private var scroll = ScrollState()

    init() {
        IconRenderer.handleCommandLine()
        IconRenderer.snapshotIfRequested()
        BrandAssets.renderIfRequested()
    }

    var body: some Scene {
        Window("Pangolin", id: "main") {
            ContentView()
                .environmentObject(router)
                .environmentObject(monitor)
                .environmentObject(cleaner)
                .environmentObject(optimizer)
                .environmentObject(analyzer)
                .environmentObject(apps)
                .environmentObject(purger)
                .environmentObject(scroll)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1120, minHeight: 740)
                .onAppear {
                    monitor.start()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1260, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Go") {
                ForEach(Array(Pane.allCases.enumerated()), id: \.offset) { i, pane in
                    Button(pane.title) { router.go(pane) }
                        .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
                }
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(router)
                .environmentObject(monitor)
                .preferredColorScheme(.dark)
        } label: {
            Image(systemName: "circle.hexagongrid.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @EnvironmentObject var router: Router
    @Namespace private var orbit
    @State private var launched: Bool

    init(skipIntro: Bool = false) {
        _launched = State(initialValue: skipIntro)
    }

    var body: some View {
        ZStack {
            if !Dbg.has("nostars") { Backdrop(tint: router.pane.tint) }
            HStack(spacing: 0) {
                Sidebar(orbit: orbit, showLogo: launched)
                Rectangle()
                    .fill(LinearGradient(colors: [Theme.stroke, Theme.violet.opacity(0.25), Theme.stroke], startPoint: .top, endPoint: .bottom))
                    .frame(width: 1)
                ZStack(alignment: .topTrailing) {
                    if !Dbg.has("noplanet") { PlanetStage(orbit: orbit) }
                    page
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(router.pane)
                    .transition(.warp)
                }
            }
            .opacity(launched ? 1 : 0)
            .scaleEffect(launched ? 1 : 0.94)
            .blur(radius: Dbg.has("noblur") ? 0 : (launched ? 0 : 14))

            if !launched {
                GalaxyIntro(orbit: orbit)
                    .transition(.asymmetric(insertion: .identity, removal: .opacity.combined(with: .scale(scale: 2.6))))
            }
        }
        .task {
            guard !launched else { return }
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            withAnimation(.spring(response: 1.15, dampingFraction: 0.86)) { launched = true }
        }
        .background(Theme.bg)
        .ignoresSafeArea()
        .foregroundStyle(Theme.text)
        .tint(Theme.magenta)
    }

    @ViewBuilder private var page: some View {
        switch router.pane {
        case .status: StatusView()
        case .clean: CleanView()
        case .optimize: OptimizeView()
        case .analyze: AnalyzeView()
        case .apps: AppsView()
        case .purge: PurgeView()
        }
    }
}

/// The current section's planet hangs in the top-right corner. It shares a matched-geometry id with
/// its sidebar twin, so switching sections match-cuts: the new world flies out, the old one flies home.
/// As the page scrolls, the planet drifts up, shrinks and turns, like the globe on weevolveit.com.
private struct PlanetStage: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var scroll: ScrollState
    let orbit: Namespace.ID

    var body: some View {
        let p = scroll.progress
        ZStack(alignment: .topTrailing) {
            Color.clear
            ForEach(Pane.allCases) { pane in
                if pane == router.pane {
                    PlanetView(style: pane.planet)
                        .matchedGeometryEffect(id: pane.rawValue, in: orbit)
                        .frame(width: 250, height: 250)
                        .padding(.top, -95)
                        .padding(.trailing, -70)
                        .opacity(0.9)
                }
            }
        }
        .rotationEffect(.degrees(p * 18), anchor: .topTrailing)
        .scaleEffect(1 - p * 0.18, anchor: .topTrailing)
        .offset(x: p * 30, y: -p * 60)
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.85), value: p)
        .allowsHitTesting(false)
        .onChange(of: router.pane) { scroll.progress = 0 }
    }
}

private struct Sidebar: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var monitor: SystemMonitor
    let orbit: Namespace.ID
    let showLogo: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 11) {
                ZStack {
                    if showLogo {
                        FlexibleLogo()
                            .matchedGeometryEffect(id: "logo", in: orbit)
                            .frame(width: 40, height: 40)
                    }
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Pangolin").font(Theme.rounded(19, .bold)).foregroundStyle(Theme.text)
                    Text("eats the bugs in your Mac").font(.system(size: 10.5)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.top, 50).padding(.bottom, 26).padding(.horizontal, 6)

            ForEach(Pane.allCases) { pane in
                SidebarButton(pane: pane, selected: router.pane == pane, orbit: orbit) {
                    router.go(pane)
                }
            }

            Spacer()

            diskMini
        }
        .padding(14)
        .frame(width: 228)
        .background(Theme.panel.opacity(0.55))
        .zIndex(1)
    }

    private var diskMini: some View {
        let h = monitor.health
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Macintosh HD").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.text)
                Spacer()
                Text("\(Bytes.format(monitor.diskFree)) free").font(.system(size: 10.5)).foregroundStyle(Theme.muted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.violet, Theme.sky], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * monitor.diskRatio)
                        .shadow(color: Theme.violet.opacity(0.6), radius: 4)
                }
            }
            .frame(height: 6)
            HStack(spacing: 6) {
                Circle().fill(Theme.scoreColor(h.score)).frame(width: 7, height: 7).shadow(color: Theme.scoreColor(h.score), radius: 3)
                Text("Health \(h.score) · \(h.grade)").font(.system(size: 10.5)).foregroundStyle(Theme.muted)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke))
        .onTapGesture { router.go(.status) }
    }
}

private struct SidebarButton: View {
    let pane: Pane
    let selected: Bool
    let orbit: Namespace.ID
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    // The empty orbit left behind while this world is out on the stage.
                    Circle()
                        .strokeBorder(pane.tint.opacity(selected ? 0.7 : 0), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .frame(width: 26, height: 26)
                    if !selected {
                        PlanetView(style: pane.planet, animated: false)
                            .matchedGeometryEffect(id: pane.rawValue, in: orbit)
                            .frame(width: 20, height: 20)
                            .scaleEffect(hover ? 1.15 : 1)
                    }
                }
                .frame(width: 28, height: 28)
                Text(pane.title)
                    .font(.system(size: 13.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Theme.text : Theme.muted)
                Spacer()
                if selected {
                    Circle().fill(pane.tint).frame(width: 5, height: 5).shadow(color: pane.tint, radius: 4)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [pane.tint.opacity(0.2), pane.tint.opacity(0.03)], startPoint: .leading, endPoint: .trailing))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(pane.tint.opacity(0.22)))
                } else if hover {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.spring(response: 0.3)) { hover = h } }
    }
}

struct MenuBarView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var router: Router
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let h = monitor.health
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                PangolinLogo(size: 30)
                Text("Pangolin").font(Theme.rounded(16, .bold)).foregroundStyle(Theme.text)
                Spacer()
                Chip(text: "Health \(h.score)", tint: Theme.scoreColor(h.score))
            }
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    metric("CPU", Fmt.percent(monitor.cpu), monitor.cpuHistory, Theme.amber)
                    metric("Memory", Fmt.percent(monitor.memRatio), monitor.memHistory, Theme.violet)
                }
                GridRow {
                    metric("Disk free", Bytes.format(monitor.diskFree), nil, Theme.teal)
                    metric("Network", "↓ " + Bytes.rate(monitor.netIn), monitor.netInHistory, Theme.sky)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("TOP CPU").font(.system(size: 9.5, weight: .bold)).kerning(1).foregroundStyle(Theme.muted)
                ForEach(monitor.processes.sorted { $0.cpu > $1.cpu }.prefix(3)) { p in
                    HStack {
                        Text(p.name).font(.system(size: 12)).foregroundStyle(Theme.text).lineLimit(1)
                        Spacer()
                        Text(String(format: "%.1f%%", p.cpu)).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.amber)
                    }
                }
            }
            HStack {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: { Label("Open Pangolin", systemImage: "macwindow") }
                    .buttonStyle(GlowButtonStyle())
                Button {
                    router.go(.clean)
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: { Label("Clean", systemImage: "sparkles") }
                    .buttonStyle(GhostButtonStyle())
                Spacer()
                IconButton(symbol: "power", help: "Quit Pangolin") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(Theme.bg)
        .onAppear { monitor.start() }
    }

    private func metric(_ title: String, _ value: String, _ history: [Double]?, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10.5)).foregroundStyle(Theme.muted)
            Text(value).font(Theme.rounded(15, .bold)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.7)
            if let history {
                Sparkline(values: Array(history.suffix(30)), color: tint).frame(height: 18)
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.07))
                        Capsule().fill(tint).frame(width: geo.size.width * (1 - monitor.diskRatio))
                    }
                }
                .frame(height: 5).padding(.vertical, 6)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.05)))
    }
}

enum IconRenderer {
    /// `Pangolin --render-icon out.png` writes the 1024px app icon and exits (used by build.sh).
    @MainActor
    static func handleCommandLine() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--render-icon"), i + 1 < args.count else { return }
        let renderer = ImageRenderer(content: AppIconArt())
        renderer.scale = 1
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { exit(1) }
        try? png.write(to: URL(fileURLWithPath: args[i + 1]))
        exit(0)
    }

    /// `Pangolin --snapshot <dir>` renders the launch screen and every section offscreen, for design review.
    @MainActor
    static func snapshotIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1])
        let router = Router(), monitor = SystemMonitor()
        monitor.sample()
        monitor.refreshDisk()
        let apps = AppsEngine(), cleaner = CleanEngine(), optimizer = OptimizeEngine(), analyzer = AnalyzeEngine(), purger = PurgeEngine()
        NSApplication.shared.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1260, height: 820), styleMask: [.borderless], backing: .buffered, defer: false)
        func render(_ name: String, skipIntro: Bool, wait: TimeInterval) {
            let view = ContentView(skipIntro: skipIntro)
                .environmentObject(router).environmentObject(monitor)
                .environmentObject(cleaner).environmentObject(optimizer)
                .environmentObject(analyzer).environmentObject(apps).environmentObject(purger)
                .environmentObject(ScrollState())
                .preferredColorScheme(.dark)
                .frame(width: 1260, height: 820)
            let host = NSHostingView(rootView: view)
            window.contentView = host
            window.orderFront(nil)
            RunLoop.main.run(until: Date().addingTimeInterval(wait))
            if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent(name + ".png"))
            }
        }
        render("intro", skipIntro: false, wait: 1.8)
        for pane in Pane.allCases {
            router.pane = pane
            render(pane.rawValue, skipIntro: true, wait: 2.5)
        }
        exit(0)
    }
}

enum Dbg { static func has(_ k: String) -> Bool { (ProcessInfo.processInfo.environment["PGDBG"] ?? "").contains(k) } }
