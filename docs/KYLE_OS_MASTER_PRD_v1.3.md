# KYLE OS — MASTER PRODUCT REQUIREMENTS DOCUMENT

**Version:** 1.3 — Build-Ready Product Definition + Phase Decision Register  
**Date:** August 11, 2026  
**Status:** Source of Truth / Build-Ready PRD  
**Primary Platform:** native macOS app — Swift + SwiftUI, local-first  
**Future Platform:** iPhone companion app

---

# 1. Executive Summary

Kyle OS is a local-first creative operating system for managing a comedy and writing career. It combines daily planning, writing, stand-up material development, video clip production, sketch production, calendar management, content posting, focus timers, progress tracking, and creative-time reporting in one connected Mac application.

Kyle OS is not intended to behave like a generic task manager. Its central job is to answer:

**What should I work on next, given what I am trying to finish and the time I actually have?**

The system should understand that creative work happens in chains. A pilot can move from idea to act outline to scene outline to first draft to later drafts. A sketch can move from writing to filming to editing to posting. A clip moves from source footage to isolation to editing to subtitles to ready to post to posted. Kyle OS should understand those relationships so the user does not have to recreate every next step manually.

The product should remain user-controlled. Kyle OS can recommend, schedule, reschedule, and warn, but the user can always override it.

---

# 2. Product Principles

## 2.1 Creative Operating System, Not Database

Every feature should help the user decide what to work on, make progress, finish work, or release it. If a feature only creates administration without helping creative output move forward, it probably does not belong in the first versions.

## 2.2 Local-First

Version 1 is primarily a Mac application. Core functionality, writing, tasks, calendar data, and reports must remain usable without internet access. Large video files should normally stay in their existing storage locations and be referenced rather than copied into Kyle OS.

## 2.3 Mac First, iPhone Later

The Mac is the primary deep-work environment. A future iPhone companion app should be possible without rebuilding the data model. The future phone app would focus on quick joke capture, task review, deadline review, calendar checks, progress updates, and other lightweight actions.

## 2.4 Autosave by Default

Normal use should not require a Save button. Writing, status changes, scheduling changes, priorities, and settings should persist continuously or near-continuously. Previous drafts and recovery snapshots must protect against accidental overwrite or crashes.

## 2.5 One Source of Truth

The same project or item should not become disconnected copies across different parts of the app. A finished sketch written in Writing should be the same project later shown in Sketches, Calendar, Home, Post It, and Reports.

## 2.6 Modular Development

Kyle OS should be built one stable version at a time on top of a durable foundation. Each version must remain runnable. Later modules extend the same architecture instead of replacing it.

---

# 3. Primary Navigation

The main navigation should contain:

- Home
- Writing
- Stand Up
- Clips
- Sketches
- Calendar
- Reports
- Settings

Home is the default startup screen.

---

# 4. Home Dashboard

## 4.1 Purpose

Home is the command center of Kyle OS. Within seconds, it should answer:

- What should I work on today?
- How much creative time do I realistically have?
- What is due soon?
- What needs to be posted?
- How far along are my active projects?
- What is coming up on the calendar?

Home should query shared underlying data rather than maintain a separate duplicate task database.

## 4.2 Today / Priority View

The default task view should display up to approximately 10 active items. Selection should account for deadline urgency, manual priority, remaining effort, project dependencies, available creative capacity, current progress, and already scheduled work.

A typical task card can show:

- Workspace/category
- Project title
- Current stage
- Progress percentage and visual progress bar
- Planned session duration
- Total project time
- Work date
- Hard deadline if any

Example:

**WRITING — UNTITLED PILOT**  
First Draft — 45% complete  
4h worked total  
Today's session: 45m  
Deadline: Aug. 22

## 4.3 Project Progress Visibility

Home should make progress visible without requiring the project to be opened. Cumulative project time should include all logged work across the project, including outlines, earlier drafts, planning, editing, or other linked stages. Detailed views may still break the total down by stage.

## 4.4 Creative Capacity

Home should show how much realistic creative time is available for the day, how much is already scheduled, and how much remains.

The system should begin with these assumptions:

- Monday–Friday, 8:00 AM–5:00 PM is blocked by the user's day job.
- A normal available day/evening can generally support about 2–3 creative hours.
- A stand-up gig night generally supports about 1 additional creative hour.
- Personal calendar events and all-day time-off events reduce available capacity.
- Daily capacity can be overridden manually.

These values are planning assumptions, not hard restrictions.

## 4.5 All Tasks / Planning View

Home should also contain an All Tasks or Planning view containing every unfinished Work Item across the app. This list should be draggable and manually reorderable.

Dragging changes priority, not just appearance. If a task is moved between tasks on different dates, Kyle OS should attempt to place it into the nearest feasible slot that preserves the new priority order.

## 4.6 Cascade Rescheduling

If there is no spare capacity to insert a newly prioritized item, lower-priority flexible work should move forward to the next available capacity. The cascade continues until everything fits or a protected deadline/commitment prevents it.

Hard deadlines and locked sessions must never silently move. If the new ordering makes a deadline infeasible, Kyle OS must flag the conflict.

## 4.7 Quick Add

Home should provide a simple + Add action for quick capture. Useful options include:

- Task
- Calendar Event
- Joke Idea
- Writing Project
- Clip
- Gig

## 4.8 Active Timer

