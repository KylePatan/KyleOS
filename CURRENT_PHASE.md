# Current Phase — V1.0 Threshold

## Status

**V0 FOUNDATION AND EVERY V0.x MODULE ARE COMPLETE.** (Updated 2026-08-14 — this file previously
described the state before Foundation began and was never updated as each phase shipped. See
`project.yml`/git history and the project memory for the authoritative build log; this file is a
status summary, not a source of truth for what exists.)

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

Per `docs/PHASE_DECISION_REGISTER.md`'s Decision Gate C and Gate E, and the Master PRD's own
framing ("V1.0 is the first complete version where the major modules and scheduling system
function together reliably... later V1.x development should be driven by actual use rather than
speculation"):

- **Decision Gate C (Final Visual Design)** — colour palette, typography, information density,
  navigation treatment, light/dark behavior, motion level. Needs Kyle's own design input; not
  something to invent unilaterally.
- **Decision Gate E (Distribution Method)** — personal/private vs. signed/notarized vs. Mac App
  Store, Apple Developer Program membership, entitlements. Needs Kyle's decision.
- Real-usage-driven refinement of the Scheduling Engine's specific weighting constants, now that
  the deterministic rule system exists and can accumulate real data to tune against.
- A full acceptance pass across every module together (not just per-module test suites), matching
  how Foundation's own V0 completion required an explicit acceptance checklist pass.

## Known, deliberately-not-yet-fixed gaps

Documented here so they aren't mistaken for oversights during a future session:

- `CreativeCapacityService.todaysCapacity` doesn't yet reduce baseline for arbitrary Busy Calendar
  events, only Gigs and manual overrides — PRD §4.4 says personal/all-day-time-off events should
  reduce capacity too. A real gap, not fixed as part of Scheduling Engine work since changing the
  capacity formula is itself a product decision, not an implementation detail.

## Stable version tags

`kyle-os-v0-foundation` — end of Foundation V0.
