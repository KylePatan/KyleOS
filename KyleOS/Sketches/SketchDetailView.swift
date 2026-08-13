import SwiftUI
import SwiftData

/// PRD §9.3: Sketch production detail — status/post-date (already on the board card, repeated
/// here for convenience) plus the full Film Scheduling field set: call time, estimated wrap,
/// location, address, cast, crew, wardrobe, props, equipment notes, parking/access instructions,
/// general notes. "Writing remains inside Writing" — this screen only manages production
/// logistics, not the script itself (still reachable from the Writing sidebar destination).
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

    private var shoot: SketchProductionService.FilmShoot? {
        project.sketchProduction?.filmShoot
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

    private func scheduleFilm() {
        SketchProductionService.scheduleFilm(for: project, callTime: callTime, estimatedWrapTime: estimatedWrapTime, context: context)
        try? context.save()
        status = SketchProductionService.status(for: project)
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
