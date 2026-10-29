import SwiftUI

/// Pangolin's logo: a glass sphere of stars that resolves into a spinning dot-matrix globe.
struct DotGlobe: View {
    /// When set, the dots start as scattered stars at this moment and settle into the globe.
    var morphStart: Date?
    var spin = true
    var marker = true
    /// Radians per second the globe turns.
    var speed: Double = 0.22

    fileprivate struct Dot {
        let lat: Double
        let lon: Double
        let land: Bool
        let starX: Double
        let starY: Double
    }

    private static func makeDots(_ count: Int, seed: UInt64) -> [Dot] {
        var state = seed
        func rand() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53)
        }
        let golden = Double.pi * (3 - 5.0.squareRoot())
        return (0..<count).map { i in
            let y = 1 - 2 * (Double(i) + 0.5) / Double(count)
            let lat = asin(y)
            let lon = (golden * Double(i)).truncatingRemainder(dividingBy: 2 * .pi)
            // Blobby "continents" from a few overlapping waves.
            let n = sin(lat * 3.1 + 0.4) + sin(lon * 2 + 1.2) * 0.9 + sin(lat * 5 + lon * 3) * 0.55 + cos(lon * 4 - lat * 2) * 0.4
            let r = rand().squareRoot(), a = rand() * 2 * .pi
            return Dot(lat: lat, lon: lon, land: n > 0.55 && abs(lat) < 1.25, starX: r * cos(a), starY: r * sin(a))
        }
    }

    private static let dense = makeDots(1400, seed: 0xD07)
    private static let light = makeDots(300, seed: 0xD07)
    private static let marker = (lat: 0.46, lon: 1.4)

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            if s > 2 {
                TimelineView(.animation(minimumInterval: s > 90 ? 1.0 / 24 : 1.0 / 12, paused: !spin && morphStart == nil)) { tl in
                    globe(s, now: tl.date)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func globe(_ s: CGFloat, now: Date) -> some View {
        let t = spin ? now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000) : 0
        let raw = morphStart.map { min(max(now.timeIntervalSince($0) / 1.8, 0), 1) } ?? 1
        let morph = raw < 0.5 ? 4 * raw * raw * raw : 1 - pow(-2 * raw + 2, 3) / 2
        let dots = s > 90 ? Self.dense : Self.light
        // Small globes get fewer, bolder dots so they still read in the sidebar and menu bar.
        let dotScale = s > 90 ? s / 120 : max(s / 60, 0.55)

        return ZStack {
            // Dark glass body, so whatever glows behind the globe doesn't wash out its dots.
            Circle().fill(Color(red: 0.05, green: 0.05, blue: 0.06).opacity(0.92))
            Circle().fill(RadialGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.015), .clear],
                                         center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: s * 0.55))
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = size.width / 2 * 0.9
                let tilt = 0.38
                for d in dots {
                    let lon = d.lon + t * speed
                    var x = cos(d.lat) * sin(lon), y = sin(d.lat), z = cos(d.lat) * cos(lon)
                    (y, z) = (y * cos(tilt) - z * sin(tilt), y * sin(tilt) + z * cos(tilt))
                    // Blend from a star scattered inside the sphere to its spot on the globe.
                    x = d.starX * (1 - morph) + x * morph
                    let py = d.starY * (1 - morph) + y * morph
                    let front = morph < 1 ? 1 - morph + morph * max(z, 0) : max(z, 0)
                    if morph >= 1 && z < -0.05 { continue }
                    let dot = (d.land ? 1.5 : 0.75) * dotScale * (0.55 + 0.45 * front)
                    let p = CGPoint(x: c.x + x * r, y: c.y - py * r)
                    ctx.opacity = d.land ? 0.3 + 0.7 * front : (s > 90 ? 0.08 : 0.16) + 0.2 * front * (1 - morph * 0.5)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - dot / 2, y: p.y - dot / 2, width: dot, height: dot)), with: .color(.white))
                }
                if marker && morph > 0.95 {
                    let lon = Self.marker.lon + t * speed
                    var y = sin(Self.marker.lat), z = cos(Self.marker.lat) * cos(lon)
                    let x = cos(Self.marker.lat) * sin(lon)
                    (y, z) = (y * cos(tilt) - z * sin(tilt), y * sin(tilt) + z * cos(tilt))
                    if z > 0 {
                        let p = CGPoint(x: c.x + x * r, y: c.y - y * r)
                        let pulse = 0.5 + 0.5 * sin(now.timeIntervalSinceReferenceDate * 3)
                        let m = max(2.4 * dotScale, 1.6)
                        ctx.opacity = 0.35 * (1 - pulse)
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - m * (1 + pulse * 2), y: p.y - m * (1 + pulse * 2),
                                                        width: m * 2 * (1 + pulse * 2), height: m * 2 * (1 + pulse * 2))), with: .color(Theme.magenta))
                        ctx.opacity = 1
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - m, y: p.y - m, width: m * 2, height: m * 2)), with: .color(Theme.magenta))
                    }
                }
            }
            // Glass rim, brightest at the top-left like the site's sphere.
            Circle()
                .strokeBorder(AngularGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.08), Color.white.opacity(0.3), Color.white.opacity(0.06), Color.white.opacity(0.55)],
                                              center: .center, angle: .degrees(-130)),
                              lineWidth: max(0.8, s * 0.012))
        }
        .frame(width: s, height: s)
    }
}

