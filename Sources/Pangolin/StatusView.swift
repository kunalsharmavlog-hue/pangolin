import SwiftUI

struct StatusView: View {
    @EnvironmentObject var m: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(title: "Status",
                           subtitle: "\(m.hostName) · \(m.chip.isEmpty ? m.model : m.chip) · \(m.osVersion) · up \(Fmt.duration(m.uptime))",
                           icon: "waveform.path.ecg", tint: Theme.teal) { EmptyView() }
                    .padding(.bottom, 4)

                HStack(alignment: .top, spacing: 16) {
                    HealthCard().frame(width: 290)
                    CPUCard()
                }
                .fixedSize(horizontal: false, vertical: true)
                .scrollReveal()

                HStack(alignment: .top, spacing: 16) {
                    MemoryCard()
                    DiskCard()
                }
                .fixedSize(horizontal: false, vertical: true)
                .scrollReveal()

                HStack(alignment: .top, spacing: 16) {
                    NetworkCard()
                    PowerCard()
                }
                .fixedSize(horizontal: false, vertical: true)
                .scrollReveal()

                ProcessesCard()
                    .scrollReveal()
            }
            .padding(28)
        }
.scrollProgressRail()
    }
}

private struct HealthCard: View {
    @EnvironmentObject var m: SystemMonitor

    var body: some View {
        let h = m.health
        let tint = Theme.scoreColor(h.score)
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardTitle(title: "Health", icon: "heart.fill", tint: tint)
                HStack {
                    Spacer()
                    RingGauge(progress: Double(h.score) / 100, colors: [tint, tint.opacity(0.55)], lineWidth: 13) {
                        VStack(spacing: 0) {
                            Text("\(h.score)").font(Theme.rounded(46, .bold)).foregroundStyle(Theme.text).contentTransition(.numericText())
                            Text(h.grade).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
                        }
                    }
                    .frame(width: 150, height: 150)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 7) {
                    if h.issues.isEmpty {
                        Label("All checks passed", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12.5, weight: .medium)).foregroundStyle(Theme.sage)
                    }
                    ForEach(h.issues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 12.5, weight: .medium)).foregroundStyle(Theme.amber)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct CPUCard: View {
    @EnvironmentObject var m: SystemMonitor

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    CardTitle(title: "Processor", icon: "cpu", tint: Theme.amber)
                    Spacer()
                    Text("Load \(String(format: "%.2f  %.2f  %.2f", m.load[0], m.load[1], m.load[2]))")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.muted)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Fmt.percent(m.cpu)).font(Theme.rounded(40, .bold)).foregroundStyle(Theme.text).monospacedDigit().contentTransition(.numericText())
                    Text("in use · \(m.cores.count) cores").font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Sparkline(values: m.cpuHistory, color: Theme.amber, ceiling: 1).frame(height: 70)
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(m.cores.enumerated()), id: \.offset) { _, v in
                        GeometryReader { geo in
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(colors: [v > 0.8 ? Theme.rose : Theme.amber, Theme.copper], startPoint: .top, endPoint: .bottom))
                                    .frame(height: max(3, geo.size.height * v))
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.05)))
                    }
                }
                .frame(height: 38)
                .animation(.easeOut(duration: 0.5), value: m.cores)
            }
        }
    }
}

private struct MemoryCard: View {
    @EnvironmentObject var m: SystemMonitor

