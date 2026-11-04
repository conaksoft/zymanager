import Foundation

enum DiskUsage {
    private static let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]

    /// Bytes actually allocated on disk for a file or folder. Symbolic links are not followed,
    /// so a folder already moved to an external drive counts as zero here.
    static func allocatedSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]),
              values.isSymbolicLink != true else { return 0 }

        guard values.isDirectory == true else { return fileSize(url) }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let file as URL in enumerator {
            total += fileSize(file)
        }
        return total
    }

    private static func fileSize(_ url: URL) -> Int64 {
        guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { return 0 }
        return Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
    }

    /// Exists without following a final symlink.
    static func exists(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }

    struct VolumeInfo {
        var total: Int64
        var available: Int64
        /// Includes purgeable space macOS can free on demand.
        var availableForImportant: Int64
        var used: Int64 { total - available }
    }

    static func rootVolume() -> VolumeInfo? {
        let url = URL(fileURLWithPath: "/")
        guard let v = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]), let total = v.volumeTotalCapacity, let available = v.volumeAvailableCapacity else { return nil }
        return VolumeInfo(
            total: Int64(total),
            available: Int64(available),
            availableForImportant: v.volumeAvailableCapacityForImportantUsage ?? Int64(available)
        )
    }
}

extension Int64 {
    /// Disk sizes in decimal units like Finder ("473.5 MB" / "473,5 MB").
    var fileSizeText: String { Self.sizeText(self, base: 1000) }
    /// Memory sizes in binary units like Activity Monitor.
    var memoryText: String { Self.sizeText(self, base: 1024) }

    /// ByteCountFormatter always follows the Mac's region, so English UI on a Turkish Mac showed "7,59 GB".
    /// This formats with the app's own language instead: bytes and KB without decimals, MB with one, GB+ with two.
    private static func sizeText(_ bytes: Int64, base: Double) -> String {
        let units = [L("bayt", "bytes"), "KB", "MB", "GB", "TB"]
        var value = Double(bytes.magnitude)
        var unit = 0
        while value >= base, unit < units.count - 1 {
            value /= base
            unit += 1
        }
        let f = NumberFormatter()
        f.locale = AppLanguage.locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = [0, 0, 1, 2, 2][unit]
        let number = f.string(from: NSNumber(value: value)) ?? String(value)
        return (bytes < 0 ? "-" : "") + number + " " + units[unit]
    }
}

extension URL {
    static let home = FileManager.default.homeDirectoryForCurrentUser

    var tildePath: String {
        let home = URL.home.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