/// Faint dot grid that sits under everything, as on the site.
struct DotGrid: View {
    var spacing: CGFloat = 24
    var body: some View {
        Canvas { ctx, size in
            ctx.opacity = 0.07
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 0.7, y: y - 0.7, width: 1.4, height: 1.4)), with: .color(.white))
                    x += spacing
                }
                y += spacing
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

// MARK: - Scroll motion

/// Shared scroll position of the visible page, so the stage planet can drift with it.
@MainActor
final class ScrollState: ObservableObject {
    @Published var progress: Double = 0
}

extension View {
    /// Cards rise, sharpen and settle as they scroll into view, and sink away as they leave.
    func scrollReveal() -> some View {
        scrollTransition(.interactive(timingCurve: .easeOut), axis: .vertical) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.25)
                .scaleEffect(phase.isIdentity ? 1 : 0.95, anchor: phase.value < 0 ? .bottom : .top)
                .blur(radius: phase.isIdentity ? 0 : 4)
                .offset(y: phase.value * 24)
        }
    }

    /// Adds the `000%` scroll rail on the right edge and reports progress to the stage planet.
    func scrollProgressRail() -> some View {
        modifier(ScrollRail())
    }
}

private struct ScrollRail: ViewModifier {
    @EnvironmentObject var scroll: ScrollState
    @State private var progress: Double = 0
    @State private var scrollable = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: [Double].self) { geo in
                let range = geo.contentSize.height - geo.containerSize.height
                return [range > 1 ? min(max((geo.contentOffset.y + geo.contentInsets.top) / range, 0), 1) : 0, range]
            } action: { _, new in
                progress = new[0]
                scrollable = new[1] > 20
                scroll.progress = new[0]
            }
            .overlay(alignment: .trailing) {
                if scrollable {
                    VStack(spacing: 8) {
                        ZStack(alignment: .top) {
                            Capsule().fill(Color.white.opacity(0.1)).frame(width: 2, height: 110)
                            Capsule().fill(Theme.magenta).frame(width: 2, height: max(4, 110 * progress))
                                .shadow(color: Theme.magenta.opacity(0.8), radius: 4)
                        }
                        Text(String(format: "%03d%%", Int((progress * 100).rounded())))
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                            .monospacedDigit()
                    }
                    .padding(.trailing, 6)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }
            .onAppear { scroll.progress = 0 }
    }
}