    var body: some View {
        let segments: [(String, UInt64, Color)] = [
            ("App", m.memApp, Theme.violet), ("Wired", m.memWired, Theme.sky),
            ("Compressed", m.memCompressed, Theme.rose), ("Cached", m.memCached, Theme.faint),
        ]
        let pressure = m.pressureLevel >= 4 ? ("Critical", Theme.rose) : m.pressureLevel >= 2 ? ("Warning", Theme.amber) : ("Normal", Theme.sage)
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    CardTitle(title: "Memory", icon: "memorychip", tint: Theme.violet)
                    Spacer()
                    Chip(text: "Pressure · \(pressure.0)", tint: pressure.1)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Bytes.format(Int64(m.memUsed))).font(Theme.rounded(32, .bold)).foregroundStyle(Theme.text).monospacedDigit()
                    Text("of \(Bytes.format(Int64(m.memTotal)))").font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(segments, id: \.0) { seg in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(seg.2)
                                .frame(width: max(0, geo.size.width * CGFloat(Double(seg.1) / Double(max(m.memTotal, 1))) - 2))
                        }
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 14)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)))
                HStack(spacing: 14) {
                    ForEach(segments, id: \.0) { seg in
                        HStack(spacing: 5) {
                            Circle().fill(seg.2).frame(width: 7, height: 7)
                            Text("\(seg.0) \(Bytes.format(Int64(seg.1)))").font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }
                    }
                }
                Sparkline(values: m.memHistory, color: Theme.violet, ceiling: 1).frame(height: 40)
                Text("Swap used \(Bytes.format(Int64(m.swapUsed)))").font(.system(size: 11.5)).foregroundStyle(Theme.muted)
            }
        }
    }
}

private struct DiskCard: View {
    @EnvironmentObject var m: SystemMonitor
    @EnvironmentObject var router: Router

