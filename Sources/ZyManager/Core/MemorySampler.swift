import Darwin
import Foundation

enum MemoryPressure: Sendable {
    case normal, warning, critical

    var title: String {
        switch self {
        case .normal: "Normal"
        case .warning: L("Sıkışık", "Under pressure")
        case .critical: L("Kritik", "Critical")
        }
    }
}

struct AppMemory: Identifiable, Sendable {
    /// App bundle path for apps (helpers grouped under it), process name otherwise.
    let id: String
    let name: String
    var footprint: Int64
    var processCount: Int
    var pids: [pid_t]
    var bundlePath: String?
}

struct MemorySnapshot: Sendable {
    var physical: Int64 = 0
    var appMemory: Int64 = 0
    var wired: Int64 = 0
    var compressed: Int64 = 0
    var swapUsed: Int64 = 0
    var swapTotal: Int64 = 0
    var pressure: MemoryPressure = .normal
    var apps: [AppMemory] = []

    /// Same definition as Activity Monitor's "Memory Used".
    var used: Int64 { appMemory + wired + compressed }
}

enum MemorySampler {
    static func sample() -> MemorySnapshot {
        var s = MemorySnapshot()
        s.physical = Int64(ProcessInfo.processInfo.physicalMemory)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            let page = Int64(vm_kernel_page_size)
            s.appMemory = (Int64(stats.internal_page_count) - Int64(stats.purgeable_count)) * page
            s.wired = Int64(stats.wire_count) * page
            s.compressed = Int64(stats.compressor_page_count) * page
        }

        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 {
            s.swapUsed = Int64(swap.xsu_used)
            s.swapTotal = Int64(swap.xsu_total)
        }

        var level: Int32 = 0
        size = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 {
            s.pressure = level >= 4 ? .critical : level >= 2 ? .warning : .normal
        }

        s.apps = appUsage()
        return s
    }

    /// Per-app physical footprint (what Activity Monitor shows as "Memory"), with helper processes
    /// such as "Google Chrome Helper (Renderer)" folded into their parent app.
    private static func appUsage() -> [AppMemory] {
        let capacity = proc_listallpids(nil, 0) + 64
        var pids = [pid_t](repeating: 0, count: Int(capacity))
        let n = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count))
        guard n > 0 else { return [] }

        var groups: [String: AppMemory] = [:]
        var pathBuffer = [CChar](repeating: 0, count: 4096)

        for pid in pids.prefix(Int(n)) where pid > 0 {
            var info = rusage_info_v4()
            let ok = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
                }
            }
            guard ok == 0, info.ri_phys_footprint > 0 else { continue }

            let path = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 ? String(cString: pathBuffer) : ""
            let (key, name, bundle) = owner(ofExecutable: path, pid: pid)

            var entry = groups[key] ?? AppMemory(id: key, name: name, footprint: 0, processCount: 0, pids: [], bundlePath: bundle)
            entry.footprint += Int64(info.ri_phys_footprint)
            entry.processCount += 1
            entry.pids.append(pid)
            groups[key] = entry
        }
        return groups.values.sorted { $0.footprint > $1.footprint }
    }

    private static func owner(ofExecutable path: String, pid: pid_t) -> (key: String, name: String, bundle: String?) {
        if let range = path.range(of: ".app/") {
            let bundle = String(path[..<range.lowerBound]) + ".app"
            let name = (bundle as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
            return (bundle, name, bundle)
        }
        var nameBuffer = [CChar](repeating: 0, count: 256)
        let name = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count)) > 0
            ? String(cString: nameBuffer)
            : ((path as NSString).lastPathComponent.isEmpty ? "pid \(pid)" : (path as NSString).lastPathComponent)
        return (path.isEmpty ? name : path, friendlyName(name), nil)
    }

    private static func friendlyName(_ process: String) -> String {
        if process.hasPrefix("qemu-system") { return L("Android Emülatörü", "Android Emulator") + " (\(process))" }
        switch process {
        case "node": return "Node.js (node)"
        case "dart", "dartaotruntime", "dartvm": return "Dart / Flutter (\(process))"
        case "java": return "Java (Gradle / Android Studio)"
        case "php", "php-fpm": return "PHP (\(process))"
        case "Python", "python3": return "Python (\(process))"
        default: return process
        }
    }
}
