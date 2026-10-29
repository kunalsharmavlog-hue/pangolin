import SwiftUI

// MARK: - Planets

struct PlanetBand {
    let y: CGFloat
    let h: CGFloat
    let color: Color
    var wobble: CGFloat = 0.02
    var freq: Double = 1
    var speed: Double = 0.15
}

struct PlanetStyle {
    let colors: [Color]
    let bands: [PlanetBand]
    let glow: Color
    var ring: [Color]?
    var star = false
}

extension Pane {
    /// Each section lives on its own world.
    var planet: PlanetStyle {
        switch self {
        case .status: // Earth
            return PlanetStyle(
                colors: [Color(red: 0.55, green: 0.82, blue: 1), Color(red: 0.12, green: 0.38, blue: 0.8), Color(red: 0.02, green: 0.07, blue: 0.24)],
                bands: [
                    PlanetBand(y: 0.16, h: 0.14, color: Color(red: 0.3, green: 0.68, blue: 0.42).opacity(0.85), wobble: 0.06, freq: 1.5, speed: 0.22),
                    PlanetBand(y: 0.46, h: 0.18, color: Color(red: 0.36, green: 0.62, blue: 0.36).opacity(0.85), wobble: 0.08, freq: 2.2, speed: 0.18),
                    PlanetBand(y: 0.74, h: 0.1, color: Color(red: 0.62, green: 0.58, blue: 0.4).opacity(0.7), wobble: 0.05, freq: 1.2, speed: 0.2),
                    PlanetBand(y: 0.32, h: 0.05, color: .white.opacity(0.55), wobble: 0.04, freq: 3, speed: 0.4),
                    PlanetBand(y: 0.62, h: 0.04, color: .white.opacity(0.45), wobble: 0.05, freq: 2.6, speed: 0.36),
                ],
                glow: Theme.sky)
        case .clean: // The Sun
            return PlanetStyle(
                colors: [Color(red: 1, green: 0.97, blue: 0.82), Theme.amber, Color(red: 0.86, green: 0.36, blue: 0.12)],
                bands: [
                    PlanetBand(y: 0.12, h: 0.1, color: Color(red: 1, green: 0.55, blue: 0.15).opacity(0.45), wobble: 0.05, freq: 3, speed: 0.5),
                    PlanetBand(y: 0.38, h: 0.08, color: Color(red: 1, green: 0.85, blue: 0.4).opacity(0.5), wobble: 0.06, freq: 4, speed: -0.45),
                    PlanetBand(y: 0.58, h: 0.12, color: Color(red: 0.95, green: 0.45, blue: 0.12).opacity(0.4), wobble: 0.05, freq: 2.5, speed: 0.6),
                    PlanetBand(y: 0.8, h: 0.1, color: Color(red: 1, green: 0.75, blue: 0.3).opacity(0.45), wobble: 0.07, freq: 3.5, speed: -0.5),
                ],
                glow: Theme.amber, star: true)
        case .optimize: // A verdant moon
            return PlanetStyle(
                colors: [Color(red: 0.78, green: 1, blue: 0.82), Color(red: 0.24, green: 0.7, blue: 0.5), Color(red: 0.02, green: 0.18, blue: 0.16)],
                bands: [
                    PlanetBand(y: 0.22, h: 0.08, color: Theme.teal.opacity(0.6), wobble: 0.04, freq: 2, speed: 0.25),
                    PlanetBand(y: 0.5, h: 0.12, color: Color(red: 0.1, green: 0.45, blue: 0.35).opacity(0.7), wobble: 0.05, freq: 1.6, speed: 0.2),
                    PlanetBand(y: 0.76, h: 0.07, color: Theme.teal.opacity(0.5), wobble: 0.03, freq: 2.4, speed: 0.3),
                ],
                glow: Theme.sage)
        case .analyze: // Saturn
            return PlanetStyle(
                colors: [Color(red: 1, green: 0.93, blue: 0.8), Color(red: 0.84, green: 0.68, blue: 0.52), Color(red: 0.26, green: 0.17, blue: 0.2)],
                bands: [
                    PlanetBand(y: 0.2, h: 0.07, color: Color(red: 0.6, green: 0.45, blue: 0.35).opacity(0.6), wobble: 0.01, freq: 1, speed: 0.12),
                    PlanetBand(y: 0.38, h: 0.1, color: Color(red: 0.95, green: 0.85, blue: 0.68).opacity(0.6), wobble: 0.012, freq: 1.4, speed: 0.1),
                    PlanetBand(y: 0.58, h: 0.08, color: Color(red: 0.55, green: 0.4, blue: 0.4).opacity(0.55), wobble: 0.01, freq: 1.2, speed: 0.14),
                    PlanetBand(y: 0.74, h: 0.06, color: Color(red: 0.7, green: 0.6, blue: 0.75).opacity(0.5), wobble: 0.01, freq: 1, speed: 0.1),
                ],
                glow: Theme.violet,
                ring: [Theme.sand.opacity(0.85), Theme.violet.opacity(0.8), Theme.sand.opacity(0.55)])
        case .apps: // Ice giant
            return PlanetStyle(
                colors: [Color(red: 0.84, green: 0.96, blue: 1), Color(red: 0.36, green: 0.66, blue: 0.96), Color(red: 0.04, green: 0.12, blue: 0.34)],
                bands: [
                    PlanetBand(y: 0.3, h: 0.06, color: .white.opacity(0.3), wobble: 0.01, freq: 1, speed: 0.1),
                    PlanetBand(y: 0.6, h: 0.08, color: Color(red: 0.2, green: 0.45, blue: 0.85).opacity(0.5), wobble: 0.012, freq: 1.2, speed: 0.12),
                ],
                glow: Theme.sky,
                ring: [Theme.sky.opacity(0.35), Color.white.opacity(0.35), Theme.sky.opacity(0.25)])
        case .purge: // Mars
            return PlanetStyle(
                colors: [Color(red: 1, green: 0.74, blue: 0.62), Color(red: 0.84, green: 0.36, blue: 0.28), Color(red: 0.22, green: 0.04, blue: 0.08)],
                bands: [
                    PlanetBand(y: 0.2, h: 0.1, color: Color(red: 0.55, green: 0.18, blue: 0.14).opacity(0.6), wobble: 0.06, freq: 2, speed: 0.18),
                    PlanetBand(y: 0.52, h: 0.14, color: Color(red: 0.62, green: 0.22, blue: 0.16).opacity(0.55), wobble: 0.07, freq: 1.7, speed: 0.15),
                    PlanetBand(y: 0.04, h: 0.06, color: .white.opacity(0.5), wobble: 0.02, freq: 2, speed: 0.1),
                ],
                glow: Theme.rose)
        }
    }
}

