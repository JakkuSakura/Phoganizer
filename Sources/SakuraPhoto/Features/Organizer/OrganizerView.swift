import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state
    @State private var confirmingOrganization = false
    @State private var showingSources = false
    var body: some View {
        TabView {
            NavigationSplitView {
                SourceSidebar(addSource: openSourcePanel)
            } detail: {
                VStack(spacing: 0) {
                    reviewHeader
                    Divider()
                    if state.plans.isEmpty { emptyState } else {
                        overview
                        Divider()
                        HSplitView {
                            planTable.frame(minWidth: 560, idealWidth: 680)
                            PhotoDetailView(plan: state.selectedPlan).frame(minWidth: 300, idealWidth: 360)
                        }
                    }
                    Divider(); statusBar
                }
            }
            .tabItem { Label("Review", systemImage: "photo.on.rectangle") }
            SourceManagementView()
                .tabItem { Label("Sources", systemImage: "externaldrive") }
        }
        .confirmationDialog("Organize \(state.readyCount.formatted()) photos?", isPresented: $confirmingOrganization) {
            Button("Organize Photos") { state.organize() }; Button("Cancel", role: .cancel) { }
        } message: { Text("Photos and matching sidecars will move into dated folders. Existing files will not be overwritten.") }
        .alert("SakuraPhoto", isPresented: Binding(get: { state.errorMessage != nil }, set: { if !$0 { state.errorMessage = nil } })) { Button("OK") { state.errorMessage = nil } } message: { Text(state.errorMessage ?? "Unknown error") }
    }

    private var reviewHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Review Photos").font(.title2.bold())
                Text(state.sources.isEmpty ? "Add a source to begin" : "Review, classify, and prepare your organization")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            TextField("Rename pattern", text: Binding(get: { state.pattern.value }, set: { state.pattern.value = $0 }))
                .textFieldStyle(.roundedBorder).frame(width: 220)
                .help("Tokens: {date}, {time}, {seq}, {original}, {class}, {ext}")
                .onSubmit { state.scan() }
            Button { state.scan() } label: { Label("Scan", systemImage: "magnifyingglass") }
                .disabled(state.sources.isEmpty || state.isWorking)
            Button { confirmingOrganization = true } label: { Label("Organize", systemImage: "arrow.right.circle.fill") }
                .buttonStyle(.borderedProminent).disabled(state.readyCount == 0 || state.isWorking)
        }.padding(.horizontal, 18).padding(.vertical, 12)
    }
    private var toolbar: some View {
        HStack(spacing: 10) {
            Menu { Button { openSourcePanel() } label: { Label("Choose Folder or SD Card…", systemImage: "folder.badge.plus") }; ForEach(CommonPhotoLocations.locations, id: \.0) { location in Button { state.addSource(location.1) } label: { Label(location.0, systemImage: location.2) } } } label: { Label("Add Source…", systemImage: "folder.badge.plus") }.keyboardShortcut("o")
            Button { state.scan() } label: { Label("Rescan", systemImage: "arrow.clockwise") }.disabled(state.root == nil || state.isWorking)
            Spacer()
            TextField("Pattern", text: Binding(get: { state.pattern.value }, set: { state.pattern.value = $0 }))
                .frame(width: 190).textFieldStyle(.roundedBorder)
                .help("Tokens: {date}, {time}, {seq}, {original}, {class}, {ext}")
                .onSubmit { state.scan() }
            if !state.sources.isEmpty {
                Button { showingSources.toggle() } label: { Label("\(state.sources.count) source\(state.sources.count == 1 ? "" : "s")", systemImage: "externaldrive") }
                    .buttonStyle(.borderless).foregroundStyle(.secondary)
                    .popover(isPresented: $showingSources) { SourceListView().environment(state) }
            }
            Button { confirmingOrganization = true } label: { Label("Organize Photos", systemImage: "wand.and.stars") }.buttonStyle(.borderedProminent).disabled(state.readyCount == 0 || state.isWorking)
        }.controlSize(.small).padding(10)
    }

    private func openSourcePanel() {
        let panel = NSOpenPanel()
        panel.title = "Add Photo Sources"
        panel.message = "Choose folders, Photos, Downloads, Desktop, or a mounted Sony SD card."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { state.addSource(url, scanImmediately: false) }
        state.scan()
    }
    private var overview: some View {
        HStack(spacing: 0) { metric("Photos", state.plans.count, "photo.on.rectangle"); Divider().frame(height: 28); metric("Ready", state.readyCount, "arrow.right.circle"); Divider().frame(height: 28); metric("Sidecars", state.sidecarCount, "doc.badge.gearshape"); Divider().frame(height: 28); metric("Missing date", state.missingDateCount, "exclamationmark.triangle"); Spacer() }.padding(.horizontal, 12).padding(.vertical, 7).background(.quaternary.opacity(0.25))
    }
    private func metric(_ label: String, _ value: Int, _ symbol: String) -> some View { Label { VStack(alignment: .leading, spacing: 1) { Text(value.formatted()).font(.callout.monospaced().bold()); Text(label).font(.caption2).foregroundStyle(.secondary) } } icon: { Image(systemName: symbol).foregroundStyle(.secondary) }.frame(minWidth: 120, alignment: .leading) }
    private var emptyState: some View { ContentUnavailableView { Label("Browse and Organize Photos", systemImage: "photo.stack") } description: { Text("Add one or more folders or a mounted Sony camera disk to preview, classify, and organize photos.") } actions: { Button("Add Photo Source…") { openSourcePanel() }.buttonStyle(.borderedProminent) }.frame(maxWidth: .infinity, maxHeight: .infinity) }
    private var planTable: some View {
        @Bindable var state = state
        return Table(state.plans, selection: $state.selectedPlanID) {
            TableColumn("Photo") { plan in Label(plan.filename, systemImage: "photo").lineLimit(1) }
            TableColumn("Captured") { plan in if let date = plan.captureDate { Text(date.formatted(date: .abbreviated, time: .standard)) } else { Text("—").foregroundStyle(.secondary) } }.width(min: 145, ideal: 175)
            TableColumn("Destination") { plan in Text(plan.destination?.lastPathComponent ?? "—").font(.callout.monospaced()).foregroundStyle(plan.destination == nil ? .secondary : .primary).lineLimit(1).help(plan.destinationDescription) }.width(min: 190, ideal: 260)
            TableColumn("Status") { plan in PlanStateLabel(state: plan.state) }.width(105)
            TableColumn("Classify") { plan in
                Picker("Classification", selection: Binding(get: { plan.classification }, set: { state.classify($0, for: plan.id) })) {
                    ForEach(PhotoClassification.allCases) { value in Label(value.rawValue, systemImage: value.symbol).tag(value) }
                }.labelsHidden().pickerStyle(.menu)
            }.width(120)
        }
    }
    private var statusBar: some View { HStack(spacing: 8) { if state.isWorking { ProgressView().controlSize(.small) } else { Image(systemName: "checkmark.circle").foregroundStyle(.secondary) }; Text(state.activity).font(.caption).foregroundStyle(.secondary); Spacer(); Text("JPEG · PNG · ARW · HEIF/HIF").font(.caption2).foregroundStyle(.tertiary) }.padding(.horizontal, 10).frame(height: 28) }
}

