import Foundation

enum PhotoSourceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case folder
    case sonyCamera
    var id: String { rawValue }
    var label: String { self == .folder ? "Folder" : "Sony A7R V" }
    var symbol: String { self == .folder ? "folder" : "camera" }
}

struct SourceIdentity: Hashable, Codable, Sendable {
    let volumeUUID: String
    let relativePath: String
    let kind: PhotoSourceKind
    var stableKey: String { "\(kind.rawValue):\(volumeUUID):\(relativePath)" }
}

enum SourceWritePolicy: Codable, Hashable, Sendable {
    case browseOnly
    case organizeInPlace
    case copyToFolder(URL)
    var label: String {
        switch self { case .browseOnly: "Browse only"; case .organizeInPlace: "Organize in place"; case .copyToFolder: "Copy to folder" }
    }
}

struct PhotoSource: Identifiable, Codable, Hashable, Sendable {
    let identity: SourceIdentity
    var displayName: String
    var lastKnownPath: String
    var mountedURL: URL?
    var bookmark: Data?
    var writePolicy: SourceWritePolicy
    var detectionConfidence: Double
    var id: String { identity.stableKey }
    var kind: PhotoSourceKind { identity.kind }
    var root: URL? { mountedURL }
    var isMounted: Bool { mountedURL != nil }
    var availabilityLabel: String { isMounted ? "Mounted" : "Offline" }
    var scanRoots: [URL] {
        guard let root = mountedURL else { return [] }
        guard kind == .sonyCamera else { return [root] }
        let candidates = ["DCIM", "MP_ROOT", "PRIVATE/M4ROOT/CLIP"]
        let roots = candidates.map { root.appending(path: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
        return roots.isEmpty ? [root] : roots
    }
    var destinationRoot: URL? {
        switch writePolicy { case .browseOnly: nil; case .organizeInPlace: mountedURL; case .copyToFolder(let url): url }
    }
}

struct SourceDetection: Sendable { let kind: PhotoSourceKind; let confidence: Double }

protocol PhotoSourceAdapter: Sendable {
    var kind: PhotoSourceKind { get }
    func detect(at root: URL) -> SourceDetection?
    func scanRoots(for source: PhotoSource) -> [URL]
}

protocol PhotoDataStore: Sendable {
    func scan(_ source: PhotoSource, pattern: RenamePattern) async throws -> [PhotoPlan]
    func organize(_ plans: [PhotoPlan]) async -> ([PhotoPlan], OrganizationSummary)
}

enum CommonPhotoLocations {
    static var locations: [(String, URL, String)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [("Photos", home.appending(path: "Photos"), "photo.on.rectangle"), ("Pictures", home.appending(path: "Pictures"), "photo"), ("Downloads", home.appending(path: "Downloads"), "arrow.down.circle"), ("Desktop", home.appending(path: "Desktop"), "desktopcomputer")]
            .filter { FileManager.default.fileExists(atPath: $0.1.path) }
    }
}

enum PhotoClassification: String, Codable, CaseIterable, Identifiable, Sendable {
    case unclassified = "Unclassified", keep = "Keep", review = "Review", reject = "Reject"
    var id: String { rawValue }
    var symbol: String { switch self { case .unclassified: "questionmark.circle"; case .keep: "checkmark.circle"; case .review: "eye"; case .reject: "xmark.circle" } }
}

struct RenamePattern: Codable, Sendable, Equatable {
    var value = "{date}_{time}.{seq}.{ext}"
    static let examples = ["{date}_{time}.{seq}.{ext}", "{year}/{month}-{day}_{seq}_{class}.{ext}", "{class}/{date}/{original}.{ext}"]
}