If a Focus Timer is running, Home should display the current session and elapsed/planned duration. The timer continues while navigating elsewhere in Kyle OS.

## 4.9 Empty or Fully Blocked Days

If nothing is scheduled but capacity exists, Home should recommend a logical task. If the day is fully blocked, it should simply indicate that no creative time is scheduled and move flexible work to later dates as appropriate. The app should not treat intentional rest or personal time as failure.

---

# 5. Focus Timer, Creative Hours, and Progress

## 5.1 Creative Hours

Kyle OS uses Creative Hours to represent estimated focused effort. Each work type can have a configurable default estimate that can be overridden for an individual project/task.

Known initial examples:

- Outline: 1.5 creative hours
- Short Story: 3 creative hours

Other estimates such as script drafting, clip editing, subtitles, sketch editing, and call sheets should be configurable and refined through actual use.

## 5.2 Focus Timer

Every meaningful Work Item should support a shared Focus Timer. Suggested session options:

- 15m
- 30m
- 45m
- 1h
- 1.5h
- Custom

Controls:

- Start
- Pause
- Resume
- Stop
- Finish Session

Paused time does not count as active Creative Time.

## 5.3 Session Goal Behavior

If a 45-minute session is selected, the timer is a session target, not a forced stop. At 45 minutes, Kyle OS should clearly say that today's planned session is complete and offer:

- Finish Session
- Keep Working

If the user stops early, actual elapsed active time is logged. If the user continues, all additional active time is logged.

## 5.4 Progress Tracking

Active work should support a 0–100% internal progress value and a user-facing 1–100% control once work is underway. At the end of a relevant session, Kyle OS asks how complete the current stage is.

Examples:

- Pilot First Draft — 45%
- Clip Editing — 70%
- Scene Outline — 65%

The user's percentage is authoritative. Time spent should not automatically determine progress.

## 5.5 Remaining Effort

Kyle OS should track original estimated effort and estimated remaining effort separately. If an original 3-hour task has already consumed 2 hours but is only 50% finished, the app should recognize that the original estimate was likely too low and revise or ask for an updated remaining estimate.

## 5.6 Project Time

Project cards should show cumulative logged project time. Detailed project views should show stage/document breakdowns.

Example:

- Act Outline — 55m
- Scene Outline — 1h 35m
- First Draft — 3h 15m
- Total Project Time — 5h 45m

---

# 6. Writing Workspace

## 6.1 Purpose

Writing is a full creative workspace inside Kyle OS, not merely a list of documents. The user should be able to create, outline, draft, revise, organize supporting material, track time, track progress, preserve draft history, and export finished work without leaving the application for normal writing activity.

## 6.2 Writing Project Types

V1 should support:

- Sketch
- TV Pilot
- Screenplay
- Short Film
- Short Story
- Other

## 6.3 Writing Home

Writing Home should show active, finished, and idea/not-started projects. Project cards should show title, type, draft/stage, progress, cumulative time, next session/deadline, and last edited information where useful.

## 6.4 Project Containers

A writing project is a container for all related documents.

Example TV Pilot project:

- Act Outline
- Scene Outline
- Pilot Script
- Series Bible
- One Pager
- Notes
- Draft History

Example Sketch project:

- Outline
- Script
- Notes
- Draft History

Short Story projects should use a prose editor while still supporting notes, drafts, deadlines, Creative Hours, work sessions, and related files.

## 6.5 New Project Flow

+ New Writing Project should request a title and project type. Structured script types should ask whether to begin with an outline or skip directly to writing. Outline stages should never be mandatory.

## 6.6 In-App Writing

Writing must happen directly inside Kyle OS. The editor changes based on document type:

- Script mode for pilots, screenplays, short films, and sketches
- Prose mode for short stories and general prose
- Structured outline mode for outlines
- Flexible long-form mode for bibles, one-pagers, and notes

All writing autosaves.

## 6.7 Script Editor Elements

Script mode should support:

- Scene Heading
- Action
- Character
- Dialogue
- Parenthetical
- Transition

Formatting should be keyboard-first and require as little manual formatting as possible. Enter-key behavior should move naturally between common screenplay elements. The editor should offer a visible element selector as a fallback.

## 6.8 Scene Heading Assistance

Scene headings may provide suggestions for:

- INT.
- EXT.
- INT./EXT.
- Known project locations
- Common/previously used times of day

The user can always type manually.

## 6.9 Character Memory

Character names previously used in the project should be suggested when entering a Character block.

## 6.10 Scene Recognition and Navigation

Scene Heading blocks should create recognizable scene objects. A scene navigator should allow jumping between scenes. Visible production scene numbering can remain optional during early drafting.

## 6.11 Layered Outlining

TV Pilot, Screenplay, and Short Film projects should support multiple outline documents, not one single outline.

The most important default workflow is:

**Idea -> High-Level Act Outline -> Detailed Scene Outline -> First Draft -> Later Drafts -> Finished**

The user may skip stages.

### High-Level Act Outline

The Act Outline is broad story architecture. Acts are customizable, renameable, reorderable, addable, and deletable. Kyle OS must not force exactly three acts.

### Scene Outline

Scene Outline entries should support fields such as:

- Act
- Scene Number
- INT./EXT.
- Location / scene heading
- Time of day
- Scene description
- Scene purpose
- Characters
- Key beats
- Notes

