import Foundation

enum PlanState: Sendable, Equatable {
    case ready, alreadyOrganized, readOnly, missingCaptureDate, completed
    case failed(String)

    var label: String {
        switch self { case .ready: "Ready"; case .alreadyOrganized: "In place"; case .readOnly: "Browse only"; case .missingCaptureDate: "Missing date"; case .completed: "Organized"; case .failed: "Failed" }
    }
    var symbol: String {
        switch self { case .ready: "arrow.right.circle"; case .alreadyOrganized: "checkmark.circle"; case .readOnly: "eye"; case .missingCaptureDate: "exclamationmark.triangle"; case .completed: "checkmark.circle.fill"; case .failed: "xmark.circle.fill" }
    }
    var canOrganize: Bool { self == .ready }
}

struct PhotoPlan: Identifiable, Sendable {
    let sourceID: String
    let source: URL
    let destination: URL?
    let captureDate: Date?
    let sidecars: [URL]
    let writePolicy: SourceWritePolicy
    var classification: PhotoClassification
    var state: PlanState
    var id: String { "\(sourceID):\(source.path)" }
    var filename: String { source.lastPathComponent }
    var destinationDescription: String { destination?.path(percentEncoded: false) ?? "Will remain in place" }
}

struct OrganizationSummary: Sendable { let organized: Int; let failed: Int }

enum OrganizerError: LocalizedError {
    case cannotReadDirectory(String)
    var errorDescription: String? { if case .cannotReadDirectory(let path) = self { return "SakuraPhoto could not read \(path)." }; return nil }
}
