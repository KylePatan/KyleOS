import SwiftUI
import SwiftData

/// PRD §7.8: "Stand Up should store gigs with date, venue, show, start time, set length,
/// location, and notes." List of all Gigs sorted by date, + New Gig, drilling into
/// GigDetailView for full editing.
struct GigListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \GigService.Gig.startAt) private var gigs: [GigService.Gig]

    @State private var newVenue = ""
    @State private var newStartAt = Date.now
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    TextField("Venue", text: $newVenue)
                        .textFieldStyle(.roundedBorder)
                    DatePicker("", selection: $newStartAt)
                        .labelsHidden()
                    Button("Add Gig", action: createGig)
                        .disabled(newVenue.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if gigs.isEmpty {
                    Text("No gigs yet. Add one to see it appear on the Calendar automatically.")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(gigs) { gig in
                            HStack {
                                NavigationLink(value: gig.persistentModelID) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(gig.venue)
                                        Text(summary(for: gig))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    GigService.delete(gig, context: context)
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
                if let gig = gigs.first(where: { $0.persistentModelID == id }) {
                    GigDetailView(gig: gig)
                }
            }
        }
    }

    private func summary(for gig: GigService.Gig) -> String {
        let date = gig.startAt.formatted(date: .abbreviated, time: .shortened)
        return gig.show.isEmpty ? date : "\(gig.show) · \(date)"
    }

    private func createGig() {
        let venue = newVenue.trimmingCharacters(in: .whitespaces)
        guard !venue.isEmpty else { return }
        GigService.createGig(venue: venue, startAt: newStartAt, context: context)
        try? context.save()
        newVenue = ""
        newStartAt = .now
    }
}

#Preview {
    GigListView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
