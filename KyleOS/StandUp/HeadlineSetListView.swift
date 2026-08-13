import SwiftUI
import SwiftData

/// PRD §7.7: "The Headline Set represents the evolving album/headlining set." List of all
/// Headline Sets, + New, drilling into HeadlineSetDetailView for Chunk membership management.
struct HeadlineSetListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HeadlineSetService.HeadlineSet.createdAt) private var sets: [HeadlineSetService.HeadlineSet]

    @State private var newSetTitle = ""
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    TextField("New headline set title", text: $newSetTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(createSet)
                    Button("Add Set", action: createSet)
                        .disabled(newSetTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if sets.isEmpty {
                    Text("No headline sets yet. Build one from your Chunks once a set starts taking shape.")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(sets) { set in
                            HStack {
                                NavigationLink(value: set.persistentModelID) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(set.title)
                                        Text(runtimeSummary(for: set))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    HeadlineSetService.delete(set, context: context)
                                    try? context.save()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let set = sets.first(where: { $0.persistentModelID == id }) {
                    HeadlineSetDetailView(headlineSet: set)
                }
            }
        }
    }

    private func runtimeSummary(for set: HeadlineSetService.HeadlineSet) -> String {
        let current = TimeFormatting.shortDuration(HeadlineSetService.totalRuntimeSeconds(for: set))
        let target = TimeFormatting.shortDuration(HeadlineSetService.targetDurationSeconds(for: set))
        return "\(current) of \(target) target"
    }

    private func createSet() {
        let title = newSetTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        HeadlineSetService.createHeadlineSet(title: title, context: context)
        try? context.save()
        newSetTitle = ""
    }
}

#Preview {
    HeadlineSetListView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
