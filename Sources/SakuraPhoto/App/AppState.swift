import Foundation
import Observation

@MainActor @Observable
final class AppState {
    var sources: [PhotoSource] = []
    var pattern = RenamePattern()
    var plans: [PhotoPlan] = []
    var selectedPlanID: String?
    var isWorking = false
    var activity = "Choose a photo folder to begin"
    var errorMessage: String?
    var lastSummary: OrganizationSummary?
    var classificationFilter: PhotoClassification?
    private let dataStore: any PhotoDataStore = LocalPhotoDataStore()
    private let workspaceStore = WorkspaceStore()
    var readyCount: Int { plans.count { $0.state.canOrganize } }
    var missingDateCount: Int { plans.count { $0.state == .missingCaptureDate } }
    var sidecarCount: Int { plans.reduce(0) { $0 + $1.sidecars.count } }
    var selectedPlan: PhotoPlan? { plans.first { $0.id == selectedPlanID } }
    var visiblePlans: [PhotoPlan] { guard let filter = classificationFilter else { return plans }; return plans.filter { $0.classification == filter } }

    init() {
        if let snapshot = workspaceStore.load() { sources = snapshot.sources; pattern = snapshot.pattern }
    }

    var root: URL? { sources.first?.root }
    func addSource(_ url: URL, scanImmediately: Bool = true) { let source = SourceResolver.resolve(url); if !sources.contains(where: { $0.id == source.id }) { sources.append(source); workspaceStore.save(sources: sources, pattern: pattern); if scanImmediately { scan() } } }
    func removeSource(_ id: String) { sources.removeAll { $0.id == id }; plans.removeAll { $0.sourceID == id }; selectedPlanID = plans.first?.id; workspaceStore.save(sources: sources, pattern: pattern) }
    func setWritePolicy(_ policy: SourceWritePolicy, for id: String) { guard let index = sources.firstIndex(where: { $0.id == id }) else { return }; sources[index].writePolicy = policy; workspaceStore.save(sources: sources, pattern: pattern); scan() }
    func selectFolder(_ url: URL) { sources = [SourceResolver.resolve(url)]; plans = []; selectedPlanID = nil; lastSummary = nil; scan() }
    func scan() {
        guard !sources.isEmpty, !isWorking else { return }; isWorking = true; activity = "Scanning \(sources.count) source\(sources.count == 1 ? "" : "s")…"; errorMessage = nil; lastSummary = nil
        Task {
            do { workspaceStore.save(sources: sources, pattern: pattern); var found: [PhotoPlan] = []; for source in sources where source.isMounted { found += try await dataStore.scan(source, pattern: pattern) }; plans = found; selectedPlanID = found.first?.id; activity = found.isEmpty ? "No supported photos found" : "Reviewed \(found.count.formatted()) photos" }
            catch { errorMessage = error.localizedDescription; activity = "Scan failed" }; isWorking = false
        }
    }
    func organize() {
        guard !sources.isEmpty, readyCount > 0, !isWorking else { return }; isWorking = true; activity = "Organizing \(readyCount.formatted()) photos…"; errorMessage = nil
        Task { var all = plans; var total = OrganizationSummary(organized: 0, failed: 0); for source in sources { let indexes = plans.indices.filter { plans[$0].sourceID == source.id }; guard source.destinationRoot != nil else { continue }; let result = await dataStore.organize(indexes.map { plans[$0] }); for (offset, index) in indexes.enumerated() { all[index] = result.0[offset] }; total = OrganizationSummary(organized: total.organized + result.1.organized, failed: total.failed + result.1.failed) }; plans = all; lastSummary = total; activity = total.failed == 0 ? "Organized \(total.organized.formatted()) photos" : "Finished with \(total.failed.formatted()) failures"; isWorking = false }
    }

    func classify(_ value: PhotoClassification, for id: String) {
        guard let index = plans.firstIndex(where: { $0.id == id }) else { return }
        plans[index].classification = value
        workspaceStore.save(sources: sources, pattern: pattern)
        if let destination = plans[index].destination, pattern.value.contains("{class}") {
            let old = destination.path
            let updated = old.replacingOccurrences(of: "unclassified", with: value.rawValue.lowercased())
            plans[index] = PhotoPlan(sourceID: plans[index].sourceID, source: plans[index].source, destination: URL(fileURLWithPath: updated), captureDate: plans[index].captureDate, sidecars: plans[index].sidecars, writePolicy: plans[index].writePolicy, classification: value, state: plans[index].state)
        }
    }
}