    var body: some View {
        let tint = m.diskRatio > 0.9 ? Theme.rose : m.diskRatio > 0.8 ? Theme.amber : Theme.teal
        Card {
            VStack(alignment: .leading, spacing: 14) {
                CardTitle(title: "Startup Disk", icon: "internaldrive", tint: tint)
                HStack(spacing: 22) {
                    RingGauge(progress: m.diskRatio, colors: [tint, Theme.sky], lineWidth: 11) {
                        Text(Fmt.percent(m.diskRatio)).font(Theme.rounded(22, .bold)).foregroundStyle(Theme.text)
                    }
                    .frame(width: 112, height: 112)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Bytes.format(m.diskFree)).font(Theme.rounded(30, .bold)).foregroundStyle(Theme.text)
                        Text("free of \(Bytes.format(m.diskTotal))").font(.system(size: 13)).foregroundStyle(Theme.muted)
                        HStack(spacing: 8) {
                            Button { router.go(.clean) } label: { Label("Clean", systemImage: "sparkles") }
                                .buttonStyle(GhostButtonStyle(tint: Theme.amber))
                            Button { router.go(.analyze) } label: { Label("Analyze", systemImage: "chart.pie") }
                                .buttonStyle(GhostButtonStyle())
                        }
                        .padding(.top, 6)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct NetworkCard: View {
    @EnvironmentObject var m: SystemMonitor

    var body: some View {
        let ceiling = max(m.netInHistory.max() ?? 0, m.netOutHistory.max() ?? 0, 1024)
        Card {
            VStack(alignment: .leading, spacing: 14) {
                CardTitle(title: "Network", icon: "antenna.radiowaves.left.and.right", tint: Theme.teal)
                HStack(spacing: 28) {
                    rate("Download", m.netIn, "arrow.down", Theme.teal)
                    rate("Upload", m.netOut, "arrow.up", Theme.copper)
                }
                ZStack {
                    Sparkline(values: m.netInHistory, color: Theme.teal, ceiling: ceiling)
                    Sparkline(values: m.netOutHistory, color: Theme.copper, ceiling: ceiling)
                }
                .frame(height: 70)
            }
        }
    }

    private func rate(_ title: String, _ value: Double, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
                .frame(width: 28, height: 28).background(Circle().fill(tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 1) {
                Text(Bytes.rate(value)).font(Theme.rounded(18, .bold)).foregroundStyle(Theme.text).monospacedDigit()
                Text(title).font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
        }
    }
}

private struct PowerCard: View {
    @EnvironmentObject var m: SystemMonitor

    var body: some View {
        let thermal: (String, Color) = {
            switch m.thermal {
            case .nominal: return ("Cool", Theme.sage)
            case .fair: return ("Warm", Theme.amber)
            case .serious: return ("Hot", Theme.copper)
            case .critical: return ("Critical", Theme.rose)
            @unknown default: return ("Unknown", Theme.muted)
            }
        }()
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    CardTitle(title: "Power & Thermal", icon: "bolt.fill", tint: Theme.sage)
                    Spacer()
                    Chip(text: "Thermal · \(thermal.0)", tint: thermal.1)
                }
                if let b = m.battery {
                    HStack(spacing: 18) {
                        BatteryGlyph(percent: b.percent, charging: b.charging)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(b.percent)%").font(Theme.rounded(30, .bold)).foregroundStyle(Theme.text)
                            Text(b.charging ? "Charging" + (b.minutesRemaining.map { " · full in \(Fmt.duration(Double($0 * 60)))" } ?? "")
                                 : b.pluggedIn ? "Plugged in" : "On battery" + (b.minutesRemaining.map { " · \(Fmt.duration(Double($0 * 60))) left" } ?? ""))
                                .font(.system(size: 12.5)).foregroundStyle(Theme.muted)
                        }
                    }
                    HStack(spacing: 8) {
                        if let h = b.health { Chip(text: "Health \(h)%", tint: h >= 80 ? Theme.sage : Theme.amber) }
                        if let c = b.cycles { Chip(text: "\(c) cycles", tint: Theme.sky) }
                        if let t = b.temperature { Chip(text: String(format: "%.1f°C", t), tint: Theme.copper) }
                    }
                } else {
                    HStack(spacing: 14) {
                        Image(systemName: "powerplug.fill").font(.system(size: 30)).foregroundStyle(Theme.sage)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("AC Power").font(Theme.rounded(24, .bold)).foregroundStyle(Theme.text)
                            Text("No internal battery on this Mac").font(.system(size: 12.5)).foregroundStyle(Theme.muted)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct BatteryGlyph: View {
    let percent: Int
    let charging: Bool
    var body: some View {
        let tint = percent < 20 ? Theme.rose : charging ? Theme.sage : Theme.amber
        HStack(spacing: 2) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.faint, lineWidth: 2)
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, 62 * CGFloat(percent) / 100))
                    .padding(4)
                if charging {
                    Image(systemName: "bolt.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white).frame(width: 70)
                }
            }
            .frame(width: 74, height: 36)
            RoundedRectangle(cornerRadius: 2).fill(Theme.faint).frame(width: 4, height: 12)
        }
    }
}

private struct ProcessesCard: View {
    @EnvironmentObject var m: SystemMonitor
    @State private var byMemory = false

    var body: some View {
        let top = Array(m.processes.sorted { byMemory ? $0.memory > $1.memory : $0.cpu > $1.cpu }.prefix(8))
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    CardTitle(title: "Top Processes", icon: "list.bullet.rectangle", tint: Theme.copper)
                    Spacer()
                    Picker("", selection: $byMemory) {
                        Text("CPU").tag(false)
                        Text("Memory").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                ForEach(top) { p in
                    ProcessRow(process: p, byMemory: byMemory)
                }
            }
        }
    }
}

private struct ProcessRow: View {
    let process: ProcessSample
    let byMemory: Bool
    @State private var hover = false

    var body: some View {
        let app = NSRunningApplication(processIdentifier: process.pid)
        HStack(spacing: 12) {
            if let app, let icon = IconCache.app(app, size: 22) {
                Image(nsImage: icon).frame(width: 22, height: 22)
            } else {
                Image(systemName: "gearshape.fill").foregroundStyle(Theme.faint).frame(width: 22, height: 22)
            }
            Text(app?.localizedName ?? process.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text).lineLimit(1)
            Text("PID \(process.pid)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.faint)
            Spacer()
            Text(String(format: "%.1f%%", process.cpu)).font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(byMemory ? Theme.muted : Theme.amber).frame(width: 70, alignment: .trailing)
            Text(Bytes.format(process.memory)).font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(byMemory ? Theme.violet : Theme.muted).frame(width: 90, alignment: .trailing)
            IconButton(symbol: "xmark.circle.fill", help: "Quit process", tint: hover ? Theme.rose : Theme.faint) {
                if let app { app.terminate() } else { kill(process.pid, SIGTERM) }
            }
            .opacity(hover ? 1 : 0.35)
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(hover ? Theme.cardHover : .clear))
        .onHover { hover = $0 }
    }
}
