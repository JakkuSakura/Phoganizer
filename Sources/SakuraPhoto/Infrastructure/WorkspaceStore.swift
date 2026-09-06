import Foundation

struct WorkspaceSnapshot: Codable, Sendable {
    var sources: [PhotoSource]
    var pattern: RenamePattern
}

final class WorkspaceStore: @unchecked Sendable {
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        let directory = appSupport.appending(path: "SakuraPhoto", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appending(path: "workspace.json")
    }

    func load() -> WorkspaceSnapshot? {
        guard let data = try? Data(contentsOf: fileURL), let snapshot = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data) else { return nil }
        var restored = snapshot
        restored.sources = snapshot.sources.map(refresh)
        return restored
    }

    func save(sources: [PhotoSource], pattern: RenamePattern) {
        let snapshot = WorkspaceSnapshot(sources: sources, pattern: pattern)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    private func refresh(_ source: PhotoSource) -> PhotoSource {
        var restored = source
        if let bookmark = source.bookmark {
            var stale = false
            if let resolved = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale), FileManager.default.fileExists(atPath: resolved.path) {
                restored.mountedURL = resolved
                return restored
            }
        }
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeUUIDStringKey], options: []) ?? []
        if let volume = volumes.first(where: { (try? $0.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString) == source.identity.volumeUUID }) {
            restored.mountedURL = volume.appending(path: source.identity.relativePath)
        } else {
            restored.mountedURL = nil
        }
        return restored
    }
}
