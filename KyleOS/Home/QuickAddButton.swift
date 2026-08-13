import SwiftUI
import SwiftData

/// PRD §4.7: "Home should provide a simple + Add action for quick capture." Task, Calendar
/// Event, Writing Project, and (per §7.3: "Home's + Add menu should also support quick Joke Idea
/// capture") Joke Idea are wired up. Clip and Gig still belong to modules that don't exist yet
/// (Clips isn't built), so those options would just be dead menu items pointing at nothing; add
/// them when that module is actually built.
struct QuickAddButton: View {
    @State private var activeSheet: QuickAddKind?

    var body: some View {
        Menu {
            Button("Task") { activeSheet = .task }
            Button("Calendar Event") { activeSheet = .calendarEvent }
            Button("Writing Project") { activeSheet = .project }
            Button("Joke Idea") { activeSheet = .jokeIdea }
        } label: {
            Label("Add", systemImage: "plus.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .sheet(item: $activeSheet) { kind in
            QuickAddSheet(kind: kind)
        }
    }
}

private enum QuickAddKind: String, Identifiable {
    case task, calendarEvent, project, jokeIdea
    var id: String { rawValue }
}

/// One sheet, switched by kind, rather than three separate files — each form is small enough
/// that splitting them out would just be indirection. All three still delegate every state
/// change to the Service layer (ProjectService/WorkItemService/CalendarEventService); nothing
/// here reimplements business logic.
private struct QuickAddSheet: View {
    let kind: QuickAddKind

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<HomeService.Project> { !$0.isArchived }, sort: \.title)
    private var activeProjects: [HomeService.Project]

    // Task fields
    @State private var taskTitle = ""
    @State private var taskProject: HomeService.Project?
    @State private var taskWorkspace: WorkItemService.Workspace = .writing
    @State private var taskWorkTypeName = ""

    // Calendar Event fields
    @State private var eventType: CalendarEventService.CalendarEventType = .personal
    @State private var eventStart = Date()
    @State private var eventDurationMinutes = 60
    @State private var eventNotes = ""

    // Writing Project fields
    @State private var projectTitle = ""

    // Joke Idea fields
    @State private var jokeText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            switch kind {
            case .task: taskForm
            case .calendarEvent: calendarEventForm
            case .project: projectForm
            case .jokeIdea: jokeIdeaForm
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
    }

    private var title: String {
        switch kind {
        case .task: return "Quick Add — Task"
        case .calendarEvent: return "Quick Add — Calendar Event"
        case .project: return "Quick Add — Writing Project"
        case .jokeIdea: return "Quick Add — Joke Idea"
        }
    }

    private var isValid: Bool {
        switch kind {
        case .task:
            return !taskTitle.trimmingCharacters(in: .whitespaces).isEmpty
                && taskProject != nil
                && !taskWorkTypeName.trimmingCharacters(in: .whitespaces).isEmpty
        case .calendarEvent:
            return eventDurationMinutes > 0
        case .project:
            return !projectTitle.trimmingCharacters(in: .whitespaces).isEmpty
        case .jokeIdea:
            return !jokeText.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private var taskForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $taskTitle)
            Picker("Project", selection: $taskProject) {
                Text("Choose a project").tag(HomeService.Project?.none)
                ForEach(activeProjects) { project in
                    Text(project.title).tag(HomeService.Project?.some(project))
                }
            }
            Picker("Workspace", selection: $taskWorkspace) {
                ForEach(WorkItemService.Workspace.allCases, id: \.self) { workspace in
                    Text(workspace.rawValue).tag(workspace)
                }
            }
            TextField("Work type (e.g. Outline)", text: $taskWorkTypeName)
        }
    }

    private var calendarEventForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Type", selection: $eventType) {
                ForEach(CalendarEventService.CalendarEventType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            DatePicker("Starts", selection: $eventStart)
            Stepper("Duration: \(eventDurationMinutes) min", value: $eventDurationMinutes, in: 15...480, step: 15)
            TextField("Notes", text: $eventNotes)
        }
    }

    private var projectForm: some View {
        TextField("Title", text: $projectTitle)
    }

    private var jokeIdeaForm: some View {
        TextField("Idea text", text: $jokeText, axis: .vertical)
    }

    private func add() {
        switch kind {
        case .task:
            guard let taskProject else { return }
            try? WorkItemService.createWorkItem(
                title: taskTitle.trimmingCharacters(in: .whitespaces),
                workspace: taskWorkspace,
                workTypeName: taskWorkTypeName.trimmingCharacters(in: .whitespaces),
                in: taskProject,
                context: context
            )
        case .calendarEvent:
            CalendarEventService.createEvent(
                type: eventType,
                startAt: eventStart,
                endAt: eventStart.addingTimeInterval(TimeInterval(eventDurationMinutes) * 60),
                notes: eventNotes,
                context: context
            )
        case .project:
            ProjectService.createProject(title: projectTitle.trimmingCharacters(in: .whitespaces), in: context)
        case .jokeIdea:
            JokeService.quickCapture(text: jokeText.trimmingCharacters(in: .whitespaces), context: context)
        }
        try? context.save()
        dismiss()
    }
}
