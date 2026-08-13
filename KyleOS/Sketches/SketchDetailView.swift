import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// PRD §9.3/§9.4/§9.5: Sketch production detail — status/post-date, the full Film Scheduling
/// field set, the generated Call Sheet, and Script access. "Writing remains inside Writing" —
/// this screen manages production logistics, not the script's own text (still edited in Writing;
/// only exported/accessed from here).
struct SketchDetailView: View {
    let project: ProjectService.Project
    @Environment(\.modelContext) private var context

    @State private var status: SketchProductionService.SketchProductionStatus = .filmingNotScheduled
    @State private var hasPostDate = false
    @State private var postDate = Date.now

    @State private var callTime = Date.now
    @State private var estimatedWrapTime = Date.now.addingTimeInterval(8 * 3600)
    @State private var location = ""
    @State private var address = ""
    @State private var cast = ""
    @State private var crew = ""
    @State private var wardrobe = ""
    @State private var props = ""
    @State private var equipmentNotes = ""
    @State private var parkingAccessInstructions = ""
    @State private var generalNotes = ""

    @State private var callSheetCastAndCharacters = ""
    @State private var callSheetCrewAndRoles = ""
    @State private var contactInformation = ""
    @State private var callSheetWardrobe = ""
    @State private var callSheetProps = ""
    @State private var callSheetEquipment = ""
    @State private var callSheetParkingAccess = ""
    @State private var sceneNotes = ""
    @State private var additionalNotes = ""