Scenes should be draggable within and between Acts. Renumbering should update automatically.

## 6.12 Multiple Outlines Side by Side

The writing workspace should support side-by-side combinations such as:

- Act Outline | Scene Outline
- Scene Outline | Script
- Act Outline | Script

A future three-panel Act Outline | Scene Outline | Script view should remain architecturally possible.

## 6.13 Split View

For scripts, a split view should be optional and resizable. The user can hide the outline for maximum writing space and reopen it without losing panel widths or workspace state.

A future enhancement should allow clicking an outline scene to jump to the associated script scene, and vice versa.

## 6.14 Create Script from Scene Outline

A useful optional workflow should allow a completed Scene Outline to initialize a script structure using scene headings while leaving actual action/dialogue blank.

## 6.15 Drafts

Writing should support unlimited drafts: First Draft, Second Draft, Third Draft, additional/custom drafts, and Finished. Creating a new draft should preserve the prior draft as history. Previous drafts should default to read-only but be duplicable/restorable.

## 6.16 Autosave and Recovery

The writing environment must autosave frequently, save on document/project transitions, and preserve enough recovery information to minimize meaningful loss after a crash. Autosave recovery snapshots should be separate from formal draft history.

## 6.17 Workspace Restoration

Reopening a writing project should restore, where practical:

- Last open document
- Current draft
- Cursor location
- Scroll position
- Split-view state
- Panel widths
- Sidebar state

The goal is to return to the same creative desk.

## 6.18 Writing Sessions

Writing documents/stages use the universal Focus Timer. Untimed writing remains allowed. Manual time can be added if work occurred outside the timer.

## 6.19 Writing Completion and Sketch Handoff

When a project of type Sketch is marked Writing Finished, the same underlying project should automatically become active in Sketches for production. This should not create a disconnected duplicate.

## 6.20 Export

Writing should support clean PDF export. Script exports should contain script content only, without Kyle OS interface, timer, progress, or internal panels. Future formats can include Fountain, Final Draft-compatible formats, and DOCX if useful.

---

# 7. Stand Up Workspace

## 7.1 Purpose

Stand Up is a live material-development workspace rather than a generic notes page. It should support quick capture, development, organization into larger chunks, headline-set construction, gigs, set lists, and time tracking.

## 7.2 Joke Board

The primary development board contains:

- Joke Ideas
- Jokes That Are New
- Jokes That Are Done

Jokes are draggable between stages and reorderable within stages. Moving them updates status automatically.

## 7.3 Quick Joke Capture

+ Joke Idea should require only the idea text. A short title and additional detail can be added later. Home's + Add menu should also support quick Joke Idea capture.

## 7.4 Joke Detail

A Joke can contain title, full material, premise/setup/punchline/tags/alternate wording, notes, time spent, performance notes, development status, optional progress, and approximate runtime. The structure should remain flexible rather than forcing a rigid comedy-writing template.

## 7.5 Joke -> Chunk -> Headline Set Hierarchy

The core stand-up hierarchy is:

**Joke -> Chunk -> Headline Set**

A Joke can exist independently or be referenced inside a Chunk. A Chunk is a larger thematic/story run of related jokes. The Headline Set should primarily be built from ordered Chunks, although loose jokes may also be allowed when useful.

## 7.6 Chunks

A Chunk should support:

- Title
- Notes
- Ordered Joke references
- Development status
- Optional progress
- Estimated/actual runtime
- Time worked

Jokes should be draggable within a Chunk. Removing a Joke from a Chunk should only remove the relationship, not delete the Joke.

## 7.7 Headline Set

The Headline Set represents the evolving album/headlining set. Chunks should be draggable/reorderable. Chunk runtimes roll up into total set runtime.

The Headline Set should support a target duration, such as 60 minutes, and display current runtime versus target.

## 7.8 Gigs

Stand Up should store gigs with date, venue, show, start time, set length, location, and notes. Gigs automatically appear on Calendar and reduce expected Creative Capacity that day.

## 7.9 Gig Set Lists

A Gig may have a planned set list built from existing Chunks and Jokes. Set-list items reference existing material rather than duplicate it. If durations exist, Kyle OS can show the planned set duration versus the gig's target set length.

## 7.10 After-Gig Notes

After a gig, Kyle OS may optionally ask how the set went. Notes can be attached to the gig, individual Jokes, or Chunks. Performance history should remain lightweight in V1.

## 7.11 Stand-Up Work Sessions

The user can start a timed session against a specific Joke/Chunk or a general Stand-Up Writing session. Status is more important than percentage for raw joke development; progress percentage is supplemental.

---

# 8. Clips Workspace

## 8.1 Purpose

Clips is a content-production pipeline that turns source footage into ready-to-post social content.

The core workflow is:

**Source Footage -> Identify Clip -> Isolate -> Edit -> Subtitle if needed -> Ready -> Post**

## 8.2 Source Media

A Source can represent a stand-up set, sketch footage, interview, podcast appearance, or other recorded material. Kyle OS should normally reference the existing local video file instead of copying it.

A Source can store title, recording date, location/venue, notes, and local file reference. If an external drive is disconnected, the source record and clip metadata remain intact and the file is simply shown as unavailable.

## 8.3 Child Clips

One Source can contain many Clip records. Each Clip can have a title, description, source timestamps, notes, editing notes, related Joke/Chunk reference, current status, progress, work time, and post date.

