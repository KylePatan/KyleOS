# Current Phase — V1.0 Threshold

## Status

**V0 FOUNDATION AND EVERY V0.x MODULE ARE COMPLETE.** (Updated 2026-08-18 — this file previously
described the state before Foundation began and was never updated as each phase shipped, so it
drifted stale again between 2026-08-14 and now while the visual reskin, multi-window support,
Settings, and a round of post-reskin refinement all shipped. See `project.yml`/git history and the
project memory for the authoritative build log; this file is a status summary, not a source of
truth for what exists.)

Shipped and stable, in build order:

- V0 Foundation (tag `kyle-os-v0-foundation`): app shell, navigation, SwiftData persistence with
  schema versioning/migrations, Project/Document/Work Item/Planned Session/Work Session/Calendar
  Event/Deadline models, Settings/Work Type Defaults, shared timer logic, autosave, File Reference
  model, archive/restore, backup/recovery.
- V0.1 Home — Today/Priority View, All Tasks, priority dragging, Creative Capacity, basic month
  calendar, Quick Add, active timer display.
- V0.2 Writing — containers, prose editor + drafts, Act/Scene outlines, native AppKit/TextKit
  script editor (Decision Gate A resolved), Focus Timer, PDF export, Workspace Restoration.
- V0.3 Stand Up — Joke Board, Joke→Chunk→Headline Set hierarchy, Gigs, Gig Set Lists, After-Gig
  Notes, Stand-Up Work Sessions.
- V0.4 Clips — Source Media, child Clips, production board, editing timer, Ready Queue.
- V0.5 Sketches — Writing Handoff + production board, Film Scheduling, Call Sheet, editing timer.
- V0.6 Calendar — full Calendar workspace, Deadline auto-sync, Day-Job block generation with
  per-day override, Daily Creative Capacity overrides. (Google OAuth two-way sync explicitly NOT
  built — gated behind Kyle provisioning his own Google Cloud OAuth credentials, CLAUDE.md §8.)
- V0.7 Scheduling Engine — Decision Gate B resolved directly by Kyle (2026-08-14, full answers in
  `docs/PHASE_DECISION_REGISTER.md`); ranking/scoring + tie-break prompt, and cascade
  rescheduling, both shipped.
- V0.8 Post It — dedicated Home publishing queue, Ready buffer, Posting Cadence, Post Dates.
- V0.9 Reports — every §13.x/roadmap item built (Default Summary, Workspace/Planned-vs-Actual/
  Estimate Accuracy/Stalled Work, Status History, Stand-Up/Clips/Sketch/Posting Reports, Project
  Progress, Ready Buffer Trends).

## What's next: V1.0 — Integration & UX Pass

Per `docs/PHASE_DECISION_REGISTER.md` and the Master PRD's own framing ("V1.0 is the first
complete version where the major modules and scheduling system function together reliably...
later V1.x development should be driven by actual use rather than speculation"):

- **Decision Gate C (Final Visual Design) — RESOLVED 2026-08-15.** Full spec in
  `docs/VISUAL_DESIGN_SYSTEM.md`; the reskin, multi-window support, and a round of post-reskin
  "sleeker information presentation" refinement (Clips/Sketches boards, Reports tabs) have all
  since shipped against it.
- **Decision Gate E (Distribution Method) — RESOLVED 2026-08-15.** Personal/private only, ad-hoc
  signing is the permanent answer — see the decision register for consequences.
- **Decision Gate D (Shared Hub Cloud Technology)** — deliberately still open; not resolved until
  the post-V1.0 Shared Hub implementation phase actually begins. Not a current blocker.
- Real-usage-driven refinement of the Scheduling Engine's specific weighting constants — ongoing
  by design, not a one-time task. First concrete step taken 2026-08-18: deadline scoring now uses
  fractional-day precision so same-day deadlines at different times rank distinctly instead of
  tying (Deadlines/Post Dates also gained an editable time-of-day the same day).
- A full acceptance pass across every module together (not just per-module test suites) — still
  outstanding, matching how Foundation's own V0 completion required an explicit acceptance
  checklist pass.

## In progress, 2026-08-19

Kyle gave a fully-specified, detailed follow-up list, worked in this explicit order (authorized to
run unattended, "do not pause the work"):

1. **DONE (commit `0858f47`)** — Script Editor rebuilt to Kyle's own 35-section professional
   screenplay spec (true 8.5×11in page geometry, real per-element margins, shared editor/PDF
   pagination engine, zoom, new element types). See `docs/VISUAL_DESIGN_SYSTEM.md`'s Implementation
   Log and the project memory for full detail, including what was deliberately deferred (Dual
   Dialogue, orphan/widow pagination markers, custom Title Page fields, drag-to-dock split mode, TV
   act templates).
2. **DONE (same commit)** — primary navigation reverted from the horizontal top bar back to a left
   sidebar (`RetroSidebar`), reversing §13's 2026-08-15 decision. See `docs/VISUAL_DESIGN_SYSTEM.md`
   §13's amendment note.
3. **In progress** — new "Packet" module: a submission-packet builder for shows/production
   companies (e.g. "This Hour Has 22 Minutes," "SNL"). Create a named packet targeting a show/
   company, then curate existing Projects/Documents/Sketches/Prose into it (drag from a list of
   finished drafts), edit/remove freely, manage multiple packets at once.
4. **Queued next** — slight modernization visual pass (small button shadows, slightly-rounded
   corners) — a deliberate, bounded exception to §7's sharp-corner rule, not a redesign.
5. **Queued last** — rebuild Release and reinstall to `/Applications`, replacing the current build.

## Stable version tags

`kyle-os-v0-foundation` — end of Foundation V0.
