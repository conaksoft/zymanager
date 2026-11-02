import Foundation

enum Cleaner {
    /// Deletes or trashes the given folders. Moving to the Trash frees no space until the Trash is emptied.
    static func remove(_ urls: [URL], toTrash: Bool) -> [String] {
        var failures: [String] = []
        for url in urls {
            do {
                if toTrash {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                } else {
                    try FileManager.default.removeItem(at: url)
                }
            } catch {
                failures.append("\(url.tildePath): \(error.localizedDescription)")
            }
        }
        return failures
    }

    static func clean(_ item: CacheItem, urls: [URL], toTrash: Bool) -> [String] {
        if let command = item.command {
            let result = Shell.run(command.executable, command.arguments)
            return result.status == 0 ? [] : ["\(item.name): \(result.output.trimmingCharacters(in: .whitespacesAndNewlines))"]
        }
        return remove(urls, toTrash: toTrash)
    }
}