## 8.4 Clip Workflow

Core states:

- Identified / To Isolate
- Footage Isolated
- Currently Editing
- Edited — Not Subtitled
- Edited — Subtitled
- Ready
- Posted

A board can visually simplify these to To Isolate, Editing, Needs Subtitles, Ready, Posted.

## 8.5 Post Date Is the Real Deadline

For Clips, the primary hard deadline is the confirmed social Post Date. Intermediate production stages should normally be flexible work dates generated backward from the Post Date.

Example:

- Friday — Post
- Thursday — Final review/export
- Wednesday — Subtitles
- Tuesday — Edit
- Monday — Isolate

The actual schedule must use available Creative Capacity rather than fixed weekdays.

## 8.6 Backward Scheduling

When a Post Date is confirmed, Kyle OS should activate and schedule every unfinished prerequisite in dependency order. If there is not enough time before the deadline, it should show the shortfall and possible resolutions rather than pretending the plan is feasible.

## 8.7 Ready Queue and Content Buffer

Once required editing/subtitles/export are complete, the Clip becomes Ready. Clips should provide a Ready to Post queue and show the number of finished pieces waiting for release.

Getting ahead should be valuable. Kyle OS should distinguish:

- Production Backlog
- Ready Content Buffer
- Scheduled Posts

## 8.8 Posting Cadence

The user should be able to set a general goal such as 2–3 or 3 posts per week. Kyle OS should suggest open posting dates and avoid unnecessary clustering when possible. Suggested Post Dates can move; confirmed Post Dates become hard deadlines until manually changed.

## 8.9 Mark Posted

On the Post Date, Home's Post It section surfaces the item. The user marks it Posted after publishing. Kyle OS records actual post date and completion history. V1 does not need to automatically upload to social networks.

---

# 9. Sketches Workspace

## 9.1 Purpose

Sketches is primarily a production-management workspace. Writing remains inside Writing. Sketches begins when a Sketch is marked Writing Finished.

The core workflow is:

**Written -> Filming Not Scheduled -> Filming Scheduled -> Filmed -> Editing -> Ready -> Posted**

## 9.2 Writing Handoff

A finished Sketch should appear in Sketches automatically as the same Project, not a copied project.

## 9.3 Film Scheduling

Schedule Film Date should capture:

- Date
- Call time
- Estimated wrap
- Location
- Address
- Cast
- Crew
- Wardrobe
- Props
- Equipment notes
- Parking/access instructions
- General notes

The shoot automatically appears on Calendar and generally acts as a hard calendar commitment once cast/crew/location are involved.

## 9.4 Call Sheet

A scheduled shoot should support generating an editable Call Sheet populated from project data. Fields may include project title, date, call time, wrap time, location/address, cast/characters, crew/roles, wardrobe, props, equipment, parking/access, contact information, scene notes, and additional notes.

## 9.5 Script Access and Email Export

The finished Script should remain accessible from Sketches. Kyle OS should be able to export the Script and Call Sheet as normal PDF files suitable for dragging into an email. If literal drag-to-email can be supported naturally on macOS, it is desirable; otherwise Export for Email is sufficient.

## 9.6 Post-Production

After Mark Filmed, Kyle OS activates Editing. A final Post Date should be requested or confirmed, and editing/subtitles/final review should be scheduled backward from that date similarly to Clips.

Subtitles should be optional per project.

## 9.7 Shared Project Time

Cumulative project time should include Writing and later production/post-production work as one connected history. Filming time may be reported separately from focused Creative Hours.

## 9.8 Post It

When the Sketch is Ready and has a Post Date, it appears in Home -> Post It and counts toward the same overall posting cadence as Clips.

---

# 10. Post It and Publishing

## 10.1 Purpose

Home should contain a dedicated Post It section so content publishing does not disappear among writing/editing tasks.

Each item should show:

- Content title
- Content type
- Scheduled Post Date
- Ready / Not Ready
- Current production stage if not ready
- Platform information if used

## 10.2 States

Useful states include:

- Not Ready
- Ready
- Due Today
- Posted
- Overdue

## 10.3 Ready Buffer

Home should show a useful summary such as:

- Ready to Post: 5
- Scheduled This Week: 3
- Unscheduled Ready Content: 2

## 10.4 Posting Cadence

The posting calendar is shared across Clips and Sketches. Kyle OS may suggest dates to maintain a target cadence, but the user retains final control.

---

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

# 12. Scheduling Engine

## 12.1 Purpose

The Scheduling Engine is one shared system used by all modules. It decides what should happen, when, and for how long based on actual availability and project needs.

The central question is:

**Given everything that needs doing and the time that actually exists, what is the most sensible work to do next?**

## 12.2 Inputs

The engine should consider:

- Hard deadlines
- User-defined priority order
- Task dependencies
- Estimated total and remaining Creative Hours
- Completion percentage
- Available calendar capacity
- Day-job blocks
- Personal Busy time
- Gigs
- Film shoots
- Confirmed Post Dates
- Locked sessions
- Preferred/minimum session lengths
- Whether work can be split
- Actual session overruns/underruns

## 12.3 Work Items

A Work Item is a schedulable unit of creative effort, such as Pilot Scene Outline, Pilot First Draft, Edit Airport Clip, Subtitle Clip, Rewrite Stand-Up Chunk, or Edit Sketch.

