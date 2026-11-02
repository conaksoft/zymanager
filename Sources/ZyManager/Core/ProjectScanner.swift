import Foundation

/// A regenerable dependency or build folder inside one of your projects.
struct ProjectArtifact: Identifiable, Sendable {
    enum Kind: String, Sendable, CaseIterable {
        case nodeModules = "node_modules"
        case nextBuild = ".next"
        case dartTool = ".dart_tool"
        case flutterBuild = "Flutter build"
        case gradleProject = "Gradle .gradle"
        case pods = "Pods"
        case composerVendor = "vendor"
        case pythonVenv = "venv"

        var restoreHint: String {
            switch self {
            case .nodeModules: "npm install"
            case .nextBuild: "next build"
            case .dartTool: "flutter pub get"
            case .flutterBuild: "flutter run / build"
            case .gradleProject: "Gradle sync"
            case .pods: "pod install"
            case .composerVendor: "composer install"
            case .pythonVenv: "python -m venv + pip install"
            }
        }

        var safety: Safety { self == .pythonVenv ? .caution : .safe }
    }

    let url: URL
    let kind: Kind
    let projectURL: URL
    let lastActivity: Date?
    var size: Int64 = 0

    var id: String { url.path }
    var projectName: String { projectURL.lastPathComponent }
}

enum ProjectScanner {
    static let maxDepth = 7
    /// Hidden or heavy folders we never walk into while looking for projects.
    private static let skipped: Set<String> = [".git", ".svn", ".hg", "Library", ".Trash", ".idea", ".vscode", "DerivedData"]

    static func scan(roots: [URL]) -> [ProjectArtifact] {
        var found: [ProjectArtifact] = []
        let fm = FileManager.default

        for root in roots {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let url as URL in enumerator {
                guard let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                      v.isDirectory == true, v.isSymbolicLink != true else { continue }

                let name = url.lastPathComponent
                if skipped.contains(name) || enumerator.level > maxDepth {
                    enumerator.skipDescendants()
                    continue
                }

                let parent = url.deletingLastPathComponent()
                if let kind = classify(name: name, url: url, parent: parent) {
                    found.append(ProjectArtifact(url: url, kind: kind, projectURL: projectRoot(for: parent, kind: kind),
                                                 lastActivity: lastActivity(of: parent)))
                    enumerator.skipDescendants()
                }
            }
        }
        return found
    }

    private static func classify(name: String, url: URL, parent: URL) -> ProjectArtifact.Kind? {
        func has(_ file: String, in dir: URL = parent) -> Bool {
            FileManager.default.fileExists(atPath: dir.appendingPathComponent(file).path)
        }
        switch name {
        case "node_modules": return .nodeModules
        case ".dart_tool": return .dartTool
        case ".next": return has("package.json") ? .nextBuild : nil
        case "build": return has("pubspec.yaml") ? .flutterBuild : nil
        case ".gradle":
            return has("settings.gradle") || has("settings.gradle.kts") || has("build.gradle") ? .gradleProject : nil
        case "Pods": return has("Podfile") ? .pods : nil
        case "vendor": return has("composer.json") ? .composerVendor : nil
        case "venv", ".venv", "env": return has("pyvenv.cfg", in: url) ? .pythonVenv : nil
        default: return nil
        }
    }

    /// Flutter keeps Pods and .gradle in ios/ and android/ — report them under the app's own name.
    private static func projectRoot(for parent: URL, kind: ProjectArtifact.Kind) -> URL {
        let up = parent.deletingLastPathComponent()
        if ["ios", "android", "macos"].contains(parent.lastPathComponent),
           FileManager.default.fileExists(atPath: up.appendingPathComponent("pubspec.yaml").path) {
            return up
        }
        return parent
    }

    /// Approximate last time you worked on a project: newest modification among the project's top level
    /// and its usual source folders, ignoring generated folders.
    static func lastActivity(of project: URL) -> Date? {
        let fm = FileManager.default
        let generated: Set<String> = ["node_modules", ".dart_tool", "build", ".gradle", "Pods", "vendor", ".next", ".venv", "venv"]
        var dirs = [project]
        for source in ["lib", "src", "app", "pages", "components", "test"] {
            let d = project.appendingPathComponent(source)
            if fm.fileExists(atPath: d.path) { dirs.append(d) }
        }
        var newest: Date?
        for dir in dirs {
            let children = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for child in children where !generated.contains(child.lastPathComponent) {
                if let date = try? child.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   date > (newest ?? .distantPast) {
                    newest = date
                }
            }
        }
        return newest
    }
}
