# Repository Setup Checklist

Use this after placing the starter pack at the root of the new GitHub repository.

## Before coding

- [ ] Create/open the GitHub repository.
- [ ] Put this starter pack at repository root.
- [ ] Confirm Xcode is installed and command-line tools are available.
- [ ] Confirm `xcodebuild -version` works.
- [ ] Confirm Swift is available with `swift --version`.
- [ ] Initialize/verify Git remote.
- [ ] Make the documentation-only baseline commit before app generation.
- [ ] Have Claude read `CLAUDE.md`, `CURRENT_PHASE.md`, and `docs/FOUNDATION_V0_BUILD_BRIEF.md`.

## First app milestone

Claude should create the native macOS project using the locked stack and minimum deployment target macOS 15.0, then get a blank Kyle OS app building successfully before adding domain models.

## Suggested first implementation sequence

1. Native app target/build sanity check.
2. App shell and sidebar navigation.
3. Persistence container and schema-version structure.
4. Core IDs/models.
5. Project CRUD and persistence test.
6. Basic Document persistence/autosave test.
7. Work Item / Planned Session / Work Session models.
8. Calendar Event / Deadline models.
9. Shared timer service.
10. Settings / Work Type Defaults.
11. Archive/restore.
12. File Reference model.
13. Backup/recovery baseline.
14. Foundation acceptance tests.
15. Fix regressions.
16. Tag `kyle-os-v0-foundation` only after the gate passes.

## Important

Do not create Google API credentials, CloudKit infrastructure, a production screenplay editor, or the Scheduling Engine during this setup phase.