A Project can contain many Work Items.

## 12.4 Hard Deadlines vs Work Dates

Hard deadlines are fixed until manually changed. Work dates are flexible scheduling decisions and can move automatically.

## 12.5 Locked Sessions

A manually locked session should not move automatically. When a user intentionally starts a Work Item, the active session is effectively locked until it ends.

## 12.6 Priority Rules

Manual priority matters strongly, but deadline feasibility can override it when necessary. A no-deadline Short Story can be priority #1, but a clip posting tomorrow still receives enough prerequisite work to avoid missing the confirmed deadline.

## 12.7 Task Splitting

Long tasks can be divided across sessions/days. Some task types may define a minimum useful session length and a preferred session length. Deep work should prefer longer uninterrupted blocks; small tasks can fill smaller gaps.

## 12.8 Multi-Task vs Single-Focus Nights

Kyle OS can schedule multiple tasks in one evening when efficient, or dedicate the entire evening to one project when uninterrupted focus is more appropriate. The user can always override the recommendation.

## 12.9 Dependencies

Required prerequisite work cannot be scheduled after dependent work. Optional stages can be skipped manually, after which they stop blocking downstream stages.

## 12.10 Backward Scheduling

For a hard final deadline, the engine should work backward through unfinished dependencies and determine a latest safe completion point for each stage. Where capacity allows, it should create buffer and finish work earlier than the absolute last possible moment.

## 12.11 Cascade Scheduling

Dragging a task upward or introducing urgent work can cause lower-priority flexible sessions to cascade forward into later capacity. Cascading stops or produces a warning if moving work would make a hard deadline infeasible.

## 12.12 Deadline Conflict

If remaining work exceeds available capacity before a deadline, Kyle OS should show:

- Remaining work
- Available capacity
- Shortfall

Possible user actions:

- Increase Creative Capacity
- Move lower-priority work
- Change deadline
- Change remaining estimate
- Work during normally blocked time
- Keep an intentionally overbooked schedule

## 12.13 Overbooking

Kyle OS should allow intentional overbooking but clearly display the amount by which the day/week exceeds known capacity.

## 12.14 Recalculation Triggers

Scheduling should recompute after meaningful changes, including:

- New task/project
- New/change deadline
- Priority drag
- Completion
- Progress/estimate change
- New/remove calendar event
- Capacity override
- Gig or shoot addition
- Post Date change
- Session overrun/underrun
- Missed session

## 12.15 Explainability

If Kyle OS moves a future session, the reason should be inspectable, such as: moved because a higher-priority Clip must be completed before Friday's Post Date.

## 12.16 Auto Scheduling Toggle

Settings should allow automatic scheduling on/off. When off, Kyle OS may still show recommendations but should not automatically move future flexible sessions.

## 12.17 Planning Horizon

Detailed work sessions can initially be generated roughly 1–2 weeks ahead, with longer-term workload visibility beyond that. Very large no-deadline projects should not automatically consume every future free hour.

---

# 13. Reports Workspace

## 13.1 Purpose

Reports explains how creative time is actually being spent and how projects are moving forward. It should be informative, not punitive.

Reports should not create a single productivity score or enforce streaks.

## 13.2 Default Summary

Default period: This Week.

Useful top-level metrics:

- Total Creative Time
- Sessions
- Projects Worked On
- Completed Items
- Content Posted

## 13.3 Date Ranges

Support:

- This Week
- Last Week
- This Month
- Last Month
- Custom Range

Future: year/all time.

## 13.4 Time Breakdowns

Reports should support time by:

- Workspace
- Project
- Activity type
- Stage/document
- Day/week/month

## 13.5 Project Reports

A Project detail report can show total time, stage breakdown, current stage, progress, and progress-over-time history.

## 13.6 Planned vs Actual

Reports should compare planned Creative Hours with actual Creative Hours and planned session length with actual session length.

## 13.7 Estimate Accuracy

Kyle OS should compare default estimates with actual historical completion times. It may suggest updating a default, but must never silently change estimates without user approval.

## 13.8 Active and Stalled Work

Reports can show active projects and optionally surface projects not worked on recently. This is informational and should not treat inactivity as failure.

## 13.9 Stand-Up Reports

Useful data:

- Stand-Up Creative Hours
- Joke ideas created
- Jokes moved to New/Done
- Chunks created
- Headline Set runtime vs target
- Gigs performed
- Time spent on individual material

## 13.10 Clips Reports

Useful data:

- Clips identified, edited, ready, posted
- Editing/subtitle time
- Average production time per clip
- Ready buffer
- Source recordings that generated the most usable clips

## 13.11 Sketch Reports

Useful data:

- Sketches written/filmed/edited/posted
- Writing-to-post turnaround
- Editing time
- Production time
- Full project lifecycle time

## 13.12 Posting Reports

Useful data:

- Posts per week/month
- Target cadence vs actual cadence
- Ready pieces waiting
- Missed planned posts
- Clips vs Sketches posted

## 13.13 Focused Work vs Commitments

Reports should distinguish Focused Creative Hours from production/commitment time such as shoots and on-stage performance time. A broader total career-time view can exist, but these should remain separately understandable.

## 13.14 Data Collection

Reports should require almost no separate data entry. It should calculate from Work Sessions, Projects, status history, posting records, gigs, shoots, and Calendar capacity.

