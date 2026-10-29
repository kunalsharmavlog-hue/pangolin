import AppKit
import SwiftUI

/// `Pangolin --render-brand <dir>` writes every logo and store image as PNG, from the same globe the app draws.
enum BrandAssets {
    @MainActor
    static func renderIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--render-brand"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1])
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        save(AppIconArt(), "pangolin-app-icon-1024.png", dir)
        save(DotGlobe(spin: false).frame(width: 1024, height: 1024), "pangolin-logo-globe-1024.png", dir)
        save(DotGlobe(spin: false).frame(width: 512, height: 512), "pangolin-logo-globe-512.png", dir)
        save(StoreAvatar(), "pangolin-store-logo-1024.png", dir)
        save(Wordmark(dark: true), "pangolin-wordmark-dark-bg.png", dir)
        save(Wordmark(dark: false), "pangolin-wordmark-light-bg.png", dir)
        save(Wordmark(dark: true, transparent: true), "pangolin-wordmark-transparent.png", dir)
        save(ProductCover(), "pangolin-cover-1600x900.png", dir)
        save(ProductSquare(), "pangolin-square-1200.png", dir)
        save(SocialCard(), "pangolin-social-1200x630.png", dir)
        save(DotGlobe(spin: false, marker: true).frame(width: 64, height: 64), "pangolin-favicon-64.png", dir)
        exit(0)
    }

    @MainActor
    private static func save<V: View>(_ view: V, _ name: String, _ dir: URL) {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = 1
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return }
        try? png.write(to: dir.appendingPathComponent(name))
    }
}

/// Stars painted directly (no drawingGroup), so they survive offscreen rendering.
private struct StaticStars: View {
    var count = 220
    var body: some View {
        Canvas { ctx, size in
            for i in 0..<count {
                let fx = abs(sin(Double(i) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                let fy = abs(sin(Double(i) * 78.233) * 12543.21).truncatingRemainder(dividingBy: 1)
                let r = i % 13 == 0 ? 3.2 : 1 + fx * 1.6
                ctx.opacity = 0.25 + fy * 0.6
                ctx.fill(Path(ellipseIn: CGRect(x: fx * size.width, y: fy * size.height, width: r, height: r)), with: .color(.white))
            }
        }
    }
}

private struct SpaceBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.11), Color(red: 0.03, green: 0.03, blue: 0.035)],
                           startPoint: .top, endPoint: .bottom)
            DotGrid(spacing: 34)
            RadialGradient(colors: [Theme.magenta.opacity(0.2), .clear], center: UnitPoint(x: 0.78, y: 0.35), startRadius: 0, endRadius: 700)
            RadialGradient(colors: [Theme.violet.opacity(0.14), .clear], center: UnitPoint(x: 0.1, y: 0.95), startRadius: 0, endRadius: 600)
            StaticStars()
        }
    }
}

private struct StoreAvatar: View {
    var body: some View {
        ZStack {
            SpaceBackground()
            DotGlobe(spin: false).frame(width: 720, height: 720)
        }
        .frame(width: 1024, height: 1024)
    }
}

private struct Wordmark: View {
    let dark: Bool
    var transparent = false

    var body: some View {
        HStack(spacing: 56) {
            DotGlobe(spin: false).frame(width: 380, height: 380)
            VStack(alignment: .leading, spacing: 14) {
                Text("Pangolin")
                    .font(.system(size: 168, weight: .bold, design: .monospaced))
                    .foregroundStyle(dark ? Color.white : Color(red: 0.07, green: 0.07, blue: 0.08))
                Text("eats the bugs in your Mac")
                    .font(.system(size: 46, weight: .regular, design: .monospaced))
                    .foregroundStyle(dark ? Color.white.opacity(0.55) : Color.black.opacity(0.5))
            }
        }
        .padding(.horizontal, 110)
        .padding(.vertical, 90)
        .background {
            if !transparent {
                if dark { SpaceBackground() } else { Color(red: 0.97, green: 0.97, blue: 0.96) }
            }
        }
    }
}

private struct PriceTag: View {
    let size: CGFloat
    var body: some View {
        Text("Free and open source")
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, size * 1.1).padding(.vertical, size * 0.6)
            .background(Capsule().fill(Theme.magenta))
            .shadow(color: Theme.magenta.opacity(0.5), radius: size)
            .fixedSize()
    }
}

private struct ProductCover: View {
    var body: some View {
        ZStack {
            SpaceBackground()
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 18) {
                        DotGlobe(spin: false).frame(width: 70, height: 70)
                        Text("PANGOLIN")
                            .font(.system(size: 30, weight: .semibold, design: .monospaced)).kerning(4)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Text("Your Mac,\ncleaned.")
                        .font(.system(size: 104, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineSpacing(-6)
                    Text("Clean junk, uninstall apps completely,\nfree up space, watch your Mac's health.")
                        .font(.system(size: 26, design: .monospaced))
                        .fixedSize()
                        .foregroundStyle(.white.opacity(0.6))
                        .lineSpacing(8)
                    PriceTag(size: 21)
                }
                Spacer(minLength: 0)
                DotGlobe(spin: false)
                    .frame(width: 540, height: 540)
                    .shadow(color: Theme.magenta.opacity(0.25), radius: 60)
            }
            .padding(.horizontal, 110)
        }
        .frame(width: 1600, height: 900)
    }
}

private struct ProductSquare: View {
    var body: some View {
        ZStack {
            SpaceBackground()
            VStack(spacing: 46) {
                DotGlobe(spin: false).frame(width: 560, height: 560)
                    .shadow(color: Theme.magenta.opacity(0.25), radius: 50)
                VStack(spacing: 14) {
                    Text("Pangolin")
                        .font(.system(size: 92, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("Clean, optimize and monitor your Mac")
                        .font(.system(size: 32, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
                PriceTag(size: 22)
            }
        }
        .frame(width: 1200, height: 1200)
    }
}

private struct SocialCard: View {
    var body: some View {
        ZStack {
            SpaceBackground()
            HStack(spacing: 50) {
                DotGlobe(spin: false).frame(width: 400, height: 400)
                VStack(alignment: .leading, spacing: 18) {
                    Text("Pangolin")
                        .font(.system(size: 92, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("The Mac cleaner that\neats the bugs in your Mac.")
                        .font(.system(size: 30, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineSpacing(6)
                    PriceTag(size: 18)
                }
            }
            .padding(.horizontal, 70)
        }
        .frame(width: 1200, height: 630)
    }
}
