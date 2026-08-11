# Kyle OS Development Roadmap

**Derived from Master PRD v1.3.** The Master PRD remains authoritative.

# 17. Development Strategy and Version Roadmap

Kyle OS should be built as a sequence of stable, testable versions.

## V0 — Foundation

Build the durable baseline:

- Mac application shell
- Sidebar/navigation
- Local database
- Schema versioning/migrations
- Stable IDs
- Core Project/Document/Work Item models
- Planned and actual Work Sessions
- Calendar Event and Deadline models
- Shared timer logic
- Settings and Work Type Defaults
- Basic autosave
- File references
- Archive/restore
- Basic backup/recovery
- Module placeholders

V0 should be deliberately boring, reliable, predictable, recoverable, and expandable.

## V0.1 — Home

- Today view
- All Tasks
- Priority dragging
- Basic Creative Capacity
- Basic month calendar
- Quick Add
- Active timer display

Intelligent scheduling can initially remain simpler.

## V0.2 — Writing

- Writing Projects
- In-app prose/script editing
- Autosave
- Drafts/history
- Act Outline
- Scene Outline
- Multiple outlines
- Split View
- Screenplay element formatting
- Scene navigation
- Writing timer/progress
- PDF export

This is expected to be one of the largest modules.

## V0.3 — Stand Up

- Joke Ideas / New / Done
- Joke editor
- Joke -> Chunk hierarchy
- Chunks -> Headline Set
- Runtime tracking
- Gigs
- Set lists
- Stand-Up work sessions

## V0.4 — Clips

- Source Media
- Child Clips
- Production status board
- Editing progress/timer
- Ready queue
- Post Dates

## V0.5 — Sketches

- Writing handoff
- Film scheduling
- Call Sheets
- Cast/crew/props
- Editing workflow
- Ready
- Post Date

## V0.6 — Calendar

- Full month view
- Week view if practical
- Personal events/time off
- Day-job blocks
- Gigs/shoots/posts/deadlines
- Capacity overrides
- Locked/flexible work sessions
- Google account connection with OAuth
- Multiple selected Google calendars
- Full two-way Google Calendar synchronization
- Dedicated Kyle OS Google calendar for auto-scheduled creative sessions by default
- Offline event cache and reconciliation
- Native notification integration for calendar/schedule reminders
- Background/calendar-sync behavior when the primary window is closed

## V0.7 — Scheduling Engine

Build intelligent scheduling only after the app contains real projects/tasks:

- Backward scheduling
- Task splitting
- Dependency ordering
- Cascade scheduling
- Deadline protection
- Conflict detection
- Priority-based replanning
- Session recommendations
- Automatic replanning after real work

## V0.8 — Post It

- Dedicated Home publishing queue
- Ready buffer
- Posting cadence
- Suggested and confirmed Post Dates
- Overdue post reminders

## V0.9 — Reports

- Creative Hours
- Project/workspace/activity breakdowns
- Planned vs actual
- Estimate accuracy
- Project progress
- Posting output
- Headline Set progress
- Ready buffer trends

## V1.0 — First Stable Complete Kyle OS

V1.0 is the first complete version where the major modules and scheduling system function together reliably.

Later V1.x development should be driven by actual use rather than speculation.

---

