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

    @State private var title = ""
    @State private var recordingDate = Date.now
    @State private var hasRecordingDate = false
    @State private var location = ""
    @State private var notes = ""
    @State private var newClipTitle = ""

    private var clips: [ClipService.Clip] {
        ClipService.clips(in: source)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                fileSection
                Divider()
                clipsSection
            }
            .padding()
        }
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
        VStack(alignment: .leading, spacing: 8) {
            TextField("Source title", text: $title)
                .font(.title3.bold())
                .textFieldStyle(.plain)
                .onChange(of: title) {
                    SourceService.rename(source, to: title)
                    try? context.save()
                }
            TextField("Location", text: $location)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
                .onChange(of: notes) {
                    SourceService.updateNotes(source, notes: notes)
                    try? context.save()
                }
        }
    }

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Footage").font(.headline)
            if let reference = source.fileReference {
                Text(reference.displayName)
                Text(reference.lastKnownAvailable ? reference.originalPath : "File currently unavailable")
                    .font(.caption)
                    .foregroundStyle(reference.lastKnownAvailable ? Color.secondary : Color.orange)
            } else {
                Button("Attach Footage File…", action: attachFile)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("New clip title", text: $newClipTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(createClip)
                Button("Add Clip", action: createClip)
                    .disabled(newClipTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Clips").font(.headline)
            if clips.isEmpty {
                Text("No clips identified yet.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(clips) { clip in
                        HStack {
                            NavigationLink(value: ClipRoute(id: clip.persistentModelID)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(clip.title)
                                    Text(clip.status.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                ClipService.delete(clip, context: context)
                                try? context.save()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 120, idealHeight: CGFloat(clips.count) * 50 + 20)
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
