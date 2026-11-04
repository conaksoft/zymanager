import Foundation

/// `ZyManager --clean <id>` cleans one catalog item without opening the window,
/// using the same locate, measure and delete steps as the app.
enum CommandLineCleaner {
    static func run(id: String) -> Int32 {
        guard let item = CacheCatalog.items.first(where: { $0.id == id }) else {
            print(L("Bilinmeyen öğe", "Unknown item") + ": \(id). " + L("Geçerli öğeler", "Valid items") + ": \(CacheCatalog.items.map(\.id).joined(separator: ", "))")
            return 2
        }
        let urls = item.locate()
        let size = urls.reduce(0) { $0 + DiskUsage.allocatedSize(of: $1) }
        print("\(item.name): \(size.fileSizeText) · \(urls.map(\.tildePath).joined(separator: ", "))")

        let failures = Cleaner.clean(item, urls: urls, toTrash: false)
        failures.forEach { print(L("Hata", "Error") + ": \($0)") }

        let remaining = item.locate().reduce(0) { $0 + DiskUsage.allocatedSize(of: $1) }
        print(L("Kalan", "Remaining") + ": \(remaining.fileSizeText)")
        return failures.isEmpty ? 0 : 1
    }
}
