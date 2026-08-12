import SwiftUI
import SwiftData

/// PRD §6.11's Scene Outline, scoped to one Act (see SceneService.swift's doc comment for why
/// Scene Outline is a drill-down of Act Outline rather than a separate document). Fields per
/// §6.11: Act, Scene Number, INT./EXT., Location/heading, Time of day, Description, Purpose,
/// Characters, Key beats, Notes. Scene Number is shown but not stored — it's this act's owning
/// document's overall sequence, always computed fresh (§6.11: "Renumbering should update
/// automatically").
struct SceneListView: View {
    let act: ActService.Act
    @Environment(\.modelContext) private var context

    private var scenes: [SceneService.Scene] {
        SceneService.scenes(for: act)
    }

    private var otherActs: [ActService.Act] {
        guard let document = act.document else { return [] }
        return ActService.acts(for: document).filter { $0.id != act.id }
    }

    private var sceneNumbers: [PersistentIdentifier: Int] {
        guard let document = act.document else { return [:] }
        return Dictionary(uniqueKeysWithValues: SceneService.numberedScenes(for: document).map { ($0.scene.persistentModelID, $0.number) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if scenes.isEmpty {
                Text("No scenes in this act yet.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                List {
                    ForEach(scenes) { scene in
                        SceneRow(
                            scene: scene,
                            sceneNumber: sceneNumbers[scene.persistentModelID] ?? 0,
                            otherActs: otherActs,
                            onDelete: {
                                SceneService.delete(scene, from: act, context: context)
                                try? context.save()
                            },
                            onMove: { newAct in
                                SceneService.move(scene, to: newAct, context: context)
                                try? context.save()
                            }
                        )
                    }
                    .onMove { source, destination in
                        SceneService.reorder(within: act, movingFromOffsets: source, toOffset: destination)
                        try? context.save()
                    }
                }
            }
            Button {
                SceneService.createScene(in: act, context: context)
                try? context.save()
            } label: {
                Label("Add Scene", systemImage: "plus")
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .navigationTitle(act.title)
    }
}

private struct SceneRow: View {
    let scene: SceneService.Scene
    let sceneNumber: Int
    let otherActs: [ActService.Act]
    let onDelete: () -> Void
    let onMove: (ActService.Act) -> Void

    @Environment(\.modelContext) private var context
    @State private var location = ""
    @State private var timeOfDay = ""
    @State private var sceneDescription = ""
    @State private var purpose = ""
    @State private var characters = ""
    @State private var keyBeats = ""
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Scene \(sceneNumber)").font(.caption.bold()).foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { scene.locationType },
                    set: { SceneService.update(scene, locationType: $0); try? context.save() }
                )) {
                    ForEach(SceneService.SceneLocationType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
                TextField("Location", text: $location)
                    .textFieldStyle(.plain)
                    .font(.body.bold())
                    .onChange(of: location) { SceneService.update(scene, location: location); try? context.save() }
                TextField("Time of day", text: $timeOfDay)
                    .textFieldStyle(.plain)
                    .frame(width: 100)
                    .onChange(of: timeOfDay) { SceneService.update(scene, timeOfDay: timeOfDay); try? context.save() }
                Spacer()
                if !otherActs.isEmpty {
                    Menu {
                        ForEach(otherActs) { act in
                            Button(act.title) { onMove(act) }
                        }
                    } label: {
                        Image(systemName: "arrow.right.arrow.left")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            TextField("Scene description", text: $sceneDescription, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.callout)
                .onChange(of: sceneDescription) { SceneService.update(scene, sceneDescription: sceneDescription); try? context.save() }
            HStack {
                TextField("Purpose", text: $purpose)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .onChange(of: purpose) { SceneService.update(scene, purpose: purpose); try? context.save() }
                TextField("Characters", text: $characters)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .onChange(of: characters) { SceneService.update(scene, characters: characters); try? context.save() }
            }
            TextField("Key beats / notes", text: $keyBeats, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .onChange(of: keyBeats) { SceneService.update(scene, keyBeats: keyBeats); try? context.save() }
        }
        .padding(.vertical, 6)
        .onAppear {
            location = scene.location
            timeOfDay = scene.timeOfDay
            sceneDescription = scene.sceneDescription
            purpose = scene.purpose
            characters = scene.characters
            keyBeats = scene.keyBeats
            notes = scene.notes
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let project = ProjectService.createProject(title: "Coastal Town", projectType: .tvPilot, in: context)
    let document = DocumentService.createDocument(title: "Act Outline", type: .actOutline, in: project, context: context)
    let act = ActService.createAct(title: "Act One", in: document, context: context)
    let scene = SceneService.createScene(in: act, context: context)
    SceneService.update(scene, locationType: .int, location: "KITCHEN", timeOfDay: "Morning", sceneDescription: "Our hero makes coffee.")
    return NavigationStack {
        SceneListView(act: act)
    }
    .modelContainer(container)
}