    private var shoot: SketchProductionService.FilmShoot? {
        project.sketchProduction?.filmShoot
    }
    private var callSheet: SketchProductionService.CallSheet? {
        shoot?.callSheet
    }
    private var scriptDocument: DocumentService.Document? {
        (try? DocumentService.documents(for: project, in: context))?.first { $0.documentType == .script }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                statusSection
                Divider()
                filmSchedulingSection
                Divider()
                castAndCrewSection
                Divider()
                logisticsSection
                Divider()
                scriptSection
                Divider()
                callSheetSection
            }
            .padding()
        }
        .navigationTitle(project.title)
        .onAppear {
            status = SketchProductionService.status(for: project)
            if let date = SketchProductionService.postDate(for: project) {
                postDate = date
                hasPostDate = true
            }
            if let callSheet {
                callSheetCastAndCharacters = callSheet.castAndCharacters
                callSheetCrewAndRoles = callSheet.crewAndRoles
                contactInformation = callSheet.contactInformation
                callSheetWardrobe = callSheet.wardrobe
                callSheetProps = callSheet.props
                callSheetEquipment = callSheet.equipment
                callSheetParkingAccess = callSheet.parkingAccess
                sceneNotes = callSheet.sceneNotes
                additionalNotes = callSheet.additionalNotes
            }
            if let shoot {
                callTime = shoot.callTime
                estimatedWrapTime = shoot.estimatedWrapTime
                location = shoot.location
                address = shoot.address
                cast = shoot.cast
                crew = shoot.crew
                wardrobe = shoot.wardrobe
                props = shoot.props
                equipmentNotes = shoot.equipmentNotes
                parkingAccessInstructions = shoot.parkingAccessInstructions
                generalNotes = shoot.generalNotes
            }
        }
    }

    private var header: some View {
        Text(project.title).font(.title3.bold())
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Status", selection: $status) {
                ForEach(SketchProductionService.SketchProductionStatus.allCases, id: \.self) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .frame(width: 220)
            .onChange(of: status) {
                SketchProductionService.changeStatus(for: project, to: status, context: context)
                try? context.save()
            }
            Toggle("Post date", isOn: $hasPostDate)
                .onChange(of: hasPostDate) {
                    SketchProductionService.setPostDate(for: project, date: hasPostDate ? postDate : nil, context: context)
                    try? context.save()
                }
            if hasPostDate {
                DatePicker("", selection: $postDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: postDate) {
                        SketchProductionService.setPostDate(for: project, date: postDate, context: context)
                        try? context.save()
                    }
            }
        }
    }

    /// PRD §9.3: "The shoot automatically appears on Calendar and generally acts as a hard
    /// calendar commitment once cast/crew/location are involved."
    private var filmSchedulingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Film Scheduling").font(.headline)
            DatePicker("Call time", selection: $callTime)
                .onChange(of: callTime) { ensureShoot() }
            DatePicker("Estimated wrap", selection: $estimatedWrapTime)
                .onChange(of: estimatedWrapTime) { ensureShoot() }
            TextField("Location", text: $location)
                .textFieldStyle(.roundedBorder)
                .onChange(of: location) { saveLocation() }
            TextField("Address", text: $address)
                .textFieldStyle(.roundedBorder)
                .onChange(of: address) { saveLocation() }
            Text("Automatically appears on Calendar as a Film Shoot.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Any field in this screen implies scheduling the shoot — lazily creates the FilmShoot
    /// (with the current call/wrap-time state, which defaults sensibly and stays in sync via
    /// its own onChange) rather than requiring the user to touch Call Time first.
    @discardableResult
    private func ensureShoot() -> SketchProductionService.FilmShoot {
        let shoot = SketchProductionService.scheduleFilm(for: project, callTime: callTime, estimatedWrapTime: estimatedWrapTime, context: context)
        status = SketchProductionService.status(for: project)
        try? context.save()
        return shoot
    }

    private func saveLocation() {
        let shoot = ensureShoot()
        SketchProductionService.updateLocation(shoot, location: location, address: address, context: context)
        try? context.save()
    }

    private var castAndCrewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cast & Crew").font(.headline)
            TextField("Cast", text: $cast, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onChange(of: cast) { saveCastAndCrew() }
            TextField("Crew", text: $crew, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onChange(of: crew) { saveCastAndCrew() }
        }
    }

    private func saveCastAndCrew() {
        let shoot = ensureShoot()
        SketchProductionService.updateCastAndCrew(shoot, cast: cast, crew: crew, context: context)
        try? context.save()
    }

    private var logisticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Logistics").font(.headline)
            TextField("Wardrobe", text: $wardrobe, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onChange(of: wardrobe) { saveLogistics() }
            TextField("Props", text: $props, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onChange(of: props) { saveLogistics() }
            TextField("Equipment notes", text: $equipmentNotes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onChange(of: equipmentNotes) { saveLogistics() }
            TextField("Parking / access instructions", text: $parkingAccessInstructions, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onChange(of: parkingAccessInstructions) { saveLogistics() }
            TextField("General notes", text: $generalNotes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onChange(of: generalNotes) { saveLogistics() }
        }
    }

    private func saveLogistics() {
        let shoot = ensureShoot()
        SketchProductionService.updateLogistics(
            shoot,
            wardrobe: wardrobe,
            props: props,
            equipmentNotes: equipmentNotes,
            parkingAccessInstructions: parkingAccessInstructions,
            generalNotes: generalNotes
        )
        try? context.save()
    }

    /// PRD §9.5: "The finished Script should remain accessible from Sketches... export the
    /// Script... as normal PDF files suitable for dragging into an email." Reuses the existing
    /// Script Editor's ExportService.exportScriptPDF — "Writing remains inside Writing" means
    /// this only exports, it doesn't open an editor here.
    private var scriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Script").font(.headline)
            if let scriptDocument {
                HStack {
                    Text(scriptDocument.title)
                    Spacer()
                    Button("Export Script PDF", action: { exportScript(scriptDocument) })
                }
            } else {
                Text("No script found in this project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func exportScript(_ document: DocumentService.Document) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = document.title
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let blocks = ScriptBlockService.blocks(for: document).map { (type: $0.elementType, text: $0.text) }
        try? ExportService.exportScriptPDF(title: document.title, blocks: blocks, to: url)
    }

    /// PRD §9.4: "A scheduled shoot should support generating an editable Call Sheet populated
    /// from project data." Shows a Generate button until one exists (needs a scheduled shoot
    /// first, matching "populated from project data"); once generated, it's its own editable
    /// document — edits here never write back to Film Scheduling above.
    private var callSheetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Call Sheet").font(.headline)
            if let callSheet {
                TextField("Cast / Characters", text: $callSheetCastAndCharacters, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: callSheetCastAndCharacters) { saveCallSheetPeople(callSheet) }
                TextField("Crew / Roles", text: $callSheetCrewAndRoles, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: callSheetCrewAndRoles) { saveCallSheetPeople(callSheet) }
                TextField("Contact information", text: $contactInformation, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: contactInformation) { saveCallSheetPeople(callSheet) }
                TextField("Wardrobe", text: $callSheetWardrobe, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: callSheetWardrobe) { saveCallSheetLogistics(callSheet) }
                TextField("Props", text: $callSheetProps, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: callSheetProps) { saveCallSheetLogistics(callSheet) }
                TextField("Equipment", text: $callSheetEquipment, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: callSheetEquipment) { saveCallSheetLogistics(callSheet) }
                TextField("Parking / access", text: $callSheetParkingAccess, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: callSheetParkingAccess) { saveCallSheetLogistics(callSheet) }
                TextField("Scene notes", text: $sceneNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: sceneNotes) { saveCallSheetNotes(callSheet) }
                TextField("Additional notes", text: $additionalNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: additionalNotes) { saveCallSheetNotes(callSheet) }
                Button("Export Call Sheet PDF", action: { exportCallSheet(callSheet) })
            } else if let shoot {
                Button("Generate Call Sheet") {
                    _ = SketchProductionService.generateCallSheet(for: shoot, projectTitle: project.title, context: context)
                    try? context.save()
                    if let callSheet = shoot.callSheet {
                        callSheetCastAndCharacters = callSheet.castAndCharacters
                        callSheetCrewAndRoles = callSheet.crewAndRoles
                        callSheetWardrobe = callSheet.wardrobe
                        callSheetProps = callSheet.props
                        callSheetEquipment = callSheet.equipment
                        callSheetParkingAccess = callSheet.parkingAccess
                    }
                }
            } else {
                Text("Schedule the film shoot above before generating a Call Sheet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveCallSheetPeople(_ callSheet: SketchProductionService.CallSheet) {
        SketchProductionService.updateCallSheetPeople(
            callSheet,
            castAndCharacters: callSheetCastAndCharacters,
            crewAndRoles: callSheetCrewAndRoles,
            contactInformation: contactInformation
        )
        try? context.save()
    }

    private func saveCallSheetLogistics(_ callSheet: SketchProductionService.CallSheet) {
        SketchProductionService.updateCallSheetLogistics(
            callSheet,
            wardrobe: callSheetWardrobe,
            props: callSheetProps,
            equipment: callSheetEquipment,
            parkingAccess: callSheetParkingAccess
        )
        try? context.save()
    }

    private func saveCallSheetNotes(_ callSheet: SketchProductionService.CallSheet) {
        SketchProductionService.updateCallSheetNotes(callSheet, sceneNotes: sceneNotes, additionalNotes: additionalNotes)
        try? context.save()
    }

    private func exportCallSheet(_ callSheet: SketchProductionService.CallSheet) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(project.title) Call Sheet"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? ExportService.exportCallSheetPDF(
            projectTitle: callSheet.projectTitle,
            callTime: callSheet.callTime,
            wrapTime: callSheet.wrapTime,
            location: callSheet.location,
            address: callSheet.address,
            castAndCharacters: callSheet.castAndCharacters,
            crewAndRoles: callSheet.crewAndRoles,
            wardrobe: callSheet.wardrobe,
            props: callSheet.props,
            equipment: callSheet.equipment,
            parkingAccess: callSheet.parkingAccess,
            contactInformation: callSheet.contactInformation,
            sceneNotes: callSheet.sceneNotes,
            additionalNotes: callSheet.additionalNotes,
            to: url
        )
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
    SketchProductionService.scheduleFilm(for: project, callTime: .now, estimatedWrapTime: .now.addingTimeInterval(8 * 3600), context: context)
    return NavigationStack {
        SketchDetailView(project: project)
    }
    .modelContainer(container)
}
