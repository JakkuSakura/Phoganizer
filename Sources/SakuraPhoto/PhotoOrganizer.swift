import Foundation
import ImageIO

actor PhotoOrganizer {
    private let supportedExtensions = Set(["jpg", "jpeg", "png", "arw"])
    private let sidecarExtensions = Set(["xmp", "xml"])

    func scan(_ root: URL) throws -> [PhotoPlan] {
        let scoped = root.startAccessingSecurityScopedResource()
        defer { if scoped { root.stopAccessingSecurityScopedResource() } }
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { throw OrganizerError.cannotReadDirectory(root.path(percentEncoded: false)) }
        let files = enumerator.compactMap { $0 as? URL }.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }.sorted { $0.path < $1.path }
        var reserved = Set<String>(); var counters: [String: Int] = [:]
        return files.map { photo in
            guard let date = captureDate(for: photo) else { return PhotoPlan(source: photo, destination: nil, captureDate: nil, sidecars: sidecars(for: photo), state: .missingCaptureDate) }
            let folder = Self.dayFormatter.string(from: date); let timestamp = Self.filenameFormatter.string(from: date); let ext = photo.pathExtension.lowercased(); let key = "\(timestamp).\(ext)"
            var count = counters[key, default: 0]; var destination: URL
            repeat {
                destination = root.appending(path: folder, directoryHint: .isDirectory).appending(path: "\(timestamp).\(count).\(ext)"); count += 1
            } while destination.path != photo.path && (reserved.contains(destination.path) || FileManager.default.fileExists(atPath: destination.path))
            counters[key] = count; reserved.insert(destination.path)
            return PhotoPlan(source: photo, destination: destination, captureDate: date, sidecars: sidecars(for: photo), state: destination.path == photo.path ? .alreadyOrganized : .ready)
        }
    }

    func organize(_ plans: [PhotoPlan], root: URL) -> ([PhotoPlan], OrganizationSummary) {
        let scoped = root.startAccessingSecurityScopedResource(); defer { if scoped { root.stopAccessingSecurityScopedResource() } }
        var result = plans; var organized = 0; var failed = 0
        for index in result.indices where result[index].state.canOrganize {
            guard let destination = result[index].destination else { continue }
            do { try move(result[index], to: destination); result[index].state = .completed; organized += 1 }
            catch { result[index].state = .failed(error.localizedDescription); failed += 1 }
        }
        return (result, OrganizationSummary(organized: organized, failed: failed))
    }

    private func move(_ plan: PhotoPlan, to destination: URL) throws {
        let manager = FileManager.default; try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard !manager.fileExists(atPath: destination.path) else { throw CocoaError(.fileWriteFileExists) }
        var moved: [(URL, URL)] = []
        do {
            try manager.moveItem(at: plan.source, to: destination); moved.append((plan.source, destination))
            for sidecar in plan.sidecars {
                let target = destination.deletingPathExtension().appendingPathExtension(sidecar.pathExtension.lowercased())
                guard !manager.fileExists(atPath: target.path) else { throw CocoaError(.fileWriteFileExists) }
                try manager.moveItem(at: sidecar, to: target); moved.append((sidecar, target))
            }
        } catch { for (from, to) in moved.reversed() where manager.fileExists(atPath: to.path) { try? manager.moveItem(at: to, to: from) }; throw error }
    }

    private func captureDate(for url: URL) -> Date? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] { for key in [kCGImagePropertyExifDateTimeOriginal, kCGImagePropertyExifDateTimeDigitized] { if let value = exif[key] as? String, let date = Self.exifFormatter.date(from: value) { return date } } }
        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any], let value = tiff[kCGImagePropertyTIFFDateTime] as? String { return Self.exifFormatter.date(from: value) }
        return nil
    }

    private func sidecars(for photo: URL) -> [URL] {
        let stem = photo.deletingPathExtension().lastPathComponent; let directory = photo.deletingLastPathComponent()
        guard let siblings = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        return siblings.filter { $0.deletingPathExtension().lastPathComponent == stem && sidecarExtensions.contains($0.pathExtension.lowercased()) }.sorted { $0.path < $1.path }
    }

    private static func formatter(_ format: String) -> DateFormatter { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Calendar(identifier: .gregorian); f.dateFormat = format; return f }
    private static let exifFormatter = formatter("yyyy:MM:dd HH:mm:ss")
    private static let dayFormatter = formatter("yyyy-MM-dd")
    private static let filenameFormatter = formatter("yyyy-MM-dd_HH-mm-ss")
}