/// A procedurally painted, slowly turning planet. Fills whatever square it is given, so it scales smoothly mid-flight.
struct PlanetView: View {
    let style: PlanetStyle
    var animated = true

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            if s > 2 {
                sphere(s)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Only the surface bands move; glow, shading and rings are static so the GPU isn't re-blurring them every frame.
    private func sphere(_ s: CGFloat) -> some View {
        ZStack {
            Circle().fill(RadialGradient(colors: style.colors, center: UnitPoint(x: 0.36, y: 0.32), startRadius: 0, endRadius: s * 0.8))
            BandTexture(bands: style.bands, size: s, animated: animated)
            if style.star {
                Circle().fill(RadialGradient(colors: [.white.opacity(0.6), .clear], center: UnitPoint(x: 0.42, y: 0.4), startRadius: 0, endRadius: s * 0.45))
            } else {
                Circle().fill(LinearGradient(stops: [.init(color: .clear, location: 0.38), .init(color: .black.opacity(0.78), location: 1)],
                                             startPoint: UnitPoint(x: 0.22, y: 0.18), endPoint: UnitPoint(x: 0.92, y: 0.96)))
            }
            Circle().strokeBorder(LinearGradient(colors: [Color.white.opacity(0.6), style.glow.opacity(0.35), .clear],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: max(1, s * 0.012))
        }
        .clipShape(Circle())
        .drawingGroup()
        .frame(width: s, height: s)
        .background(
            Circle()
                .fill(RadialGradient(colors: [style.glow.opacity(style.star ? 0.8 : 0.45), style.glow.opacity(style.star ? 0.25 : 0.1), .clear],
                                     center: .center, startRadius: s * 0.42, endRadius: s * (style.star ? 0.95 : 0.72)))
                .frame(width: s * 2, height: s * 2)
        )
        .background(ringHalf(s, back: true))
        .overlay(ringHalf(s, back: false))
    }

    @ViewBuilder
    private func ringHalf(_ s: CGFloat, back: Bool) -> some View {
        if let ring = style.ring {
            ZStack {
                Ellipse()
                    .trim(from: back ? 0.5 : 0, to: back ? 1 : 0.5)
                    .stroke(LinearGradient(colors: ring, startPoint: .leading, endPoint: .trailing), lineWidth: s * 0.07)
                Ellipse()
                    .trim(from: back ? 0.5 : 0, to: back ? 1 : 0.5)
                    .stroke(ring[0].opacity(0.5), lineWidth: max(0.5, s * 0.015))
                    .padding(-s * 0.08)
            }
            .frame(width: s * 2.0, height: s * 0.5)
            .rotationEffect(.degrees(-16))
            .opacity(back ? 0.7 : 1)
        }
    }
}

/// Two planet-widths of seamless surface bands, painted once and slid sideways on a slow 12 fps clock.
private struct BandTexture: View {
    let bands: [PlanetBand]
    let size: CGFloat
    let animated: Bool

    var body: some View {
        Color.clear
            .frame(width: size, height: size)
            .overlay(alignment: .leading) {
                TimelineView(.animation(minimumInterval: 1.0 / 12, paused: !animated)) { tl in
                    let t = animated ? tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000) : 0
                    BandCanvas(bands: bands, size: size)
                        .equatable()
                        .offset(x: -CGFloat((t * Double(size) / 45).truncatingRemainder(dividingBy: Double(size))))
                }
            }
    }
}

private struct BandCanvas: View, Equatable {
    let bands: [PlanetBand]
    let size: CGFloat

