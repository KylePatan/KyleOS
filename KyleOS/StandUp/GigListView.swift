import SwiftUI
import SwiftData

/// PRD §7.8: "Stand Up should store gigs with date, venue, show, start time, set length,
/// location, and notes." List of all Gigs sorted by date, + New Gig, drilling into
/// GigDetailView for full editing.
struct GigListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \GigService.Gig.startAt) private var gigs: [GigService.Gig]

    @State private var newVenue = ""
    @State private var newStartAt = Date.now
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
                RetroPanel {
                    HStack {
                        TextField("Venue", text: $newVenue)
                            .retroInputStyle()
                        DatePicker("", selection: $newStartAt)
                            .labelsHidden()
                        Button("Add Gig", action: createGig)
                            .buttonStyle(.retroProminent)
                            .disabled(newVenue.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if gigs.isEmpty {
                    Text("No gigs yet. Add one to see it appear on the Calendar automatically.")
                        .foregroundStyle(RetroTheme.secondaryText)
                } else {
                    RetroPanel("Gigs") {
                        VStack(spacing: 0) {
                            ForEach(gigs) { gig in
                                HStack {
                                    NavigationLink(value: gig.persistentModelID) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(gig.venue).foregroundStyle(RetroTheme.primaryText)
                                            HStack(spacing: 6) {
                                                Text(summary(for: gig))
                                                if GigService.needsAfterGigNotes(gig) {
                                                    Text("· Needs notes")
                                                        .foregroundStyle(RetroTheme.warning)
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundStyle(RetroTheme.secondaryText)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    Spacer()
                                    Button {
                                        openWindow(value: DetachedWindowTarget.gigDetail(gig.persistentModelID))
                                    } label: {
                                        Image(systemName: "arrow.up.forward.square")
                                    }
                                    .buttonStyle(.retro)
                                    .help("Open in a new window")
                                    Button(role: .destructive) {
                                        GigService.delete(gig, context: context)
                                        try? context.save()
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.retro)
                                }
                                .padding(.horizontal, RetroTheme.controlSpacing + 4)
                                .padding(.vertical, RetroTheme.controlSpacing)
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(RetroTheme.sectionPadding)
            .background(RetroTheme.background)
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
