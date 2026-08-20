import SwiftUI
import SwiftData

/// Kyle (2026-08-19): "pick the projects or drafts or sketches or prose (series of jokes but NOT
/// stand up) easily into the packet... edit and add things and remove easily." / follow-up: "I
/// like the idea of having the list of finished first drafts/second drafts ready, and from there
/// i can drag and drop to create packets." Split layout — this packet's current items on the
/// left, a draggable source list of everything available to add on the right (Projects grouped by
/// type, Documents grouped by draft label). Drag-and-drop uses `onDrag`/`onDrop` + `NSItemProvider`
/// (not SwiftUI's `.draggable`/`.dropDestination`, already confirmed unreliable on macOS in this
/// codebase — see ClipBoardView/WeeklyBoardView's own doc comments), same mechanism, new payload
/// prefix ("project:"/"document:") since a packet item can be either kind.
struct PacketDetailView: View {
    let packet: PacketService.Packet
    @Environment(\.modelContext) private var context
    @State private var targetName: String = ""

    private var packetID: PersistentIdentifier { packet.persistentModelID }

    @Query(sort: \KyleOSSchemaV33.Project.title) private var allProjects: [KyleOSSchemaV33.Project]
    @Query(sort: \KyleOSSchemaV33.Document.title) private var allDocuments: [KyleOSSchemaV33.Document]

    /// Live @Query, not `packet.items` held off the parent — a plain relationship array here would
    /// go stale after adding/removing items without a full view reload (the exact bug this
    /// codebase already hit once with Act/Scene lists — see feedback_swiftdata_relationship_lists).
    @Query private var allItems: [PacketService.PacketItem]

    private var items: [PacketService.PacketItem] {
        allItems.filter { $0.packet?.persistentModelID == packetID }.sorted { $0.order < $1.order }
    }

    private var availableProjects: [KyleOSSchemaV33.Project] {
        let usedIDs = Set(items.compactMap { $0.project?.id })
        return allProjects.filter { !$0.isArchived && !usedIDs.contains($0.id) }
    }

    private var availableDocuments: [KyleOSSchemaV33.Document] {
        let usedIDs = Set(items.compactMap { $0.document?.id })
        return allDocuments.filter {
            ($0.documentType == .script || $0.documentType == .prose) && !usedIDs.contains($0.id)
        }
    }

    private var documentsByDraftLabel: [(label: String, documents: [KyleOSSchemaV33.Document])] {
        Dictionary(grouping: availableDocuments, by: \.displayDraftLabel)
            .sorted { $0.key < $1.key }
            .map { (label: $0.key, documents: $0.value) }
    }

    @State private var isTargeted = false

