import Foundation

struct FolderSourceAdapter: PhotoSourceAdapter {
    let kind: PhotoSourceKind = .folder
    func detect(at root: URL) -> SourceDetection? { FileManager.default.fileExists(atPath: root.path) ? SourceDetection(kind: .folder, confidence: 0.5) : nil }
    func scanRoots(for source: PhotoSource) -> [URL] { source.mountedURL.map { [$0] } ?? [] }
}

struct SonyCameraSourceAdapter: PhotoSourceAdapter {
    let kind: PhotoSourceKind = .sonyCamera
    func detect(at root: URL) -> SourceDetection? {
        let name = (try? root.resourceValues(forKeys: [.volumeNameKey]).volumeName)?.uppercased() ?? ""
        let directories = ["DCIM", "MP_ROOT", "PRIVATE/M4ROOT"].map { root.appending(path: $0) }
        let score = directories.contains { FileManager.default.fileExists(atPath: $0.path) } ? 0.95 : (name.contains("SONY") ? 0.75 : 0)
        return score > 0 ? SourceDetection(kind: .sonyCamera, confidence: score) : nil
    }
    func scanRoots(for source: PhotoSource) -> [URL] { source.scanRoots }
}

enum SourceResolver {
    static let adapters: [any PhotoSourceAdapter] = [SonyCameraSourceAdapter(), FolderSourceAdapter()]

    static func resolve(_ url: URL) -> PhotoSource {
        let mountedURLs = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeUUIDStringKey, .volumeNameKey], options: []) ?? []
        let volumeRoot = mountedURLs.filter { url.path.hasPrefix($0.path + "/") || url.path == $0.path }.max { $0.path.count < $1.path.count } ?? url
        let volumeValues = try? volumeRoot.resourceValues(forKeys: [.volumeUUIDStringKey, .volumeNameKey])
        let uuid = volumeValues?.volumeUUIDString ?? "path:\(volumeRoot.path)"
        let relative = url.path.replacingOccurrences(of: volumeRoot.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let detection = adapters.compactMap { adapter -> (PhotoSourceKind, Double)? in
            guard let result = adapter.detect(at: volumeRoot) else { return nil }
            return (result.kind, result.confidence)
        }.max { $0.1 < $1.1 } ?? (.folder, 0.5)
        let identity = SourceIdentity(volumeUUID: uuid, relativePath: relative, kind: detection.0)
        let mountedURL = volumeRoot.appending(path: relative)
        return PhotoSource(identity: identity, displayName: detection.0 == .sonyCamera ? "Sony A7R V · \(volumeRoot.lastPathComponent)" : (url.lastPathComponent.isEmpty ? volumeRoot.lastPathComponent : url.lastPathComponent), lastKnownPath: url.path, mountedURL: mountedURL, bookmark: try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil), writePolicy: detection.0 == .sonyCamera ? .browseOnly : .organizeInPlace, detectionConfidence: detection.1)
    }
}
