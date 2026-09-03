import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// PRD §8.2/§8.3: Source detail — title/recordingDate/location/notes, an attached local video
/// file reference ("Kyle OS should normally reference the existing local video file instead of
/// copying it"), and its child Clips.
struct SourceDetailView: View {
    let source: SourceService.Source
    @Environment(\.modelContext) private var context

    /// Live @Query, not `source.clips` read via `ClipService.clips(in:)` — same class of
    /// stale-list bug confirmed for Add Scene (see SceneListView.swift's doc comment); "Add Clip"
    /// has the identical shape (a new Clip inserted, inverse-linked to `source`).
    @Query(sort: \ClipService.Clip.createdAt) private var allClips: [ClipService.Clip]

    @State private var title = ""
    @State private var recordingDate = Date.now
    @State private var hasRecordingDate = false
    @State private var location = ""
    @State private var notes = ""
    @State private var newClipTitle = ""

    private var clips: [ClipService.Clip] {
        allClips.filter { $0.source?.persistentModelID == source.persistentModelID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
                header
                fileSection
                clipsSection
            }
            .padding(RetroTheme.sectionPadding)
        }
        .background(RetroTheme.background)
        .navigationTitle(source.title)
        .onAppear {
            title = source.title
            location = source.location
            notes = source.notes
            if let date = source.recordingDate {
                recordingDate = date
                hasRecordingDate = true
            }
        }
    }

    private var header: some View {
        RetroPanel {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                TextField("Source title", text: $title)
                    .font(.title3.bold())
                    .textFieldStyle(.plain)
                    .foregroundStyle(RetroTheme.primaryText)
                    .onChange(of: title) {
                        SourceService.rename(source, to: title)
                        try? context.save()
                    }
                TextField("Location", text: $location)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(RetroTheme.secondaryText)
                    .onChange(of: location) {
                        SourceService.updateLocation(source, location: location)
                        try? context.save()
                    }
                Toggle("Recording date", isOn: $hasRecordingDate)
                    .onChange(of: hasRecordingDate) {
                        SourceService.updateRecordingDate(source, date: hasRecordingDate ? recordingDate : nil)
                        try? context.save()
                    }
                if hasRecordingDate {
                    DatePicker("", selection: $recordingDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: recordingDate) {
                            SourceService.updateRecordingDate(source, date: recordingDate)
                            try? context.save()
                        }
                }
                TextField("Notes", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(RetroTheme.secondaryText)
                    .onChange(of: notes) {
                        SourceService.updateNotes(source, notes: notes)
                        try? context.save()
                    }
            }
        }
    }

    private var fileSection: some View {
        RetroPanel("Footage", accentCategory: .clips) {
            if let reference = source.fileReference {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reference.displayName).foregroundStyle(RetroTheme.primaryText)
                    Text(reference.lastKnownAvailable ? reference.originalPath : "File currently unavailable")
                        .font(.caption)
                        .foregroundStyle(reference.lastKnownAvailable ? RetroTheme.secondaryText : RetroTheme.warning)
                }
            } else {
                Button("Attach Footage File…", action: attachFile)
                    .buttonStyle(.retro)
            }
        }
    }

    private func attachFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .quickTimeMovie, .mpeg4Movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? SourceService.attachFile(to: source, displayName: url.lastPathComponent, fileURL: url, context: context)
        try? context.save()
    }

    private var clipsSection: some View {
        RetroPanel("Clips", accentCategory: .clips) {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                HStack {
                    TextField("New clip title", text: $newClipTitle)
                        .retroInputStyle()
                        .onSubmit(createClip)
                    Button("Add Clip", action: createClip)
                        .buttonStyle(.retroProminent)
                        .disabled(newClipTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if clips.isEmpty {
                    Text("No clips identified yet.")
                        .foregroundStyle(RetroTheme.secondaryText)
                } else {
                    List {
                        ForEach(clips) { clip in
                            HStack {
                                NavigationLink(value: ClipRoute(id: clip.persistentModelID)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(clip.title).foregroundStyle(RetroTheme.primaryText)
                                        Text(clip.status.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(RetroTheme.secondaryText)
                                    }
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Button(role: .destructive) {
                                    ClipService.delete(clip, context: context)
                                    try? context.save()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.retro)
                            }
                            .listRowBackground(RetroTheme.panelBackground)
                            .listRowSeparatorTint(RetroTheme.border.opacity(0.5))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(height: min(max(120, CGFloat(clips.count) * 50 + 20), RetroTheme.maxListHeight))
                }
            }
        }
    }

    private func createClip() {
        let title = newClipTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        ClipService.createClip(title: title, in: source, context: context)
        try? context.save()
        newClipTitle = ""
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let source = SourceService.createSource(title: "March Comedy Slam", context: context)
    ClipService.createClip(title: "Airline Bit", in: source, context: context)
    return NavigationStack {
        SourceDetailView(source: source)
    }
    .modelContainer(container)
}
