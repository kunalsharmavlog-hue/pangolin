import AppKit
import Foundation

let home = FileManager.default.homeDirectoryForCurrentUser

enum Bytes {
    static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(bytes, 0), countStyle: .file)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        format(Int64(bytesPerSecond)) + "/s"
    }
}

enum Fmt {
    static func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    static func duration(_ t: TimeInterval) -> String {
        let s = Int(t)
        let d = s / 86_400, h = (s % 86_400) / 3_600, m = (s % 3_600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func relative(_ date: Date?) -> String {
        guard let date else { return "Never" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    static func tilde(_ url: URL) -> String {
        url.path.replacingOccurrences(of: home.path, with: "~")
    }
}

enum FileSizer {
    /// Allocated size of a file or a whole directory tree. Stops early if the calling task is cancelled.
    static func size(of url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]
        guard let top = try? url.resourceValues(forKeys: Set(keys)) else { return 0 }
        if top.isSymbolicLink == true { return 0 }
        if top.isDirectory != true { return Int64(top.totalFileAllocatedSize ?? top.fileAllocatedSize ?? 0) }

        var total: Int64 = 0
        var seen = 0
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }) else { return 0 }
        for case let file as URL in walker {
            seen += 1
            if seen % 4000 == 0, Task.isCancelled { break }
            guard let v = try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]),
                  v.isRegularFile == true else { continue }
            total += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
        }
        return total
    }

    static func modified(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}

enum Shell {
    @discardableResult
    static func run(_ path: String, _ args: [String]) -> (status: Int32, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["LC_ALL"] = "C"
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// Runs a shell script as root through the standard macOS admin password prompt.
    static func runAdmin(_ script: String) -> (ok: Bool, out: String) {
        let escaped = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let r = run("/usr/bin/osascript", ["-e", "do shell script \"\(escaped)\" with administrator privileges"])
        return (r.status == 0, r.out)
    }

    static func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum FileOps {
    /// Moves to the Trash, or deletes outright when `permanent`. `contentsOnly` empties a folder but keeps it.
    @discardableResult
    static func remove(_ url: URL, permanent: Bool, contentsOnly: Bool = false) -> Bool {
        let fm = FileManager.default
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        if contentsOnly && isDir {
            let kids = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            var removed = 0
            for kid in kids where remove(kid, permanent: permanent) { removed += 1 }
            return kids.isEmpty || removed > 0
        }
        do {
            if permanent { try fm.removeItem(at: url) } else { try fm.trashItem(at: url, resultingItemURL: nil) }
            return true
        } catch {
            return false
        }
    }

    /// Moves root-owned items into the user's Trash with one admin prompt.
    static func adminTrash(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return true }
        let trash = home.appendingPathComponent(".Trash").path
        let stamp = Int(Date().timeIntervalSince1970)
        let cmds = urls.map { u in
            "mv -f \(Shell.quote(u.path)) \(Shell.quote(trash + "/" + u.lastPathComponent + " \(stamp)"))"
        }
        return Shell.runAdmin(cmds.joined(separator: " ; ")).ok
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

enum OpLog {
    static let url = home.appendingPathComponent("Library/Logs/Pangolin/operations.log")

    static func write(_ op: String, _ action: String, _ detail: String, bytes: Int64 = 0) {
        let line = "\(ISO8601DateFormatter().string(from: Date()))\t\(op)\t\(action)\t\(detail)\t\(bytes)\n"
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile()
            h.write(Data(line.utf8))
            try? h.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}

enum Permissions {
    static var hasFullDiskAccess: Bool {
        let tcc = home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        guard let h = try? FileHandle(forReadingFrom: tcc) else { return false }
        defer { try? h.close() }
        return (try? h.read(upToCount: 16)) != nil
    }

    static func openFullDiskAccess() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }

    static func openLoginItems() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
    }
}

enum AppLookup {
    static func looksLikeBundleID(_ s: String) -> Bool {
        let parts = s.split(separator: ".")
        guard parts.count >= 3 else { return false }
        return parts.allSatisfy { p in !p.isEmpty && p.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" } }
    }

    static func displayName(forBundleID id: String) -> String? {
        guard looksLikeBundleID(id), let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        return url.deletingPathExtension().lastPathComponent
    }

    static func pretty(_ folderName: String) -> String {
        displayName(forBundleID: folderName) ?? folderName
    }
}

/// App and file icons pre-rendered once at small sizes; NSImage would otherwise re-scale its 1024px rep on every redraw.
@MainActor
enum IconCache {
    private static var cache: [String: NSImage] = [:]

    static func file(_ url: URL, size: CGFloat) -> NSImage {
        image(key: "f\(Int(size))|" + url.path, size: size) { NSWorkspace.shared.icon(forFile: url.path) }
    }

    static func app(_ app: NSRunningApplication, size: CGFloat) -> NSImage? {
        guard let icon = app.icon else { return nil }
        return image(key: "a\(Int(size))|" + (app.bundleURL?.path ?? "\(app.processIdentifier)"), size: size) { icon }
    }

    private static func image(key: String, size: CGFloat, source: () -> NSImage) -> NSImage {
        if let hit = cache[key] { return hit }
        let src = source()
        let px = Int(size * 2)
        let rendered = NSImage(size: NSSize(width: size, height: size))
        if let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                                      hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) {
            rep.size = NSSize(width: size, height: size)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSGraphicsContext.current?.imageInterpolation = .high
            src.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
            NSGraphicsContext.restoreGraphicsState()
            rendered.addRepresentation(rep)
        }
        if cache.count > 600 { cache.removeAll() }
        cache[key] = rendered
        return rendered
    }
}
