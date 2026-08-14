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

**RESOLVED 2026-08-14.** Kyle answered directly rather than waiting out the "several weeks of realistic usage" framing below — the design is a deterministic rule system (not ML/statistically calibrated), so it doesn't need historical usage data to be implementable, testable, and explainable; usage can still inform future tuning of the specific constants.

Kyle's answers, as given:

- **Deadline urgency dominates everything else.** "I think that deadlines should be number 1 priority. If something is due tomorrow - that needs to be done."
- **Quick-win boost.** "But if there is something with less work to be done and can get closed that night - that gives some weight to its priority."
- **Anti-starvation is the overarching goal.** "The key about the weighting is to make sure that nothing gets lost in the cracks and in the end, all creative projects eventually get finished." (Implemented as a staleness boost that rises the longer an item sits untouched.)
- **Tie-breakers are a user prompt, not an automatic rule.** "If there are two things that are scored basically exactly. There should be a prompt to ask which one should be worked on - and the user gets to choose as the tie-breaker."
- **Cascade should be aggressive, not protective of the original plan.** "Schedule changes (especially blocked off things) should re-shuffle the already-planned creative work. And if there are no hours to do the creative work - so be it. It should be more aggressive because it's dealing with time we don't have anymore."
- **Moderate safety buffers, and favor session focus over spread.** "I think there should be moderate safety buffers. Leave some slack and make it useful for humans - because usually they won't want to work on 4 separate projects in a given session."

Implementation: `KyleOS/Domain/SchedulingService.swift` (ranking/scoring, dependency-blocking, tie detection) — increment 1, PRD §4.2. Cascade rescheduling (§4.6) reflowing already-planned sessions when Calendar capacity shrinks is increment 2, not yet built. The initial engine remains deterministic, explainable, manually overridable, and testable, per the bar this gate always set.

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

**Scheduling V0.7: Decision Gate B resolved 2026-08-14 (Kyle's direct answers, see above); implementation underway (increment 1 of 2 shipped).**

The PRD is therefore at the correct level for the current stage: detailed enough to start engineering, but still flexible enough to evolve based on actual use.

---