    static func == (a: BandCanvas, b: BandCanvas) -> Bool { a.size == b.size && a.bands.count == b.bands.count }

    var body: some View {
        Canvas { ctx, canvas in
            for band in bands {
                ctx.fill(path(band, canvas), with: .color(band.color))
            }
        }
        .frame(width: size * 2, height: size)
        .blur(radius: size * 0.022)
        .drawingGroup()
    }

    /// The wave repeats every `size` points, so sliding by exactly one width loops seamlessly.
    private func path(_ band: PlanetBand, _ canvas: CGSize) -> Path {
        var p = Path()
        let steps = 56
        let cycles = max(1, band.freq.rounded())
        let y0 = canvas.height * band.y, thickness = canvas.height * band.h, amp = canvas.height * band.wobble
        func point(_ i: Int, _ offset: CGFloat, _ phase: Double) -> CGPoint {
            let x = canvas.width * CGFloat(i) / CGFloat(steps)
            let wave = sin(Double(x / size) * .pi * 2 * cycles + phase)
            return CGPoint(x: x, y: y0 + offset + amp * CGFloat(wave))
        }
        p.move(to: point(0, 0, 0))
        for i in 1...steps { p.addLine(to: point(i, 0, 0)) }
        for i in stride(from: steps, through: 0, by: -1) { p.addLine(to: point(i, thickness, 0.9)) }
        p.closeSubpath()
        return p
    }
}

// MARK: - Deep space backdrop

private struct SeededRandom {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

private struct Star {
    let x: Double, y: Double, r: CGFloat, alpha: Double
    let twinkle: Double, phase: Double, drift: Double
    let color: Color
}

struct Starfield: View {
    private static let stars: [Star] = {
        var rng = SeededRandom(state: 0xFAB1E5)
        let tints: [Color] = [.white, .white, .white, Color(red: 0.75, green: 0.82, blue: 1), Color(red: 1, green: 0.88, blue: 0.75)]
        return (0..<300).map { i in
            let x = rng.next()
            // 40% of stars gather along a diagonal Milky Way band.
            let y = i % 5 < 2 ? min(max(0.82 - 0.62 * x + (rng.next() - 0.5) * 0.22, 0), 1) : rng.next()
            let big = rng.next() > 0.93
            return Star(x: x, y: y, r: big ? CGFloat(1.2 + rng.next() * 0.9) : CGFloat(0.35 + rng.next() * 0.7),
                        alpha: 0.35 + rng.next() * 0.6, twinkle: 0.6 + rng.next() * 2.2, phase: rng.next() * 6.3,
                        drift: 1 + rng.next() * 4, color: tints[Int(rng.next() * Double(tints.count)) % tints.count])
        }
    }()

