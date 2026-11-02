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
    private static func formatter(_ style: ByteCountFormatter.CountStyle) -> ByteCountFormatter {
        let f = ByteCountFormatter()
        f.countStyle = style
        f.allowsNonnumericFormatting = false // "0 KB" instead of "Zero KB"
        return f
    }
    private static let fileFormatter = formatter(.file)
    private static let memoryFormatter = formatter(.memory)

    var fileSizeText: String { Self.fileFormatter.string(fromByteCount: self) }
    var memoryText: String { Self.memoryFormatter.string(fromByteCount: self) }
}

extension URL {
    static let home = FileManager.default.homeDirectoryForCurrentUser

    var tildePath: String {
        let home = URL.home.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