    var body: some View {
        HSplitView {
            packetItemsPane
                .frame(minWidth: 320, maxWidth: .infinity)
            sourcePane
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 380)
        }
        .navigationTitle(packet.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                TextField("Show or production company", text: $targetName)
                    .retroInputStyle()
                    .frame(width: 220)
                    .onSubmit(saveTargetName)
                    .onChange(of: targetName) { _, _ in saveTargetName() }
            }
        }
        .onAppear { targetName = packet.targetName }
    }

    private func saveTargetName() {
        guard targetName != packet.targetName else { return }
        PacketService.updatePacket(packet, title: packet.title, targetName: targetName)
        try? context.save()
    }

    private var packetItemsPane: some View {
        VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
            Text("IN THIS PACKET")
                .font(.caption.bold())
                .foregroundStyle(RetroTheme.secondaryText)
            if items.isEmpty {
                Text("Drag projects, drafts, sketches, or prose from the right to add them.")
                    .foregroundStyle(RetroTheme.secondaryText)
                    .padding(RetroTheme.sectionPadding)
            } else {
                RetroPanel {
                    VStack(spacing: 0) {
                        ForEach(items) { item in
                            itemRow(item)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(RetroTheme.sectionPadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(isTargeted ? RetroTheme.accent.opacity(0.12) : RetroTheme.background)
        .overlay(Rectangle().strokeBorder(isTargeted ? RetroTheme.accent : .clear, lineWidth: 3))
        .contentShape(Rectangle())
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { reading, _ in
                guard let payload = reading as? String else { return }
                DispatchQueue.main.async { addFromPayload(payload) }
            }
            return true
        }
        .animation(RetroTheme.interactionAnimation, value: isTargeted)
    }

    private func itemRow(_ item: PacketService.PacketItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(PacketService.displayTitle(for: item)).foregroundStyle(RetroTheme.primaryText)
                Text(PacketService.displaySubtitle(for: item))
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            }
            Spacer()
            Button(role: .destructive) {
                PacketService.removeItem(item, from: packet, context: context)
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

    private var sourcePane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
                if !availableProjects.isEmpty {
                    RetroPanel("Projects") {
                        VStack(spacing: 0) {
                            ForEach(availableProjects) { project in
                                sourceRow(
                                    title: project.title,
                                    subtitle: project.projectType == .sketch ? "Sketch Project" : "Writing Project",
                                    dragPayload: "project:\(project.id.uuidString)"
                                ) {
                                    PacketService.addProject(project, to: packet, context: context)
                                    try? context.save()
                                }
                            }
                        }
                    }
                }
                if !documentsByDraftLabel.isEmpty {
                    ForEach(documentsByDraftLabel, id: \.label) { group in
                        RetroPanel(group.label) {
                            VStack(spacing: 0) {
                                ForEach(group.documents) { document in
                                    sourceRow(
                                        title: document.title,
                                        subtitle: document.documentType.rawValue,
                                        dragPayload: "document:\(document.id.uuidString)"
                                    ) {
                                        PacketService.addDocument(document, to: packet, context: context)
                                        try? context.save()
                                    }
                                }
                            }
                        }
                    }
                }
                if availableProjects.isEmpty && documentsByDraftLabel.isEmpty {
                    Text("Everything's already in this packet, or there's nothing to add yet.")
                        .font(.caption)
                        .foregroundStyle(RetroTheme.secondaryText)
                        .padding(RetroTheme.sectionPadding)
                }
            }
            .padding(RetroTheme.sectionPadding)
        }
        .background(RetroTheme.panelBackground)
    }

    /// `onAdd` is a plain click-to-add fallback alongside the drag — Kyle's own spec doesn't rule
    /// out clicking, and requiring a drag for every single addition would be a worse experience
    /// than the shared onDrag/onDrop pattern elsewhere in this app, which always keeps a click path
    /// too (e.g. ClipBoardView's lanes still support the old contextual actions).
    private func sourceRow(title: String, subtitle: String, dragPayload: String, onAdd: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(RetroTheme.primaryText)
                Text(subtitle).font(.caption).foregroundStyle(RetroTheme.secondaryText)
            }
            Spacer()
            Button {
                onAdd()
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.retro)
        }
        .padding(.horizontal, RetroTheme.controlSpacing + 4)
        .padding(.vertical, RetroTheme.controlSpacing)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
        }
        .onDrag {
            NSItemProvider(object: dragPayload as NSString)
        }
    }

    private func addFromPayload(_ payload: String) {
        if payload.hasPrefix("project:"), let uuid = UUID(uuidString: String(payload.dropFirst("project:".count))),
           let project = allProjects.first(where: { $0.id == uuid }) {
            PacketService.addProject(project, to: packet, context: context)
            try? context.save()
        } else if payload.hasPrefix("document:"), let uuid = UUID(uuidString: String(payload.dropFirst("document:".count))),
                  let document = allDocuments.first(where: { $0.id == uuid }) {
            PacketService.addDocument(document, to: packet, context: context)
            try? context.save()
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let packet = PacketService.createPacket(title: "SNL Submission", targetName: "Saturday Night Live", context: context)
    try? context.save()
    return NavigationStack {
        PacketDetailView(packet: packet)
    }
    .modelContainer(container)
}
