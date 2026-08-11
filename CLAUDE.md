# CLAUDE.md — Kyle OS Development Rules

## 1. Read before coding

Before making architectural or implementation changes, read:

- `CURRENT_PHASE.md`
- `docs/FOUNDATION_V0_BUILD_BRIEF.md` for the current V0 phase
- `docs/TECHNICAL_ARCHITECTURE.md`
- Relevant sections of `docs/KYLE_OS_MASTER_PRD_v1.3.md`
- `docs/PHASE_DECISION_REGISTER.md` before making any decision that appears deliberately deferred

## 2. Current scope is V0 Foundation only

Do **not** implement later-phase product features merely because they appear in the PRD.

During V0, do not build the finished Home dashboard, screenplay editor, Stand Up board, Clips pipeline, Sketch production UI, full Google Calendar integration, intelligent Scheduling Engine, Post It, Reports, Shared Hub, iPhone app, cloud sync, social-media APIs, or AI features.

You may create clean service/model boundaries required so those later features can be added without rewriting Foundation.

## 3. Locked technical direction

- Native macOS application.
- Swift.
- SwiftUI for primary UI.
- AppKit interoperability only where native macOS behavior or future editor requirements justify it.
- SwiftData for V1 local structured persistence.
- Explicit schema versioning/migrations from Foundation.
- Xcode project/toolchain; use `xcodebuild` for command-line builds/tests where appropriate.
- VS Code + Claude Code is the main coding workflow.
- Git + GitHub for source control.
- Docker is not the runtime for Kyle OS. Do not move the app into Electron, a web runtime, or a container.

Do not replace the locked stack without explicit approval.

## 4. Architecture rules

Keep important business logic out of individual SwiftUI views.

Maintain clear boundaries for:

- UI
- Domain/project logic
- Persistence/autosave
- Timer/work-session logic
- Calendar/event logic
- Scheduling service boundary
- File management/export
- Reporting boundary
- External integrations
- Future sync/collaboration

Prefer reusable domain/service actions such as Create Project, Archive Project, Create Work Item, Complete Work Item, Create Planned Session, Complete Work Session, and Set Deadline.

## 5. Data safety is more important than polish

Kyle OS will eventually contain irreplaceable scripts, jokes, drafts, notes, and work history.

Never casually solve a migration/model problem by deleting the user's database.

Foundation must establish:

- stable IDs
- schema versioning
- migrations
- autosave
- archive/soft delete
- backup/recovery path
- safe relationship handling

A renamed object must retain its relationships.

## 6. Local-first

Core Kyle OS data remains usable offline.

External integrations are supplemental. Future Google Calendar sync or Shared Hub cloud functionality must not turn the core app into a cloud-dependent application.

## 7. Future collaboration compatibility

Do not implement Shared Hub now.

However, avoid architectural choices that make future project sharing impossible. Preserve stable object IDs, ownership-ready data design, timestamps/revision metadata where appropriate, and a future SyncService boundary.

Everything is private by default. Future sharing will apply only to explicitly shared Writing/Sketch projects.

## 8. Google Calendar

Full two-way Google Calendar integration is a V0.6 feature, not a V0 feature.

Foundation should keep Calendar models/provider boundaries clean enough to support later:

- multiple Google calendars
- bidirectional event sync
- a dedicated Kyle OS calendar for auto-scheduled work
- offline cache/reconciliation
- future free/busy collaboration scheduling

Do not implement Google OAuth/API work during Foundation unless the user explicitly changes the phase scope.

## 9. Notifications

Native macOS notifications/background behavior are product requirements. Foundation may establish reusable notification service boundaries and permission handling only if part of the approved Foundation implementation sequence. Do not prematurely build the complete reminder system for later workflows.

## 10. Deferred decisions

Do not silently decide the following before their decision gates:

- V0.2: exact screenplay editor architecture/pagination/export fidelity
- V0.7: Scheduling Engine weighting/tie-breakers/buffers/cascade aggressiveness
- V1.0 UX pass: final visual identity
- Post-V1 Shared Hub: cloud/sync/auth/conflict technology
- V1.0 release prep: final distribution/signing/notarization/App Store path

See `docs/PHASE_DECISION_REGISTER.md`.

## 11. Testing and completion

A feature is not complete merely because it compiles.

For each Foundation increment:

1. Build the app.
2. Run relevant automated tests.
3. Exercise the relevant acceptance scenario.
4. Verify persistence across restart where applicable.
5. Verify existing Foundation behavior still works.
6. Report exactly what changed and any known limitations.

Do not mark Foundation complete until the V0 acceptance checklist passes.

## 12. Git discipline

Keep changes reviewable.

Do not rewrite working architecture unnecessarily.

At the end of a stable Foundation phase, create/prepare the checkpoint:

`kyle-os-v0-foundation`

Later stable phases follow the roadmap tags in the PRD.

## 13. When uncertain

If ambiguity affects architecture, data safety, a deferred decision gate, or scope, surface the ambiguity rather than inventing a permanent product decision.

For small implementation details that do not materially affect product behavior, choose the simplest native, maintainable solution and document it.
