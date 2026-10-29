import AppKit
import Darwin
import Foundation
import IOKit
import IOKit.ps

struct BatteryInfo {
    var percent: Int
    var charging: Bool
    var pluggedIn: Bool
    var minutesRemaining: Int?
    var cycles: Int?
    var health: Int?
    var temperature: Double?
}

struct ProcessSample: Identifiable, Hashable {
    let pid: Int32
    let name: String
    let cpu: Double
    let memory: Int64
    var id: Int32 { pid }
}

@MainActor
final class SystemMonitor: ObservableObject {
    @Published var cpu: Double = 0
    @Published var cores: [Double] = []
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var memTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    @Published var memApp: UInt64 = 0
    @Published var memWired: UInt64 = 0
    @Published var memCompressed: UInt64 = 0
    @Published var memCached: UInt64 = 0
    @Published var swapUsed: UInt64 = 0
    @Published var pressureLevel: Int = 1
    @Published var memHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var diskTotal: Int64 = 0
    @Published var diskFree: Int64 = 0
    @Published var netIn: Double = 0
    @Published var netOut: Double = 0
    @Published var netInHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var netOutHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var battery: BatteryInfo?
    @Published var uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    @Published var thermal: ProcessInfo.ThermalState = .nominal
    @Published var load: [Double] = [0, 0, 0]
    @Published var processes: [ProcessSample] = []