    /// Stars are painted once; only the occasional shooting star moves.
    var body: some View {
        ZStack {
            Canvas { ctx, size in draw(&ctx, size) { _ in true } }
                .drawingGroup()
            ShootingStar()
        }
        .allowsHitTesting(false)
    }
}

extension Starfield {
    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ include: (Star) -> Bool) {
        for s in Self.stars where include(s) {
            let rect = CGRect(x: s.x * size.width - s.r, y: s.y * size.height - s.r, width: s.r * 2, height: s.r * 2)
            ctx.opacity = s.alpha
            if s.r > 1.2 {
                ctx.fill(Path(ellipseIn: rect.insetBy(dx: -s.r * 2.5, dy: -s.r * 2.5)), with: .color(s.color.opacity(0.12)))
            }
            ctx.fill(Path(ellipseIn: rect), with: .color(s.color))
        }
    }
}

private struct ShootingStar: View {
    @State private var progress: CGFloat = 0
    @State private var origin = CGPoint(x: 0.7, y: 0.15)

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(LinearGradient(colors: [.clear, .white.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 110, height: 1.6)
                .rotationEffect(.degrees(150))
                .position(x: geo.size.width * origin.x - 280 * progress, y: geo.size.height * origin.y + 160 * progress)
                .opacity(progress > 0 && progress < 1 ? Double(sin(progress * .pi)) : 0)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 9_000_000_000)
                origin = CGPoint(x: .random(in: 0.4...0.95), y: .random(in: 0.05...0.4))
                progress = 0
                withAnimation(.easeIn(duration: 1.0)) { progress = 1 }
            }
        }
    }
}

struct Backdrop: View {
    let tint: Color

    var body: some View {
        ZStack {
            Theme.bg
            DotGrid()
            RadialGradient(colors: [tint.opacity(0.13), .clear], center: UnitPoint(x: 0.92, y: 0.04), startRadius: 0, endRadius: 650)
            RadialGradient(colors: [Theme.violet.opacity(0.07), .clear], center: UnitPoint(x: 0.1, y: 0.95), startRadius: 0, endRadius: 560)
            Starfield()
        }
        // The haze is far wider than the window, so it sits in an overlay where it can't widen the layout.
        .overlay {
            // Milky Way haze: a stretched radial glow, soft at every edge without a blur pass.
            EllipticalGradient(colors: [Color(red: 0.72, green: 0.7, blue: 1).opacity(0.08), Color(red: 1, green: 0.88, blue: 0.78).opacity(0.03), .clear])
                .frame(width: 2000, height: 320)
                .rotationEffect(.degrees(-28))
                .allowsHitTesting(false)
        }
        .clipped()
        .animation(.easeInOut(duration: 0.9), value: tint)
        .ignoresSafeArea()
    }
}

