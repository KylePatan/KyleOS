# Current Phase — V0 Foundation

## Status

**READY TO BUILD**

Kyle OS product definition is complete enough to begin engineering. The current task is not to build the full application. It is to establish the durable native macOS foundation every later module will use.

## Goal

At the end of V0, Kyle OS should be a real native Mac application that can reliably persist and reopen its core objects and that later modules can extend without replacing the architecture.

## Build now

- macOS app shell
- sidebar/navigation
- SwiftData local persistence
- explicit schema versioning/migration structure
- stable IDs
- baseline Project model
- baseline Document model
- Work Item model
- Planned Session model
- Work Session model
- Calendar Event model
- Deadline model
- Settings / Work Type Defaults
- shared timer logic
- basic autosave
- external File Reference model
- Archive/restore
- basic backup/recovery path
- placeholder destinations for later modules

## Do not build yet

- finished Home planning dashboard
- screenplay/prose production editor
- Stand Up workflow
- Clips workflow
- Sketch production workflow
- full Calendar UX or Google Calendar sync
- intelligent Scheduling Engine
- Post It
- Reports
- Shared Hub/cloud collaboration
- iPhone app

## Completion gate

V0 is complete only after the Foundation acceptance tests in `docs/FOUNDATION_V0_BUILD_BRIEF.md` pass and the existing data survives application restart/reopen without broken relationships.

## Stable version tag

`kyle-os-v0-foundation`
