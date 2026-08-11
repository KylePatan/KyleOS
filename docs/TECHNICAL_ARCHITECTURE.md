# Technical Architecture — Locked Direction

**Derived from Master PRD v1.3.** These choices are locked for the first build unless implementation evidence reveals a material blocker and the user explicitly approves a change.

# 15. Application Architecture

## 15.1 Locked Technical Stack

Kyle OS V1 should be a true native macOS application. The baseline technical direction is:

- **Language:** Swift.
- **User interface:** SwiftUI, using AppKit interoperability only where native macOS behavior or editor functionality requires it.
- **Primary local persistence:** SwiftData, with explicit schema versioning and migrations from Foundation V0.
- **Development environment:** VS Code with Claude Code working directly in the repository.
- **Apple build toolchain:** Xcode installed locally, with `xcodebuild` available for command-line build/test workflows.
- **Source control:** Git with GitHub as the remote repository and stable version tags at each roadmap gate.
- **Docker:** optional supporting development infrastructure only; the native Kyle OS application itself does not run in Docker.
- **External integrations:** implemented behind shared service boundaries so Google Calendar, future sync, and other services do not become embedded directly in individual views.

The technical stack should only be changed if implementation evidence shows a material blocker. A coding agent should not replace SwiftUI/SwiftData or introduce a parallel web/Electron runtime without explicit approval.

Kyle OS should conceptually separate:

- User Interface
- Domain/project logic
- Scheduling Engine
- Persistence/autosave
- File management/export
- Reporting
- External integrations / account authorization
- Google Calendar synchronization

Important business rules should live in shared logic rather than inside individual screen components.

Examples of shared actions:

- Create Project
- Archive Project
- Create/Complete Work Item
- Change Status
- Create Planned Session
- Complete Work Session
- Set Deadline
- Schedule Film Date
- Set Post Date

Important state changes should trigger related updates. Examples:

- WritingFinished for a Sketch -> activate production
- PostDateChanged -> recalculate prerequisites
- WorkSessionCompleted -> update actual time/progress/remaining effort and schedule

## 15.2 Native Notifications and Background Operation

Kyle OS should use the native macOS User Notifications system to actively help the user stay on track. Notification behavior is a core product capability, not merely visual polish.

Planned notification categories include:

- Upcoming Creative Work session
- Creative Work session starting now
- Planned session completion / timer completion
- Deadline approaching
- Work becoming overdue
- Content scheduled to post today
- Upcoming Gig
- Upcoming Film Shoot
- Important schedule change or conflict
- Optional daily plan / Today summary

Notification categories and timing should be configurable in Settings so the user can disable categories or adjust lead times without disabling all notifications.

Kyle OS should request notification permission deliberately during onboarding or first use of a notification-dependent feature. Notifications should support useful actions where practical, such as **Open Project**, **Start Session**, **Snooze**, or **Reschedule**.

Closing or minimizing the main Kyle OS window should not stop the app's planning/reminder behavior. The default macOS app lifecycle should allow Kyle OS to remain running quietly after its primary window is closed. A menu-bar/background presence may be used if it improves clarity.

Kyle OS should also support an optional **Launch at Login** / background service so calendar synchronization, schedule maintenance, and notification preparation can continue without requiring the main window to be open. The implementation should use Apple-supported macOS background/login-item mechanisms rather than an ad hoc daemon.

Already scheduled local notifications should be designed to rely on macOS for delivery at the requested time, including when the main Kyle OS interface is not open. If the user explicitly quits all Kyle OS processes, live discovery of new Google Calendar changes may pause until Kyle OS or its authorized background service runs again. Explicit Quit should remain a genuine way to stop active background syncing.

## 15.3 Deployment Baseline

The primary development machine currently runs **macOS 15.7.7**. For the first personal build, Kyle OS should use **macOS 15.0** as the initial minimum deployment target unless implementation evidence gives a reason to lower or raise it.

Using a macOS 15 baseline keeps the first build focused on the user's actual environment and reduces compatibility work while the product is still evolving. If Kyle OS is later distributed to collaborators or the public, the minimum supported macOS version should be reassessed before release.

**Amendment (2026-08-11):** The primary development Mac is Intel-based (MacBookPro16,3, 2020), and Xcode 16+ requires Apple Silicon to run. The last Xcode release that runs on Intel is **Xcode 15.4**, which bundles the macOS 14 (Sonoma) SDK, not the macOS 15 SDK. Per the material-blocker/explicit-approval clause above, the user approved lowering the working minimum deployment target to **macOS 14.0** until development moves to Apple Silicon and Xcode 16+. The app still runs fine on the dev machine's actual macOS 15.7.7. Revisit the macOS 15.0 target once Xcode 16+ is available.

---

# 16. Persistence, Files, Backups, and Recovery

## 16.1 Local Database

Primary structured Kyle OS information should live in SwiftData as the V1 local persistence layer. The data model must preserve relationships, support explicit schema versioning/migrations, remain fast for local use, and leave room for future device synchronization.

OAuth access/refresh credentials and other secrets must not be stored as ordinary SwiftData records. Use the macOS Keychain or another Apple-provided secure credential store.

## 16.2 Stable IDs

All important objects use stable unique identifiers independent of title or list position. Renaming cannot break relationships.

## 16.3 Schema Versioning and Migrations

The local database should have an explicit schema version from Foundation V0. Future app versions should migrate existing user data forward instead of requiring deletion/recreation.

## 16.4 External Files

Large video files remain in their existing locations by default. Kyle OS stores references and can indicate available/missing/disconnected-drive states without destroying metadata.

## 16.5 Export Folder

Kyle OS should have a predictable app-managed export location for generated Script PDFs, Call Sheet PDFs, and future report exports.

## 16.6 Backup

Foundation should support at least a simple manual Back Up Kyle OS action containing the local database, writing data, work history, calendar data, settings, and other app-managed content. External source video files do not need to be copied.

## 16.7 Crash Recovery

On an unclean shutdown, Kyle OS should restore latest autosaved writing and enough timer state to offer resume/end/discard choices for an interrupted session.

## 16.8 Archive Before Delete

Important creative objects should use Archive/Soft Delete by default. Permanent deletion requires deliberate confirmation. Removing relationships must not delete the underlying object.

---

