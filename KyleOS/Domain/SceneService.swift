import Foundation
import SwiftData

/// Reusable domain actions for the Scene Outline (PRD §6.11/§14.4), kept out of views per
/// CLAUDE.md §4.
///
/// Implementation note (CLAUDE.md §13 — a small implementation detail, documented rather than
/// asked about): the PRD lists "Scene Outline" as its own Document type (§14.2) and shows it
/// side-by-side with the Act Outline (§6.12), which could be read as two independent documents.
/// But §14.4 says "Act Outline and Scene Outline should eventually share scene relationships
/// with the actual Script" — i.e. Scene Outline isn't independent data, it's a more detailed
/// view of the SAME acts. Modeling a second, separate Document that duplicates or cross-links
/// the same Acts would invite the two falling out of sync. Scenes therefore belong directly to
/// Act (`Act.scenes`), and the Scene Outline is a drill-down view of an Act Outline document,
/// not a separate Document row. Side-by-side split view (§6.12/§6.13) is a later increment; this
/// choice doesn't block it — a split view can show an Act Outline pane and a Scene Outline pane
/// of the same underlying Acts/Scenes without them being separate Documents.
enum SceneService {
    typealias Scene = KyleOSSchemaV20.Scene
    typealias SceneLocationType = KyleOSSchemaV20.SceneLocationType
    typealias Act = KyleOSSchemaV20.Act
    typealias Document = KyleOSSchemaV20.Document

    @discardableResult
    static func createScene(in act: Act, context: ModelContext) -> Scene {
        let scene = Scene(act: act, orderWithinAct: act.scenes.count)
        context.insert(scene)
        return scene
    }

    static func update(
        _ scene: Scene,
        locationType: SceneLocationType? = nil,
        location: String? = nil,
        timeOfDay: String? = nil,
        sceneDescription: String? = nil,
        purpose: String? = nil,
        characters: String? = nil,
        keyBeats: String? = nil,
        notes: String? = nil
    ) {
        if let locationType { scene.locationType = locationType }
        if let location { scene.location = location }
        if let timeOfDay { scene.timeOfDay = timeOfDay }
        if let sceneDescription { scene.sceneDescription = sceneDescription }
        if let purpose { scene.purpose = purpose }
        if let characters { scene.characters = characters }
        if let keyBeats { scene.keyBeats = keyBeats }
        if let notes { scene.notes = notes }
        scene.updatedAt = .now
    }

    static func scenes(for act: Act) -> [Scene] {
        act.scenes.sorted { $0.orderWithinAct < $1.orderWithinAct }
    }

    static func delete(_ scene: Scene, from act: Act, context: ModelContext) {
        context.delete(scene)
        renumber(scenes(for: act).filter { $0.id != scene.id })
    }

    /// PRD §6.11: "Scenes should be draggable within and between Acts."
    static func reorder(within act: Act, movingFromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = scenes(for: act)
        ordered.move(fromOffsets: source, toOffset: destination)
        renumber(ordered)
    }

    static func move(_ scene: Scene, to newAct: Act, context: ModelContext) {
        let oldAct = scene.act
        let priorCountInNewAct = newAct.scenes.count
        scene.act = newAct
        scene.orderWithinAct = priorCountInNewAct
        scene.updatedAt = .now
        if let oldAct {
            renumber(scenes(for: oldAct))
        }
    }

    /// PRD: "Renumbering should update automatically." Scene Number isn't stored — it's each
    /// scene's overall sequential position across the whole Act Outline (every act in order,
    /// every scene within each act in order), computed fresh so it can never drift.
    static func numberedScenes(for document: Document) -> [(scene: Scene, number: Int)] {
        let orderedActs = ActService.acts(for: document)
        let orderedScenes = orderedActs.flatMap { scenes(for: $0) }
        return orderedScenes.enumerated().map { index, scene in (scene, index + 1) }
    }

    private static func renumber(_ orderedScenes: [Scene]) {
        for (index, scene) in orderedScenes.enumerated() {
            scene.orderWithinAct = index
            scene.updatedAt = .now
        }
    }
}