---

# 14. Core Data Model

## 14.1 Project

A Project is the central object for larger creative work such as a TV Pilot, Screenplay, Short Film, Short Story, or Sketch.

Core fields include:

- Permanent unique ID
- Title
- Project Type
- Overall Status (Idea / Active / On Hold / Finished / Archived)
- Created/updated/finished timestamps
- Optional hard deadline
- Manual priority

Total logged time should generally be derived from Work Sessions.

## 14.2 Document

A Document belongs to a Project and represents material such as Script, Prose, Act Outline, Scene Outline, Notes, Series Bible, One Pager, or Custom Document.

Different Document types may store different structured data; Kyle OS should not force everything into a generic text field.

## 14.3 Script Blocks

Script content should ideally be stored as ordered structured blocks with element type, text, order, and optional Scene ID. This enables reliable screenplay formatting and scene navigation.

## 14.4 Act and Scene

Structured scripted projects can contain Act objects and Scene objects. Acts are flexible in number. Scene data can include act, scene number, INT/EXT, location, time of day, heading, description, purpose, characters, key beats, notes, and order.

Act Outline and Scene Outline should eventually share scene relationships with the actual Script.

## 14.5 Draft

A Draft preserves a formal version of a Document. Completed old Drafts should remain immutable by default. Autosave recovery snapshots are separate from user-visible Draft history.

## 14.6 Work Item

A Work Item represents schedulable effort and can store:

- ID
- Related Project/Content
- Workspace
- Work type/stage
- Status
- Progress
- Estimated total/remaining minutes
- Preferred/minimum session length
- Can Split
- Manual priority
- Hard deadline reference
- Dependencies
- Completion date

## 14.7 Planned Session

A Planned Session is future intended work and stores work item, date/time, planned duration, lock state, auto/manual origin, and Scheduled/Completed/Missed/Cancelled status.

## 14.8 Work Session

A Work Session is actual completed effort and stores start/end time, active duration, paused duration, planned duration, progress before/after, optional note, and Timer/Manual entry type.

Historical completed sessions must never be rewritten by future rescheduling.

## 14.9 Calendar Event

For externally synchronized calendar events, Calendar Event should also be capable of storing source metadata such as provider, external calendar ID, external event ID, last synchronized timestamp, and local/external modification state. These fields should not be required for Kyle OS-only events.

A Calendar Event represents a time commitment and can link to a Gig, Shoot, Deadline, Posting Item, or Work Item. Core fields include event type, start/end, all-day state, availability, hard commitment, lock state, linked object, notes, and location.

## 14.10 Deadline

A Deadline stores related object, type, date/time, hard/suggested state, confirmation state, and notes.

## 14.11 Joke

A Joke is a dedicated Stand-Up object with title, joke text, status, optional progress, notes, runtime, priority, timestamps, and archive state.

## 14.12 Chunk

A Chunk groups Joke references with title, notes, development status, runtime, optional progress/time tracking, and order. Membership should preserve Joke IDs instead of duplicating text.

## 14.13 Headline Set

A Headline Set contains ordered Chunk references, a title, target runtime, and notes. Runtime is derived from members.

## 14.14 Gig

A Gig stores show, venue, location, date, start time, set length, notes, and linked Calendar Event. Gig Set Lists reference existing Jokes/Chunks.

## 14.15 Source Media

A Source Media object stores source recording metadata and a file reference rather than necessarily copying the file.

## 14.16 Clip

A Clip belongs to Source Media and stores title, description, timestamps, status, progress, post deadline, optional related Joke/Chunk, notes, and editing notes. It generates linked Work Items for production stages.

## 14.17 Sketch Production / Shoot / Call Sheet

Sketch production belongs to the same Sketch Project. A Shoot stores date, times, location, notes, cast/crew relationships, and Calendar Event. Call Sheet is structured editable data populated from Shoot/Cast/Crew before PDF export.

## 14.18 Posting Item

Clips and Sketches should share a Posting Item model where practical. It stores related content, suggested/confirmed post date, ready state, posting status, platform information, and actual posted date.

Home's Post It view should query these items instead of maintaining another list.

## 14.19 Status and Progress History

Important status changes and progress changes should create history records with timestamps. This enables turnaround and progress-over-time reporting.

## 14.20 Settings and Work Type Defaults

Settings include day-job schedule, Creative Capacity, posting target, Auto Scheduling, and editable Work Type Defaults such as default estimate, preferred session length, minimum session length, and whether work can be split.

---

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

# 20. V1 Non-Goals

The first complete version does not need to:

- Automatically post to social media
- Replace Premiere/Final Cut or other video editors
- Replace email
- Recreate every feature of Final Draft or WriterDuet
- Require AI
- Require internet/cloud accounts
- Ship the iPhone companion immediately
- Provide sophisticated social analytics
- Become a general-purpose project management suite

Future integrations can be considered after the core creative workflow proves useful.

---

# 21. Future Possibilities

Potential later additions include:

- iPhone companion app
- Cross-device/cloud synchronization
- Additional calendar providers such as Apple Calendar
- Smarter prediction based on historical workload
- AI-assisted organization or writing support
- Joke tags/search
- Script version comparison
- Social-platform links/integrations
- Posting analytics
- Three-panel writing workspace
- Multi-camera TV formatting
- Advanced production scene numbering
- Rehearsal timers
- Global search
- Report export to CSV/PDF

