import Foundation
import ImageIO

actor LocalPhotoDataStore: PhotoDataStore {
    private let supportedExtensions = Set(["jpg", "jpeg", "png", "arw"])
    private let sidecarExtensions = Set(["xmp", "xml"])

    func scan(_ source: any PhotoSource, pattern: RenamePattern = RenamePattern()) throws -> [PhotoPlan] {
        let root = source.root
        let scoped = root.startAccessingSecurityScopedResource()
        defer { if scoped { root.stopAccessingSecurityScopedResource() } }
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { throw OrganizerError.cannotReadDirectory(root.path(percentEncoded: false)) }
        let files = enumerator.compactMap { $0 as? URL }.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }.sorted { $0.path < $1.path }
        var reserved = Set<String>(); var counters: [String: Int] = [:]
        return files.map { photo in
            guard let date = captureDate(for: photo) else { return PhotoPlan(sourceID: source.id, source: photo, destination: nil, captureDate: nil, sidecars: sidecars(for: photo), classification: .unclassified, state: .missingCaptureDate) }
            let folder = Self.dayFormatter.string(from: date); let timestamp = Self.filenameFormatter.string(from: date); let ext = photo.pathExtension.lowercased(); let key = "\(timestamp).\(ext)"
            var count = counters[key, default: 0]; var destination: URL
            repeat {
                let rendered = Self.render(pattern.value, date: date, sequence: count, original: photo.deletingPathExtension().lastPathComponent, ext: ext, classification: .unclassified)
                let relative = rendered.contains("/") ? rendered : "\(folder)/\(rendered)"
                destination = root.appending(path: relative); count += 1
            } while destination.path != photo.path && (reserved.contains(destination.path) || FileManager.default.fileExists(atPath: destination.path))
            counters[key] = count; reserved.insert(destination.path)
            return PhotoPlan(sourceID: source.id, source: photo, destination: destination, captureDate: date, sidecars: sidecars(for: photo), classification: .unclassified, state: destination.path == photo.path ? .alreadyOrganized : .ready)
        }
    }

    private static func render(_ pattern: String, date: Date, sequence: Int, original: String, ext: String, classification: PhotoClassification) -> String {
        let values = ["{year}": yearFormatter.string(from: date), "{month}": monthFormatter.string(from: date), "{day}": dayFormatter.string(from: date), "{date}": dayFormatter.string(from: date), "{time}": timeFormatter.string(from: date), "{seq}": String(sequence), "{original}": original, "{ext}": ext, "{class}": classification.rawValue.lowercased()]
        return values.reduce(pattern) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
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
    private static let yearFormatter = formatter("yyyy")
    private static let monthFormatter = formatter("MM")
    private static let timeFormatter = formatter("HH-mm-ss")
}
