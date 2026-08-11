# Phase Decision Register

**Derived from Master PRD v1.3.** These questions are intentionally deferred. Do not answer them prematurely during Foundation.

## 23.4 Still To Decide During Implementation

The native application stack, local persistence direction, Google Calendar two-way integration, notification philosophy, and initial macOS deployment baseline are now locked. Remaining choices are phase-specific rather than reasons to delay Foundation:

- Distribution path: initially personal/private, later direct collaborator distribution, Mac App Store, or another signed/notarized path.
- Exact rich-text/script-editor implementation and early screenplay pagination fidelity.
- Exact algorithm/weighting for scheduling priority once real workload data exists.
- Precise default Creative Hour values beyond known examples.
- Exact visual design/theme.
- Exact backup file format and later shared/cloud sync technology.
- Exact implementation timing for the background sync/login-item service; the architecture should support it even if the first Foundation build uses simpler app-running behavior.

These should be answered only where they materially affect the phase being built. They do not justify reopening the overall product design.

## 23.5 Phase Decision Register

The following decisions are intentionally **not** being locked before Foundation. Each has a defined phase where it must be answered before the affected implementation proceeds. This prevents premature technical choices while ensuring no important question is forgotten.

### Decision Gate A — Screenplay Editor Implementation

**Must be resolved during:** V0.2 — Writing Workspace, before production implementation of the Script Editor.

Questions to answer:

- What native editing architecture should power the screenplay editor: SwiftUI text components, an AppKit/TextKit-based editor wrapped for SwiftUI, or another carefully evaluated native approach?
- How should structured screenplay blocks behave during typing, deletion, paste, undo/redo, and element changes?
- What level of screenplay pagination accuracy is required for the first implementation?
- What PDF/export fidelity is required for V0.2?
- Which professional interchange formats, if any, should be deferred until after V1?
- How should scene navigation, character autocomplete, scene-heading autocomplete, and keyboard transitions behave in the first usable version?

The decision should prioritize writing reliability, autosave safety, keyboard flow, and maintainable structured data before attempting Final Draft-level feature parity.

### Decision Gate B — Scheduling Engine Weighting

**Must be resolved during:** V0.7 — Scheduling Engine, after Kyle OS contains real Work Items, Calendar data, and several weeks of realistic usage where possible.

Questions to answer:

- Should the first scheduler use an ordered deterministic rule system, numeric weighting, or a hybrid?
- How much relative influence should hard-deadline urgency, manual priority, dependencies, remaining effort, Creative Capacity, progress, preferred session length, and context switching have?
- What tie-breakers should apply when multiple tasks are equally viable?
- How aggressively should flexible work cascade when new priority work is inserted?
- How much safety buffer should be preserved before deadlines?
- When should Kyle OS concentrate heavily on one urgent project versus continue progressing several projects?
- How should historical actual-vs-estimated performance influence recommendations without silently changing user preferences?

The initial engine should remain deterministic, explainable, manually overridable, and testable.

### Decision Gate C — Final Visual Design

**Must be resolved during:** V1.0 — Integration & UX Pass. A consistent baseline component system should exist from Foundation, but final visual identity is deliberately deferred until the workflows are proven.

Questions to answer:

- Final colour palette and accent treatment.
- Typography hierarchy.
- Information density.
- Sidebar and navigation treatment.
- Card, list, progress, timer, and calendar visual language.
- Light-mode and dark-mode behaviour.
- Motion/animation level.
- How much visual personality Kyle OS should have while remaining calm and focused for long writing sessions.

The final design should polish proven workflows rather than forcing workflows to fit an early visual concept.

### Decision Gate D — Shared Hub Cloud Technology

**Must be resolved during:** the post-V1 Shared Hub implementation phase, before multi-user synchronization is built.

Questions to answer:

- CloudKit versus a custom backend or another current sync platform.
- User identity and authentication model.
- Shared Project ownership and permission enforcement.
- Offline synchronization strategy.
- Conflict resolution for simultaneous script/outline edits.
- Revision history and recovery requirements.
- Security/privacy model for private versus shared project data.
- Operational cost, maintenance burden, and scalability.
- How Google Calendar collaboration and Shared Hub identities should relate.

Foundation must preserve stable IDs, ownership-ready models, timestamps, revision metadata, and a SyncService boundary so this choice can be made later without rebuilding the core application.

### Decision Gate E — Distribution Method

**Must be resolved during:** V1.0 release preparation before Kyle OS is distributed beyond the primary development Mac.

Questions to answer:

- Personal/private installation only, direct signed/notarized distribution, Mac App Store, or another supported distribution route.
- Whether an Apple Developer Program membership is required at that stage.
- App Sandbox and entitlement requirements.
- Google OAuth configuration implications for the chosen distribution model.
- Update mechanism for non-App-Store distribution, if applicable.
- Signing, notarization, privacy disclosures, and packaging requirements.

Foundation development should avoid unnecessarily blocking future sandboxed or notarized distribution, but packaging decisions should not delay the first personal build.

### Other Phase-Local Decisions

Other smaller open choices already identified in this PRD should be answered when their relevant phase begins, including precise Creative Hour defaults, backup format, and the exact background/login-item implementation for continuous Google Calendar synchronization. These are not blockers for Foundation.

## 23.6 Readiness

**Foundation V0: Ready to build. Distribution packaging can be decided later because it does not block the first personal development build.**

**Home V0.1: Product requirements are ready; build after Foundation passes.**

**Writing V0.2: Product requirements are strong, but technical editor choices should be made before implementation.**

**Scheduling V0.7: Product logic is defined, but implementation should wait for real application data and usage patterns.**

The PRD is therefore at the correct level for the current stage: detailed enough to start engineering, but still flexible enough to evolve based on actual use.

---