## 21.1 Future Shared Hub

Kyle OS should eventually support a **Shared Hub** for selected collaborative Writing and Sketch projects. This is a post-V1 feature, but Foundation architecture must avoid choices that would make collaboration require rebuilding core models.

Every collaborator should have the complete Kyle OS application and their own private creative environment. Sharing one project does **not** expose the owner's full Kyle OS database. Everything is private until deliberately shared.

A shared Writing project may eventually include the same logical Project container, documents, Act Outlines, Scene Outlines, scripts, drafts, Series Bible, One Pager, shared notes, project status, and relevant project files across authorized users. A shared Sketch may additionally include shoot scheduling, Call Sheets, cast/crew information, production notes, editing status, Ready status, and Post status.

Future architecture should therefore preserve room for:

- Stable User IDs
- Project ownership
- Shared Project identity
- Owner / Editor / Viewer permissions
- Revision/change history with user attribution
- Shared vs private project data where needed
- Offline editing
- Synchronization state
- Conflict detection and recovery
- A future Sync Service isolated from the core UI/domain model

Shared project deadlines, shoots, table reads, and explicit collaborative work sessions may be common commitments. Each person's unrelated Calendar, private work sessions, Reports, Clips, Stand Up material, and other projects remain private.

Collaboration should preserve Kyle OS's local-first philosophy: private work remains private/local by default, while only explicitly shared objects synchronize through a future shared/cloud layer.

These future capabilities should not delay the stable V1 baseline.

---

# 22. Definition of Product Success

Kyle OS is successful when the user can open the application and immediately understand:

- What needs attention today
- How much time is realistically available
- What is due soon
- What is currently being written
- What jokes/chunks are being developed
- What is being filmed or edited
- What is ready to post
- What should be posted and when
- How far along active projects are
- How much time has gone into them
- Where creative time has been spent

The long-term workflow is:

**Decide -> Work -> Track -> Finish -> Release -> Learn -> Repeat**

---

# 23. Current PRD Assessment

## 23.1 Overall Assessment

This is a strong pre-build PRD. The product has a clear purpose, coherent modules, consistent shared concepts, a scheduling philosophy, a data model, and an incremental implementation strategy. The strongest design decision is that Kyle OS is built around connected creative workflows rather than disconnected tasks.

The PRD is detailed enough to begin Foundation V0 without needing to redesign the product first.

## 23.2 Strongest Areas

### Clear Product Identity

Kyle OS has a defined job: convert creative ambitions and deadlines into realistic daily action. That is substantially stronger than building a collection of generic productivity screens.

### Cross-Module Logic

Writing, Sketches, Clips, Calendar, Home, Post It, Stand Up, and Reports are intentionally connected through shared underlying objects. This will prevent duplicated data and reduce manual administration.

### Scheduling Model

The distinction between Hard Deadlines, flexible Work Dates, locked sessions, Creative Capacity, dependencies, priority, and cascade scheduling gives the application a coherent planning model rather than a vague "smart schedule" requirement.

### Writing Workspace

The Writing design is particularly strong: in-app writing, autosave, multiple outline layers, split view, scene-level structure, drafts, and progress/time tracking form a useful workspace without requiring Kyle OS to reproduce every professional screenwriting feature immediately.

### Build Strategy

The decision to create Foundation V0 and then add one working module at a time is the right risk-control strategy. It fits iterative/vibe coding well and creates clear rollback points.

## 23.3 Main Risks

### Scope

The ideal Kyle OS is a substantial application. The PRD solves this by explicitly separating Foundation and module versions, but development discipline will matter. Each version should resist "just one more feature" until its acceptance tests pass.

### Script Editor Complexity

Reliable screenplay editing is likely the most technically difficult individual user-interface component. The first implementation should focus on clean structured screenplay blocks, keyboard flow, autosave, and PDF output before attempting perfect Final Draft-level pagination or compatibility.

### Scheduling Engine Complexity

The Scheduling Engine is conceptually well defined but can become complicated quickly. Delaying the intelligent engine until real Work Items and Calendar data exist is important. V0.7 should start with deterministic rules before adding optimization sophistication.

### Local File References

macOS permissions and external-drive file references need careful implementation so references remain useful without causing the app to copy large media. This should be tested early in Foundation even though the full Clips interface comes later.

### Google Calendar Synchronization

Full two-way external calendar synchronization introduces OAuth, conflict resolution, recurring-event behavior, offline changes, duplicate prevention, background refresh, and source-of-truth questions. V0.6 should first make the local Calendar stable, then add Google sync behind a dedicated integration layer. Automatic creative scheduling may create and move Kyle OS-owned events in Google Calendar, but must never directly mutate unrelated personal Google events.

### Data Safety

Because Kyle OS will eventually contain original writing, jokes, and project history, autosave, backups, migrations, and recovery should be treated as product features rather than implementation details.

## 23.4 Still To Decide During Implementation

The native application stack, local persistence direction, Google Calendar two-way integration, notification philosophy, and initial macOS deployment baseline are now locked. Remaining choices are phase-specific rather than reasons to delay Foundation:

