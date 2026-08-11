# Google Calendar Integration Requirements

**Future implementation phase: V0.6 Calendar.** This document exists so Foundation does not make choices that block the eventual integration. Do not implement the full integration during V0.

# 11. Calendar Workspace

## 11.1 Purpose

Calendar is the time-management backbone of Kyle OS. It combines creative commitments and real-life commitments so the scheduling system works with the user's actual availability.

## 11.2 Views

Primary V1 view: Month. Week is highly desirable. Day view can follow.

The Home calendar uses the same data source as the Calendar workspace.

## 11.3 Event Types

Calendar should support:

- Personal Event
- Unavailable / Time Off
- Day Job
- Stand-Up Gig
- Film Shoot
- Hard Deadline
- Post Date
- Creative Work Session

## 11.4 Day Job

Monday–Friday, 8 AM–5 PM is blocked by default. Individual days can be overridden for vacation or unusual availability.

## 11.5 Personal Time

The user can book appointments, dinners, travel, cottage weekends, vacations, errands, dates, family plans, social events, and general unavailable time. These events reduce Creative Capacity.

V1 availability types:

- Busy
- Available

Future:

- Flexible

## 11.6 Daily Capacity Overrides

The user can override a day's expected Creative Capacity, including setting it to zero or increasing it for a free day.

## 11.7 Shared Events

Events created by modules must be the same underlying Calendar Event. Editing a Gig date in Calendar updates Stand Up; changing it in Stand Up updates Calendar.

## 11.8 Flexible Work vs Hard Events

Creative work sessions can normally move. Hard deadlines, gigs, shoots, and locked sessions require explicit confirmation before moving.

## 11.9 Scheduled Work Session Actions

Opening a Creative Work Session should allow Start Working, Reschedule, Change Duration, or Open Project.

## 11.10 Missed, Partial, and Overrun Sessions

A missed flexible session returns its remaining effort to the scheduling pool. A partial session records actual time and reschedules the remainder if needed. An overrun reduces remaining daily capacity and may move lower-priority future work.

## 11.11 Google Calendar Integration

Google Calendar is the primary external calendar integration for Kyle OS and should operate as a true two-way synchronization layer rather than a one-time import. Kyle OS keeps its own local Calendar model for offline-first operation, but connected Google calendars and Kyle OS calendar items remain linked and synchronized.

The intended relationship is:

**Google Calendar <-> Kyle OS Calendar <-> Scheduling Engine**

The integration should use the Google Calendar API with OAuth 2.0 user authorization. Google access and refresh credentials must be stored securely using the macOS Keychain rather than as ordinary SwiftData fields.

Minimum V0.6 behavior:

- Connect/disconnect a Google Account from Settings.
- Allow the user to select multiple Google calendars that Kyle OS should consider.
- Import Google events with title, start/end time, all-day state, location, description where appropriate, recurrence information, busy/free state, calendar identifier, and provider event identifier.
- Treat selected Busy events as real scheduling constraints unless the user changes how a calendar is interpreted.
- Perform an initial full synchronization and retain provider sync metadata for efficient incremental synchronization afterward.
- Handle Google-side edits, moves, recurrence changes, and deletions without creating duplicate Kyle OS events.
- Create and edit Google Calendar events from Kyle OS.
- Maintain a stable link between a Kyle OS Calendar Event and its corresponding Google event so edits from either side reconcile to the same logical event.
- Allow the user to choose the Google calendar used for Kyle OS-created events. A dedicated **Kyle OS** Google calendar is the preferred default for automatically scheduled creative work.
- Allow Kyle OS-created Gigs, Film Shoots, writing sessions, editing sessions, deadlines, Post Dates, and other selected commitments to appear in Google Calendar.
- When the Scheduling Engine moves a flexible Kyle OS session, update the existing Google event rather than creating a duplicate.
- When the user moves a linked creative session in Google Calendar, sync the new time into Kyle OS and recalculate Creative Capacity and downstream scheduling as needed.

Kyle OS remains local-first. Previously synchronized events remain visible while offline. Local changes should be queued and reconciled when connectivity returns where technically appropriate.

The system should distinguish events that Kyle OS owns from externally originated events. Automatic scheduling may move Kyle OS-owned flexible Creative Work, but it must never silently move unrelated personal Google Calendar events.

### 11.11.1 Future Collaborative Availability

Future Shared Hub collaboration should allow each participant to authorize their own Google calendars for availability. Kyle OS should be able to search authorized free/busy availability across collaborators without exposing private event titles or details.

For a shared Writing or Sketch project, Kyle OS should eventually support actions such as **Schedule Writing Session**, **Schedule Table Read**, **Schedule Rehearsal**, or **Schedule Shoot**. The system should:

1. Determine the requested duration and date range.
2. Check each participant's authorized free/busy availability.
3. Suggest mutually available time slots.
4. Allow the organizer to confirm a slot.
5. Create a shared Google Calendar event with the relevant collaborators invited.
6. Link that Google event to the shared Kyle OS project.

Shared project commitments may therefore appear on each collaborator's calendar while unrelated personal calendar details remain private. Personal work sessions continue to be scheduled independently for each user's own availability unless a session is explicitly collaborative.

---

