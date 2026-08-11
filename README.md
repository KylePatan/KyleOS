# Kyle OS

Kyle OS is a native macOS creative operating system for managing writing, stand-up, clips, sketches, calendar commitments, creative work sessions, publishing, and progress.

## Project status

- **PRD:** v1.3 — Build-Ready Product Definition + Phase Decision Register
- **Current build phase:** V0 — Foundation
- **Primary platform:** native macOS
- **Minimum deployment target:** macOS 15.0
- **Primary development machine:** macOS 15.7.7
- **Language:** Swift
- **UI:** SwiftUI, with AppKit interoperability only where genuinely required
- **Persistence:** SwiftData
- **Development:** VS Code + Claude Code
- **Apple toolchain:** Xcode / `xcodebuild`
- **Source control:** Git + GitHub
- **Docker:** optional supporting infrastructure only; Kyle OS itself does not run in Docker

## Start here

Claude/developer should read these files in this order before implementing anything:

1. `CLAUDE.md` — non-negotiable coding and scope rules.
2. `CURRENT_PHASE.md` — what is being built right now.
3. `docs/FOUNDATION_V0_BUILD_BRIEF.md` — exact Foundation scope and gate.
4. `docs/TECHNICAL_ARCHITECTURE.md` — locked technical direction.
5. `docs/KYLE_OS_MASTER_PRD_v1.3.md` — full source-of-truth product requirements.
6. `docs/DEVELOPMENT_ROADMAP.md` — later phase sequence.
7. `docs/PHASE_DECISION_REGISTER.md` — decisions deliberately deferred until later phases.

## Source of truth

`docs/KYLE_OS_MASTER_PRD_v1.3.md` is the authoritative product specification.

The smaller files in this repository are build-facing extracts and instructions derived from the Master PRD. If a derived file appears to conflict with the Master PRD, stop and surface the conflict rather than silently choosing one interpretation.

## Development philosophy

Build one stable version at a time:

**V0 Foundation → V0.1 Home → V0.2 Writing → V0.3 Stand Up → V0.4 Clips → V0.5 Sketches → V0.6 Calendar → V0.7 Scheduling Engine → V0.8 Post It → V0.9 Reports → V1.0 Integration/Stabilization**

Every stable phase should remain runnable and should receive a clean Git commit/tag before the next phase begins.