- Distribution path: initially personal/private, later direct collaborator distribution, Mac App Store, or another signed/notarized path.
- Exact rich-text/script-editor implementation and early screenplay pagination fidelity.
- Exact algorithm/weighting for scheduling priority once real workload data exists.
- Precise default Creative Hour values beyond known examples.
- Exact visual design/theme.
- Exact backup file format and later shared/cloud sync technology.
- Exact implementation timing for the background sync/login-item service; the architecture should support it even if the first Foundation build uses simpler app-running behavior.

These should be answered only where they materially affect the phase being built. They do not justify reopening the overall product design.

## 23.5 Phase Decision Register

The following decisions are intentionally **not** being locked before Foundation. Each has a defined phase where it must be answered before the affected implementation proceeds. This prevents premature technical choices while ensuring no important question is forgotten.

### Decision Gate A — Screenplay Editor Implementation

**Must be resolved during:** V0.2 — Writing Workspace, before production implementation of the Script Editor.

Questions to answer:

- What native editing architecture should power the screenplay editor: SwiftUI text components, an AppKit/TextKit-based editor wrapped for SwiftUI, or another carefully evaluated native approach?
- How should structured screenplay blocks behave during typing, deletion, paste, undo/redo, and element changes?
- What level of screenplay pagination accuracy is required for the first implementation?
- What PDF/export fidelity is required for V0.2?
- Which professional interchange formats, if any, should be deferred until after V1?
- How should scene navigation, character autocomplete, scene-heading autocomplete, and keyboard transitions behave in the first usable version?

The decision should prioritize writing reliability, autosave safety, keyboard flow, and maintainable structured data before attempting Final Draft-level feature parity.

### Decision Gate B — Scheduling Engine Weighting

**Must be resolved during:** V0.7 — Scheduling Engine, after Kyle OS contains real Work Items, Calendar data, and several weeks of realistic usage where possible.

Questions to answer:

- Should the first scheduler use an ordered deterministic rule system, numeric weighting, or a hybrid?
- How much relative influence should hard-deadline urgency, manual priority, dependencies, remaining effort, Creative Capacity, progress, preferred session length, and context switching have?
- What tie-breakers should apply when multiple tasks are equally viable?
- How aggressively should flexible work cascade when new priority work is inserted?
- How much safety buffer should be preserved before deadlines?
- When should Kyle OS concentrate heavily on one urgent project versus continue progressing several projects?
- How should historical actual-vs-estimated performance influence recommendations without silently changing user preferences?

The initial engine should remain deterministic, explainable, manually overridable, and testable.

### Decision Gate C — Final Visual Design

**Must be resolved during:** V1.0 — Integration & UX Pass. A consistent baseline component system should exist from Foundation, but final visual identity is deliberately deferred until the workflows are proven.

Questions to answer:

- Final colour palette and accent treatment.
- Typography hierarchy.
- Information density.
- Sidebar and navigation treatment.
- Card, list, progress, timer, and calendar visual language.
- Light-mode and dark-mode behaviour.
- Motion/animation level.
- How much visual personality Kyle OS should have while remaining calm and focused for long writing sessions.

The final design should polish proven workflows rather than forcing workflows to fit an early visual concept.

### Decision Gate D — Shared Hub Cloud Technology

**Must be resolved during:** the post-V1 Shared Hub implementation phase, before multi-user synchronization is built.

Questions to answer:

- CloudKit versus a custom backend or another current sync platform.
- User identity and authentication model.
- Shared Project ownership and permission enforcement.
- Offline synchronization strategy.
- Conflict resolution for simultaneous script/outline edits.
- Revision history and recovery requirements.
- Security/privacy model for private versus shared project data.
- Operational cost, maintenance burden, and scalability.
- How Google Calendar collaboration and Shared Hub identities should relate.

Foundation must preserve stable IDs, ownership-ready models, timestamps, revision metadata, and a SyncService boundary so this choice can be made later without rebuilding the core application.

### Decision Gate E — Distribution Method

**Must be resolved during:** V1.0 release preparation before Kyle OS is distributed beyond the primary development Mac.

Questions to answer:

- Personal/private installation only, direct signed/notarized distribution, Mac App Store, or another supported distribution route.
- Whether an Apple Developer Program membership is required at that stage.
- App Sandbox and entitlement requirements.
- Google OAuth configuration implications for the chosen distribution model.
- Update mechanism for non-App-Store distribution, if applicable.
- Signing, notarization, privacy disclosures, and packaging requirements.

Foundation development should avoid unnecessarily blocking future sandboxed or notarized distribution, but packaging decisions should not delay the first personal build.

### Other Phase-Local Decisions

Other smaller open choices already identified in this PRD should be answered when their relevant phase begins, including precise Creative Hour defaults, backup format, and the exact background/login-item implementation for continuous Google Calendar synchronization. These are not blockers for Foundation.

## 23.6 Readiness

**Foundation V0: Ready to build. Distribution packaging can be decided later because it does not block the first personal development build.**

**Home V0.1: Product requirements are ready; build after Foundation passes.**

**Writing V0.2: Product requirements are strong, but technical editor choices should be made before implementation.**

**Scheduling V0.7: Product logic is defined, but implementation should wait for real application data and usage patterns.**

The PRD is therefore at the correct level for the current stage: detailed enough to start engineering, but still flexible enough to evolve based on actual use.

---

# 24. Final Product Rule

Every major feature should pass this test:

**Does this help me understand what to work on, actually work on it, finish it, or release it?**

If not, it probably does not belong in the current version of Kyle OS.
