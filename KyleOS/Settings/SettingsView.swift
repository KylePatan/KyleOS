import SwiftUI
import SwiftData

/// The first real Settings screen — replaces `PlaceholderDestinationView(.settings)`. Kyle
/// (2026-08-17): "I feel like there's settings that need to be done." The roadmap note this
/// screen used to show ("Work Type Defaults and Creative Capacity settings are being built later
/// in V0 Foundation") named exactly two of these sections; Day Job Schedule and Posting Cadence
/// join them because they had the identical shape — a real, tested `SettingsService` function
/// with no UI ever built to call it (`updateDayJobSchedule` since Foundation, `updatePostsPerWeekTarget`
/// only ever driven from Home's Post It tab). Posting Cadence intentionally duplicates Post It's
/// own Stepper rather than removing it there — both read/write the same single `AppSettings` row,
/// so there's no sync to get wrong, just two convenient places to find it.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var allSettings: [SettingsService.AppSettings]
    @Query(sort: \WorkTypeDefaultService.WorkTypeDefault.name) private var workTypeDefaults: [WorkTypeDefaultService.WorkTypeDefault]

    @State private var dayJobWeekdays: Set<Int> = []
    @State private var dayJobStartHour = 8
    @State private var dayJobEndHour = 17
    @State private var weekdayCapacityHours = 2.5
    @State private var weekendCapacityHours = 2.5
    @State private var standUpNightBonusHours = 1.0
    @State private var postsPerWeekTarget = 3

    @State private var newWorkTypeName = ""
    @State private var newWorkTypeHours = 1.0

    private static let weekdayLabels: [(number: Int, short: String)] = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
                dayJobSection
                creativeCapacitySection
                postingCadenceSection
                workTypeDefaultsSection
            }
            .padding(RetroTheme.sectionPadding)
        }
        .background(RetroTheme.background)
        .navigationTitle("Settings")
        .onAppear(perform: populate)
    }

    private func populate() {
        guard let settings = allSettings.first else { return }
        dayJobWeekdays = Set(settings.dayJobWeekdays)
        dayJobStartHour = settings.dayJobStartHour
        dayJobEndHour = settings.dayJobEndHour
        weekdayCapacityHours = settings.weekdayCreativeCapacityHours
        weekendCapacityHours = settings.displayWeekendCreativeCapacityHours
        standUpNightBonusHours = settings.standUpNightBonusHours
        postsPerWeekTarget = settings.displayPostsPerWeekTarget
    }

    /// PRD §11.4: "Monday–Friday, 8 AM–5 PM is blocked by default."
    private var dayJobSection: some View {
        RetroPanel("Day Job Schedule") {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                HStack(spacing: RetroTheme.controlSpacing) {
                    ForEach(Self.weekdayLabels, id: \.number) { weekday in
                        let isOn = dayJobWeekdays.contains(weekday.number)
                        // RetroButtonStyle's own `prominent` variant already draws exactly the
                        // "selected" look (accent fill) versus the neutral one — reused here as a
                        // toggle's on/off rather than building a separate component, since a plain
                        // `Toggle(...).toggleStyle(.button).buttonStyle(.retro)` renders with no
                        // visible on/off distinction at all (RetroButtonStyle only reacts to
                        // `configuration.isPressed`, not a Toggle's `isOn`).
                        Button(weekday.short) {
                            if isOn { dayJobWeekdays.remove(weekday.number) } else { dayJobWeekdays.insert(weekday.number) }
                            saveDayJobSchedule()
                        }
                        .buttonStyle(isOn ? .retroProminent : .retro)
                    }
                }
                HStack {
                    Stepper("Start: \(dayJobStartHour):00", value: $dayJobStartHour, in: 0...23)
                        .onChange(of: dayJobStartHour) { saveDayJobSchedule() }
                    Stepper("End: \(dayJobEndHour):00", value: $dayJobEndHour, in: 0...23)
                        .onChange(of: dayJobEndHour) { saveDayJobSchedule() }
                }
                .foregroundStyle(RetroTheme.primaryText)
                Text("Blocked automatically on Calendar as busy time on the days checked above.")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            }
        }
    }

    private func saveDayJobSchedule() {
        guard let settings = try? SettingsService.currentSettings(in: context) else { return }
        SettingsService.updateDayJobSchedule(
            settings,
            weekdays: Array(dayJobWeekdays).sorted(),
            startHour: dayJobStartHour,
            endHour: dayJobEndHour
        )
        try? context.save()
    }

    /// PRD §4.4: "a normal available day/evening can generally support about 2-3 creative hours."
    private var creativeCapacitySection: some View {
        RetroPanel("Creative Capacity") {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                Stepper("Weekday capacity: \(weekdayCapacityHours.formatted(.number.precision(.fractionLength(0...1))))h", value: $weekdayCapacityHours, in: 0...12, step: 0.5)
                    .onChange(of: weekdayCapacityHours) { saveCreativeCapacity() }
                Stepper("Weekend capacity: \(weekendCapacityHours.formatted(.number.precision(.fractionLength(0...1))))h", value: $weekendCapacityHours, in: 0...12, step: 0.5)
                    .onChange(of: weekendCapacityHours) { saveCreativeCapacity() }
                Stepper("Stand-Up night bonus: +\(standUpNightBonusHours.formatted(.number.precision(.fractionLength(0...1))))h", value: $standUpNightBonusHours, in: 0...12, step: 0.5)
                    .onChange(of: standUpNightBonusHours) { saveCreativeCapacity() }
            }
            .foregroundStyle(RetroTheme.primaryText)
        }
    }

    private func saveCreativeCapacity() {
        guard let settings = try? SettingsService.currentSettings(in: context) else { return }
        SettingsService.updateCreativeCapacity(settings, weekdayHours: weekdayCapacityHours, weekendHours: weekendCapacityHours, standUpNightBonusHours: standUpNightBonusHours)
        try? context.save()
    }

    /// PRD §8.8/§10.4: "a general goal such as 2–3 or 3 posts per week" — the same setting Post
    /// It's own Stepper reads/writes; both are the single `AppSettings.postsPerWeekTarget` row.
    private var postingCadenceSection: some View {
        RetroPanel("Posting Cadence") {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                Stepper("Weekly posting goal: \(postsPerWeekTarget)", value: $postsPerWeekTarget, in: 0...14)
                    .onChange(of: postsPerWeekTarget) { savePostsPerWeekTarget() }
                    .foregroundStyle(RetroTheme.primaryText)
                Text("Drives the \"Recommended\" post date shown on Clips and Sketches, and the Post It tab's suggestions.")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            }
        }
    }

    private func savePostsPerWeekTarget() {
        guard let settings = try? SettingsService.currentSettings(in: context) else { return }
        SettingsService.updatePostsPerWeekTarget(settings, to: postsPerWeekTarget)
        try? context.save()
    }

    private var workTypeDefaultsSection: some View {
        RetroPanel("Work Type Defaults") {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                Text("The estimated time a new Work Item of this type starts with — override any single task's estimate from that task itself.")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
                if workTypeDefaults.isEmpty {
                    Text("No work types configured yet.")
                        .foregroundStyle(RetroTheme.secondaryText)
                } else {
                    VStack(spacing: 0) {
                        ForEach(workTypeDefaults) { workType in
                            WorkTypeDefaultRow(workType: workType)
                        }
                    }
                }
                HStack {
                    TextField("New work type name", text: $newWorkTypeName)
                        .retroInputStyle()
                    Stepper("\(newWorkTypeHours.formatted(.number.precision(.fractionLength(0...1))))h", value: $newWorkTypeHours, in: 0.25...40, step: 0.25)
                        .fixedSize()
                        .foregroundStyle(RetroTheme.primaryText)
                    Button("Add", action: addWorkType)
                        .buttonStyle(.retroProminent)
                        .disabled(newWorkTypeName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addWorkType() {
        let name = newWorkTypeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        WorkTypeDefaultService.createWorkTypeDefault(name: name, defaultEstimateHours: newWorkTypeHours, in: context)
        try? context.save()
        newWorkTypeName = ""
        newWorkTypeHours = 1.0
    }
}

private struct WorkTypeDefaultRow: View {
    let workType: WorkTypeDefaultService.WorkTypeDefault
    @Environment(\.modelContext) private var context

    @State private var estimateHours = 1.0
    @State private var preferredMinutes = 45
    @State private var minimumMinutes = 15
    @State private var isSplittable = true

    var body: some View {
        HStack {
            Text(workType.name).foregroundStyle(RetroTheme.primaryText).frame(width: 140, alignment: .leading)
            Stepper("\(estimateHours.formatted(.number.precision(.fractionLength(0...2))))h", value: $estimateHours, in: 0.25...40, step: 0.25)
                .onChange(of: estimateHours) { save() }
                .fixedSize()
            Stepper("Session: \(preferredMinutes)m", value: $preferredMinutes, in: 5...240, step: 5)
                .onChange(of: preferredMinutes) { save() }
                .fixedSize()
            Toggle("Splittable", isOn: $isSplittable)
                .onChange(of: isSplittable) { save() }
            Spacer()
            Button(role: .destructive) {
                WorkTypeDefaultService.delete(workType, context: context)
                try? context.save()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.retro)
        }
        .foregroundStyle(RetroTheme.primaryText)
        .padding(.vertical, RetroTheme.controlSpacing)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
        }
        .onAppear {
            estimateHours = workType.defaultEstimateHours
            preferredMinutes = workType.preferredSessionMinutes
            minimumMinutes = workType.minimumSessionMinutes
            isSplittable = workType.isSplittable
        }
    }

    private func save() {
        WorkTypeDefaultService.update(
            workType,
            defaultEstimateHours: estimateHours,
            preferredSessionMinutes: preferredMinutes,
            minimumSessionMinutes: minimumMinutes,
            isSplittable: isSplittable
        )
        try? context.save()
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    try? WorkTypeDefaultService.seedKnownDefaultsIfNeeded(in: context)
    return NavigationStack {
        SettingsView()
    }
    .modelContainer(container)
}
