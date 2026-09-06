import Foundation
import Observation

@MainActor @Observable
final class AppState {
    var root: URL?
    var plans: [PhotoPlan] = []
    var selectedPlanID: String?
    var isWorking = false
    var activity = "Choose a photo folder to begin"
    var errorMessage: String?
    var lastSummary: OrganizationSummary?
    private let organizer = PhotoOrganizer()
    var readyCount: Int { plans.count { $0.state.canOrganize } }
    var missingDateCount: Int { plans.count { $0.state == .missingCaptureDate } }
    var sidecarCount: Int { plans.reduce(0) { $0 + $1.sidecars.count } }
    var selectedPlan: PhotoPlan? { plans.first { $0.id == selectedPlanID } }

    func selectFolder(_ url: URL) { root = url; plans = []; selectedPlanID = nil; lastSummary = nil; scan() }
    func scan() {
        guard let root, !isWorking else { return }; isWorking = true; activity = "Scanning \(root.lastPathComponent)…"; errorMessage = nil; lastSummary = nil
        Task {
            do { let found = try await organizer.scan(root); plans = found; selectedPlanID = found.first?.id; activity = found.isEmpty ? "No supported photos found" : "Reviewed \(found.count.formatted()) photos" }
            catch { errorMessage = error.localizedDescription; activity = "Scan failed" }; isWorking = false
        }
    }
    func organize() {
        guard let root, readyCount > 0, !isWorking else { return }; isWorking = true; activity = "Organizing \(readyCount.formatted()) photos…"; errorMessage = nil
        Task { let result = await organizer.organize(plans, root: root); plans = result.0; lastSummary = result.1; activity = result.1.failed == 0 ? "Organized \(result.1.organized.formatted()) photos" : "Finished with \(result.1.failed.formatted()) failures"; isWorking = false }
    }
}
