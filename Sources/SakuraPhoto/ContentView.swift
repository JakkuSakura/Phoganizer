import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppState.self) private var state
    @State private var choosingFolder = false
    @State private var confirmingOrganization = false
    var body: some View {
        VStack(spacing: 0) {
            toolbar; overview; Divider()
            if state.plans.isEmpty { emptyState } else { HSplitView { planTable.frame(minWidth: 560, idealWidth: 680); PhotoDetailView(plan: state.selectedPlan).frame(minWidth: 300, idealWidth: 360) } }
            Divider(); statusBar
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result { case .success(let urls): if let url = urls.first { state.selectFolder(url) }; case .failure(let error): state.errorMessage = error.localizedDescription }
        }
        .confirmationDialog("Organize \(state.readyCount.formatted()) photos?", isPresented: $confirmingOrganization) {
            Button("Organize Photos") { state.organize() }; Button("Cancel", role: .cancel) { }
        } message: { Text("Photos and matching sidecars will move into dated folders. Existing files will not be overwritten.") }
        .alert("SakuraPhoto", isPresented: Binding(get: { state.errorMessage != nil }, set: { if !$0 { state.errorMessage = nil } })) { Button("OK") { state.errorMessage = nil } } message: { Text(state.errorMessage ?? "Unknown error") }
    }
    private var toolbar: some View {
        HStack(spacing: 10) {
            Button { choosingFolder = true } label: { Label("Choose Folder…", systemImage: "folder") }.keyboardShortcut("o")
            Button { state.scan() } label: { Label("Rescan", systemImage: "arrow.clockwise") }.disabled(state.root == nil || state.isWorking)
            Spacer()
            if let root = state.root { Label(root.path(percentEncoded: false), systemImage: "folder.fill").font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).help(root.path(percentEncoded: false)) }
            Button { confirmingOrganization = true } label: { Label("Organize Photos", systemImage: "wand.and.stars") }.buttonStyle(.borderedProminent).disabled(state.readyCount == 0 || state.isWorking)
        }.controlSize(.small).padding(10)
    }
    private var overview: some View {
        HStack(spacing: 0) { metric("Photos", state.plans.count, "photo.on.rectangle"); Divider().frame(height: 28); metric("Ready", state.readyCount, "arrow.right.circle"); Divider().frame(height: 28); metric("Sidecars", state.sidecarCount, "doc.badge.gearshape"); Divider().frame(height: 28); metric("Missing date", state.missingDateCount, "exclamationmark.triangle"); Spacer() }.padding(.horizontal, 12).padding(.vertical, 7).background(.quaternary.opacity(0.25))
    }
    private func metric(_ label: String, _ value: Int, _ symbol: String) -> some View { Label { VStack(alignment: .leading, spacing: 1) { Text(value.formatted()).font(.callout.monospaced().bold()); Text(label).font(.caption2).foregroundStyle(.secondary) } } icon: { Image(systemName: symbol).foregroundStyle(.secondary) }.frame(minWidth: 120, alignment: .leading) }
    private var emptyState: some View { ContentUnavailableView { Label("Organize Photos by Capture Date", systemImage: "photo.stack") } description: { Text("Choose a folder to preview dated folders and filenames before moving anything.") } actions: { Button("Choose Photo Folder…") { choosingFolder = true }.buttonStyle(.borderedProminent) }.frame(maxWidth: .infinity, maxHeight: .infinity) }
    private var planTable: some View {
        @Bindable var state = state
        return Table(state.plans, selection: $state.selectedPlanID) {
            TableColumn("Photo") { plan in Label(plan.filename, systemImage: "photo").lineLimit(1) }
            TableColumn("Captured") { plan in if let date = plan.captureDate { Text(date.formatted(date: .abbreviated, time: .standard)) } else { Text("—").foregroundStyle(.secondary) } }.width(min: 145, ideal: 175)
            TableColumn("Destination") { plan in Text(plan.destination?.lastPathComponent ?? "—").font(.callout.monospaced()).foregroundStyle(plan.destination == nil ? .secondary : .primary).lineLimit(1).help(plan.destinationDescription) }.width(min: 190, ideal: 260)
            TableColumn("Status") { plan in PlanStateLabel(state: plan.state) }.width(105)
        }
    }
    private var statusBar: some View { HStack(spacing: 8) { if state.isWorking { ProgressView().controlSize(.small) } else { Image(systemName: "checkmark.circle").foregroundStyle(.secondary) }; Text(state.activity).font(.caption).foregroundStyle(.secondary); Spacer(); Text("JPEG · PNG · ARW").font(.caption2).foregroundStyle(.tertiary) }.padding(.horizontal, 10).frame(height: 28) }
}

private struct PlanStateLabel: View {
    let state: PlanState
    var body: some View { Label(state.label, systemImage: state.symbol).font(.caption).foregroundStyle(color).help(helpText) }
    private var color: Color { switch state { case .ready: .blue; case .alreadyOrganized, .completed: .green; case .missingCaptureDate: .orange; case .failed: .red } }
    private var helpText: String { if case .failed(let message) = state { return message }; return state.label }
}

private struct PhotoDetailView: View {
    let plan: PhotoPlan?
    var body: some View {
        if let plan { ScrollView { VStack(alignment: .leading, spacing: 16) { preview(plan.source); Text(plan.filename).font(.headline).textSelection(.enabled); detail("Captured", plan.captureDate?.formatted(date: .complete, time: .standard) ?? "No EXIF capture date"); detail("From", plan.source.path(percentEncoded: false)); detail("To", plan.destinationDescription); if !plan.sidecars.isEmpty { detail("Sidecars", plan.sidecars.map(\.lastPathComponent).joined(separator: ", ")) }; if case .failed(let message) = plan.state { Label(message, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(.red) }; Spacer(minLength: 0) }.padding(18) } } else { ContentUnavailableView("Select a Photo", systemImage: "photo") }
    }
    @ViewBuilder private func preview(_ url: URL) -> some View { if let image = NSImage(contentsOf: url) { Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 260).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8)) } else { RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.25)).frame(height: 180).overlay { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) } } }
    private func detail(_ label: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 3) { Text(label).font(.caption.bold()).foregroundStyle(.secondary); Text(value).font(.callout).textSelection(.enabled) } }
}
