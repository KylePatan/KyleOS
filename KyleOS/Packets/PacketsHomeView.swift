import SwiftUI
import SwiftData

/// Kyle (2026-08-19): "Create a Packet, name the packet of the show/production company I want to
/// send it to... have multiple packets for shows." Top-level list of Packets + inline create,
/// mirroring GigListView/SourceListView's own "inline fields + Add" convention rather than a
/// modal sheet, for one simple two-field create action.
struct PacketsHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PacketService.Packet.updatedAt, order: .reverse) private var packets: [PacketService.Packet]

    @State private var newTitle = ""
    @State private var newTargetName = ""
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
                RetroPanel {
                    HStack {
                        TextField("Packet name", text: $newTitle)
                            .retroInputStyle()
                        TextField("Show or production company", text: $newTargetName)
                            .retroInputStyle()
                        Button("Create Packet", action: createPacket)
                            .buttonStyle(.retroProminent)
                            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if packets.isEmpty {
                    Text("No packets yet. Create one to start building a submission.")
                        .foregroundStyle(RetroTheme.secondaryText)
                } else {
                    RetroPanel("Packets") {
                        VStack(spacing: 0) {
                            ForEach(packets) { packet in
                                packetRow(packet)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(RetroTheme.sectionPadding)
            .background(RetroTheme.background)
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let packet = packets.first(where: { $0.persistentModelID == id }) {
                    PacketDetailView(packet: packet)
                }
            }
        }
    }

    private func packetRow(_ packet: PacketService.Packet) -> some View {
        HStack {
            NavigationLink(value: packet.persistentModelID) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(packet.title).foregroundStyle(RetroTheme.primaryText)
                    Text("\(packet.targetName) · \(packet.items.count) item\(packet.items.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(RetroTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button(role: .destructive) {
                PacketService.deletePacket(packet, context: context)
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

    private func createPacket() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let targetName = newTargetName.trimmingCharacters(in: .whitespaces)
        _ = PacketService.createPacket(title: title, targetName: targetName, context: context)
        try? context.save()
        newTitle = ""
        newTargetName = ""
    }
}

#Preview {
    PacketsHomeView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
