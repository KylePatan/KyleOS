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

**RESOLVED 2026-08-15.** Full spec given directly by Kyle, preserved verbatim in
`docs/VISUAL_DESIGN_SYSTEM.md` — that document is now the authoritative source, not this
summary. Short version: **Windows 95/98 structure + late-90s/early-2000s web personality +
modern application smoothness** — dense, bordered, top-down, desktop-first, square-cornered
panels/windows/toolbars/tabs instead of floating rounded cards, horizontal top navigation
instead of a permanent sidebar, light mode default with a parallel dark mode (not a redesign),
Courier-style typewriter typography on writing surfaces only. See that document's own §34 "
Reference Principle" for how to resolve anything it doesn't explicitly cover, and its
Implementation Log for what's actually been built against it so far (only §20 typography as of
this resolution — the rest, including the full component system and navigation restructure, is
still pending).

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

**RESOLVED 2026-08-15.** Kyle: personal/private installation only — not signed/notarized for outside distribution, not the Mac App Store.

Consequences of that answer:

- No Apple Developer Program membership needed.
- No App Sandbox/entitlement work required.
- The existing ad-hoc signing setup (`CODE_SIGN_IDENTITY: "-"`, `CODE_SIGN_STYLE: Manual`, no team, hardened runtime off — see `project_kyle_os_current_state` memory's very first lesson) is the real, final answer, not a Foundation-era placeholder to revisit.
- No update mechanism needed — Kyle builds and runs it himself via Xcode.
- No notarization, privacy-disclosure, or packaging pipeline to build.
- Google OAuth (whenever that's tackled, still separately gated per CLAUDE.md §8) only needs to satisfy personal-use OAuth consent, not an App-Store-review or public-notarization bar.

Do not build App Sandbox, notarization, or Mac-App-Store-oriented packaging work unless Kyle explicitly reopens this.

### Other Phase-Local Decisions

Other smaller open choices already identified in this PRD should be answered when their relevant phase begins, including precise Creative Hour defaults, backup format, and the exact background/login-item implementation for continuous Google Calendar synchronization. These are not blockers for Foundation.

## 23.6 Readiness

**Foundation V0: Ready to build. Distribution packaging can be decided later because it does not block the first personal development build.**

**Home V0.1: Product requirements are ready; build after Foundation passes.**

**Writing V0.2: Product requirements are strong, but technical editor choices should be made before implementation.**

**Scheduling V0.7: Decision Gate B resolved 2026-08-14 (Kyle's direct answers, see above); implementation underway (increment 1 of 2 shipped).**

The PRD is therefore at the correct level for the current stage: detailed enough to start engineering, but still flexible enough to evolve based on actual use.

---