private struct SourceManagementView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Photo Sources").font(.title2.bold())
                    Text("Manage folders, Photos, and mounted Sony A7R V cards.").foregroundStyle(.secondary)
                }
                Spacer()
                Button { openPanel() } label: { Label("Add Source…", systemImage: "plus") }.buttonStyle(.borderedProminent)
                Button("Scan All") { state.scan() }.disabled(state.sources.isEmpty || state.isWorking)
            }.padding(20)
            Divider()
            if state.sources.isEmpty {
                ContentUnavailableView("No Sources", systemImage: "externaldrive.badge.plus", description: Text("Add a folder or mounted camera card to start browsing."))
            } else {
                List {
                    ForEach(Array(state.sources.enumerated()), id: \.element.id) { _, source in
                        HStack(spacing: 12) {
                            Image(systemName: source.kind.symbol).font(.title3).foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(source.displayName).font(.headline)
                                Text(source.kind.rawValue).font(.caption).foregroundStyle(.secondary)
                                Text(source.root.path(percentEncoded: false)).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            Text("\(source.scanRoots.count) media root\(source.scanRoots.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                            Button { state.removeSource(source.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless).foregroundStyle(.red)
                        }.padding(.vertical, 5)
                    }
                }
            }
        }
        .frame(minWidth: 720, minHeight: 420)
    }

    private func openPanel() {
        let panel = NSOpenPanel(); panel.title = "Add Photo Sources"; panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = true; panel.canCreateDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { state.addSource(url, scanImmediately: false) }
        state.scan()
    }
}

private struct SourceSidebar: View {
    @Environment(AppState.self) private var state
    let addSource: () -> Void

    var body: some View {
        List {
            Section("Sources") {
                if state.sources.isEmpty {
                    Text("No sources added").font(.callout).foregroundStyle(.secondary)
                }
                ForEach(Array(state.sources.enumerated()), id: \.element.id) { _, source in
                    HStack(spacing: 8) {
                        Image(systemName: source.kind.symbol).foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.displayName).lineLimit(1)
                            Text(source.kind.rawValue).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { state.removeSource(source.id) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless).foregroundStyle(.secondary)
                    }
                    .help(source.root.path(percentEncoded: false))
                }
            }
            Section("Quick Add") {
                Button { addSource() } label: { Label("Folder or SD Card…", systemImage: "plus") }
                ForEach(CommonPhotoLocations.locations, id: \.0) { location in
                    Button { state.addSource(location.1) } label: { Label(location.0, systemImage: location.2) }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("SakuraPhoto")
        .toolbar { ToolbarItem { Button { state.scan() } label: { Image(systemName: "arrow.clockwise") }.disabled(state.sources.isEmpty || state.isWorking) } }
    }
}

private struct SourceListView: View {
    @Environment(AppState.self) private var state
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources").font(.headline)
            ForEach(Array(state.sources.enumerated()), id: \.element.id) { _, source in
                HStack { Label(source.displayName, systemImage: source.kind.symbol); Spacer(); Button { state.removeSource(source.id) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless) }
                    .help(source.root.path(percentEncoded: false))
            }
        }.padding(14).frame(width: 300)
    }
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