    let chip = SystemMonitor.sysctlString("machdep.cpu.brand_string")
    let model = SystemMonitor.sysctlString("hw.model")
    let hostName = Host.current().localizedName ?? "This Mac"
    let osVersion: String = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion)" + (v.patchVersion > 0 ? ".\(v.patchVersion)" : "")
    }()

    private var prevTicks: [[UInt64]] = []
    private var prevNet: (inBytes: UInt64, outBytes: UInt64, at: Date)?
    private var timer: Timer?
    private var tick = 0
    private var readingProcesses = false

    var memUsed: UInt64 { memApp + memWired + memCompressed }
    var memRatio: Double { Double(memUsed) / Double(max(memTotal, 1)) }
    var diskUsed: Int64 { diskTotal - diskFree }
    var diskRatio: Double { Double(diskUsed) / Double(max(diskTotal, 1)) }

    func start() {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    func sample() {
        sampleCPU()
        sampleMemory()
        sampleNetwork()
        uptime = ProcessInfo.processInfo.systemUptime
        thermal = ProcessInfo.processInfo.thermalState
        var l = [Double](repeating: 0, count: 3)
        getloadavg(&l, 3)
        load = l
        if tick % 5 == 0 {
            refreshDisk()
            battery = Self.readBattery()
        }
        tick += 1

        guard !readingProcesses else { return }
        readingProcesses = true
        Task { [weak self] in
            let procs = await Task.detached(priority: .utility) { SystemMonitor.readProcesses() }.value
            self?.processes = procs
            self?.readingProcesses = false
        }
    }

    func refreshDisk() {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        if let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys) {
            diskTotal = Int64(v.volumeTotalCapacity ?? 0)
            diskFree = v.volumeAvailableCapacityForImportantUsage ?? 0
        }
    }

    // MARK: Health

    struct Health {
        let score: Int
        let issues: [String]
        var grade: String {
            score >= 90 ? "Excellent" : score >= 75 ? "Good" : score >= 60 ? "Fair" : "Needs attention"
        }
    }

    var health: Health {
        var score = 100
        var issues: [String] = []
        if cpu > 0.85 { score -= 15; issues.append("CPU load is high") } else if cpu > 0.6 { score -= 5 }
        if pressureLevel >= 4 { score -= 25; issues.append("Memory pressure is critical") }
        else if pressureLevel >= 2 { score -= 12; issues.append("Memory pressure is elevated") }
        let free = Double(diskFree) / Double(max(diskTotal, 1))
        if diskTotal > 0 && free < 0.1 { score -= 20; issues.append("Startup disk is almost full") }
        else if diskTotal > 0 && free < 0.2 { score -= 8; issues.append("Disk space is getting low") }
        if uptime > 14 * 86_400 { score -= 6; issues.append("No restart in \(Int(uptime / 86_400)) days") }
        if thermal == .serious || thermal == .critical { score -= 15; issues.append("Mac is running hot") }
        if let h = battery?.health, h < 80 { score -= 8; issues.append("Battery health is \(h)%") }
        if swapUsed > 4 << 30 { score -= 6; issues.append("Heavy swap use (\(Bytes.format(Int64(swapUsed))))") }
        return Health(score: max(score, 0), issues: issues)
    }

    // MARK: Samplers

    private func sampleCPU() {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return }

        var ticks: [[UInt64]] = []
        for i in 0..<Int(count) {
            let base = Int(CPU_STATE_MAX) * i
            ticks.append([CPU_STATE_USER, CPU_STATE_SYSTEM, CPU_STATE_IDLE, CPU_STATE_NICE].map {
                UInt64(UInt32(bitPattern: info[base + Int($0)]))
            })
        }
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))

        if prevTicks.count == ticks.count {
            var perCore: [Double] = []
            var busyAll = 0.0, totalAll = 0.0
            for (now, before) in zip(ticks, prevTicks) {
                let d = (0..<4).map { now[$0] >= before[$0] ? Double(now[$0] - before[$0]) : 0 }
                let busy = d[0] + d[1] + d[3]
                let total = busy + d[2]
                perCore.append(total > 0 ? busy / total : 0)
                busyAll += busy
                totalAll += total
            }
            cores = perCore
            cpu = totalAll > 0 ? busyAll / totalAll : 0
            push(&cpuHistory, cpu)
        }
        prevTicks = ticks
    }

    private func sampleMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return }
        let page = UInt64(vm_kernel_page_size)
        let internalPages = UInt64(stats.internal_page_count), purgeable = UInt64(stats.purgeable_count)
        memApp = (internalPages > purgeable ? internalPages - purgeable : 0) * page
        memWired = UInt64(stats.wire_count) * page
        memCompressed = UInt64(stats.compressor_page_count) * page
        memCached = (UInt64(stats.external_page_count) + purgeable) * page

        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 { pressureLevel = Int(level) }
        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 { swapUsed = swap.xsu_used }
        push(&memHistory, memRatio)
    }

    private func sampleNetwork() {
        let (inB, outB) = Self.readNetworkBytes()
        let now = Date()
        if let prev = prevNet {
            let dt = max(now.timeIntervalSince(prev.at), 0.5)
            netIn = inB >= prev.inBytes ? Double(inB - prev.inBytes) / dt : 0
            netOut = outB >= prev.outBytes ? Double(outB - prev.outBytes) / dt : 0
            push(&netInHistory, netIn)
            push(&netOutHistory, netOut)
        }
        prevNet = (inB, outB, now)
    }

    private func push(_ arr: inout [Double], _ v: Double) {
        arr.append(v)
        if arr.count > 60 { arr.removeFirst(arr.count - 60) }
    }

    // MARK: Readers (off the main actor)

    nonisolated static func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return "" }
        return String(cString: buf)
    }

    nonisolated static func readNetworkBytes() -> (UInt64, UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }
        var inB: UInt64 = 0, outB: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let p = cursor {
            let a = p.pointee
            if let addr = a.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
               String(cString: a.ifa_name).hasPrefix("en"),
               let data = a.ifa_data?.assumingMemoryBound(to: if_data.self) {
                inB += UInt64(data.pointee.ifi_ibytes)
                outB += UInt64(data.pointee.ifi_obytes)
            }
            cursor = a.ifa_next
        }
        return (inB, outB)
    }

    nonisolated static func readProcesses() -> [ProcessSample] {
        let r = Shell.run("/bin/ps", ["-Aceo", "pid=,pcpu=,rss=,comm="])
        return r.out.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4, let pid = Int32(parts[0]), let cpu = Double(parts[1]), let rss = Int64(parts[2]) else { return nil }
            return ProcessSample(pid: pid, name: String(parts[3]), cpu: cpu, memory: rss * 1024)
        }
    }

    nonisolated static func readBattery() -> BatteryInfo? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let d = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            let cur = d[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCap = d[kIOPSMaxCapacityKey] as? Int ?? 100
            let charging = d[kIOPSIsChargingKey] as? Bool ?? false
            let ac = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let minutes = charging ? d[kIOPSTimeToFullChargeKey] as? Int : d[kIOPSTimeToEmptyKey] as? Int
            var info = BatteryInfo(percent: maxCap > 0 ? cur * 100 / maxCap : cur, charging: charging, pluggedIn: ac,
                                   minutesRemaining: (minutes ?? -1) > 0 ? minutes : nil)

            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
            if service != 0 {
                defer { IOObjectRelease(service) }
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let dict = props?.takeRetainedValue() as? [String: Any] {
                    info.cycles = dict["CycleCount"] as? Int
                    let design = dict["DesignCapacity"] as? Int ?? 0
                    let full = dict["AppleRawMaxCapacity"] as? Int ?? dict["NominalChargeCapacity"] as? Int ?? 0
                    if design > 0, full > 0 { info.health = min(100, full * 100 / design) }
                    if let t = dict["Temperature"] as? Int { info.temperature = Double(t) / 100 }
                }
            }
            return info
        }
        return nil
    }
}