// MARK: - Spiral galaxy

/// A three-armed spiral galaxy of ~1,600 stars, tilted toward the viewer and turning slowly.
struct GalaxyView: View {
    var tint: Color = Theme.violet
    var speed: Double = 1

    fileprivate struct Particle {
        let r: Double
        let a: Double
        let size: CGFloat
        let alpha: Double
        let color: Color
    }

    fileprivate static let core = Color(red: 1, green: 0.93, blue: 0.82)
    fileprivate static let particles: [Particle] = {
        var rng = SeededRandom(state: 0x6A1A_C7)
        let mid = Color(red: 0.86, green: 0.74, blue: 1)
        let outer = Color(red: 0.58, green: 0.72, blue: 1)
        return (0..<1600).map { i in
            let arm = Double(i % 3)
            let r = pow(rng.next(), 0.8)
            let spread = (rng.next() - 0.5) * (0.55 * (1 - r) + 0.22)
            let a = arm * 2 * .pi / 3 + r * 4.4 + spread
            let pick = rng.next()
            let color = r < 0.16 ? core : r < 0.5 ? (pick > 0.5 ? mid : core) : (pick > 0.3 ? outer : mid)
            return Particle(r: r, a: a, size: CGFloat(0.5 + rng.next() * (r < 0.2 ? 1.7 : 1.2)),
                            alpha: 0.25 + rng.next() * 0.7, color: color)
        }
    }()

    /// Painted once as a flat disc, then turned, squashed and tilted as a transform on a 20 fps clock.
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000)
            GalaxyDisc(tint: tint)
                .equatable()
                .rotationEffect(.degrees(t * 360 / (160 / speed)))
        }
        .scaleEffect(x: 1, y: 0.56)
        .rotationEffect(.degrees(-16))
        .allowsHitTesting(false)
    }
}

private struct GalaxyDisc: View, Equatable {
    let tint: Color

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)),
                     with: .radialGradient(Gradient(colors: [tint.opacity(0.22), tint.opacity(0.05), .clear]), center: c, startRadius: 0, endRadius: radius))
            for p in GalaxyView.particles {
                let x = c.x + cos(p.a) * p.r * radius
                let y = c.y + sin(p.a) * p.r * radius
                ctx.opacity = p.alpha
                ctx.fill(Path(ellipseIn: CGRect(x: x - p.size / 2, y: y - p.size / 2, width: p.size, height: p.size)), with: .color(p.color))
            }
            ctx.opacity = 1
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - radius * 0.3, y: c.y - radius * 0.3, width: radius * 0.6, height: radius * 0.6)),
                     with: .radialGradient(Gradient(colors: [Color.white.opacity(0.85), GalaxyView.core.opacity(0.35), .clear]),
                                           center: c, startRadius: 0, endRadius: radius * 0.3))
        }
        .drawingGroup()
    }
}

/// The logo at any size, so it can scale smoothly during a matched-geometry flight.
struct FlexibleLogo: View {
    var morphStart: Date?

