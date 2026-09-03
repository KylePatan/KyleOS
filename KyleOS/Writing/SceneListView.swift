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

    /// Live @Query, not `SceneService.scenes(for: act)` (which just reads `act.scenes` off this
    /// plain-held `act` reference) — confirmed live (2026-08-16, Kyle: "add scene... nothing
    /// happens") that a to-many relationship read this way does NOT reliably trigger a SwiftUI
    /// re-render when a new child is inserted elsewhere and linked via its own `act` property; the
    /// new Scene persisted correctly (visible after relaunch) but never appeared on screen without
    /// one. `@Query` is the one data source SwiftData reliably re-fetches and republishes on every
    /// save, so every list in this app that needs to grow live should be backed by one directly,
    /// not by reading a relationship off a manually-held parent — see also
    /// `ArchivedWritingProjectsSheet` in WritingHomeView.swift for the same fix applied
    /// preemptively. Broad, unfiltered @Query + in-memory filter by `persistentModelID` (rather
    /// than a `#Predicate` comparing the relationship directly) matches this codebase's existing
    /// workaround for SwiftData predicate limitations (see WritingHomeView's own doc comment) and
    /// costs nothing at this app's realistic scene counts.
    @Query(sort: \SceneService.Scene.orderWithinAct) private var allScenes: [SceneService.Scene]

    private var scenes: [SceneService.Scene] {
        allScenes.filter { $0.act?.persistentModelID == act.persistentModelID }
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
        // Kyle (2026-08-27): "when there are many items anywhere, it has to be able to scroll to
        // see everything." Scene rows are tall (190pt each) — even a handful of scenes could push
        // "Add Scene" off the bottom of the window with no way to reach it, on top of the List's
        // own height cap (RetroTheme.maxListHeight) once a single act has many scenes.
        ScrollView {
            VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
                if scenes.isEmpty {
                    Text("No scenes in this act yet.")
                        .foregroundStyle(RetroTheme.secondaryText)
                } else {
                    RetroPanel("Scenes", accentCategory: .writing) {
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
                                .listRowBackground(RetroTheme.panelBackground)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparatorTint(RetroTheme.border.opacity(0.5))
                            }
                            .onMove { source, destination in
                                SceneService.reorder(within: act, movingFromOffsets: source, toOffset: destination)
                                try? context.save()
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .frame(height: min(max(160, CGFloat(scenes.count) * 190 + 20), RetroTheme.maxListHeight))
                    }
                }
                Button {
                    SceneService.createScene(in: act, context: context)
                    try? context.save()
                } label: {
                    Label("Add Scene", systemImage: "plus")
                }
                .buttonStyle(.retroProminent)
            }
            .padding(RetroTheme.sectionPadding)
        }
        .background(RetroTheme.background)
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

    /// Kyle (2026-08-16): "I think it should be like a fill in the blanks. INT EXT. PLACE OF
    /// SCENE. SHORT DESCRIPTION OF SCENE and then below it a big field to fill in of things that
    /// happen in the scene." The cue line (type/location/time) stays compact; Scene description
    /// is now the visually prominent field — larger text, a real inset well, room to grow — since
    /// that's literally "what happens in the scene." Purpose/Characters/Key beats stay small,
    /// secondary metadata below it.
    var body: some View {
        VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
            HStack {
                Text("Scene \(sceneNumber)").font(.caption.bold()).foregroundStyle(RetroTheme.secondaryText)
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
                    .foregroundStyle(RetroTheme.primaryText)
                    .onChange(of: location) { SceneService.update(scene, location: location); try? context.save() }
                TextField("Time of day", text: $timeOfDay)
                    .textFieldStyle(.plain)
                    .foregroundStyle(RetroTheme.secondaryText)
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
                .buttonStyle(.retro)
            }
            TextField("What happens in this scene?", text: $sceneDescription, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(RetroTheme.primaryText)
                .lineLimit(3...8)
                .padding(RetroTheme.controlSpacing)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(RetroTheme.insetBackground)
                .overlay(RetroBevel(isPressed: true))
                .overlay(Rectangle().strokeBorder(RetroTheme.border, lineWidth: RetroTheme.borderWidth))
                .onChange(of: sceneDescription) { SceneService.update(scene, sceneDescription: sceneDescription); try? context.save() }
            HStack {
                TextField("Purpose", text: $purpose)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
                    .onChange(of: purpose) { SceneService.update(scene, purpose: purpose); try? context.save() }
                TextField("Characters", text: $characters)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
                    .onChange(of: characters) { SceneService.update(scene, characters: characters); try? context.save() }
            }
            TextField("Key beats / notes", text: $keyBeats, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundStyle(RetroTheme.secondaryText)
                .onChange(of: keyBeats) { SceneService.update(scene, keyBeats: keyBeats); try? context.save() }
        }
        .padding(RetroTheme.controlSpacing + 4)
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
