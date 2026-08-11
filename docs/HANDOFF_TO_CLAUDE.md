# Handoff Prompt for Claude Code

Use the following as the first instruction after opening this repository in VS Code / Claude Code:

> You are building Kyle OS, a native macOS creative operating system. Read `CLAUDE.md`, `CURRENT_PHASE.md`, `docs/FOUNDATION_V0_BUILD_BRIEF.md`, `docs/TECHNICAL_ARCHITECTURE.md`, and the relevant portions of `docs/KYLE_OS_MASTER_PRD_v1.3.md` before writing code. The current phase is V0 Foundation only. Do not implement later roadmap modules early. First inspect the repository and propose the smallest safe implementation sequence for Foundation V0 using Swift, SwiftUI, SwiftData, macOS 15.0+, and the Xcode/xcodebuild toolchain. Preserve stable IDs, schema migration readiness, data safety, shared service boundaries, and future sync compatibility. After the plan, begin with the native project/app-shell build and verify it compiles before moving to persistence/models. Run tests/builds as you go and do not mark V0 complete until the Foundation acceptance criteria pass.

The Master PRD is the product source of truth. `CLAUDE.md` governs implementation behavior and scope.