    var body: some View {
        GeometryReader { geo in
            DotGlobe(morphStart: morphStart)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// Launch screen: the galaxy fills the window, then the logo match-cuts from its core into the sidebar.
struct GalaxyIntro: View {
    let orbit: Namespace.ID
    @State private var appear = false
    @State private var start = Date()

    var body: some View {
        ZStack {
            GalaxyView(tint: Theme.violet, speed: 2.2)
                .frame(width: 900, height: 900)
                .scaleEffect(appear ? 1 : 0.55)
                .opacity(appear ? 1 : 0)
            // Stars fill a glass sphere, then settle into the dotted globe before it flies to the sidebar.
            FlexibleLogo(morphStart: start)
                .matchedGeometryEffect(id: "logo", in: orbit)
                .frame(width: 230, height: 230)
                .scaleEffect(appear ? 1 : 0.7)
            VStack(spacing: 6) {
                Text("Pangolin").font(Theme.rounded(36, .bold)).foregroundStyle(Theme.text)
                Text("Hunting down the bugs in your Mac").font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            .offset(y: 175)
            .opacity(appear ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { withAnimation(.easeOut(duration: 1.6)) { appear = true } }
    }
}

// MARK: - Orbit hero (scan screens)

struct OrbitScene: View {
    let tint: Color
    let scanning: Bool

    private struct Orbit {
        let r: CGFloat
        let tilt: Double
        let speed: Double
        let moon: CGFloat
        let color: Color
    }

    private var orbits: [Orbit] {
        [
            Orbit(r: 98, tilt: 18, speed: 0.9, moon: 8, color: Theme.teal),
            Orbit(r: 128, tilt: -12, speed: 0.6, moon: 13, color: tint),
            Orbit(r: 160, tilt: 6, speed: 0.38, moon: 7, color: Theme.violet),
        ]
    }

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [tint.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 110))
                .frame(width: 240, height: 240)
            ForEach(0..<orbits.count, id: \.self) { i in
                let o = orbits[i]
                Ellipse()
                    .stroke(tint.opacity(scanning ? 0.32 : 0.2), style: StrokeStyle(lineWidth: 1, dash: i == 1 ? [] : [3, 5]))
                    .frame(width: o.r * 2, height: o.r * 0.76)
                    .rotationEffect(.degrees(o.tilt))
            }
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
                ZStack {
                    moonLayer(front: false, t: t)
                    DotGlobe(speed: scanning ? 1.4 : 0.22)
                        .frame(width: 170, height: 170)
                        .shadow(color: tint.opacity(0.35), radius: 24)
                    moonLayer(front: true, t: t)
                }
            }
        }
    }

    private func moonLayer(front: Bool, t: Double) -> some View {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for (i, o) in orbits.enumerated() {
                    let a = t * o.speed * (scanning ? 2.8 : 1) + Double(i) * 2.1
                    let depth = sin(a)
                    guard (depth > 0) == front else { continue }
                    let x = cos(a) * Double(o.r), y = sin(a) * Double(o.r) * 0.38
                    let rad = o.tilt * .pi / 180
                    let p = CGPoint(x: c.x + x * cos(rad) - y * sin(rad), y: c.y + x * sin(rad) + y * cos(rad))
                    let r = o.moon / 2 * (0.7 + 0.3 * (depth + 1) / 2)
                    ctx.opacity = 0.55 + 0.45 * (depth + 1) / 2
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 3, y: p.y - r * 3, width: r * 6, height: r * 6)),
                             with: .radialGradient(Gradient(colors: [o.color.opacity(0.5), .clear]), center: p, startRadius: 0, endRadius: r * 3))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(Gradient(colors: [.white, o.color]), center: CGPoint(x: p.x - r * 0.4, y: p.y - r * 0.4), startRadius: 0, endRadius: r * 1.6))
                }
            }
        .frame(width: 360, height: 300)
        .allowsHitTesting(false)
    }
}

// MARK: - Warp transition between sections

struct WarpModifier: ViewModifier {
    let amount: Double
    func body(content: Content) -> some View {
        content
            .scaleEffect(1 + amount * 0.05)
            .blur(radius: abs(amount) * 16)
            .opacity(1 - abs(amount))
    }
}

extension AnyTransition {
    static var warp: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: WarpModifier(amount: -1), identity: WarpModifier(amount: 0)),
            removal: .modifier(active: WarpModifier(amount: 1), identity: WarpModifier(amount: 0))
        )
    }
}
