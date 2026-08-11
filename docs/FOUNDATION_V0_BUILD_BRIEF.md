# Foundation V0 Build Brief

**Current implementation phase.** Derived from Master PRD v1.3.

The purpose of V0 is to create a durable baseline, not to demonstrate every future Kyle OS feature. Build only the scope below, verify each behavior, and preserve service boundaries for later phases.

# 18. Foundation V0 Build Requirements

Foundation should be completed and tagged before Home development begins.

Recommended implementation sequence:

1. Create macOS application shell.
2. Create navigation and module placeholders.
3. Create local database and schema version.
4. Implement stable IDs/core models.
5. Create Settings.
6. Implement basic Project CRUD and Archive.
7. Implement basic Document persistence/editor.
8. Add autosave.
9. Implement Work Items.
10. Implement Calendar Events and Deadlines.
11. Implement Planned Sessions and Work Sessions.
12. Implement shared timer service.
13. Implement File References.
14. Implement basic backup/recovery.
15. Run persistence, relationship, timer, restart, and backup tests.

Foundation completion should be tagged in Git, e.g. `kyle-os-v0-foundation`.

Every later major milestone should also be committed/tagged so a known-good version can be restored if vibe-coding changes break the app.

---

# 19. Foundation Acceptance Tests

Foundation V0 is complete when all of the following are demonstrably working:

- App opens and navigation works.
- Home, Writing, Stand Up, Clips, Sketches, Calendar, Reports, Settings destinations exist.
- Projects can be created, renamed, archived, restored, and persisted.
- Related objects remain linked after renaming.
- Basic Documents persist and autosave.
- Work Items persist with progress, estimate, and priority.
- Deadlines are separate from flexible work dates.
- Planned Sessions and Work Sessions are separate.
- Timer start/pause/resume/stop works and excludes paused time.
- Calendar Events persist with Busy/Available state.
- Day-job and Creative Capacity settings exist.
- Work Type Defaults exist and are not scattered hard-coded values.
- File References can survive temporary source-file unavailability.
- Basic backup is possible.
- Data survives restart and normal shutdown.
- App can detect/recover relevant state after an interrupted timer/crash where practical.
- Database schema version exists and future migrations are possible.
- Important business logic is separated from screen components.
- Test/dev data can be kept separate from production data where practical.

---

