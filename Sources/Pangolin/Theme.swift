import SwiftUI

enum Theme {
    static let bg = Color(red: 0.06, green: 0.06, blue: 0.065)
    static let panel = Color(red: 0.075, green: 0.075, blue: 0.08)
    static let card = Color(red: 0.09, green: 0.09, blue: 0.095).opacity(0.88)
    static let cardHover = Color(red: 0.12, green: 0.12, blue: 0.13).opacity(0.94)
    static let stroke = Color.white.opacity(0.09)
    static let text = Color(red: 0.94, green: 0.95, blue: 1.0)
    static let muted = Color(red: 0.86, green: 0.88, blue: 1.0).opacity(0.6)
    static let faint = Color(red: 0.86, green: 0.88, blue: 1.0).opacity(0.32)

    static let magenta = Color(red: 0.93, green: 0.12, blue: 0.46)
    static let amber = Color(red: 1.00, green: 0.72, blue: 0.30)
    static let copper = Color(red: 0.91, green: 0.47, blue: 0.26)
    static let bark = Color(red: 0.48, green: 0.25, blue: 0.13)
    static let rose = Color(red: 0.96, green: 0.43, blue: 0.46)
    static let sage = Color(red: 0.50, green: 0.85, blue: 0.58)
    static let teal = Color(red: 0.36, green: 0.80, blue: 0.78)
    static let sky = Color(red: 0.43, green: 0.67, blue: 0.99)
    static let violet = Color(red: 0.67, green: 0.58, blue: 0.99)
    static let sand = Color(red: 0.87, green: 0.77, blue: 0.61)

    static let palette: [Color] = [amber, copper, rose, violet, sky, teal, sage, sand]

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func scoreColor(_ score: Int) -> Color {
        score >= 85 ? sage : score >= 65 ? amber : rose
    }
}

// MARK: - Brand

/// The brand mark: the curled-up pangolin as a little world with a ring and a moon.
struct PangolinLogo: View {
    var size: CGFloat = 40
    var spin = true

    var body: some View {
        DotGlobe(spin: spin)
            .frame(width: size, height: size)
    }
}

struct AppIconArt: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 186, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [Color(red: 0.13, green: 0.13, blue: 0.14), Color(red: 0.04, green: 0.04, blue: 0.045)],
                                      startPoint: .top, endPoint: .bottom))
            DotGrid(spacing: 40).clipShape(shape)
            shape.fill(RadialGradient(colors: [Theme.magenta.opacity(0.22), .clear], center: UnitPoint(x: 0.7, y: 0.3), startRadius: 0, endRadius: 420))
            shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 4)
            DotGlobe(spin: false)
                .frame(width: 640, height: 640)
                .shadow(color: .white.opacity(0.12), radius: 30)
        }
        .frame(width: 824, height: 824)
        .padding(100)
    }
}

// MARK: - Building blocks

struct Card<Content: View>: View {
    var padding: CGFloat
    var content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    @State private var hover = false

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(hover ? Theme.cardHover : Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LinearGradient(colors: [hover ? Color.white.opacity(0.22) : Theme.stroke, Theme.stroke],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
            .scaleEffect(hover ? 1.006 : 1)
            .shadow(color: .black.opacity(hover ? 0.45 : 0), radius: 18, y: 10)
            .onHover { h in withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { hover = h } }
    }
}

struct CardTitle: View {
    let title: String
    let icon: String
    let tint: Color
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
            Text(title.uppercased()).font(.system(size: 10.5, weight: .semibold, design: .monospaced)).kerning(1.4).foregroundStyle(Theme.muted)
        }
    }
}

struct TintIcon: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 34

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(LinearGradient(colors: [tint.opacity(0.24), tint.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).strokeBorder(tint.opacity(0.28)))
            .overlay(Image(systemName: symbol).font(.system(size: size * 0.44, weight: .semibold)).foregroundStyle(tint))
            .frame(width: size, height: size)
    }
}

struct Chip: View {
    let text: String
    var tint: Color = Theme.muted
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}

struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            TintIcon(symbol: icon, tint: tint, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.rounded(28, .bold)).foregroundStyle(Theme.text)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 16)
            trailing
        }
    }
}

struct GlowButtonStyle: ButtonStyle {
    var colors: [Color] = [Theme.magenta, Color(red: 1, green: 0.38, blue: 0.56)]
    var large = false

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        GlowButton(configuration: configuration, colors: colors, large: large)
    }

    private struct GlowButton: View {
        let configuration: ButtonStyleConfiguration
        let colors: [Color]
        let large: Bool
        @Environment(\.isEnabled) private var enabled
        @State private var ripple: CGFloat = 1
        @State private var rippleOpacity: Double = 0
        @State private var hover = false

        var body: some View {
            configuration.label
                .font(Theme.rounded(large ? 15 : 12.5, .semibold))
                .foregroundStyle(colors[0] == Theme.magenta ? Color.white : Color.black.opacity(0.82))
                .padding(.horizontal, large ? 34 : 20)
                .padding(.vertical, large ? 14 : 10)
                .background(Capsule().fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1).blendMode(.overlay))
                .shadow(color: colors[0].opacity(enabled ? 0.45 : 0), radius: configuration.isPressed ? 4 : 16, y: 6)
                .background(
                    Capsule().stroke(colors[0], lineWidth: 1.5)
                        .scaleEffect(ripple)
                        .opacity(rippleOpacity)
                )
                .scaleEffect(configuration.isPressed ? 0.95 : hover ? 1.03 : 1)
                .opacity(enabled ? 1 : 0.38)
                .contentShape(Capsule())
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hover)
                .onHover { hover = $0 }
                .onChange(of: configuration.isPressed) { _, pressed in
                    guard !pressed else { return }
                    ripple = 1
                    rippleOpacity = 0.9
                    withAnimation(.easeOut(duration: 0.65)) {
                        ripple = 1.45
                        rippleOpacity = 0
                    }
                }
        }
    }
}

