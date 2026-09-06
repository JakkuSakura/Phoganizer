import Foundation

enum PhotoSourceKind: String, CaseIterable, Identifiable, Sendable {
    case folder = "Folder"
    case sonyCamera = "Sony A7R V camera"
    var id: String { rawValue }
    var symbol: String { self == .folder ? "folder" : "camera" }
}

protocol PhotoSource: Sendable {
    var id: String { get }
    var root: URL { get }
    var kind: PhotoSourceKind { get }
    var displayName: String { get }
    var scanRoots: [URL] { get }
}

protocol PhotoDataStore: Sendable {
    func scan(_ source: any PhotoSource, pattern: RenamePattern) async throws -> [PhotoPlan]
    func organize(_ plans: [PhotoPlan], root: URL) async -> ([PhotoPlan], OrganizationSummary)
}

struct FolderPhotoSource: PhotoSource {
    let root: URL
    var id: String { root.path }
    let kind: PhotoSourceKind = .folder
    var displayName: String { root.lastPathComponent }
    var scanRoots: [URL] { [root] }
}

struct SonyCameraSource: PhotoSource {
    let root: URL
    var id: String { root.path }
    let kind: PhotoSourceKind = .sonyCamera
    var displayName: String { "Sony A7R V · \(root.lastPathComponent)" }
    var scanRoots: [URL] {
        let candidates = ["DCIM", "MP_ROOT", "PRIVATE/M4ROOT/CLIP"]
        let roots = candidates.map { root.appending(path: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
        return roots.isEmpty ? [root] : roots
    }
}

enum SourceDetector {
    static func source(for url: URL) -> any PhotoSource {
        let name = (try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? ""
        let path = url.path.uppercased()
        let sonyDirectories = ["DCIM", "MP_ROOT", "PRIVATE/M4ROOT"]
            .map { url.appending(path: $0) }
            .contains { FileManager.default.fileExists(atPath: $0.path) }
        if name.uppercased().contains("SONY") || path.hasSuffix("/DCIM") || path.contains("/DCIM/") || sonyDirectories {
            return SonyCameraSource(root: url)
        }
        return FolderPhotoSource(root: url)
    }
}

enum CommonPhotoLocations {
    static var locations: [(String, URL, String)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            ("Photos", home.appending(path: "Photos"), "photo.on.rectangle"),
            ("Pictures", home.appending(path: "Pictures"), "photo"),
            ("Downloads", home.appending(path: "Downloads"), "arrow.down.circle"),
            ("Desktop", home.appending(path: "Desktop"), "desktopcomputer")
        ].filter { FileManager.default.fileExists(atPath: $0.1.path) }
    }
}

enum PhotoClassification: String, CaseIterable, Identifiable, Sendable {
    case unclassified = "Unclassified"
    case keep = "Keep"
    case review = "Review"
    case reject = "Reject"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .unclassified: "questionmark.circle"; case .keep: "checkmark.circle"; case .review: "eye"; case .reject: "xmark.circle" }
    }
}

struct RenamePattern: Sendable, Equatable {
    var value = "{date}_{time}.{seq}.{ext}"
    static let examples = ["{date}_{time}.{seq}.{ext}", "{year}/{month}-{day}_{seq}_{class}.{ext}", "{class}/{date}/{original}.{ext}"]
}