struct GhostButtonStyle: ButtonStyle {
    var tint: Color = Theme.text

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Theme.panel.opacity(configuration.isPressed ? 0.95 : 0.7)))
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.1 : 0.04)))
            .overlay(Capsule().strokeBorder(Theme.stroke))
            .contentShape(Capsule())
    }
}

struct IconButton: View {
    let symbol: String
    var help: String = ""
    var tint: Color = Theme.muted
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hover ? Theme.text : tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(hover ? 0.1 : 0)))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

/// Checkbox with a mixed state (`nil`).
struct CheckBox: View {
    let state: Bool?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(state == false ? AnyShapeStyle(Color.clear) : AnyShapeStyle(LinearGradient(colors: [Theme.amber, Theme.copper], startPoint: .top, endPoint: .bottom)))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(state == false ? Theme.faint : Color.clear, lineWidth: 1.5)
                if state != false {
                    Image(systemName: state == nil ? "minus" : "checkmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.8))
                }
            }
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct RingGauge<Label: View>: View {
    let progress: Double
    let colors: [Color]
    var lineWidth: CGFloat = 12
    @ViewBuilder var label: Label

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.07), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.002, min(progress, 1)))
                .stroke(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: colors[0].opacity(0.45), radius: 8)
            label
        }
        .animation(.easeOut(duration: 0.7), value: progress)
    }
}

struct Sparkline: View {
    let values: [Double]
    let color: Color
    var ceiling: Double?

    var body: some View {
        GeometryReader { geo in
            let top = max(ceiling ?? (values.max() ?? 1), 0.0001)
            let step = geo.size.width / CGFloat(max(values.count - 1, 1))
            let points = values.enumerated().map { i, v in
                CGPoint(x: CGFloat(i) * step, y: geo.size.height * (1 - CGFloat(min(v / top, 1))))
            }
            ZStack {
                Path { p in
                    guard let first = points.first, let last = points.last else { return }
                    p.move(to: CGPoint(x: first.x, y: geo.size.height))
                    points.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.32), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    points.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/// Big centred call-to-action with the curled-up mascot, used before and during scans.
struct ScanHero: View {
    let title: String
    let subtitle: String
    var button: String = ""
    var buttonIcon: String = "sparkle.magnifyingglass"
    var tint: Color = Theme.amber
    var scanning = false
    var status: String = ""
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            ZStack {
                GalaxyView(tint: tint, speed: scanning ? 5 : 1)
                    .frame(width: 560, height: 560)
                OrbitScene(tint: tint, scanning: scanning)
            }
            .frame(height: 320)

            VStack(spacing: 8) {
                Text(title).font(Theme.rounded(30, .bold)).foregroundStyle(Theme.text).contentTransition(.numericText())
                Text(subtitle).font(.system(size: 14)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center).frame(maxWidth: 480)
            }

            if scanning {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(status).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                .frame(height: 48)
            } else {
                Button(action: action) { Label(button, systemImage: buttonIcon) }
                    .buttonStyle(GlowButtonStyle(large: true))
                    .keyboardShortcut(.defaultAction)
                    .frame(height: 48)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Celebration after a clean / purge / uninstall.
struct DoneHero: View {
    let headline: String
    let detail: String
    var button = "Done"
    let action: () -> Void
    @State private var appear = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(RadialGradient(colors: [Theme.sage.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 150)).frame(width: 300, height: 300)
                Circle().stroke(Theme.sage.opacity(0.35), lineWidth: 2).frame(width: 150, height: 150).scaleEffect(appear ? 1 : 0.6)
                Image(systemName: "checkmark")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(Theme.sage)
                    .scaleEffect(appear ? 1 : 0.3)
                    .opacity(appear ? 1 : 0)
            }
            Text(headline).font(Theme.rounded(34, .bold)).foregroundStyle(Theme.text)
            Text(detail).font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 460)
            Button(button, action: action).buttonStyle(GlowButtonStyle(colors: [Theme.sage, Theme.teal], large: true))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { appear = true } }
    }
}

struct ProgressHero: View {
    let title: String
    let status: String
    let progress: Double
    var tint: Color = Theme.amber

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            RingGauge(progress: progress, colors: [tint, Theme.copper], lineWidth: 14) {
                VStack(spacing: 2) {
                    Text(Fmt.percent(progress)).font(Theme.rounded(34, .bold)).foregroundStyle(Theme.text).monospacedDigit()
                }
            }
            .frame(width: 170, height: 170)
            Text(title).font(Theme.rounded(24, .bold)).foregroundStyle(Theme.text)
            Text(status).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1).frame(maxWidth: 480)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AccessBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill").font(.system(size: 18)).foregroundStyle(Theme.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Give Pangolin Full Disk Access").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                Text("Safari, Mail, Trash and some app data stay hidden until you allow it in System Settings.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button("Open Settings") { Permissions.openFullDiskAccess() }.buttonStyle(GhostButtonStyle(tint: Theme.amber))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.amber.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.amber.opacity(0.25)))
    }
}

struct EmptyNote: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundStyle(Theme.faint)
            Text(title).font(Theme.rounded(17, .semibold)).foregroundStyle(Theme.text)
            Text(detail).font(.system(size: 12.5)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

struct FileIcon: View {
    let url: URL
    var size: CGFloat = 22
    var body: some View {
        Image(nsImage: IconCache.file(url, size: size))
            .frame(width: size, height: size)
    }
}
